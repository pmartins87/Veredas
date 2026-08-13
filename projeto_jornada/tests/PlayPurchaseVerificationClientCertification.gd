extends Node

class FakeRequest:
    extends Node
    signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)

    var endpoint := ""
    var headers := PackedStringArray()
    var method := -1
    var body_text := ""

    func request(url: String, request_headers: PackedStringArray, request_method: int, body: String) -> int:
        endpoint = url
        headers = request_headers
        method = request_method
        body_text = body
        return OK

    func respond_json(response_code: int, value: Dictionary, result: int = HTTPRequest.RESULT_SUCCESS) -> void:
        request_completed.emit(
            result,
            response_code,
            PackedStringArray(["content-type: application/json"]),
            JSON.stringify(value).to_utf8_buffer()
        )

    func respond_text(response_code: int, text: String, result: int = HTTPRequest.RESULT_SUCCESS) -> void:
        request_completed.emit(
            result,
            response_code,
            PackedStringArray(["content-type: text/plain"]),
            text.to_utf8_buffer()
        )


var failures: Array[String] = []
var created_requests: Array[FakeRequest] = []
var responses: Array[Dictionary] = []
var client := PlayPurchaseVerificationClient.new()


func _ready() -> void:
    add_child(client)
    client.verification_completed.connect(func(result: Dictionary): responses.append(result.duplicate(true)))
    client.set_request_factory(func(): return _new_fake_request())

    _endpoint_gate()
    _concurrency_and_correlation_gate()
    _transport_failure_gate()
    _payload_rejection_gate()
    _finish()


func _endpoint_gate() -> void:
    expect(not bool(client.configure("http://example.invalid/verify").get("ok", true)), "12.4 verifier accepted plaintext HTTP")
    expect(not bool(client.configure("PENDING_12_4_BACKEND_ENDPOINT").get("ok", true)), "12.4 verifier accepted pending endpoint placeholder")
    expect(bool(client.configure("https://billing.example.invalid/v1/verify").get("ok", false)), "12.4 verifier rejected HTTPS endpoint")


func _concurrency_and_correlation_gate() -> void:
    var created_start := created_requests.size()
    var response_start := responses.size()
    var first := _payload("vreq-purchase-0-1", "full_game_unlock", "token-a")
    var second := _payload("vreq-restore-1-2", "full_game_unlock", "token-a")

    expect(client.verify_purchase(first), "12.4 verifier rejected first valid request")
    expect(client.verify_purchase(second), "12.4 verifier rejected concurrent same-token request")
    expect(client.pending_count() == 2, "12.4 verifier serialized/collapsed concurrent requests")
    expect(created_requests.size() == created_start + 2, "12.4 verifier did not allocate one transport per request")
    expect(not client.verify_purchase(first), "12.4 verifier accepted duplicate in-flight request id")

    var request_a := created_requests[created_start]
    var request_b := created_requests[created_start + 1]
    expect(request_a.endpoint.begins_with("https://"), "12.4 verifier transport endpoint is not HTTPS")
    expect(request_a.method == HTTPClient.METHOD_POST, "12.4 verifier did not use POST")
    expect("Cache-Control: no-store" in request_a.headers, "12.4 verifier request does not disable HTTP caching")

    request_a.respond_json(200, _backend_success(first))
    expect(client.pending_count() == 1, "12.4 first response consumed wrong number of pending requests")
    expect(responses.size() == response_start + 1, "12.4 valid backend response not emitted")
    expect(bool(responses.back().get("ok", false)), "12.4 valid backend response converted to failure")

    var mismatched := _backend_success(second)
    mismatched.verification_request_id = "vreq-wrong"
    request_b.respond_json(200, mismatched)
    expect(client.pending_count() == 0, "12.4 mismatched response left request hanging")
    expect(responses.size() == response_start + 2, "12.4 mismatched response did not emit fail-closed result")
    expect(not bool(responses.back().get("ok", true)), "12.4 mismatched request id was accepted")
    expect(str(responses.back().get("verification_request_id", "")) == str(second.verification_request_id), "12.4 fail-closed response lost original correlation id")


func _transport_failure_gate() -> void:
    var created_start := created_requests.size()
    var response_start := responses.size()
    var payload := _payload("vreq-restore-2-3", "supporter_cosmetic_pack", "token-b")
    expect(client.verify_purchase(payload), "12.4 verifier rejected request for HTTP failure case")
    created_requests[created_start].respond_text(503, "temporarily unavailable")
    expect(client.pending_count() == 0, "12.4 HTTP failure left request pending")
    expect(responses.size() == response_start + 1, "12.4 HTTP failure did not emit result")
    expect(not bool(responses.back().get("ok", true)), "12.4 HTTP 503 was accepted")
    expect(str(responses.back().get("error", "")).begins_with("http_status:"), "12.4 HTTP failure reason not normalized")

    created_start = created_requests.size()
    response_start = responses.size()
    payload = _payload("vreq-restore-3-4", "supporter_cosmetic_pack", "token-c")
    expect(client.verify_purchase(payload), "12.4 verifier rejected malformed-JSON case")
    created_requests[created_start].respond_text(200, "not-json")
    expect(responses.size() == response_start + 1, "12.4 malformed JSON did not emit failure")
    expect(not bool(responses.back().get("ok", true)), "12.4 malformed JSON was accepted")
    expect(str(responses.back().get("error", "")) == "response_not_json_object", "12.4 malformed JSON reason mismatch")


func _payload_rejection_gate() -> void:
    var created_start := created_requests.size()
    var bad_package := _payload("vreq-bad-package", "full_game_unlock", "token-d")
    bad_package.package_name = "com.example.impostor"
    expect(not client.verify_purchase(bad_package), "12.4 verifier accepted wrong application package")

    var bad_product := _payload("vreq-bad-product", "coins_100", "token-e")
    expect(not client.verify_purchase(bad_product), "12.4 verifier accepted product outside commercial contract")

    var missing_token := _payload("vreq-missing-token", "full_game_unlock", "")
    expect(not client.verify_purchase(missing_token), "12.4 verifier accepted empty purchase token")
    expect(created_requests.size() == created_start, "12.4 rejected payload reached HTTP transport")


func _new_fake_request() -> FakeRequest:
    var request := FakeRequest.new()
    created_requests.append(request)
    return request


func _payload(request_id: String, product_id: String, token: String) -> Dictionary:
    return {
        "verification_request_id": request_id,
        "application_id": "com.pmartins87.veredasdatrama",
        "product_id": product_id,
        "purchase_token": token,
        "purchase_time": 1786540000000,
        "package_name": "com.pmartins87.veredasdatrama",
        "client_acknowledged_state": false,
    }


func _backend_success(payload: Dictionary) -> Dictionary:
    return {
        "verification_request_id": str(payload.verification_request_id),
        "ok": true,
        "purchase_token": str(payload.purchase_token),
        "product_id": str(payload.product_id),
        "owned": true,
        "purchase_state": "PURCHASED",
        "acknowledged": true,
        "source": "play_backend",
    }


func _finish() -> void:
    if failures.is_empty():
        print(
            "PLAY_PURCHASE_VERIFICATION_CLIENT_CERTIFICATION PASS: 12.4 https_only=1 concurrent_requests=1 correlation_fail_closed=1 http_fail_closed=1 malformed_json_fail_closed=1 payload_guard=1"
        )
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAY_PURCHASE_VERIFICATION_CLIENT_CERTIFICATION: %s" % failure)
    print("PLAY_PURCHASE_VERIFICATION_CLIENT_CERTIFICATION FAIL: %d" % failures.size())
    get_tree().quit(1)


func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
