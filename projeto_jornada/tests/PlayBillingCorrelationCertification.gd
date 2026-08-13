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
            var row := purchase_variant as Dictionary
            var product_id := str(row.get("product_id", ""))
            if owned.has(product_id) and bool(row.get("owned", true)):
                owned[product_id] = true
        snapshot_apply_count += 1
        return summary()

    func summary() -> Dictionary:
        return {
            "full_game": bool(owned["full_game_unlock"]),
            "supporter_cosmetics": bool(owned["supporter_cosmetic_pack"]),
        }


class DeferredStore:
    extends RefCounted
    signal store_ready()
    signal product_details_received(response: Dictionary)
    signal purchases_received(response: Dictionary)
    signal purchase_updated(response: Dictionary)
    signal store_error(code: String, message: String)

    var products := ["full_game_unlock", "supporter_cosmetic_pack"]
    var owned_purchases: Array = []

    func start() -> bool:
        store_ready.emit()
        return true

    func query_products(_product_ids: Array[String]) -> bool:
        product_details_received.emit({"ok": true, "product_ids": products.duplicate()})
        return true

    func query_owned_purchases() -> bool:
        purchases_received.emit({"ok": true, "purchases": owned_purchases.duplicate(true)})
        return true

    func launch_purchase(_product_id: String) -> Dictionary:
        return {"ok": true, "pending_callback": true}

    func emit_purchase(purchase: Dictionary) -> void:
        purchase_updated.emit({"ok": true, "purchases": [purchase]})


class DeferredVerifier:
    extends RefCounted
    signal verification_completed(result: Dictionary)

    var requests: Array[Dictionary] = []

    func verify_purchase(payload: Dictionary) -> bool:
        requests.append(payload.duplicate(true))
        return true

    func respond(index: int) -> void:
        if index < 0 or index >= requests.size():
            return
        var payload := requests[index]
        verification_completed.emit({
            "verification_request_id": str(payload.get("verification_request_id", "")),
            "ok": true,
            "purchase_token": str(payload.get("purchase_token", "")),
            "product_id": str(payload.get("product_id", "")),
            "owned": true,
            "purchase_state": "PURCHASED",
            "acknowledged": true,
            "source": "play_backend",
        })


var failures: Array[String] = []
var store := DeferredStore.new()
var verifier := DeferredVerifier.new()
var entitlements := FakeEntitlements.new()
var billing := PlayBillingCoordinator.new()
var restores: Array[Dictionary] = []
var coordinator_errors: Array[String] = []


func _ready() -> void:
    billing.restore_completed.connect(
        func(ok: bool, summary: Dictionary):
            restores.append({"ok": ok, "summary": summary.duplicate(true)})
    )
    billing.coordinator_error.connect(func(code: String): coordinator_errors.append(code))

    var configured := billing.configure(store, verifier, entitlements)
    expect(bool(configured.get("ok", false)), "12.4 correlation test could not configure coordinator")
    expect(billing.start(), "12.4 correlation test could not start coordinator")
    expect(billing.products_ready(), "12.4 correlation test product catalog not ready")

    _overlapping_purchase_restore_gate()
    _stale_restore_response_isolation_gate()
    _finish()


