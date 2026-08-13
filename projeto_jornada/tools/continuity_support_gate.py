#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "product" / "continuity_support_contract.json"
RUNBOOK = ROOT / "docs" / "CONTINUITY_AND_SUPPORT.md"
RC_COMPLETION = ROOT / "RELEASE_12_8_COMPLETION.json"
PROVENANCE_GATE = ROOT / "tools" / "provenance_license_gate.py"
ARCHIVE_GATE = ROOT / "tools" / "release_archive_gate.py"
PLACEHOLDER_RE = re.compile(r"^(?:PENDING_|TODO|TBD|CHANGEME)", re.IGNORECASE)


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def unresolved(value: Any) -> bool:
    return not isinstance(value, str) or not value.strip() or bool(PLACEHOLDER_RE.match(value.strip()))


def git_output(*args: str) -> str:
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:  # noqa: BLE001
        return ""


def is_ancestor(commit_sha: str, head_sha: str) -> bool:
    if not commit_sha or not head_sha:
        return False
    return subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit_sha, head_sha],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0


def completion_commit(row: dict[str, Any]) -> str:
    for key in ("certified_against_head", "certified_commit", "commit_sha", "head_sha", "rc_commit_sha"):
        value = row.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def run_component_gate(path: Path, release: bool) -> tuple[bool, str]:
    command = [sys.executable, str(path)]
    if release:
        command.append("--release")
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    output = "\n".join(part.strip() for part in (result.stdout, result.stderr) if part.strip())
    return result.returncode == 0, output


