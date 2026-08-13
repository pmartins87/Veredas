extends RefCounted
class_name EntitlementEngine

const SCHEMA_VERSION := 2
const PROVIDER_ID := "platform_billing"

func ensure_state() -> Dictionary:
    var raw = GameState.profile.get("entitlements", {})
    var source: Dictionary = raw as Dictionary if typeof(raw) == TYPE_DICTIONARY else {}
    var grants_raw = source.get("grants", {})
    var grants_source: Dictionary = grants_raw as Dictionary if typeof(grants_raw) == TYPE_DICTIONARY else {}
    var grants: Dictionary = {}

    for product_variant in CommercialPolicyEngine.new().products():
        var product: Dictionary = product_variant as Dictionary
        var product_id := str(product.get("id", ""))
        if product_id == "":
            continue
        var record_raw = grants_source.get(product_id, {})
        var record: Dictionary = record_raw as Dictionary if typeof(record_raw) == TYPE_DICTIONARY else {}
        grants[product_id] = {
            "owned":bool(record.get("owned", false)),
            "verified_at":int(record.get("verified_at", 0)),
            "source":str(record.get("source", "none")),
            "transaction_id":PurchaseReference.normalize_persisted(str(record.get("transaction_id", ""))),
            "revoked_at":int(record.get("revoked_at", 0)),
        }

    var state := {
        "schema_version":SCHEMA_VERSION,
        "provider":str(source.get("provider", PROVIDER_ID)),
        "grants":grants,
        "last_restore_at":int(source.get("last_restore_at", 0)),
        "last_store_contact_at":int(source.get("last_store_contact_at", 0)),
        "last_store_error":str(source.get("last_store_error", "")),
        "offline_cache_valid":bool(source.get("offline_cache_valid", true)),
    }
    GameState.profile.entitlements = state.duplicate(true)
    return state.duplicate(true)

func is_owned(product_id: String) -> bool:
    var state := ensure_state()
    var grants: Dictionary = state.get("grants", {}) as Dictionary
    if not grants.has(product_id):
        return false
    return bool((grants[product_id] as Dictionary).get("owned", false))

func has_full_game() -> bool:
    return is_owned(CommercialPolicyEngine.new().full_unlock_product_id())

func has_supporter_cosmetics() -> bool:
    return is_owned(CommercialPolicyEngine.new().supporter_product_id())

func can_access_world(world_id: String) -> bool:
    var commercial := CommercialPolicyEngine.new()
    if not commercial.world_requires_full_unlock(world_id):
        return true
    return has_full_game()

func apply_authoritative_snapshot(purchases: Array, source: String = PROVIDER_ID) -> Dictionary:
    var state := ensure_state()
    var grants: Dictionary = (state.get("grants", {}) as Dictionary).duplicate(true)
    var now := int(Time.get_unix_time_from_system())
    var owned_snapshot: Dictionary = {}

    for purchase_variant in purchases:
        if typeof(purchase_variant) != TYPE_DICTIONARY:
            continue
        var purchase: Dictionary = purchase_variant as Dictionary
        var product_id := str(purchase.get("product_id", ""))
        if CommercialPolicyEngine.new().product(product_id).is_empty():
            continue
        if not bool(purchase.get("owned", true)):
            continue
        var raw_reference := str(purchase.get("transaction_id", ""))
        var safe_reference := PurchaseReference.normalize_persisted(raw_reference)
        if not raw_reference.is_empty() and safe_reference.is_empty():
            continue
        owned_snapshot[product_id] = {
            "owned":true,
            "verified_at":now,
            "source":source,
            "transaction_id":safe_reference,
            "revoked_at":0,
        }

    for product_id_variant in grants.keys():
        var product_id := str(product_id_variant)
        if owned_snapshot.has(product_id):
            grants[product_id] = (owned_snapshot[product_id] as Dictionary).duplicate(true)
        else:
            var prior: Dictionary = grants[product_id] as Dictionary
            grants[product_id] = {
                "owned":false,
                "verified_at":int(prior.get("verified_at", 0)),
                "source":source,
                "transaction_id":"",
                "revoked_at":now if bool(prior.get("owned", false)) else int(prior.get("revoked_at", 0)),
            }

    state.grants = grants
    state.last_restore_at = now
    state.last_store_contact_at = now
    state.last_store_error = ""
    state.offline_cache_valid = true
    _store_state(state)
    SaveService.save_game()
    return summary()

