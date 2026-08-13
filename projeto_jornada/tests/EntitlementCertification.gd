extends Node

class MockStoreProvider:
    extends RefCounted
    var online := true
    var owned: Array[String] = []
    var transaction_counter := 0

    func restore_purchases() -> Dictionary:
        if not online:
            return {"ok":false,"error":"offline","source":"mock_store"}
        var purchases: Array = []
        for product_id in owned:
            purchases.append({"product_id":product_id,"owned":true,"transaction_id":"restore-%s" % product_id})
        return {"ok":true,"source":"mock_store","purchases":purchases}

    func purchase(product_id: String) -> Dictionary:
        if not online:
            return {"ok":false,"error":"offline","source":"mock_store","product_id":product_id}
        transaction_counter += 1
        if product_id not in owned:
            owned.append(product_id)
        return {
            "ok":true,
            "source":"mock_store",
            "product_id":product_id,
            "transaction_id":"tx-%d" % transaction_counter,
        }

var failures: Array[String] = []
var entitlements := EntitlementEngine.new()
var provider := MockStoreProvider.new()

func _ready() -> void:
    await get_tree().process_frame
    GameState.reset_profile()
    GameState.run = {}
    entitlements.ensure_state()

    _free_trial_gate()
    _restore_gate()
    _offline_cache_gate()
    _authoritative_revocation_gate()
    _purchase_gate()
    _local_reference_minimization_gate()
    _save_load_gate()
    _power_neutrality_gate()
    _finish()

func _free_trial_gate() -> void:
    expect(not entitlements.has_full_game(), "9.8 fresh profile unexpectedly owns full game")
    expect(entitlements.can_access_world("world.mata_fio_verde"), "9.8 free-trial Domain is inaccessible")
    expect(not entitlements.can_access_world("world.varzea_espelhos"), "9.8 paid Domain accessible without entitlement")
    expect(not entitlements.has_supporter_cosmetics(), "9.8 fresh profile unexpectedly owns supporter cosmetics")

func _restore_gate() -> void:
    provider.owned = ["full_game_unlock"]
    var restored := entitlements.restore_from_provider(provider)
    expect(bool(restored.get("ok", false)), "9.8 authoritative restore failed")
    expect(entitlements.has_full_game(), "9.8 restored full-game entitlement not owned")
    expect(entitlements.can_access_world("world.varzea_espelhos"), "9.8 restored full-game entitlement did not open paid Domain")
    expect(not entitlements.has_supporter_cosmetics(), "9.8 restore granted unowned supporter pack")

func _offline_cache_gate() -> void:
    expect(SaveService.save_game(), "9.8 entitlement save failed before offline test")
    provider.online = false
    var offline_restore := entitlements.restore_from_provider(provider)
    expect(not bool(offline_restore.get("ok", true)), "9.8 offline provider incorrectly reported authoritative success")
    expect(bool(offline_restore.get("offline", false)), "9.8 offline restore did not identify cached mode")
    expect(entitlements.has_full_game(), "9.8 temporary offline state revoked cached full-game entitlement")
    expect(entitlements.can_access_world("world.varzea_espelhos"), "9.8 cached offline entitlement stopped opening paid content")
    expect(str(entitlements.summary().get("last_store_error", "")) == "offline", "9.8 offline error was not recorded")

func _authoritative_revocation_gate() -> void:
    provider.online = true
    provider.owned = []
    var restored := entitlements.restore_from_provider(provider)
    expect(bool(restored.get("ok", false)), "9.8 empty authoritative restore failed")
    expect(not entitlements.has_full_game(), "9.8 authoritative empty snapshot did not revoke full-game entitlement")
    expect(not entitlements.can_access_world("world.varzea_espelhos"), "9.8 revoked entitlement still opens paid Domain")

