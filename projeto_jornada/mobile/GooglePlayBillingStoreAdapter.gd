extends RefCounted
class_name GooglePlayBillingStoreAdapter

signal store_ready()
signal product_details_received(response: Dictionary)
signal purchases_received(response: Dictionary)
signal purchase_updated(response: Dictionary)
signal store_error(code: String, message: String)

const BILLING_CLIENT_SCRIPT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"

var _client: Object
var _billing_script: Script
var _started := false


func start() -> bool:
    if _started and _client != null:
        return true
    if not ResourceLoader.exists(BILLING_CLIENT_SCRIPT):
        store_error.emit("plugin_missing", BILLING_CLIENT_SCRIPT)
        return false
    var resource = load(BILLING_CLIENT_SCRIPT)
    if not (resource is Script):
        store_error.emit("plugin_script_invalid", BILLING_CLIENT_SCRIPT)
        return false
    _billing_script = resource as Script
    var instance = _billing_script.new()
    if instance == null:
        store_error.emit("billing_client_create_failed", "")
        return false
    _client = instance as Object
    if _client == null:
        store_error.emit("billing_client_not_object", "")
        return false
    if not _validate_plugin_api():
        _client = null
        return false
    _connect_plugin_signals()
    _started = true
    _client.call("start_connection")
    return true


func query_products(product_ids: Array[String]) -> bool:
    if not _is_ready_for_calls():
        store_error.emit("billing_not_ready", "query_products")
        return false
    _client.call("query_product_details", product_ids, _enum_value("ProductType", "INAPP", 0))
    return true


func query_owned_purchases() -> bool:
    if not _is_ready_for_calls():
        store_error.emit("billing_not_ready", "query_owned_purchases")
        return false
    _client.call("query_purchases", _enum_value("ProductType", "INAPP", 0))
    return true


func launch_purchase(product_id: String) -> Dictionary:
    if not _is_ready_for_calls():
        return {"ok": false, "error": "billing_not_ready"}
    var raw = _client.call("purchase", product_id)
    if typeof(raw) != TYPE_DICTIONARY:
        return {"ok": false, "error": "invalid_purchase_launch_response"}
    var response: Dictionary = raw as Dictionary
    if _response_ok(response):
        return {"ok": true, "pending_callback": true}
    return {
        "ok": false,
        "error": str(response.get("debug_message", "billing_flow_failed")),
        "response_code": int(response.get("response_code", -1)),
    }


func close() -> void:
    if _client != null and _client.has_method("end_connection"):
        _client.call("end_connection")
    _client = null
    _started = false


func plugin_version_contract_path() -> String:
    return "res://mobile/play_billing_contract.json"


func _validate_plugin_api() -> bool:
    for method_name in [
        "start_connection",
        "is_ready",
        "query_product_details",
        "query_purchases",
        "purchase",
    ]:
        if not _client.has_method(method_name):
            store_error.emit("plugin_method_missing", method_name)
            return false
    for signal_name in [
        "connected",
        "disconnected",
        "connect_error",
        "query_product_details_response",
        "query_purchases_response",
        "on_purchase_updated",
    ]:
        if not _client.has_signal(signal_name):
            store_error.emit("plugin_signal_missing", signal_name)
            return false
    return true


func _connect_plugin_signals() -> void:
    _connect_once("connected", Callable(self, "_on_connected"))
    _connect_once("disconnected", Callable(self, "_on_disconnected"))
    _connect_once("connect_error", Callable(self, "_on_connect_error"))
    _connect_once("query_product_details_response", Callable(self, "_on_product_details"))
    _connect_once("query_purchases_response", Callable(self, "_on_purchases"))
    _connect_once("on_purchase_updated", Callable(self, "_on_purchase_updated"))


func _on_connected() -> void:
    store_ready.emit()


func _on_disconnected() -> void:
    store_error.emit("billing_disconnected", "")


func _on_connect_error(response_code: int, debug_message: String) -> void:
    store_error.emit("billing_connect_error:%d" % response_code, debug_message)


func _on_product_details(response: Dictionary) -> void:
    if not _response_ok(response):
        product_details_received.emit({
            "ok": false,
            "error": str(response.get("debug_message", "product_query_failed")),
            "response_code": int(response.get("response_code", -1)),
        })
        return
    var ids: Array[String] = []
    var raw = response.get("product_details", [])
    if typeof(raw) == TYPE_ARRAY:
        for row_variant in raw as Array:
            if typeof(row_variant) != TYPE_DICTIONARY:
                continue
            var product_id := str((row_variant as Dictionary).get("product_id", ""))
            if product_id != "" and product_id not in ids:
                ids.append(product_id)
    product_details_received.emit({"ok": true, "product_ids": ids})


func _on_purchases(response: Dictionary) -> void:
    if not _response_ok(response):
        purchases_received.emit({
            "ok": false,
            "error": str(response.get("debug_message", "purchase_query_failed")),
            "response_code": int(response.get("response_code", -1)),
        })
        return
    purchases_received.emit({
        "ok": true,
        "purchases": _normalize_purchases(response.get("purchases", [])),
    })


func _on_purchase_updated(response: Dictionary) -> void:
    if not _response_ok(response):
        purchase_updated.emit({
            "ok": false,
            "error": str(response.get("debug_message", "purchase_update_failed")),
            "response_code": int(response.get("response_code", -1)),
        })
        return
    purchase_updated.emit({
        "ok": true,
        "purchases": _normalize_purchases(response.get("purchases", [])),
    })


func _normalize_purchases(raw: Variant) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if typeof(raw) != TYPE_ARRAY:
        return result
    for row_variant in raw as Array:
        if typeof(row_variant) != TYPE_DICTIONARY:
            continue
        var row: Dictionary = row_variant as Dictionary
        var products: Array[String] = []
        var product_raw = row.get("product_ids", [])
        if typeof(product_raw) == TYPE_ARRAY or typeof(product_raw) == TYPE_PACKED_STRING_ARRAY:
            for value in product_raw:
                products.append(str(value))
        result.append({
            "order_id": str(row.get("order_id", "")),
            "purchase_token": str(row.get("purchase_token", "")),
            "package_name": str(row.get("package_name", "")),
            "purchase_state": _purchase_state_name(int(row.get("purchase_state", 0))),
            "purchase_time": int(row.get("purchase_time", 0)),
            "is_acknowledged": bool(row.get("is_acknowledged", false)),
            "quantity": int(row.get("quantity", 1)),
            "product_ids": products,
        })
    return result


func _purchase_state_name(value: int) -> String:
    if value == _enum_value("PurchaseState", "PURCHASED", 1):
        return "PURCHASED"
    if value == _enum_value("PurchaseState", "PENDING", 2):
        return "PENDING"
    return "UNSPECIFIED"


func _response_ok(response: Dictionary) -> bool:
    return int(response.get("response_code", -999)) == _enum_value("BillingResponseCode", "OK", 0)


func _is_ready_for_calls() -> bool:
    if _client == null or not _client.has_method("is_ready"):
        return false
    return bool(_client.call("is_ready"))


func _enum_value(enum_name: String, key: String, fallback: int) -> int:
    if _billing_script == null or not _billing_script.has_method("get_script_constant_map"):
        return fallback
    var constants: Dictionary = _billing_script.get_script_constant_map()
    var enum_variant = constants.get(enum_name, {})
    if typeof(enum_variant) != TYPE_DICTIONARY:
        return fallback
    return int((enum_variant as Dictionary).get(key, fallback))


func _connect_once(signal_name: String, callable: Callable) -> void:
    if not _client.is_connected(signal_name, callable):
        _client.connect(signal_name, callable)