func _overlapping_purchase_restore_gate() -> void:
    var request_start := verifier.requests.size()
    var restore_start := restores.size()
    var snapshot_start := entitlements.snapshot_apply_count
    var purchase := _purchase("full_game_unlock", "shared-token")

    store.emit_purchase(purchase)
    expect(verifier.requests.size() == request_start + 1, "12.4 purchase did not create verification request")

    store.owned_purchases = [purchase]
    expect(billing.restore(), "12.4 overlapping restore did not launch")
    expect(verifier.requests.size() == request_start + 2, "12.4 restore reused purchase verification instead of creating its own request")
    expect(billing.pending_verification_count() == 2, "12.4 overlapping purchase/restore requests collapsed by token")
    expect(entitlements.snapshot_apply_count == snapshot_start, "12.4 overlapping restore applied snapshot before verification")

    var purchase_request_id := str(verifier.requests[request_start].get("verification_request_id", ""))
    var restore_request_id := str(verifier.requests[request_start + 1].get("verification_request_id", ""))
    expect(not purchase_request_id.is_empty(), "12.4 purchase verification request id missing")
    expect(not restore_request_id.is_empty(), "12.4 restore verification request id missing")
    expect(purchase_request_id != restore_request_id, "12.4 purchase and restore share verification request id")

    verifier.respond(request_start)
    expect(bool(entitlements.summary().full_game), "12.4 verified purchase did not grant while restore remained pending")
    expect(billing.pending_verification_count() == 1, "12.4 purchase response consumed restore request")
    expect(restores.size() == restore_start, "12.4 restore completed on purchase-context response")
    expect(entitlements.snapshot_apply_count == snapshot_start, "12.4 purchase response caused premature authoritative snapshot")

    verifier.respond(request_start + 1)
    expect(billing.pending_verification_count() == 0, "12.4 restore verification remained pending after matching response")
    expect(restores.size() == restore_start + 1, "12.4 restore did not complete after its own response")
    expect(bool(restores.back().get("ok", false)), "12.4 overlapping restore completed as failure")
    expect(entitlements.snapshot_apply_count == snapshot_start + 1, "12.4 authoritative snapshot count mismatch after overlap")
    expect(bool(entitlements.summary().full_game), "12.4 overlapping restore lost verified entitlement")


func _stale_restore_response_isolation_gate() -> void:
    entitlements.owned["full_game_unlock"] = true
    entitlements.owned["supporter_cosmetic_pack"] = true
    var purchase := _purchase("full_game_unlock", "restart-token")
    store.owned_purchases = [purchase]

    var request_start := verifier.requests.size()
    var restore_start := restores.size()
    var snapshot_start := entitlements.snapshot_apply_count

    expect(billing.restore(), "12.4 first restart-race restore did not launch")
    expect(verifier.requests.size() == request_start + 1, "12.4 first restart-race request missing")
    var stale_request_id := str(verifier.requests[request_start].get("verification_request_id", ""))

    expect(billing.restore(), "12.4 second restart-race restore did not launch")
    expect(verifier.requests.size() == request_start + 2, "12.4 second restart-race request missing")
    var current_request_id := str(verifier.requests[request_start + 1].get("verification_request_id", ""))
    expect(stale_request_id != current_request_id, "12.4 restore generations reused verification request id")
    expect(billing.pending_verification_count() == 1, "12.4 stale restore request was not retired")

    verifier.respond(request_start)
    expect(billing.pending_verification_count() == 1, "12.4 stale backend response consumed current restore request")
    expect(restores.size() == restore_start, "12.4 stale backend response completed current restore")
    expect(entitlements.snapshot_apply_count == snapshot_start, "12.4 stale backend response applied authoritative snapshot")
    expect("verification_for_unknown_request" in coordinator_errors, "12.4 stale response was not rejected as unknown request")

    verifier.respond(request_start + 1)
    expect(billing.pending_verification_count() == 0, "12.4 current restore response not consumed")
    expect(restores.size() == restore_start + 1, "12.4 current restore did not complete")
    expect(bool(restores.back().get("ok", false)), "12.4 current restore reported failure")
    expect(entitlements.snapshot_apply_count == snapshot_start + 1, "12.4 current restore did not apply exactly one snapshot")
    expect(bool(entitlements.summary().full_game), "12.4 current restore lost owned full game")
    expect(not bool(entitlements.summary().supporter_cosmetics), "12.4 current restore failed to revoke absent supporter pack")


func _purchase(product_id: String, token: String) -> Dictionary:
    return {
        "product_ids": [product_id],
        "purchase_token": token,
        "package_name": "com.pmartins87.veredasdatrama",
        "purchase_state": "PURCHASED",
        "purchase_time": 1786540000000,
        "is_acknowledged": false,
    }


func _finish() -> void:
    if failures.is_empty():
        print(
            "PLAY_BILLING_CORRELATION_CERTIFICATION PASS: 12.4 request_correlation=1 overlap_safe=1 stale_response_isolation=1"
        )
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAY_BILLING_CORRELATION_CERTIFICATION: %s" % failure)
    print("PLAY_BILLING_CORRELATION_CERTIFICATION FAIL: %d" % failures.size())
    get_tree().quit(1)


func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