func apply_purchase_result(result: Dictionary) -> bool:
    if not bool(result.get("ok", false)):
        _record_store_error(str(result.get("error", "purchase_failed")))
        return false
    var product_id := str(result.get("product_id", ""))
    if CommercialPolicyEngine.new().product(product_id).is_empty():
        _record_store_error("unknown_product")
        return false
    var raw_reference := str(result.get("transaction_id", ""))
    var safe_reference := PurchaseReference.normalize_persisted(raw_reference)
    if not raw_reference.is_empty() and safe_reference.is_empty():
        _record_store_error("purchase_reference_hash_failed")
        return false
    var state := ensure_state()
    var grants: Dictionary = (state.get("grants", {}) as Dictionary).duplicate(true)
    var now := int(Time.get_unix_time_from_system())
    grants[product_id] = {
        "owned":true,
        "verified_at":now,
        "source":str(result.get("source", PROVIDER_ID)),
        "transaction_id":safe_reference,
        "revoked_at":0,
    }
    state.grants = grants
    state.last_store_contact_at = now
    state.last_store_error = ""
    state.offline_cache_valid = true
    _store_state(state)
    SaveService.save_game()
    return true

func restore_from_provider(provider: Object) -> Dictionary:
    if provider == null or not provider.has_method("restore_purchases"):
        _record_store_error("provider_unavailable")
        return {"ok":false,"offline":true,"cached":summary()}
    var response = provider.call("restore_purchases")
    if typeof(response) != TYPE_DICTIONARY:
        _record_store_error("invalid_restore_response")
        return {"ok":false,"offline":true,"cached":summary()}
    var result: Dictionary = response as Dictionary
    if not bool(result.get("ok", false)):
        _record_store_error(str(result.get("error", "store_offline")))
        return {"ok":false,"offline":true,"cached":summary()}
    var purchases_raw = result.get("purchases", [])
    var purchases: Array = purchases_raw as Array if typeof(purchases_raw) == TYPE_ARRAY else []
    var restored := apply_authoritative_snapshot(purchases, str(result.get("source", PROVIDER_ID)))
    return {"ok":true,"offline":false,"restored":restored}

func purchase_from_provider(provider: Object, product_id: String) -> Dictionary:
    var commercial := CommercialPolicyEngine.new()
    var product := commercial.product(product_id)
    if product.is_empty():
        return {"ok":false,"error":"unknown_product"}
    if provider == null or not provider.has_method("purchase"):
        _record_store_error("provider_unavailable")
        return {"ok":false,"error":"provider_unavailable"}
    var response = provider.call("purchase", product_id)
    if typeof(response) != TYPE_DICTIONARY:
        _record_store_error("invalid_purchase_response")
        return {"ok":false,"error":"invalid_purchase_response"}
    var result: Dictionary = response as Dictionary
    if not apply_purchase_result(result):
        return {"ok":false,"error":str(result.get("error", "purchase_failed"))}
    return {"ok":true,"product_id":product_id,"owned":true}

func summary() -> Dictionary:
    var state := ensure_state()
    return {
        "full_game":is_owned(CommercialPolicyEngine.new().full_unlock_product_id()),
        "supporter_cosmetics":is_owned(CommercialPolicyEngine.new().supporter_product_id()),
        "last_restore_at":int(state.get("last_restore_at", 0)),
        "last_store_contact_at":int(state.get("last_store_contact_at", 0)),
        "last_store_error":str(state.get("last_store_error", "")),
        "offline_cache_valid":bool(state.get("offline_cache_valid", true)),
    }

func _record_store_error(error: String) -> void:
    var state := ensure_state()
    state.last_store_error = error
    state.offline_cache_valid = true
    _store_state(state)
    SaveService.save_game()

func _store_state(state: Dictionary) -> void:
    GameState.profile.entitlements = state.duplicate(true)