func _purchase_gate() -> void:
    var unknown := entitlements.purchase_from_provider(provider, "vigil_threads")
    expect(not bool(unknown.get("ok", true)), "9.8 internal meta currency leaked into store purchase path")
    expect(str(unknown.get("error", "")) == "unknown_product", "9.8 unknown store product error mismatch")

    var full_purchase := entitlements.purchase_from_provider(provider, "full_game_unlock")
    expect(bool(full_purchase.get("ok", false)), "9.8 full-game purchase result failed")
    expect(entitlements.has_full_game(), "9.8 successful full-game purchase did not grant entitlement")

    var supporter_purchase := entitlements.purchase_from_provider(provider, "supporter_cosmetic_pack")
    expect(bool(supporter_purchase.get("ok", false)), "9.8 supporter purchase result failed")
    expect(entitlements.has_supporter_cosmetics(), "9.8 successful supporter purchase did not grant cosmetic entitlement")

func _local_reference_minimization_gate() -> void:
    var state: Dictionary = GameState.profile.get("entitlements", {}) as Dictionary
    expect(int(state.get("schema_version", 0)) == 2, "12.4 entitlement cache schema did not migrate to hashed references")
    var grants: Dictionary = state.get("grants", {}) as Dictionary
    for product_id in ["full_game_unlock", "supporter_cosmetic_pack"]:
        var record: Dictionary = grants.get(product_id, {}) as Dictionary
        var reference := str(record.get("transaction_id", ""))
        expect(PurchaseReference.is_reference(reference), "12.4 local entitlement reference is not canonical SHA-256: %s" % product_id)
        expect("tx-" not in reference and "restore-" not in reference, "12.4 raw provider transaction id leaked into local entitlement cache: %s" % product_id)

    var legacy_record: Dictionary = (grants.get("full_game_unlock", {}) as Dictionary).duplicate(true)
    legacy_record.transaction_id = "legacy-sensitive-purchase-token"
    grants.full_game_unlock = legacy_record
    state.grants = grants
    GameState.profile.entitlements = state
    entitlements.ensure_state()
    var migrated_state: Dictionary = GameState.profile.get("entitlements", {}) as Dictionary
    var migrated_grants: Dictionary = migrated_state.get("grants", {}) as Dictionary
    var migrated_record: Dictionary = migrated_grants.get("full_game_unlock", {}) as Dictionary
    var migrated := str(migrated_record.get("transaction_id", ""))
    expect(PurchaseReference.is_reference(migrated), "12.4 legacy raw entitlement reference was not migrated")
    expect("legacy-sensitive-purchase-token" not in migrated, "12.4 legacy raw token remained in entitlement profile after migration")

func _save_load_gate() -> void:
    var before := entitlements.summary().duplicate(true)
    expect(SaveService.save_game(), "9.8 entitlement save failed")
    GameState.profile.entitlements = {}
    expect(SaveService.load_game(), "9.8 entitlement reload failed")
    var after := entitlements.summary()
    expect(bool(after.full_game) == bool(before.full_game), "9.8 full-game entitlement changed after save/load")
    expect(bool(after.supporter_cosmetics) == bool(before.supporter_cosmetics), "9.8 supporter entitlement changed after save/load")
    expect(bool(after.offline_cache_valid), "9.8 verified entitlement cache invalid after save/load")

func _power_neutrality_gate() -> void:
    MetaUnlockEngine.ensure_state()
    expect(RunFlowEngine.start_journey("character.mata_fio_verde.01", 98001), "9.8 could not start power-neutrality journey")
    expect(int(GameState.run.get("max_health", 0)) == 16, "9.8 paid entitlement altered max health")
    expect(int(GameState.run.get("max_vigor", 0)) == 8, "9.8 paid entitlement altered max vigor")
    expect(not (GameState.profile.get("entitlements", {}) as Dictionary).has("damage_bonus"), "9.8 entitlement state contains forbidden damage bonus")
    expect(not (GameState.profile.get("entitlements", {}) as Dictionary).has("currency_grant"), "9.8 entitlement state contains forbidden currency grant")

func _finish() -> void:
    if failures.is_empty():
        print("ENTITLEMENT_CERTIFICATION PASS: 9.8 local_purchase_reference_sha256=1")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("ENTITLEMENT_CERTIFICATION: %s" % failure)
        print("ENTITLEMENT_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
