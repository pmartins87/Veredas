#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "product" / "final_release_contract.json"
LEDGER = ROOT / "qa" / "known_issues.json"
CONTINUITY = ROOT / "product" / "continuity_support_contract.json"
REQUIRED_COMPLETIONS = {
    "12.8": ROOT / "RELEASE_12_8_COMPLETION.json",
    "12.9": ROOT / "RELEASE_12_9_COMPLETION.json",
}
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


def completion_commit(row: dict[str, Any]) -> str:
    for key in ("certified_commit", "commit_sha", "head_sha", "rc_commit_sha"):
        value = row.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Certify Veredas da Trama 12.10 final readiness.")
    parser.add_argument("--release", action="store_true", help="Require all final real release evidence.")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    try:
        contract = read_object(CONTRACT)
        ledger = read_object(LEDGER)
        continuity = read_object(CONTINUITY)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FINAL_RELEASE FAIL: {exc}")
        return 1

    if contract.get("schema_version") != 1 or contract.get("roadmap_step") != "12.10":
        errors.append("12.10 contract schema/roadmap_step invalid")
    expected_names = [path.name for path in REQUIRED_COMPLETIONS.values()]
    if contract.get("required_completion_records") != expected_names:
        errors.append("12.10 required completion record list changed unexpectedly")

    active = []
    for issue in ledger.get("issues", []):
        if not isinstance(issue, dict) or issue.get("kind") != "product_defect":
            continue
        if issue.get("severity") in {"blocker", "critical"} and issue.get("status") in {"open", "in_progress"}:
            active.append(str(issue.get("id", "unknown")))
    if active:
        errors.append("active blocker/critical product defects: " + ", ".join(active))

    readiness = contract.get("readiness", {})
    claims = contract.get("public_claims", {})
    if not isinstance(readiness, dict) or len(readiness) < 8:
        errors.append("final readiness checklist incomplete")
    if not isinstance(claims, dict) or set(claims) != {"ready_to_play", "ready_to_promote", "ready_to_publish"}:
        errors.append("public readiness claim contract invalid")

    head_sha = git_output("rev-parse", "HEAD")
    completion_rows: dict[str, dict[str, Any]] = {}
    if args.release:
        for step, path in REQUIRED_COMPLETIONS.items():
            if not path.exists():
                errors.append(f"{step}: completion record missing")
                continue
            try:
                row = read_object(path)
            except (OSError, ValueError, json.JSONDecodeError) as exc:
                errors.append(f"{step}: invalid completion record: {exc}")
                continue
            completion_rows[step] = row
            if row.get("status") != "pass" and row.get("formal_status") != "complete":
                errors.append(f"{step}: completion record does not report pass")
            commit_sha = completion_commit(row)
            if not is_ancestor(commit_sha, head_sha):
                errors.append(f"{step}: certified commit is not an ancestor of final HEAD")

        identity = contract.get("final_identity", {})
        for key in ("release_tag", "commit_sha", "version_name", "aab_sha256", "signing_certificate_sha256"):
            if unresolved(identity.get(key)):
                errors.append(f"final_identity.{key} is unresolved")
        if not isinstance(identity.get("version_code"), int) or int(identity.get("version_code", 0)) <= 0:
            errors.append("final_identity.version_code must be positive")
        if identity.get("commit_sha") != head_sha:
            errors.append("final_identity.commit_sha must equal current HEAD")

        tag = identity.get("release_tag", "")
        if isinstance(tag, str) and tag and not unresolved(tag):
            tag_commit = git_output("rev-list", "-n", "1", tag)
            if not tag_commit or tag_commit != head_sha:
                errors.append("final release tag does not resolve exactly to current HEAD")

        archive = continuity.get("release_archive", {})
        source = continuity.get("source_of_truth", {})
        comparisons = {
            "commit_sha": archive.get("rc_commit_sha"),
            "version_name": archive.get("store_version_name"),
            "version_code": archive.get("store_version_code"),
            "aab_sha256": archive.get("aab_sha256"),
            "signing_certificate_sha256": archive.get("signing_certificate_sha256"),
            "release_tag": source.get("final_release_tag"),
        }
        for key, archived in comparisons.items():
            if identity.get(key) != archived:
                errors.append(f"final identity differs from 12.9 archive for {key}")

        if any(value is not True for value in readiness.values()):
            errors.append("one or more final readiness checks are not true")
        if any(value is not True for value in claims.values()):
            errors.append("ready_to_play/promote/publish claims are not all true")
        decision = contract.get("final_decision", {})
        if unresolved(decision.get("decision_owner")):
            errors.append("final decision owner is unresolved")
        if unresolved(decision.get("recorded_at")):
            errors.append("final decision timestamp is unresolved")
        if decision.get("decision") != "go":
            errors.append("final decision is not 'go'")
        if contract.get("pass_recorded") is not True:
            errors.append("12.10 pass_recorded is not true")
    else:
        for step, path in REQUIRED_COMPLETIONS.items():
            if not path.exists():
                warnings.append(f"{step}: awaiting {path.name}")
        if active:
            warnings.append("active release blocker exists")

    report = {
        "schema_version": 1,
        "roadmap_step": "12.10",
        "mode": "release" if args.release else "preflight",
        "head_sha": head_sha,
        "active_blocker_critical": active,
        "completion_records_found": sorted(completion_rows),
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if errors:
        print(f"FINAL_RELEASE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    if args.release:
        print("FINAL_RELEASE PASS: 12.10 ready to play, promote and publish")
    else:
        print(f"FINAL_RELEASE PREFLIGHT PASS: contract valid warnings={len(warnings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
