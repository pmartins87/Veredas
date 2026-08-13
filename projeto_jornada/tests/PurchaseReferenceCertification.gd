extends Node

var failures: Array[String] = []


func _ready() -> void:
    _known_sha256_gate()
    _canonical_reference_gate()
    _legacy_reference_migration_gate()
    _invalid_reference_gate()
    _empty_reference_gate()
    _finish()


func _known_sha256_gate() -> void:
    var expected := "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    var actual := PurchaseReference.from_sensitive("abc")
    expect(actual == expected, "12.4 SHA-256 known vector mismatch")
    expect(PurchaseReference.is_reference(actual), "12.4 generated SHA-256 reference rejected")


func _canonical_reference_gate() -> void:
    var upper := "SHA256:BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"
    var normalized := PurchaseReference.normalize_persisted(upper)
    expect(normalized == upper.to_lower(), "12.4 canonical purchase reference did not normalize case")
    expect(PurchaseReference.normalize_persisted(normalized) == normalized, "12.4 canonical reference was re-hashed")


func _legacy_reference_migration_gate() -> void:
    var legacy := "legacy-sensitive-purchase-token"
    var migrated := PurchaseReference.normalize_persisted(legacy)
    expect(PurchaseReference.is_reference(migrated), "12.4 legacy sensitive reference was not hashed")
    expect(migrated != legacy, "12.4 legacy sensitive reference persisted verbatim")
    expect(legacy not in migrated, "12.4 legacy token leaked into hashed reference")


func _invalid_reference_gate() -> void:
    var invalid := "sha256:not-a-valid-digest"
    expect(not PurchaseReference.is_reference(invalid), "12.4 malformed SHA-256 reference accepted")
    var normalized := PurchaseReference.normalize_persisted(invalid)
    expect(PurchaseReference.is_reference(normalized), "12.4 malformed persisted reference was not sanitized")
    expect(normalized != invalid, "12.4 malformed reference persisted verbatim")


func _empty_reference_gate() -> void:
    expect(PurchaseReference.from_sensitive("") == "", "12.4 empty sensitive reference produced a digest")
    expect(PurchaseReference.normalize_persisted("  ") == "", "12.4 blank persisted reference produced a digest")
    expect(not PurchaseReference.is_reference(""), "12.4 empty reference accepted as canonical")


func _finish() -> void:
    if failures.is_empty():
        print("PURCHASE_REFERENCE_CERTIFICATION PASS: 12.4 sha256_known_vector=1 migration=1 canonical=1 malformed_sanitized=1")
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PURCHASE_REFERENCE_CERTIFICATION: %s" % failure)
    print("PURCHASE_REFERENCE_CERTIFICATION FAIL: %d" % failures.size())
    get_tree().quit(1)


func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
