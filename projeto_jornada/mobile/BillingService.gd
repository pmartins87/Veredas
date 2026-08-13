extends Node

signal status_changed(status: String)
signal purchase_pending(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal entitlement_changed(product_id: String)
signal restore_finished(ok: bool, summary: Dictionary)

const CONTRACT_PATH := "res://mobile/play_billing_contract.json"
const FULL_GAME_PRODUCT := "full_game_unlock"
const SUPPORTER_PRODUCT := "supporter_cosmetic_pack"

var _status := "initializing"
var _last_error := ""
var _store: GooglePlayBillingStoreAdapter
var _verifier: PlayPurchaseVerificationClient
var _coordinator: PlayBillingCoordinator


func _ready() -> void:
    call_deferred("_initialize")


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_RESUMED:
        call_deferred("_resume_billing")


func status() -> String:
    return _status


func last_error() -> String:
    return _last_error


func is_purchase_available() -> bool:
    return (
        _status == "ready"
        and _coordinator != null
        and _coordinator.products_ready()
    )


func purchase(product_id: String) -> Dictionary:
    if product_id not in [FULL_GAME_PRODUCT, SUPPORTER_PRODUCT]:
        return {"ok": false, "error": "unknown_product"}
    if EntitlementEngine.new().is_owned(product_id):
        return {"ok": false, "error": "already_owned"}
    if not is_purchase_available():
        return {"ok": false, "error": "billing_unavailable"}
    return _coordinator.purchase(product_id)


func restore() -> bool:
    if _coordinator == null:
        return false
    if not _coordinator.products_ready():
        return _coordinator.start()
    return _coordinator.restore()


func summary() -> Dictionary:
    var entitlement_summary := EntitlementEngine.new().summary()
    return {
        "status": _status,
        "last_error": _last_error,
        "purchase_available": is_purchase_available(),
        "full_game": bool(entitlement_summary.get("full_game", false)),
        "supporter_cosmetics": bool(entitlement_summary.get("supporter_cosmetics", false)),
        "pending_verifications": _coordinator.pending_verification_count() if _coordinator != null else 0,
    }


func _initialize() -> void:
    EntitlementEngine.new().ensure_state()
    if not OS.has_feature("android"):
        _set_status("not_android")
        return

    var contract := _load_contract()
    if contract.is_empty():
        _fail("contract_invalid")
        return
    var verification = contract.get("verification_boundary", {})
    if typeof(verification) != TYPE_DICTIONARY:
        _fail("verification_contract_missing")
        return
    var endpoint := str((verification as Dictionary).get("backend_endpoint", "")).strip_edges()

    _verifier = PlayPurchaseVerificationClient.new()
    add_child(_verifier)
    var verifier_config := _verifier.configure(endpoint)
    if not bool(verifier_config.get("ok", false)):
        _last_error = ",".join(verifier_config.get("errors", []))
        _set_status("configuration_pending")
        return

    _store = GooglePlayBillingStoreAdapter.new()
    _coordinator = PlayBillingCoordinator.new()
    _connect_once(_coordinator, "ready", Callable(self, "_on_store_connected"))
    _connect_once(_coordinator, "products_updated", Callable(self, "_on_products_updated"))
    _connect_once(_coordinator, "purchase_pending", Callable(self, "_on_purchase_pending"))
    _connect_once(_coordinator, "purchase_failed", Callable(self, "_on_purchase_failed"))
    _connect_once(_coordinator, "entitlement_granted", Callable(self, "_on_entitlement_granted"))
    _connect_once(_coordinator, "restore_completed", Callable(self, "_on_restore_completed"))
    _connect_once(_coordinator, "coordinator_error", Callable(self, "_on_coordinator_error"))

    var configured := _coordinator.configure(_store, _verifier, EntitlementEngine.new())
    if not bool(configured.get("ok", false)):
        _last_error = ",".join(configured.get("errors", []))
        _set_status("configuration_error")
        return

    _set_status("connecting")
    if not _coordinator.start():
        if _status == "connecting":
            _fail("store_start_failed")


func _resume_billing() -> void:
    if not OS.has_feature("android") or _coordinator == null:
        return
    if _coordinator.products_ready():
        _coordinator.restore()
        return
    _set_status("connecting")
    if not _coordinator.start():
        if _status == "connecting":
            _fail("store_resume_failed")


func _on_store_connected() -> void:
    _last_error = ""
    _set_status("catalog_loading")


func _on_products_updated(_product_ids: Array[String]) -> void:
    _last_error = ""
    _set_status("ready")


func _on_purchase_pending(product_id: String) -> void:
    purchase_pending.emit(product_id)


func _on_purchase_failed(product_id: String, reason: String) -> void:
    _last_error = reason
    purchase_failed.emit(product_id, reason)


func _on_entitlement_granted(product_id: String) -> void:
    entitlement_changed.emit(product_id)


func _on_restore_completed(ok: bool, restored_summary: Dictionary) -> void:
    if ok:
        _last_error = ""
        if _coordinator != null and _coordinator.products_ready():
            _set_status("ready")
        entitlement_changed.emit("restore")
    restore_finished.emit(ok, restored_summary.duplicate(true))


func _on_coordinator_error(code: String) -> void:
    _last_error = code
    if code.begins_with("plugin_"):
        _set_status("plugin_unavailable")
    elif code == "billing_disconnected" or code.begins_with("billing_connect_error"):
        _set_status("disconnected")
    elif _status != "configuration_pending":
        _set_status("error")


func _load_contract() -> Dictionary:
    var file := FileAccess.open(CONTRACT_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


func _fail(code: String) -> void:
    _last_error = code
    _set_status("error")


func _set_status(value: String) -> void:
    if _status == value:
        return
    _status = value
    status_changed.emit(_status)


func _connect_once(emitter: Object, signal_name: String, callable: Callable) -> void:
    if not emitter.is_connected(signal_name, callable):
        emitter.connect(signal_name, callable)
