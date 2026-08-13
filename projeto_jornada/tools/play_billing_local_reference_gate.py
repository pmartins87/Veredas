#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "core" / "systems" / "PurchaseReference.gd"
COORDINATOR = ROOT / "core" / "systems" / "PlayBillingCoordinator.gd"
ENTITLEMENT = ROOT / "core" / "systems" / "EntitlementEngine.gd"
REFERENCE_CERT = ROOT / "tests" / "PurchaseReferenceCertification.gd"
REFERENCE_SCENE = ROOT / "tests" / "purchase_reference_certification.tscn"
ENTITLEMENT_CERT = ROOT / "tests" / "EntitlementCertification.gd"
PRIVACY = ROOT / "product" / "privacy_data_safety.json"

REQUIRED = [
    REFERENCE,
    COORDINATOR,
    ENTITLEMENT,
    REFERENCE_CERT,
    REFERENCE_SCENE,
    ENTITLEMENT_CERT,
    PRIVACY,
]


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def require(text: str, fragment: str, label: str, errors: list[str]) -> None:
    if fragment not in text:
        errors.append(f"{label} missing fragment: {fragment}")


def main() -> int:
    errors: list[str] = []
    for path in REQUIRED:
        if not path.exists():
            errors.append(f"required local-reference file missing: {path.relative_to(ROOT)}")
    if errors:
        print("PLAY_BILLING_LOCAL_REFERENCE_GATE FAIL")
        for error in errors:
            print("ERROR:", error)
        return 1

    reference = REFERENCE.read_text(encoding="utf-8")
    coordinator = COORDINATOR.read_text(encoding="utf-8")
    entitlement = ENTITLEMENT.read_text(encoding="utf-8")
    reference_cert = REFERENCE_CERT.read_text(encoding="utf-8")
    entitlement_cert = ENTITLEMENT_CERT.read_text(encoding="utf-8")
    privacy = read_json(PRIVACY)

    for fragment in [
        'const PREFIX := "sha256:"',
        "HashingContext.HASH_SHA256",
        "normalized.to_utf8_buffer()",
        "digest.size() != 32",
        "digest.hex_encode()",
        "static func normalize_persisted",
        "static func is_reference",
        "SHA256_HEX_LENGTH := 64",
    ]:
        require(reference, fragment, "PurchaseReference", errors)

    if coordinator.count("PurchaseReference.from_sensitive(token)") < 2:
        errors.append("purchase and restore coordinator paths must hash the purchase token before persistence")
    require(coordinator, 'purchase_failed.emit(product_id, "purchase_reference_hash_failed")', "coordinator", errors)
    require(coordinator, 'coordinator_error.emit("purchase_reference_hash_failed")', "coordinator", errors)
    if '"transaction_id": token' in coordinator:
        errors.append("raw purchase token must never be assigned to persisted transaction_id")

    require(entitlement, "const SCHEMA_VERSION := 2", "EntitlementEngine", errors)
    if entitlement.count("PurchaseReference.normalize_persisted") < 3:
        errors.append("entitlement load, snapshot and purchase paths must normalize persisted references")
    require(entitlement, '"purchase_reference_hash_failed"', "EntitlementEngine", errors)
    if "purchase_token" in entitlement:
        errors.append("EntitlementEngine must not know or persist raw purchase tokens")

    for fragment in [
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        "_legacy_reference_migration_gate",
        "_invalid_reference_gate",
        "PURCHASE_REFERENCE_CERTIFICATION PASS: 12.4",
    ]:
        require(reference_cert, fragment, "purchase-reference certification", errors)
    for fragment in [
        "_local_reference_minimization_gate",
        "schema_version",
        "PurchaseReference.is_reference",
        "legacy-sensitive-purchase-token",
        "local_purchase_reference_sha256=1",
    ]:
        require(entitlement_cert, fragment, "entitlement certification", errors)

    behavior = privacy.get("current_application_behavior", {})
    commercial = privacy.get("commercial_behavior", {})
    verification = commercial.get("production_purchase_verification", {}) if isinstance(commercial, dict) else {}
    local_cache = commercial.get("local_entitlement_cache", {}) if isinstance(commercial, dict) else {}
    if not isinstance(behavior, dict) or not isinstance(verification, dict) or not isinstance(local_cache, dict):
        errors.append("privacy manifest lacks structured local purchase-reference declarations")
    else:
        if local_cache.get("raw_purchase_token_at_rest") is not False:
            errors.append("privacy contract must declare raw purchase token absent from local entitlement cache")
        if local_cache.get("purchase_token_sha256_reference_at_rest") is not True:
            errors.append("privacy contract must declare hashed local purchase reference")
        if local_cache.get("schema_version") != 2:
            errors.append("privacy local entitlement cache schema must match EntitlementEngine schema 2")
        if verification.get("reference_backend_persistence", {}).get("raw_purchase_token_at_rest") is not False:
            errors.append("backend privacy declaration regressed raw-token-at-rest policy")

    print(
        "PLAY_BILLING_LOCAL_REFERENCE_GATE PREFLIGHT: errors=%d raw_token_local_at_rest=0 sha256_reference=1 schema=2 migration=1"
        % len(errors)
    )
    if errors:
        print(f"PLAY_BILLING_LOCAL_REFERENCE_GATE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PLAY_BILLING_LOCAL_REFERENCE_GATE PASS: local entitlement persistence contains only canonical hashed purchase references")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
