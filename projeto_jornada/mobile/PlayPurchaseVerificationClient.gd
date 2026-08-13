extends Node
class_name PlayPurchaseVerificationClient

signal verification_completed(result: Dictionary)

const APPLICATION_ID := "com.pmartins87.veredasdatrama"
const SOURCE_ID := "play_backend"
const DEFAULT_TIMEOUT_SECONDS := 30.0
const EXPECTED_PRODUCTS := ["full_game_unlock", "supporter_cosmetic_pack"]

var _endpoint := ""
var _configured := false
var _pending: Dictionary = {}
var _request_factory: Callable = Callable()


func configure(endpoint: String) -> Dictionary:
    var normalized := endpoint.strip_edges()
    var errors: Array[String] = []
    if normalized.is_empty():
        errors.append("endpoint_missing")
    elif "PENDING_12_4" in normalized:
        errors.append("endpoint_pending")
    elif not normalized.begins_with("https://"):
        errors.append("endpoint_must_be_https")
    if not errors.is_empty():
        _endpoint = ""
        _configured = false
        return {"ok": false, "errors": errors}
    _endpoint = normalized
    _configured = true
    return {"ok": true, "errors": []}


func set_request_factory(factory: Callable) -> void:
    _request_factory = factory


func is_configured() -> bool:
    return _configured


func pending_count() -> int:
    return _pending.size()


func verify_purchase(payload: Dictionary) -> bool:
    if not _configured:
        return false
    var request_id := str(payload.get("verification_request_id", "")).strip_edges()
    var application_id := str(payload.get("application_id", "")).strip_edges()
    var package_name := str(payload.get("package_name", "")).strip_edges()
    var product_id := str(payload.get("product_id", "")).strip_edges()
    var purchase_token := str(payload.get("purchase_token", "")).strip_edges()
    if request_id.is_empty() or _pending.has(request_id):
        return false
    if application_id != APPLICATION_ID or package_name != APPLICATION_ID:
        return false
    if product_id not in EXPECTED_PRODUCTS or purchase_token.is_empty():
        return false

    var request_node := _make_request_node()
    if request_node == null:
        return false
    if not request_node.has_method("request") or not request_node.has_signal("request_completed"):
        request_node.queue_free()
        return false
    if request_node.get_parent() == null:
        add_child(request_node)
    if request_node is HTTPRequest:
        (request_node as HTTPRequest).timeout = DEFAULT_TIMEOUT_SECONDS

    var expected := {
        "verification_request_id": request_id,
        "purchase_token": purchase_token,
        "product_id": product_id,
        "request_node": request_node,
    }
    _pending[request_id] = expected
    request_node.connect(
        "request_completed",
        Callable(self, "_on_request_completed").bind(request_id, request_node),
        CONNECT_ONE_SHOT
    )

    var headers := PackedStringArray([
        "Content-Type: application/json; charset=utf-8",
        "Accept: application/json",
        "Cache-Control: no-store",
    ])
    var body := JSON.stringify(payload)
    var raw_error = request_node.call("request", _endpoint, headers, HTTPClient.METHOD_POST, body)
    var request_error := int(raw_error) if typeof(raw_error) == TYPE_INT else ERR_CANT_CONNECT
    if request_error != OK:
        _pending.erase(request_id)
        _release_request_node(request_node)
        return false
    return true


func cancel_all() -> void:
    var request_ids: Array = _pending.keys()
    for request_variant in request_ids:
        var request_id := str(request_variant)
        var expected: Dictionary = _pending.get(request_id, {}) as Dictionary
        var request_node = expected.get("request_node")
        if request_node is HTTPRequest:
            (request_node as HTTPRequest).cancel_request()
        _pending.erase(request_id)
        if request_node is Node:
            _release_request_node(request_node as Node)


func _make_request_node() -> Node:
    if _request_factory.is_valid():
        var candidate = _request_factory.call()
        if candidate is Node:
            return candidate as Node
        return null
    return HTTPRequest.new()


func _on_request_completed(
    result: int,
    response_code: int,
    _headers: PackedStringArray,
    body: PackedByteArray,
    request_id: String,
    request_node: Node
) -> void:
    if not _pending.has(request_id):
        _release_request_node(request_node)
        return
    var expected: Dictionary = _pending[request_id] as Dictionary
    _pending.erase(request_id)
    _release_request_node(request_node)

    if result != HTTPRequest.RESULT_SUCCESS:
        _emit_failure(expected, "transport_result:%d" % result)
        return
    if response_code < 200 or response_code >= 300:
        _emit_failure(expected, "http_status:%d" % response_code)
        return

    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if typeof(parsed) != TYPE_DICTIONARY:
        _emit_failure(expected, "response_not_json_object")
        return
    var response: Dictionary = parsed as Dictionary
    if str(response.get("verification_request_id", "")) != request_id:
        _emit_failure(expected, "response_request_id_mismatch")
        return
    if str(response.get("purchase_token", "")) != str(expected.get("purchase_token", "")):
        _emit_failure(expected, "response_token_mismatch")
        return
    if str(response.get("product_id", "")) != str(expected.get("product_id", "")):
        _emit_failure(expected, "response_product_mismatch")
        return
    verification_completed.emit(response.duplicate(true))


func _emit_failure(expected: Dictionary, error: String) -> void:
    verification_completed.emit({
        "verification_request_id": str(expected.get("verification_request_id", "")),
        "ok": false,
        "purchase_token": str(expected.get("purchase_token", "")),
        "product_id": str(expected.get("product_id", "")),
        "owned": false,
        "purchase_state": "UNSPECIFIED",
        "acknowledged": false,
        "source": SOURCE_ID,
        "error": error,
    })


func _release_request_node(request_node: Node) -> void:
    if is_instance_valid(request_node) and not request_node.is_queued_for_deletion():
        request_node.queue_free()