def require_true_flags(section: Any, keys: tuple[str, ...], label: str, errors: list[str]) -> None:
    if not isinstance(section, dict):
        errors.append(f"{label} section missing")
        return
    for key in keys:
        if section.get(key) is not True:
            errors.append(f"{label}.{key} must remain true")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Veredas 12.9 continuity, archive, provenance and support readiness.")
    parser.add_argument("--release", action="store_true", help="Require final real continuity evidence.")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    try:
        contract = read_object(CONTRACT)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"CONTINUITY_SUPPORT FAIL: {exc}")
        return 1

    if contract.get("schema_version") != 3 or contract.get("roadmap_step") != "12.9":
        errors.append("12.9 contract schema/roadmap_step invalid")
    if not RUNBOOK.exists() or RUNBOOK.stat().st_size < 3000:
        errors.append("continuity/support runbook is missing or unexpectedly small")

    for gate, label in ((PROVENANCE_GATE, "provenance/license"), (ARCHIVE_GATE, "release archive")):
        if not gate.exists():
            errors.append(f"12.9 {label} gate missing")
            continue
        ok, output = run_component_gate(gate, args.release)
        if not ok:
            errors.append(f"{label} gate failed in matching mode")
            if output:
                errors.append(f"{label} detail: {output.splitlines()[-1][:500]}")

    source = contract.get("source_of_truth", {})
    if not isinstance(source, dict) or source.get("repository") != "pmartins87/desktop-tutorial":
        errors.append("source_of_truth.repository changed unexpectedly")
    if not isinstance(source, dict) or source.get("development_branch") != "projeto-jornada-snapshots":
        errors.append("source_of_truth.development_branch changed unexpectedly")

    support = contract.get("support_policy", {})
    targets = support.get("initial_triage_target_hours", {}) if isinstance(support, dict) else {}
    required_severities = {"blocker", "critical", "major", "minor", "trivial"}
    if set(targets) != required_severities or any(not isinstance(v, int) or v <= 0 for v in targets.values()):
        errors.append("support triage targets are incomplete/invalid")

    compatibility = contract.get("compatibility_policy", {})
    if not isinstance(compatibility, dict) or any(value is not True for value in compatibility.values()):
        errors.append("compatibility policy must remain explicitly enabled")

    secret_policy = contract.get("secret_and_signing_policy", {})
    require_true_flags(
        secret_policy,
        ("secrets_in_repository_forbidden", "keystore_in_repository_forbidden"),
        "secret_and_signing_policy",
        errors,
    )

    provenance = contract.get("provenance_and_dependency_evidence", {})
    require_true_flags(
        provenance,
        (
            "asset_file_coverage_required",
            "reference_game_assets_forbidden",
            "unknown_or_unlicensed_assets_forbidden",
            "backend_transitive_hash_lock_required",
            "backend_final_sbom_required",
            "android_final_gradle_dependency_inventory_required",
        ),
        "provenance_and_dependency_evidence",
        errors,
    )

    archive = contract.get("release_archive", {})
    require_true_flags(
        archive,
        (
            "identity_cross_check_with_12_6_and_12_8_required",
            "required_item_hash_verification",
            "external_evidence_references_separate_from_repository_secrets",
        ),
        "release_archive",
        errors,
    )
    if not isinstance(archive, dict) or archive.get("manifest_path") != "product/release_archive_manifest.json":
        errors.append("release_archive.manifest_path must remain canonical")
    if not isinstance(archive, dict) or archive.get("gate") != "tools/release_archive_gate.py":
        errors.append("release_archive.gate must remain canonical")

    head_sha = git_output("rev-parse", "HEAD")
    if args.release:
        if not RC_COMPLETION.exists():
            errors.append("12.8 completion record missing")
        else:
            try:
                rc = read_object(RC_COMPLETION)
                if str(rc.get("roadmap_step", "")) != "12.8":
                    errors.append("12.8 completion roadmap_step mismatch")
                if str(rc.get("status", "")).lower() != "pass":
                    errors.append("12.8 completion record does not report pass")
                if not is_ancestor(completion_commit(rc), head_sha):
                    errors.append("12.8 certified commit is not an ancestor of 12.9 evidence HEAD")
            except (OSError, ValueError, json.JSONDecodeError) as exc:
                errors.append(f"invalid 12.8 completion record: {exc}")

        for section_name, keys in {
            "source_of_truth": ("final_release_tag",),
            "release_archive": (
                "rc_commit_sha", "aab_sha256", "release_input_fingerprint",
                "signing_certificate_sha256", "store_version_name",
            ),
            "ownership_and_recovery": (
                "primary_release_owner", "secondary_recovery_contact", "support_channel", "privacy_contact",
            ),
        }.items():
            section = contract.get(section_name, {})
            for key in keys:
                if not isinstance(section, dict) or unresolved(section.get(key)):
                    errors.append(f"{section_name}.{key} is unresolved")

        if not isinstance(archive.get("store_version_code"), int) or int(archive.get("store_version_code", 0)) <= 0:
            errors.append("release_archive.store_version_code must be positive")
        artifact_commit = str(archive.get("rc_commit_sha", ""))
        if not is_ancestor(artifact_commit, head_sha):
            errors.append("archived artifact commit must be an ancestor of the evidence HEAD")

        tag = source.get("final_release_tag", "") if isinstance(source, dict) else ""
        if isinstance(tag, str) and tag and not unresolved(tag):
            tag_commit = git_output("rev-list", "-n", "1", tag)
            if not tag_commit or tag_commit != artifact_commit:
                errors.append("final release tag does not resolve to archived artifact commit")

        ownership = contract.get("ownership_and_recovery", {})
        require_true_flags(
            ownership,
            ("play_console_recovery_verified", "repository_recovery_verified", "billing_backend_recovery_verified"),
            "ownership_and_recovery",
            errors,
        )
        require_true_flags(
            secret_policy,
            (
                "external_keystore_backup_verified", "external_secret_backup_verified",
                "backup_restore_drill_recorded", "signing_identity_documented_without_private_material",
            ),
            "secret_and_signing_policy",
            errors,
        )

        legal = contract.get("asset_and_legal_archive", {})
        if not isinstance(legal, dict) or any(value is not True for value in legal.values()):
            errors.append("asset/legal/provenance/archive evidence is incomplete")
        evidence = contract.get("evidence", {})
        if not isinstance(evidence, dict) or any(value is not True for value in evidence.values()):
            errors.append("12.9 final evidence is incomplete")
        if not isinstance(provenance, dict) or provenance.get("finalized") is not True:
            errors.append("provenance/dependency evidence is not finalized")
        if contract.get("pass_recorded") is not True:
            errors.append("12.9 pass_recorded is not true")
    else:
        if not RC_COMPLETION.exists():
            warnings.append("awaiting RELEASE_12_8_COMPLETION.json")
        if not isinstance(provenance, dict) or provenance.get("finalized") is not True:
            warnings.append("provenance/dependency evidence remains open until final assets/dependency reports exist")
        for section_name, keys in {
            "source_of_truth": ("final_release_tag",),
            "ownership_and_recovery": ("primary_release_owner", "secondary_recovery_contact", "support_channel", "privacy_contact"),
        }.items():
            section = contract.get(section_name, {})
            for key in keys:
                if not isinstance(section, dict) or unresolved(section.get(key)):
                    warnings.append(f"{section_name}.{key} not configured yet")

    report = {
        "schema_version": 3,
        "roadmap_step": "12.9",
        "mode": "release" if args.release else "preflight",
        "head_sha": head_sha,
        "provenance_gate_bound": True,
        "release_archive_gate_bound": True,
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if errors:
        print(f"CONTINUITY_SUPPORT FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    if args.release:
        print("CONTINUITY_SUPPORT PASS: 12.9 continuity/archive/provenance/support certified")
    else:
        print(f"CONTINUITY_SUPPORT PREFLIGHT PASS: warnings={len(warnings)} provenance_gate=1 archive_gate=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
