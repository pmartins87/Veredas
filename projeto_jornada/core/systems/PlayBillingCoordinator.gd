extends RefCounted
class_name PlayBillingCoordinator

signal ready()
signal products_updated(product_ids: Array[String])
signal purchase_pending(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal entitlement_granted(product_id: String)
signal restore_completed(ok: bool, summary: Dictionary)
signal coordinator_error(code: String)

const APPLICATION_ID := "com.pmartins87.veredasdatrama"
const SOURCE_ID := "play_backend"
const PURCHASED_STATE := 1
const PENDING_STATE := 2

var _store: Object
var _verifier: Object
var _entitlements: Variant = null
var _configured := false
var _products_ready := false
var _pending_verifications: Dictionary = {}
var _verification_sequence := 0
var _restore_active := false
var _restore_collecting := false
var _restore_generation := 0
var _restore_failed := false
var _restore_verified: Array[Dictionary] = []


func configure(store: Object, verifier: Object, entitlements: Variant = null) -> Dictionary:
    var errors: Array[String] = []
    if store == null:
        errors.append("store_missing")
    if verifier == null:
        errors.append("verifier_missing")
    if not errors.is_empty():
        return {"ok": false, "errors": errors}

    for method_name in ["start", "query_products", "query_owned_purchases", "launch_purchase"]:
        if not store.has_method(method_name):
            errors.append("store_method_missing:%s" % method_name)
    for signal_name in ["store_ready", "product_details_received", "purchases_received", "purchase_updated", "store_error"]:
        if not store.has_signal(signal_name):
            errors.append("store_signal_missing:%s" % signal_name)
    if not verifier.has_method("verify_purchase"):
        errors.append("verifier_method_missing:verify_purchase")
    if not verifier.has_signal("verification_completed"):
        errors.append("verifier_signal_missing:verification_completed")
    if not errors.is_empty():
        return {"ok": false, "errors": errors}

    _store = store
    _verifier = verifier
    _entitlements = entitlements
    _connect_once(_store, "store_ready", Callable(self, "_on_store_ready"))
    _connect_once(_store, "product_details_received", Callable(self, "_on_product_details_received"))
    _connect_once(_store, "purchases_received", Callable(self, "_on_purchases_received"))
    _connect_once(_store, "purchase_updated", Callable(self, "_on_purchase_updated"))
    _connect_once(_store, "store_error", Callable(self, "_on_store_error"))
    _connect_once(_verifier, "verification_completed", Callable(self, "_on_verification_completed"))
    _configured = true
    return {"ok": true, "errors": []}


func start() -> bool:
    if not _configured:
        coordinator_error.emit("not_configured")
        return false
    var result = _store.call("start")
    if typeof(result) == TYPE_BOOL and not bool(result):
        coordinator_error.emit("store_start_failed")
        return false
    return true


func purchase(product_id: String) -> Dictionary:
    if not _configured:
        return {"ok": false, "error": "not_configured"}
    if CommercialPolicyEngine.new().product(product_id).is_empty():
        return {"ok": false, "error": "unknown_product"}
    if not _products_ready:
        return {"ok": false, "error": "product_catalog_not_ready"}
    var result = _store.call("launch_purchase", product_id)
    if typeof(result) == TYPE_DICTIONARY:
        var row: Dictionary = result as Dictionary
        if not bool(row.get("ok", false)):
            purchase_failed.emit(product_id, str(row.get("error", "billing_flow_failed")))
        return row
    if typeof(result) == TYPE_BOOL:
        return {"ok": bool(result), "error": "" if bool(result) else "billing_flow_failed"}
    return {"ok": true, "pending_callback": true}


func restore() -> bool:
    if not _configured:
        coordinator_error.emit("not_configured")
        return false
    _restore_generation += 1
    _restore_active = true
    _restore_collecting = false
    _restore_failed = false
    _restore_verified.clear()
    _discard_pending_restore_verifications()
    var result = _store.call("query_owned_purchases")
    if typeof(result) == TYPE_BOOL and not bool(result):
        _restore_active = false
        _restore_collecting = false
        restore_completed.emit(false, _summary())
        return false
    return true


func products_ready() -> bool:
    return _products_ready


func pending_verification_count() -> int:
    return _pending_verifications.size()


func _on_store_ready() -> void:
    var ids := _required_product_ids()
    _store.call("query_products", ids)
    ready.emit()
    restore()


func _on_store_error(code: String, _message: String) -> void:
    coordinator_error.emit(code)


func _on_product_details_received(response: Dictionary) -> void:
    if not bool(response.get("ok", false)):
        _products_ready = false
        coordinator_error.emit("product_query_failed")
        return
    var returned: Array[String] = []
    var raw = response.get("product_ids", [])
    if typeof(raw) == TYPE_ARRAY or typeof(raw) == TYPE_PACKED_STRING_ARRAY:
        for value in raw:
            var product_id := str(value)
            if product_id != "" and product_id not in returned:
                returned.append(product_id)
    var required := _required_product_ids()
    for product_id in required:
        if product_id not in returned:
            _products_ready = false
            coordinator_error.emit("product_missing:%s" % product_id)
            return
    _products_ready = true
    products_updated.emit(returned)


func _on_purchases_received(response: Dictionary) -> void:
    if not _restore_active:
        return
    if not bool(response.get("ok", false)):
        _restore_active = false
        _restore_collecting = false
        restore_completed.emit(false, _summary())
        return

    var purchases: Array = []
    var raw = response.get("purchases", [])
    if typeof(raw) == TYPE_ARRAY:
        purchases = raw as Array

    _restore_collecting = true
    for purchase_variant in purchases:
        if typeof(purchase_variant) != TYPE_DICTIONARY:
            _restore_failed = true
            continue
        var purchase: Dictionary = purchase_variant as Dictionary
        var product_id := _extract_product_id(purchase)
        if product_id == "":
            _restore_failed = true
            continue
        var state := _purchase_state(purchase)
        if state == "PENDING":
            purchase_pending.emit(product_id)
            continue
        if state != "PURCHASED":
            continue
        if not _request_verification(purchase, "restore", _restore_generation):
            _restore_failed = true
    _restore_collecting = false
    _finish_restore_if_ready()


func _on_purchase_updated(response: Dictionary) -> void:
    if not bool(response.get("ok", false)):
        purchase_failed.emit("", str(response.get("error", "purchase_update_failed")))
        return
    var raw = response.get("purchases", [])
    if typeof(raw) != TYPE_ARRAY:
        purchase_failed.emit("", "purchase_update_invalid")
        return
    for purchase_variant in raw as Array:
        if typeof(purchase_variant) != TYPE_DICTIONARY:
            continue
        var purchase: Dictionary = purchase_variant as Dictionary
        var product_id := _extract_product_id(purchase)
        if product_id == "":
            purchase_failed.emit("", "unknown_product_in_purchase")
            continue
        var state := _purchase_state(purchase)
        if state == "PENDING":
            purchase_pending.emit(product_id)
            continue
        if state != "PURCHASED":
            purchase_failed.emit(product_id, "purchase_not_purchased")
            continue
        if not _request_verification(purchase, "purchase", 0):
            purchase_failed.emit(product_id, "verification_request_rejected")


func _request_verification(purchase: Dictionary, context: String, generation: int) -> bool:
    var product_id := _extract_product_id(purchase)
    var token := str(purchase.get("purchase_token", "")).strip_edges()
    if product_id == "" or token == "":
        return false
    var package_name := str(purchase.get("package_name", "")).strip_edges()
    if package_name != "" and package_name != APPLICATION_ID:
        return false

    var request_id := _next_verification_request_id(context, generation)
    var payload := {
        "verification_request_id": request_id,
        "application_id": APPLICATION_ID,
        "product_id": product_id,
        "purchase_token": token,
        "purchase_time": int(purchase.get("purchase_time", 0)),
        "package_name": package_name if package_name != "" else APPLICATION_ID,
        "client_acknowledged_state": bool(purchase.get("is_acknowledged", false)),
    }
    _pending_verifications[request_id] = {
        "context": context,
        "generation": generation,
        "product_id": product_id,
        "purchase_token": token,
        "purchase": purchase.duplicate(true),
    }
    var result = _verifier.call("verify_purchase", payload)
    if typeof(result) == TYPE_DICTIONARY and not (result as Dictionary).is_empty():
        _on_verification_completed(result as Dictionary)
    elif typeof(result) == TYPE_BOOL and not bool(result):
        _pending_verifications.erase(request_id)
        return false
    return true


func _on_verification_completed(result: Dictionary) -> void:
    var request_id := str(result.get("verification_request_id", "")).strip_edges()
    if request_id == "" or not _pending_verifications.has(request_id):
        coordinator_error.emit("verification_for_unknown_request")
        return
    var pending: Dictionary = _pending_verifications[request_id] as Dictionary
    _pending_verifications.erase(request_id)
    var context := str(pending.get("context", ""))
    var product_id := str(pending.get("product_id", ""))
    var token := str(pending.get("purchase_token", ""))
    var generation := int(pending.get("generation", 0))

    var verified := _valid_verification(result, request_id, token, product_id)
    if context == "restore":
        if generation != _restore_generation or not _restore_active:
            return
        if verified:
            _restore_verified.append({
                "product_id": product_id,
                "owned": true,
                "transaction_id": token,
            })
        else:
            _restore_failed = true
        _finish_restore_if_ready()
        return

    if context == "purchase":
        if not verified:
            purchase_failed.emit(product_id, "backend_verification_failed")
            return
        var applied := _entitlement_engine().apply_purchase_result({
            "ok": true,
            "product_id": product_id,
            "source": SOURCE_ID,
            "transaction_id": token,
        })
        if not bool(applied):
            purchase_failed.emit(product_id, "entitlement_apply_failed")
            return
        entitlement_granted.emit(product_id)


func _finish_restore_if_ready() -> void:
    if not _restore_active or _restore_collecting:
        return
    for pending_variant in _pending_verifications.values():
        if typeof(pending_variant) != TYPE_DICTIONARY:
            continue
        var pending: Dictionary = pending_variant as Dictionary
        if str(pending.get("context", "")) == "restore" and int(pending.get("generation", 0)) == _restore_generation:
            return
    _restore_active = false
    if _restore_failed:
        restore_completed.emit(false, _summary())
        return
    _entitlement_engine().apply_authoritative_snapshot(_restore_verified, SOURCE_ID)
    restore_completed.emit(true, _summary())


func _valid_verification(result: Dictionary, request_id: String, token: String, product_id: String) -> bool:
    if not bool(result.get("ok", false)):
        return false
    if str(result.get("verification_request_id", "")) != request_id:
        return false
    if str(result.get("purchase_token", "")) != token:
        return false
    if str(result.get("product_id", "")) != product_id:
        return false
    if not bool(result.get("owned", false)):
        return false
    if str(result.get("purchase_state", "")) != "PURCHASED":
        return false
    if not bool(result.get("acknowledged", false)):
        return false
    if str(result.get("source", "")) != SOURCE_ID:
        return false
    return true


func _next_verification_request_id(context: String, generation: int) -> String:
    _verification_sequence += 1
    return "vreq-%s-%d-%d" % [context, generation, _verification_sequence]


func _purchase_state(purchase: Dictionary) -> String:
    var raw = purchase.get("purchase_state", 0)
    if typeof(raw) == TYPE_STRING:
        return str(raw).to_upper()
    var state := int(raw)
    if state == PURCHASED_STATE:
        return "PURCHASED"
    if state == PENDING_STATE:
        return "PENDING"
    return "UNSPECIFIED"


func _extract_product_id(purchase: Dictionary) -> String:
    var direct := str(purchase.get("product_id", "")).strip_edges()
    if direct != "" and not CommercialPolicyEngine.new().product(direct).is_empty():
        return direct
    var matches: Array[String] = []
    var raw = purchase.get("product_ids", [])
    if typeof(raw) == TYPE_ARRAY or typeof(raw) == TYPE_PACKED_STRING_ARRAY:
        for value in raw:
            var product_id := str(value)
            if not CommercialPolicyEngine.new().product(product_id).is_empty() and product_id not in matches:
                matches.append(product_id)
    return matches[0] if matches.size() == 1 else ""


func _required_product_ids() -> Array[String]:
    var result: Array[String] = []
    for product_variant in CommercialPolicyEngine.new().products():
        if typeof(product_variant) != TYPE_DICTIONARY:
            continue
        var product_id := str((product_variant as Dictionary).get("id", ""))
        if product_id != "":
            result.append(product_id)
    result.sort()
    return result


func _discard_pending_restore_verifications() -> void:
    var remove: Array[String] = []
    for request_variant in _pending_verifications.keys():
        var request_id := str(request_variant)
        var pending: Dictionary = _pending_verifications[request_id] as Dictionary
        if str(pending.get("context", "")) == "restore":
            remove.append(request_id)
    for request_id in remove:
        _pending_verifications.erase(request_id)


func _summary() -> Dictionary:
    return _entitlement_engine().summary()


func _entitlement_engine() -> Variant:
    return _entitlements if _entitlements != null else EntitlementEngine.new()


func _connect_once(emitter: Object, signal_name: String, callable: Callable) -> void:
    if not emitter.is_connected(signal_name, callable):
        emitter.connect(signal_name, callable)
