extends Node

class FakeEntitlements:
    extends RefCounted
    var owned := {
        "full_game_unlock": false,
        "supporter_cosmetic_pack": false,
    }
    var purchase_apply_count := 0
    var snapshot_apply_count := 0

    func apply_purchase_result(result: Dictionary) -> bool:
        if not bool(result.get("ok", false)):
            return false
        var product_id := str(result.get("product_id", ""))
        if not owned.has(product_id):
            return false
        owned[product_id] = true
        purchase_apply_count += 1
        return true

    func apply_authoritative_snapshot(purchases: Array, _source: String = "") -> Dictionary:
        for product_id in owned.keys():
            owned[product_id] = false
        for purchase_variant in purchases:
            if typeof(purchase_variant) != TYPE_DICTIONARY:
                continue
            var product_id := str((purchase_variant as Dictionary).get("product_id", ""))
            if owned.has(product_id) and bool((purchase_variant as Dictionary).get("owned", true)):
                owned[product_id] = true
        snapshot_apply_count += 1
        return summary()

    func summary() -> Dictionary:
        return {
            "full_game": bool(owned["full_game_unlock"]),
            "supporter_cosmetics": bool(owned["supporter_cosmetic_pack"]),
        }


class FakeStore:
    extends RefCounted
    signal store_ready()
    signal product_details_received(response: Dictionary)
    signal purchases_received(response: Dictionary)
    signal purchase_updated(response: Dictionary)
    signal store_error(code: String, message: String)

    var products := ["full_game_unlock", "supporter_cosmetic_pack"]
    var owned_purchases: Array = []
    var online := true
    var start_count := 0
    var restore_queries := 0
    var purchase_launches: Array[String] = []

    func start() -> bool:
        start_count += 1
        if not online:
            store_error.emit("offline", "")
            return false
        store_ready.emit()
        return true

    func query_products(_product_ids: Array[String]) -> bool:
        if not online:
            product_details_received.emit({"ok": false, "error": "offline"})
            return false
        product_details_received.emit({"ok": true, "product_ids": products.duplicate()})
        return true

    func query_owned_purchases() -> bool:
        restore_queries += 1
        if not online:
            purchases_received.emit({"ok": false, "error": "offline"})
            return false
        purchases_received.emit({"ok": true, "purchases": owned_purchases.duplicate(true)})
        return true

    func launch_purchase(product_id: String) -> Dictionary:
        if not online:
            return {"ok": false, "error": "offline"}
        purchase_launches.append(product_id)
        return {"ok": true, "pending_callback": true}

    func emit_purchase(purchase: Dictionary) -> void:
        purchase_updated.emit({"ok": true, "purchases": [purchase]})


class FakeVerifier:
    extends RefCounted
    signal verification_completed(result: Dictionary)

    var requests: Array[Dictionary] = []
    var reject_tokens: Dictionary = {}
    var unacknowledged_tokens: Dictionary = {}

    func verify_purchase(payload: Dictionary) -> bool:
        requests.append(payload.duplicate(true))
        var token := str(payload.get("purchase_token", ""))
        var product_id := str(payload.get("product_id", ""))
        verification_completed.emit({
            "ok": not bool(reject_tokens.get(token, false)),
            "purchase_token": token,
            "product_id": product_id,
            "owned": true,
            "purchase_state": "PURCHASED",
            "acknowledged": not bool(unacknowledged_tokens.get(token, false)),
            "source": "play_backend",
        })
        return true


var failures: Array[String] = []
var store := FakeStore.new()
var verifier := FakeVerifier.new()
var entitlements := FakeEntitlements.new()
var billing := PlayBillingCoordinator.new()
var pending_products: Array[String] = []
var failed_products: Array[String] = []
var granted_products: Array[String] = []
var restores: Array[Dictionary] = []


func _ready() -> void:
    billing.purchase_pending.connect(func(product_id: String): pending_products.append(product_id))
    billing.purchase_failed.connect(func(product_id: String, reason: String): failed_products.append("%s:%s" % [product_id, reason]))
    billing.entitlement_granted.connect(func(product_id: String): granted_products.append(product_id))
    billing.restore_completed.connect(func(ok: bool, summary: Dictionary): restores.append({"ok": ok, "summary": summary.duplicate(true)}))

    _configuration_and_catalog_gate()
    _pending_never_grants_gate()
    _verification_failure_never_grants_gate()
    _acknowledgement_required_gate()
    _verified_purchase_grants_gate()
    _authoritative_restore_gate()
    _partial_restore_failure_preserves_cache_gate()
    _invalid_package_never_reaches_backend_gate()
    _finish()


func _configuration_and_catalog_gate() -> void:
    var configured := billing.configure(store, verifier, entitlements)
    expect(bool(configured.get("ok", false)), "12.4 coordinator configuration failed")
    expect(billing.start(), "12.4 coordinator start failed")
    expect(billing.products_ready(), "12.4 product catalog did not become ready")
    expect(store.start_count == 1, "12.4 store started unexpected number of times")
    expect(store.restore_queries == 1, "12.4 connection did not trigger authoritative restore")
    expect(restores.size() == 1 and bool(restores[0].get("ok", false)), "12.4 startup empty authoritative restore failed")


