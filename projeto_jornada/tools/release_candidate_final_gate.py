#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "product" / "release_candidate_final_contract.json"
LEDGER = ROOT / "qa" / "known_issues.json"
PLACEHOLDER_RE = re.compile(r"^(?:PENDING_|TODO|TBD|CHANGEME)", re.IGNORECASE)
COMPLETION_FILES = {
    "11.10": ROOT / "QA_11_10_COMPLETION.json",
    "12.1": ROOT / "RELEASE_12_1_COMPLETION.json",
    "12.2": ROOT / "RELEASE_12_2_COMPLETION.json",
    "12.3": ROOT / "RELEASE_12_3_COMPLETION.json",
    "12.4": ROOT / "RELEASE_12_4_COMPLETION.json",
    "12.5": ROOT / "RELEASE_12_5_COMPLETION.json",
    "12.6": ROOT / "RELEASE_12_6_COMPLETION.json",
    "12.7": ROOT / "RELEASE_12_7_COMPLETION.json",
}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def placeholder(value: Any) -> bool:
    return not isinstance(value, str) or not value.strip() or bool(PLACEHOLDER_RE.match(value.strip()))


def current_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:  # noqa: BLE001
        return ""


def is_ancestor(commit_sha: str, head_sha: str) -> bool:
    if not commit_sha or not head_sha:
        return False
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit_sha, head_sha],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def completion_commit(row: dict[str, Any]) -> str:
    for key in ("certified_against_head", "certified_commit", "commit_sha", "head_sha", "rc_commit_sha"):
        value = row.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the Veredas 12.8 final RC and rollback contract.")
    parser.add_argument("--release", action="store_true", help="Require complete real release evidence.")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    try:
        contract = read_object(CONTRACT)
        ledger = read_object(LEDGER)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"RELEASE_CANDIDATE_FINAL FAIL: {exc}")
        return 1

    if contract.get("schema_version") != 1 or contract.get("roadmap_step") != "12.8":
        errors.append("12.8 contract schema/roadmap_step invalid")
    if contract.get("required_prerequisites", []) != list(COMPLETION_FILES):
        errors.append("12.8 prerequisite order/set differs from frozen contract")

    checklist = contract.get("final_regression_checklist", {})
    if not isinstance(checklist, dict) or len(checklist) < 10:
        errors.append("final_regression_checklist is incomplete")
    rollback = contract.get("rollback", {})
    if not isinstance(rollback, dict):
        errors.append("rollback contract missing")
        rollback = {}
    if not isinstance(rollback.get("immediate_stop_conditions", []), list) or len(rollback.get("immediate_stop_conditions", [])) < 5:
        errors.append("rollback immediate stop conditions incomplete")
    if not isinstance(rollback.get("required_compatibility", []), list) or len(rollback.get("required_compatibility", [])) < 4:
        errors.append("rollback compatibility rules incomplete")

    active = []
    for issue in ledger.get("issues", []):
        if not isinstance(issue, dict) or issue.get("kind") != "product_defect":
            continue
        if issue.get("severity") in {"blocker", "critical"} and issue.get("status") in {"open", "in_progress"}:
            active.append(str(issue.get("id", "unknown")))
    if active:
        errors.append("active blocker/critical product defects: " + ", ".join(active))

    completion_reports: dict[str, Any] = {}
    head_sha = current_head()
    if args.release:
        for step, path in COMPLETION_FILES.items():
            if not path.exists():
                errors.append(f"{step}: completion record missing: {path.name}")
                continue
            try:
                row = read_object(path)
            except (OSError, ValueError, json.JSONDecodeError) as exc:
                errors.append(f"{step}: invalid completion record: {exc}")
                continue
            completion_reports[step] = row
            if str(row.get("roadmap_step", "")) != step:
                errors.append(f"{step}: roadmap_step mismatch in completion record")
            if str(row.get("status", "")).lower() != "pass":
                errors.append(f"{step}: completion record does not report pass")
            certified = completion_commit(row)
            if not is_ancestor(certified, head_sha):
                errors.append(f"{step}: certified commit is not an ancestor of current evidence HEAD")

        identity = contract.get("candidate_identity", {})
        for key in ("commit_sha", "version_name", "aab_sha256", "signing_certificate_sha256", "tested_track"):
            if placeholder(identity.get(key)):
                errors.append(f"candidate_identity.{key} is unresolved")
        if not isinstance(identity.get("version_code"), int) or int(identity.get("version_code", 0)) <= 0:
            errors.append("candidate_identity.version_code must be positive")
        candidate_sha = str(identity.get("commit_sha", ""))
        if not is_ancestor(candidate_sha, head_sha):
            errors.append("candidate artifact commit must be an ancestor of the evidence HEAD")

        if any(value is not True for value in checklist.values()):
            errors.append("one or more final regression checklist items are not true")
        for key in ("decision_owner", "incident_channel"):
            if placeholder(rollback.get(key)):
                errors.append(f"rollback.{key} is unresolved")
        first_release = rollback.get("first_public_release", {})
        if not isinstance(first_release, dict) or first_release.get("hotfix_build_recipe_verified") is not True:
            errors.append("first-release hotfix build recipe is not verified")

        evidence = contract.get("evidence", {})
        required_evidence = (
            "prerequisite_completion_files_verified",
            "exact_commit_ancestry_verified",
            "artifact_identity_matches_12_6",
            "tested_artifact_matches_12_7",
            "zero_release_blocking_defects_verified",
            "rollback_dry_run_recorded",
            "final_go_no_go_recorded",
        )
        if not isinstance(evidence, dict) or any(evidence.get(key) is not True for key in required_evidence):
            errors.append("12.8 release evidence is incomplete")
        if evidence.get("go_no_go_decision") != "go":
            errors.append("final go/no-go decision is not 'go'")
        if contract.get("pass_recorded") is not True:
            errors.append("12.8 pass_recorded is not true")
    else:
        for step, path in COMPLETION_FILES.items():
            if not path.exists():
                warnings.append(f"{step}: awaiting {path.name}")
        if placeholder(rollback.get("decision_owner")):
            warnings.append("rollback decision owner not assigned yet")
        if placeholder(rollback.get("incident_channel")):
            warnings.append("release incident channel not assigned yet")

    report = {
        "schema_version": 1,
        "roadmap_step": "12.8",
        "mode": "release" if args.release else "preflight",
        "head_sha": head_sha,
        "active_blocker_critical": active,
        "completion_reports_found": sorted(completion_reports),
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if errors:
        print(f"RELEASE_CANDIDATE_FINAL FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    if args.release:
        print("RELEASE_CANDIDATE_FINAL PASS: 12.8 final RC and rollback evidence certified")
    else:
        print(f"RELEASE_CANDIDATE_FINAL PREFLIGHT PASS: contract valid warnings={len(warnings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
