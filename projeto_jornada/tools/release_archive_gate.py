#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "product" / "release_archive_manifest.json"
RC_CONTRACT = ROOT / "product" / "release_candidate_final_contract.json"
ARTIFACT_CONTRACT = ROOT / "mobile" / "release_artifact_contract.json"
PROVENANCE = ROOT / "product" / "release_provenance.json"
INPUT_SCOPE_GATE = ROOT / "tools" / "release_input_scope_gate.py"
PLACEHOLDER_RE = re.compile(r"^(?:PENDING_|TODO|TBD|CHANGEME)", re.IGNORECASE)
SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
EXPECTED_ARCHIVE_ITEMS = {
    "release_input_manifest",
    "asset_provenance",
    "backend_dependency_lock",
    "backend_software_sbom",
    "android_dependency_inventory",
    "privacy_policy_final",
    "terms_final",
    "store_listing_final",
    "release_notes",
    "public_signing_identity_record",
    "recovery_and_backup_drill_record",
}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def unresolved(value: Any) -> bool:
    return not isinstance(value, str) or not value.strip() or bool(PLACEHOLDER_RE.match(value.strip()))


def pending_paths(value: Any, path: str = "") -> list[str]:
    result: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            result.extend(pending_paths(child, f"{path}.{key}" if path else str(key)))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            result.extend(pending_paths(child, f"{path}[{index}]"))
    elif isinstance(value, str) and PLACEHOLDER_RE.match(value.strip()):
        result.append(path)
    return result


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git_output(*args: str) -> str:
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:  # noqa: BLE001
        return ""


