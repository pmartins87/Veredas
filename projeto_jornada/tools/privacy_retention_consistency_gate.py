#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND_CONTRACT = ROOT / "backend" / "play_purchase_verifier" / "backend_contract.json"
PRIVACY = ROOT / "product" / "privacy_data_safety.json"
POLICY = ROOT / "docs" / "PRIVACY_POLICY_DRAFT.md"
LEGAL = ROOT / "product" / "legal_documents.json"

EXPECTED = {
    "ttl_field": "expires_at",
    "active_verified_nonconsumable_days_since_last_activity": 730,
    "non_owned_pending_bound_cancelled_days_since_last_activity": 30,
    "test_purchase_days_since_last_activity": 7,
    "refresh_on_backend_activity": True,
    "expired_record_recreation_requires_authoritative_google_verification": True,
}


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def main() -> int:
    errors: list[str] = []
    for path in [BACKEND_CONTRACT, PRIVACY, POLICY, LEGAL]:
        if not path.exists():
            errors.append(f"required retention disclosure missing: {path.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1

    backend = read_json(BACKEND_CONTRACT)
    privacy = read_json(PRIVACY)
    legal = read_json(LEGAL)
    policy_text = POLICY.read_text(encoding="utf-8")

    backend_retention = backend.get("persistence", {}).get("retention_and_deletion_policy", {})
    privacy_retention = (
        privacy.get("commercial_behavior", {})
        .get("production_purchase_verification", {})
        .get("reference_backend_persistence", {})
        .get("retention_and_deletion", {})
    )
    if not isinstance(backend_retention, dict):
        errors.append("backend retention contract missing")
        backend_retention = {}
    if not isinstance(privacy_retention, dict):
        errors.append("privacy retention declaration missing")
        privacy_retention = {}

    for key, expected in EXPECTED.items():
        if backend_retention.get(key) != expected:
            errors.append(f"backend retention drift: {key}={backend_retention.get(key)!r} expected={expected!r}")
        if privacy_retention.get(key) != expected:
            errors.append(f"privacy retention drift: {key}={privacy_retention.get(key)!r} expected={expected!r}")

    if backend_retention.get("ttl_provider") != "Google Cloud Firestore TTL":
        errors.append("backend TTL provider drift")
    if privacy_retention.get("ttl_provider") != "Google Cloud Firestore TTL":
        errors.append("privacy TTL provider drift")
    if backend_retention.get("all_records_have_finite_expiry") is not True:
        errors.append("backend contract no longer guarantees finite expiry")
    if privacy_retention.get("all_records_have_finite_expiry") is not True:
        errors.append("privacy manifest no longer guarantees finite expiry")

    if "PENDING_12_3_12_4_RETENTION_POLICY" in policy_text:
        errors.append("obsolete retention placeholder remains in privacy policy")

    policy_fragments = [
        "**730 dias**",
        "**30 dias**",
        "**7 dias**",
        "**730 days**",
        "**30 days**",
        "**7 days**",
        "expires_at",
        "nova verificação autoritativa com o Google Play",
        "fresh authoritative Google Play verification",
    ]
    for fragment in policy_fragments:
        if fragment not in policy_text:
            errors.append(f"privacy policy missing retention disclosure fragment: {fragment}")

    locales = legal.get("locales", {})
    if not isinstance(locales, dict):
        errors.append("runtime legal locale map missing")
        locales = {}
    for locale_id, fragments in {
        "pt_BR": ["730 dias", "30 dias", "7 dias", "expires_at", "novamente verificada com o Google Play"],
        "en": ["730 days", "30 days", "7 days", "expires_at", "freshly verified with Google Play"],
    }.items():
        row = locales.get(locale_id, {})
        body = str(row.get("privacy_body", "")) if isinstance(row, dict) else ""
        for fragment in fragments:
            if fragment not in body:
                errors.append(f"runtime legal {locale_id} missing retention disclosure: {fragment}")

    if legal.get("publication_status") != "pre_release":
        errors.append("retention hardening must not prematurely finalize runtime legal documents")

    if errors:
        print(f"PRIVACY_RETENTION_CONSISTENCY FAIL: errors={len(errors)}")
        for error in errors:
            print("ERROR:", error)
        return 1

    print("PRIVACY_RETENTION_CONSISTENCY PASS: backend=privacy=policy=runtime_legal active=730 non_owned=30 test=7 ttl=expires_at authoritative_reverify=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