func _pending_never_grants_gate() -> void:
    var before_requests := verifier.requests.size()
    var before_apply := entitlements.purchase_apply_count
    store.emit_purchase(_purchase("full_game_unlock", "pending-1", "PENDING"))
    expect("full_game_unlock" in pending_products, "12.4 PENDING purchase did not surface pending state")
    expect(verifier.requests.size() == before_requests, "12.4 PENDING purchase reached backend verification")
    expect(entitlements.purchase_apply_count == before_apply, "12.4 PENDING purchase granted entitlement")
    expect(not bool(entitlements.summary().full_game), "12.4 PENDING purchase owns full game")


func _verification_failure_never_grants_gate() -> void:
    verifier.reject_tokens["reject-1"] = true
    var before_apply := entitlements.purchase_apply_count
    store.emit_purchase(_purchase("full_game_unlock", "reject-1", "PURCHASED"))
    expect(entitlements.purchase_apply_count == before_apply, "12.4 rejected backend verification granted entitlement")
    expect(not bool(entitlements.summary().full_game), "12.4 rejected purchase owns full game")
    expect(_has_failure("full_game_unlock", "backend_verification_failed"), "12.4 rejected purchase did not emit backend failure")


func _acknowledgement_required_gate() -> void:
    verifier.unacknowledged_tokens["unacked-1"] = true
    var before_apply := entitlements.purchase_apply_count
    store.emit_purchase(_purchase("supporter_cosmetic_pack", "unacked-1", "PURCHASED"))
    expect(entitlements.purchase_apply_count == before_apply, "12.4 unacknowledged verification granted entitlement")
    expect(not bool(entitlements.summary().supporter_cosmetics), "12.4 unacknowledged purchase owns supporter pack")


func _verified_purchase_grants_gate() -> void:
    store.emit_purchase(_purchase("full_game_unlock", "verified-1", "PURCHASED"))
    expect(bool(entitlements.summary().full_game), "12.4 verified purchase did not grant full game")
    expect("full_game_unlock" in granted_products, "12.4 verified purchase did not emit grant event")
    expect(verifier.requests.back().application_id == "com.pmartins87.veredasdatrama", "12.4 verifier request application id mismatch")
    expect(verifier.requests.back().purchase_token == "verified-1", "12.4 verifier request token mismatch")


func _authoritative_restore_gate() -> void:
    entitlements.owned["supporter_cosmetic_pack"] = true
    store.owned_purchases = [_purchase("full_game_unlock", "restore-full", "PURCHASED")]
    expect(billing.restore(), "12.4 explicit restore did not launch")
    expect(bool(entitlements.summary().full_game), "12.4 authoritative restore lost verified full game")
    expect(not bool(entitlements.summary().supporter_cosmetics), "12.4 authoritative restore failed to revoke absent supporter entitlement")
    expect(bool(restores.back().get("ok", false)), "12.4 authoritative restore did not report success")


func _partial_restore_failure_preserves_cache_gate() -> void:
    entitlements.owned["full_game_unlock"] = true
    entitlements.owned["supporter_cosmetic_pack"] = true
    var snapshot_count := entitlements.snapshot_apply_count
    verifier.reject_tokens["restore-reject"] = true
    store.owned_purchases = [
        _purchase("full_game_unlock", "restore-ok", "PURCHASED"),
        _purchase("supporter_cosmetic_pack", "restore-reject", "PURCHASED"),
    ]
    expect(billing.restore(), "12.4 partial-failure restore did not launch")
    expect(not bool(restores.back().get("ok", true)), "12.4 partial verification failure reported restore success")
    expect(entitlements.snapshot_apply_count == snapshot_count, "12.4 partial verification failure applied destructive snapshot")
    expect(bool(entitlements.summary().full_game), "12.4 partial verification failure revoked cached full game")
    expect(bool(entitlements.summary().supporter_cosmetics), "12.4 partial verification failure revoked cached supporter pack")


func _invalid_package_never_reaches_backend_gate() -> void:
    var before_requests := verifier.requests.size()
    var bad := _purchase("full_game_unlock", "bad-package", "PURCHASED")
    bad.package_name = "com.example.impostor"
    store.emit_purchase(bad)
    expect(verifier.requests.size() == before_requests, "12.4 wrong-package purchase reached verifier")
    expect(_has_failure("full_game_unlock", "verification_request_rejected"), "12.4 wrong-package purchase did not fail closed")


func _purchase(product_id: String, token: String, state: String) -> Dictionary:
    return {
        "product_ids": [product_id],
        "purchase_token": token,
        "package_name": "com.pmartins87.veredasdatrama",
        "purchase_state": state,
        "purchase_time": 1786540000000,
        "is_acknowledged": false,
    }


func _has_failure(product_id: String, reason: String) -> bool:
    return "%s:%s" % [product_id, reason] in failed_products


func _finish() -> void:
    if failures.is_empty():
        print(
            "PLAY_BILLING_COORDINATOR_CERTIFICATION PASS: 12.4 pending_no_grant=1 verify_fail_no_grant=1 ack_required=1 verified_grant=1 authoritative_restore=1 partial_failure_cache_safe=1 package_guard=1"
        )
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAY_BILLING_COORDINATOR_CERTIFICATION: %s" % failure)
    print("PLAY_BILLING_COORDINATOR_CERTIFICATION FAIL: %d" % failures.size())
    get_tree().quit(1)


func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