def run_input_scope_gate() -> tuple[bool, str]:
    if not INPUT_SCOPE_GATE.is_file():
        return False, "release_input_scope_gate.py missing"
    result = subprocess.run(
        [sys.executable, str(INPUT_SCOPE_GATE)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    output = "\n".join(part.strip() for part in (result.stdout, result.stderr) if part.strip())
    return result.returncode == 0, output


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the canonical 12.9 release archive manifest and identity chain.")
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    try:
        manifest = read_object(MANIFEST)
        rc_contract = read_object(RC_CONTRACT)
        artifact_contract = read_object(ARTIFACT_CONTRACT)
        provenance = read_object(PROVENANCE)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"RELEASE_ARCHIVE FAIL: {exc}")
        return 1

    scope_ok, scope_output = run_input_scope_gate()
    if not scope_ok:
        errors.append("release input scope gate failed; archive fingerprint identity is unsafe")
        if scope_output:
            errors.append("release input scope detail: " + scope_output.splitlines()[-1][:500])

    if manifest.get("schema_version") != 1 or manifest.get("roadmap_step") != "12.9":
        errors.append("release archive manifest schema/roadmap_step invalid")
    if manifest.get("application_id") != rc_contract.get("application_id"):
        errors.append("archive application_id disagrees with 12.8 candidate")
    if manifest.get("application_id") != artifact_contract.get("application_id"):
        errors.append("archive application_id disagrees with 12.6 artifact contract")
    if manifest.get("target_public_version_name") != artifact_contract.get("target_public_version_name"):
        errors.append("archive target public version disagrees with 12.6 artifact contract")

    items = manifest.get("archive_items", [])
    if not isinstance(items, list):
        errors.append("archive_items must be an array")
        items = []
    item_ids: list[str] = []
    item_paths: list[str] = []
    for index, row in enumerate(items):
        if not isinstance(row, dict):
            errors.append(f"archive item {index} is not an object")
            continue
        item_id = str(row.get("id", ""))
        path = str(row.get("path", ""))
        if not item_id:
            errors.append(f"archive item {index} id missing")
        if not path:
            errors.append(f"archive item {item_id or index} path missing")
        if row.get("required") is not True:
            errors.append(f"canonical archive item must remain required: {item_id}")
        item_ids.append(item_id)
        item_paths.append(path)
    if set(item_ids) != EXPECTED_ARCHIVE_ITEMS:
        errors.append(
            "release archive item set drifted: missing=%s extra=%s"
            % (sorted(EXPECTED_ARCHIVE_ITEMS - set(item_ids)), sorted(set(item_ids) - EXPECTED_ARCHIVE_ITEMS))
        )
    if len(item_ids) != len(set(item_ids)):
        errors.append("duplicate release archive item ids")
    resolved_paths = [path for path in item_paths if not unresolved(path)]
    if len(resolved_paths) != len(set(resolved_paths)):
        errors.append("duplicate resolved archive paths")

    invariants = manifest.get("invariants", {})
    if not isinstance(invariants, dict):
        errors.append("release archive invariants missing")
        invariants = {}
    if invariants.get("no_private_secret_material_archived_in_repository") is not True:
        errors.append("release archive must explicitly forbid private secret material in repository")

    pending = pending_paths(manifest)
    identity = manifest.get("identity", {})
    artifact = manifest.get("artifact", {})
    rc_identity = rc_contract.get("candidate_identity", {})

    if args.release:
        if pending:
            errors.append(f"release archive retains {len(pending)} unresolved placeholder(s)")
        if manifest.get("formal_status") != "certified" or manifest.get("pass_recorded") is not True:
            errors.append("release archive manifest is not certified")
        if provenance.get("formal_status") != "certified" or provenance.get("pass_recorded") is not True:
            errors.append("release provenance is not certified before archive freeze")
        if not isinstance(identity, dict) or not isinstance(artifact, dict):
            errors.append("release archive identity/artifact sections invalid")
        else:
            commit_sha = str(identity.get("rc_commit_sha", ""))
            if not COMMIT_RE.fullmatch(commit_sha):
                errors.append("archive rc_commit_sha must be a full 40-hex commit")
            if str(identity.get("version_name", "")) != manifest.get("target_public_version_name"):
                errors.append("archive version_name disagrees with target public version")
            if not isinstance(identity.get("version_code"), int) or int(identity.get("version_code", 0)) <= 0:
                errors.append("archive version_code must be positive")
            for label, value in (
                ("aab_sha256", artifact.get("aab_sha256")),
                ("signing_certificate_sha256", artifact.get("signing_certificate_sha256")),
                ("release_input_fingerprint_sha256", artifact.get("release_input_fingerprint_sha256")),
            ):
                if not SHA256_RE.fullmatch(str(value or "")):
                    errors.append(f"archive {label} must be 64 hex characters")

            if isinstance(rc_identity, dict):
                comparisons = {
                    "rc_commit_sha": "commit_sha",
                    "version_name": "version_name",
                    "version_code": "version_code",
                }
                for archive_key, rc_key in comparisons.items():
                    if identity.get(archive_key) != rc_identity.get(rc_key):
                        errors.append(f"archive identity mismatch with 12.8: {archive_key}")
                if artifact.get("aab_sha256") != rc_identity.get("aab_sha256"):
                    errors.append("archive AAB SHA-256 mismatch with 12.8 candidate")
                if artifact.get("signing_certificate_sha256") != rc_identity.get("signing_certificate_sha256"):
                    errors.append("archive signing certificate SHA-256 mismatch with 12.8 candidate")
                if identity.get("tested_track") != rc_identity.get("tested_track"):
                    errors.append("archive tested track mismatch with 12.8 candidate")

            tag = str(identity.get("release_tag", ""))
            tag_commit = git_output("rev-list", "-n", "1", tag)
            if not tag_commit or tag_commit != commit_sha:
                errors.append("archive release tag does not resolve exactly to rc_commit_sha")

        for row in items:
            if not isinstance(row, dict):
                continue
            item_id = str(row.get("id", ""))
            relative = str(row.get("path", ""))
            expected_hash = str(row.get("sha256", ""))
            path = ROOT / relative
            if not path.is_file():
                errors.append(f"required archive item missing from repository: {item_id}:{relative}")
                continue
            actual_hash = sha256_file(path)
            if not SHA256_RE.fullmatch(expected_hash) or actual_hash.lower() != expected_hash.lower():
                errors.append(f"archive item SHA-256 mismatch: {item_id}")

        for key, value in invariants.items():
            if value is not True:
                errors.append(f"release archive invariant not verified: {key}")
    else:
        if pending:
            warnings.append(f"archive preflight retains {len(pending)} release-time placeholder(s)")
        if provenance.get("formal_status") != "certified":
            warnings.append("release provenance remains in progress, expected before final assets/dependency evidence")

    report = {
        "schema_version": 2,
        "roadmap_step": "12.9",
        "mode": "release" if args.release else "preflight",
        "archive_item_count": len(items),
        "placeholder_count": len(pending),
        "release_input_scope_verified": scope_ok,
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if errors:
        print(f"RELEASE_ARCHIVE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(f"RELEASE_ARCHIVE {mode} PASS: items={len(items)} placeholders={len(pending)} warnings={len(warnings)} input_scope=1")
    for warning in warnings:
        print("WARNING:", warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
