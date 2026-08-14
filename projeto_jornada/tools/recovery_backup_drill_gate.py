#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "product" / "recovery_backup_drill.json"
PLACEHOLDER_RE = re.compile(r"^(?:PENDING_|TODO|TBD|CHANGEME)", re.IGNORECASE)
SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")
SECRET_PATTERNS = (
    "-----BEGIN PRIVATE KEY-----",
    "-----BEGIN ENCRYPTED PRIVATE KEY-----",
    "-----BEGIN RSA PRIVATE KEY-----",
    "github_pat_",
    "ghp_",
    "AIza",
)
REQUIRED_SCENARIOS = {
    "repository_access_recovery",
    "play_console_access_recovery",
    "billing_backend_access_recovery",
    "upload_keystore_backup_restore",
    "ci_secret_reconfiguration",
    "clean_rebuild_from_source_of_truth",
}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def unresolved(value: Any) -> bool:
    return not isinstance(value, str) or not value.strip() or bool(PLACEHOLDER_RE.match(value.strip()))


def valid_utc(value: Any) -> bool:
    if unresolved(value):
        return False
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate non-secret recovery and backup drill evidence for Veredas 12.9.")
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    try:
        raw = EVIDENCE.read_text(encoding="utf-8")
        row = read_object(EVIDENCE)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"RECOVERY_BACKUP_DRILL FAIL: {exc}")
        return 1

    for pattern in SECRET_PATTERNS:
        if pattern in raw:
            errors.append(f"recovery evidence appears to contain forbidden secret material pattern: {pattern}")

    if row.get("schema_version") != 1 or row.get("roadmap_step") != "12.9":
        errors.append("recovery evidence schema/roadmap_step invalid")

    policy = row.get("policy", {})
    for key in (
        "private_keys_passwords_tokens_recovery_codes_forbidden",
        "evidence_references_must_be_non_secret",
        "two_authorized_people_required_for_final_handoff",
        "restore_test_must_prove_usability_not_merely_backup_existence",
        "production_credentials_must_not_be_exposed_during_drill",
    ):
        if not isinstance(policy, dict) or policy.get(key) is not True:
            errors.append(f"recovery policy invariant missing: {key}")

    systems = row.get("systems", {})
    if not isinstance(systems, dict):
        errors.append("systems section missing")
        systems = {}

    required_systems = {"github_repository", "google_play_console", "billing_backend", "android_upload_keystore", "ci_release_secrets"}
    if set(systems) != required_systems:
        errors.append(f"recovery systems mismatch: expected={sorted(required_systems)} observed={sorted(systems)}")

    for system_id, system in systems.items():
        if not isinstance(system, dict) or system.get("required") is not True:
            errors.append(f"required recovery system invalid: {system_id}")

    keystore = systems.get("android_upload_keystore", {}) if isinstance(systems, dict) else {}
    if isinstance(keystore, dict):
        minimum_locations = int(keystore.get("minimum_independent_backup_locations", 0) or 0)
        if minimum_locations < 2:
            errors.append("upload keystore policy must require at least two independent backup locations")
        if keystore.get("private_key_material_recorded") is not False:
            errors.append("recovery record must never persist upload private-key material")

    ci_secrets = systems.get("ci_release_secrets", {}) if isinstance(systems, dict) else {}
    if isinstance(ci_secrets, dict) and ci_secrets.get("secret_values_recorded") is not False:
        errors.append("recovery record must never persist CI secret values")

    drill = row.get("drill", {})
    scenarios = drill.get("scenarios", []) if isinstance(drill, dict) else []
    if not isinstance(scenarios, list):
        errors.append("recovery drill scenarios must be an array")
        scenarios = []
    scenario_ids = [str(item.get("id", "")) for item in scenarios if isinstance(item, dict)]
    if len(scenario_ids) != len(set(scenario_ids)):
        errors.append("recovery drill scenario ids must be unique")
    if set(scenario_ids) != REQUIRED_SCENARIOS:
        errors.append(f"recovery drill scenario coverage mismatch: expected={sorted(REQUIRED_SCENARIOS)} observed={sorted(scenario_ids)}")
    if isinstance(drill, dict) and drill.get("secret_material_persisted") is not False:
        errors.append("recovery drill must explicitly record secret_material_persisted=false")

    if args.release:
        github = systems.get("github_repository", {})
        play = systems.get("google_play_console", {})
        backend = systems.get("billing_backend", {})
        for system_id, system in (("github_repository", github), ("google_play_console", play)):
            if not isinstance(system, dict) or system.get("recovery_verified") is not True:
                errors.append(f"{system_id} recovery is not verified")
            else:
                for key in ("primary_owner", "secondary_recovery_contact", "evidence_reference"):
                    if unresolved(system.get(key)):
                        errors.append(f"{system_id}.{key} unresolved")
        if not isinstance(backend, dict) or any(backend.get(key) is not True for key in ("recovery_verified", "service_identity_recovery_verified", "firestore_access_recovery_verified")):
            errors.append("billing backend recovery/service identity/Firestore recovery must all be verified")
        elif unresolved(backend.get("evidence_reference")):
            errors.append("billing_backend.evidence_reference unresolved")

        if not isinstance(keystore, dict):
            errors.append("android upload keystore recovery evidence missing")
        else:
            if int(keystore.get("encrypted_backup_locations_verified", 0) or 0) < int(keystore.get("minimum_independent_backup_locations", 2) or 2):
                errors.append("upload keystore has fewer verified encrypted backups than required")
            if keystore.get("restore_tested") is not True:
                errors.append("upload keystore restore has not been tested")
            if not SHA256_RE.fullmatch(str(keystore.get("public_certificate_sha256", ""))):
                errors.append("upload keystore public certificate SHA-256 missing/invalid")
            if unresolved(keystore.get("evidence_reference")):
                errors.append("upload keystore restore evidence reference unresolved")

        if not isinstance(ci_secrets, dict) or ci_secrets.get("external_backup_verified") is not True or ci_secrets.get("reconfiguration_tested") is not True:
            errors.append("CI release secret recovery/reconfiguration is not verified")
        elif unresolved(ci_secrets.get("evidence_reference")):
            errors.append("CI secret recovery evidence reference unresolved")

        if not isinstance(drill, dict) or drill.get("status") != "pass":
            errors.append("recovery drill status is not pass")
        else:
            if not valid_utc(drill.get("performed_at_utc")):
                errors.append("recovery drill performed_at_utc missing/invalid")
            primary = drill.get("primary_operator")
            secondary = drill.get("secondary_observer")
            if unresolved(primary) or unresolved(secondary):
                errors.append("recovery drill primary/secondary operators unresolved")
            elif str(primary).strip() == str(secondary).strip():
                errors.append("recovery drill requires a distinct secondary observer")
            if drill.get("all_scenarios_passed") is not True:
                errors.append("recovery drill all_scenarios_passed is not true")
            if unresolved(drill.get("evidence_archive")):
                errors.append("recovery drill evidence archive unresolved")
            for item in scenarios:
                if not isinstance(item, dict):
                    errors.append("invalid recovery drill scenario row")
                    continue
                if item.get("status") != "pass":
                    errors.append(f"recovery drill scenario not passed: {item.get('id')}")
                if unresolved(item.get("evidence_reference")):
                    errors.append(f"recovery drill scenario evidence unresolved: {item.get('id')}")

        if row.get("formal_status") != "certified" or row.get("pass_recorded") is not True:
            errors.append("recovery drill evidence is not formally certified")
    else:
        pending_systems = sum(
            1
            for system in systems.values()
            if isinstance(system, dict) and (
                system.get("recovery_verified") is False
                or system.get("restore_tested") is False
                or system.get("external_backup_verified") is False
            )
        )
        if pending_systems:
            warnings.append(f"{pending_systems} recovery/backup system verification(s) remain pending")
        pending_scenarios = sum(1 for item in scenarios if isinstance(item, dict) and item.get("status") != "pass")
        if pending_scenarios:
            warnings.append(f"{pending_scenarios} recovery drill scenario(s) remain pending")

    report = {
        "schema_version": 1,
        "roadmap_step": "12.9",
        "mode": "release" if args.release else "preflight",
        "required_system_count": len(required_systems),
        "scenario_count": len(scenarios),
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print(f"RECOVERY_BACKUP_DRILL FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(f"RECOVERY_BACKUP_DRILL {mode} PASS: systems={len(required_systems)} scenarios={len(scenarios)} warnings={len(warnings)}")
    for warning in warnings:
        print("WARNING:", warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
