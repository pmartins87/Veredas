#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend" / "play_purchase_verifier"
CONTRACT = BACKEND / "backend_contract.json"
POLICY = BACKEND / "retention_policy.py"
REPOSITORY = BACKEND / "firestore_repository.py"
DOCKERFILE = BACKEND / "Dockerfile"
TEST = BACKEND / "tests" / "test_retention_policy.py"

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


def load_policy_summary() -> dict[str, Any]:
    spec = importlib.util.spec_from_file_location("veredas_retention_policy", POLICY)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load retention_policy.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    summary = module.policy_summary()
    if not isinstance(summary, dict):
        raise RuntimeError("policy_summary() must return an object")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate finite purchase-record retention and Firestore TTL contract for 12.3/12.4.")
    parser.add_argument("--release", action="store_true", help="Require the Firestore TTL policy to be enabled and verified in production.")
    args = parser.parse_args()

    errors: list[str] = []
    for path in [CONTRACT, POLICY, REPOSITORY, DOCKERFILE, TEST]:
        if not path.exists():
            errors.append(f"required retention file missing: {path.relative_to(ROOT)}")
    if errors:
        print("PLAY_BILLING_RETENTION_GATE FAIL")
        for error in errors:
            print("ERROR:", error)
        return 1

    try:
        contract = read_json(CONTRACT)
        summary = load_policy_summary()
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"PLAY_BILLING_RETENTION_GATE FAIL: {exc}")
        return 1

    persistence = contract.get("persistence", {})
    if not isinstance(persistence, dict):
        errors.append("backend persistence contract missing")
        persistence = {}
    retention = persistence.get("retention_and_deletion_policy", {})
    if not isinstance(retention, dict):
        errors.append("retention_and_deletion_policy must be an object")
        retention = {}

    if retention.get("implementation") != "retention_policy.py":
        errors.append("retention policy implementation path mismatch")
    if retention.get("ttl_provider") != "Google Cloud Firestore TTL":
        errors.append("retention policy must use declared Firestore TTL provider")
    if retention.get("all_records_have_finite_expiry") is not True:
        errors.append("all backend purchase records must have finite expiry")
    if retention.get("raw_purchase_token_persisted") is not False:
        errors.append("retention policy must never persist the raw purchase token")
    if retention.get("expiration_is_not_entitlement_evidence") is not True:
        errors.append("expiry state must never become entitlement evidence")
    if retention.get("production_ttl_policy_required") is not True:
        errors.append("production Firestore TTL must remain mandatory")

    for key, expected in EXPECTED.items():
        if retention.get(key) != expected:
            errors.append(f"contract retention drift: {key}={retention.get(key)!r} expected={expected!r}")
        if summary.get(key) != expected:
            errors.append(f"code retention drift: {key}={summary.get(key)!r} expected={expected!r}")

    minimum_fields = persistence.get("minimum_fields", [])
    if not isinstance(minimum_fields, list) or "expires_at" not in minimum_fields:
        errors.append("expires_at must be part of the minimum persisted-field contract")

    repository = REPOSITORY.read_text(encoding="utf-8")
    for fragment in [
        "from retention_policy import retention_expiry",
        '"expires_at": retention_expiry(record)',
        "self._activity_patch(current)",
        "effective.update(self._activity_patch(effective))",
        'merged.get("stale_observation", False)',
    ]:
        if fragment not in repository:
            errors.append(f"Firestore repository missing retention fragment: {fragment}")
    if "purchase_token" in repository:
        errors.append("Firestore repository must not accept/store raw purchase_token")

    dockerfile = DOCKERFILE.read_text(encoding="utf-8")
    if "retention_policy.py" not in dockerfile:
        errors.append("backend image does not include retention_policy.py")

    tests = TEST.read_text(encoding="utf-8")
    for test_name in [
        "test_verified_owned_purchase_uses_long_finite_window",
        "test_pending_bound_and_cancelled_records_use_short_window",
        "test_test_purchase_always_uses_shortest_window",
        "test_expiry_is_normalized_to_utc",
        "test_naive_clock_is_rejected",
        "test_policy_summary_matches_frozen_contract",
    ]:
        if test_name not in tests:
            errors.append(f"retention test missing: {test_name}")

    deployment = contract.get("deployment", {})
    if not isinstance(deployment, dict):
        errors.append("backend deployment contract missing")
        deployment = {}
    if args.release:
        if retention.get("status") != "certified_production":
            errors.append("release retention policy status must be certified_production")
        if deployment.get("firestore_ttl_expires_at_enabled") is not True:
            errors.append("production Firestore TTL on expires_at is not enabled")
        if deployment.get("firestore_ttl_policy_verified") is not True:
            errors.append("production Firestore TTL policy is not verified")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    if errors:
        print(f"PLAY_BILLING_RETENTION_GATE {mode} FAIL: errors={len(errors)}")
        for error in errors:
            print("ERROR:", error)
        return 1

    print(
        "PLAY_BILLING_RETENTION_GATE %s PASS: active_days=730 non_owned_days=30 test_days=7 ttl_field=expires_at finite=1 raw_token=0 authoritative_recreate=1"
        % mode
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
