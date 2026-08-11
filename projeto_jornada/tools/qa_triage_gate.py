#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "qa" / "known_issues.json"
SEVERITIES = ("blocker", "critical", "major", "minor", "trivial")
ACTIVE = {"open", "in_progress"}
RESOLVED = {"resolved", "verified", "wont_fix"}
KINDS = {"product_defect"}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the canonical QA issue ledger and enforce the 11.8 zero blocker/critical rule.")
    parser.add_argument("--require-zero", action="store_true", help="Fail when any active blocker/critical product defect exists.")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    ledger = read_object(LEDGER)
    errors: list[str] = []
    warnings: list[str] = []
    issues = ledger.get("issues", [])
    if ledger.get("schema_version") != 1:
        errors.append("known issue ledger schema must be 1")
    if not isinstance(issues, list):
        errors.append("issues must be an array")
        issues = []

    seen: set[str] = set()
    active_release_blockers: list[dict[str, Any]] = []
    counts = Counter()
    normalized: list[dict[str, Any]] = []

    for index, raw in enumerate(issues):
        if not isinstance(raw, dict):
            errors.append(f"issue[{index}] must be an object")
            continue
        issue_id = str(raw.get("id", "")).strip()
        kind = str(raw.get("kind", "")).strip()
        severity = str(raw.get("severity", "")).strip()
        status = str(raw.get("status", "")).strip()
        area = str(raw.get("area", "")).strip()
        title = str(raw.get("title", "")).strip()
        impact = str(raw.get("impact", "")).strip()
        exit_criteria = raw.get("exit_criteria", [])
        evidence = raw.get("evidence", [])

        if not issue_id:
            errors.append(f"issue[{index}] missing id")
        elif issue_id in seen:
            errors.append(f"duplicate issue id: {issue_id}")
        seen.add(issue_id)
        if kind not in KINDS:
            errors.append(f"{issue_id or index}: unsupported issue kind {kind!r}")
        if severity not in SEVERITIES:
            errors.append(f"{issue_id or index}: unsupported severity {severity!r}")
        if status not in ACTIVE | RESOLVED:
            errors.append(f"{issue_id or index}: unsupported status {status!r}")
        if not area or not title or not impact:
            errors.append(f"{issue_id or index}: area/title/impact are required")
        if not isinstance(evidence, list) or not evidence:
            errors.append(f"{issue_id or index}: at least one evidence item is required")
        if not isinstance(exit_criteria, list) or not exit_criteria:
            errors.append(f"{issue_id or index}: explicit exit criteria are required")

        counts[f"severity:{severity}"] += 1
        counts[f"status:{status}"] += 1
        normalized_row = {
            "id": issue_id,
            "severity": severity,
            "status": status,
            "area": area,
            "title": title,
        }
        normalized.append(normalized_row)
        if kind == "product_defect" and severity in {"blocker", "critical"} and status in ACTIVE:
            active_release_blockers.append(normalized_row)

    dependencies = ledger.get("non_defect_release_dependencies", [])
    if not isinstance(dependencies, list):
        errors.append("non_defect_release_dependencies must be an array")
        dependencies = []
    dep_ids: set[str] = set()
    for index, raw in enumerate(dependencies):
        if not isinstance(raw, dict):
            errors.append(f"dependency[{index}] must be an object")
            continue
        dep_id = str(raw.get("id", "")).strip()
        if not dep_id:
            errors.append(f"dependency[{index}] missing id")
        elif dep_id in dep_ids or dep_id in seen:
            errors.append(f"duplicate ledger id: {dep_id}")
        dep_ids.add(dep_id)
        if str(raw.get("status", "")) not in {"pending", "satisfied"}:
            errors.append(f"{dep_id or index}: dependency status must be pending/satisfied")

    if active_release_blockers:
        message = f"{len(active_release_blockers)} active blocker/critical product defect(s)"
        if args.require_zero:
            errors.append(message)
        else:
            warnings.append(message)

    report = {
        "schema_version": 1,
        "require_zero": args.require_zero,
        "issues": normalized,
        "active_blocker_critical": active_release_blockers,
        "active_blocker_critical_count": len(active_release_blockers),
        "dependencies": dependencies,
        "counts": dict(sorted(counts.items())),
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        "QA_TRIAGE %s: issues=%d active_blocker_critical=%d dependencies=%d"
        % ("FINAL" if args.require_zero else "PREFLIGHT", len(normalized), len(active_release_blockers), len(dependencies))
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"QA_TRIAGE FAIL: {len(errors)} issue group(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    if active_release_blockers:
        print("QA_TRIAGE PREFLIGHT PASS: ledger valid; 11.8 remains blocked")
    else:
        print("QA_TRIAGE PASS: zero blocker/critical product defects")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
