#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "product" / "play_test_rollout_plan.json"
STATE_126 = ROOT / "RELEASE_12_6_STATE.json"
QA_LEDGER = ROOT / "qa" / "known_issues.json"

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def pending_paths(value: Any, path: str = "") -> list[str]:
    found: list[str] = []
    if isinstance(value, dict):
        for key, item in value.items():
            child = f"{path}.{key}" if path else str(key)
            found.extend(pending_paths(item, child))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            found.extend(pending_paths(item, f"{path}[{index}]"))
    elif isinstance(value, str) and "PENDING_" in value:
        found.append(path)
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Play internal/closed-test evidence for roadmap 12.7.")
    parser.add_argument("--release", action="store_true", help="Require completed internal and closed testing evidence.")
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    for path in (PLAN, STATE_126, QA_LEDGER):
        if not path.exists():
            errors.append(f"required test/release file missing: {path.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1

    plan = read_json(PLAN)
    state126 = read_json(STATE_126)
    ledger = read_json(QA_LEDGER)
    if plan.get("roadmap_step") != "12.7":
        errors.append("test plan must identify roadmap_step 12.7")
    if str(plan.get("application_id", "")) != "com.pmartins87.veredasdatrama":
        errors.append("12.7 application id mismatch")

    policy = plan.get("project_minimum_policy", {})
    if not isinstance(policy, dict):
        errors.append("project_minimum_policy missing")
        policy = {}
    if int(policy.get("closed_test_min_testers", 0)) < 12:
        errors.append("project closed-test minimum must be at least 12 testers")
    if int(policy.get("closed_test_min_continuous_opt_in_days", 0)) < 14:
        errors.append("project closed-test minimum must be at least 14 continuous days")

    tracks = plan.get("tracks", {})
    internal = tracks.get("internal", {}) if isinstance(tracks, dict) else {}
    closed = tracks.get("closed", {}) if isinstance(tracks, dict) else {}
    if not isinstance(internal, dict) or not isinstance(closed, dict):
        errors.append("internal/closed track contracts missing")
        internal, closed = {}, {}

    internal_evidence = internal.get("evidence", {}) if isinstance(internal, dict) else {}
    closed_evidence = closed.get("evidence", {}) if isinstance(closed, dict) else {}
    if not isinstance(internal_evidence, dict):
        internal_evidence = {}
        errors.append("internal evidence must be an object")
    if not isinstance(closed_evidence, dict):
        closed_evidence = {}
        errors.append("closed evidence must be an object")

    active_blockers = 0
    for row in ledger.get("issues", []):
        if not isinstance(row, dict):
            continue
        if str(row.get("severity", "")) in {"blocker", "critical"} and str(row.get("status", "")) in {"open", "in_progress"}:
            active_blockers += 1
    if active_blockers:
        errors.append(f"canonical ledger has {active_blockers} active blocker/critical issue(s)")

    pending = pending_paths(plan)
    if args.release:
        if pending:
            errors.append(f"12.7 release evidence has {len(pending)} unresolved PENDING field(s)")
        if plan.get("formal_status") != "certified" or plan.get("pass_recorded") is not True:
            errors.append("12.7 is not certified")
        if state126.get("formal_status") != "certified" or state126.get("pass_recorded") is not True:
            errors.append("12.6 final artifact must be certified before 12.7 completion")
        if internal.get("status") != "pass" or internal_evidence.get("result") != "pass":
            errors.append("internal track has not passed")
        if int(internal_evidence.get("hours_elapsed", 0)) < int(internal.get("minimum_window_hours", 48)):
            errors.append("internal test window is shorter than project policy")
        if int(internal_evidence.get("tester_count", 0)) < 1 or int(internal_evidence.get("device_count", 0)) < 1:
            errors.append("internal test has no tester/device evidence")
        if int(internal_evidence.get("blocker_critical", 0)) != 0:
            errors.append("internal test recorded blocker/critical issue(s)")
        internal_sha = str(internal_evidence.get("aab_sha256", ""))
        if not SHA256_RE.fullmatch(internal_sha):
            errors.append("internal tested AAB SHA-256 invalid/missing")

        if closed.get("status") != "pass" or closed_evidence.get("result") != "pass":
            errors.append("closed track has not passed")
        if int(closed_evidence.get("continuous_testers", 0)) < int(closed.get("minimum_testers", 12)):
            errors.append("closed test has fewer than 12 continuously opted-in testers")
        if int(closed_evidence.get("days_continuous", 0)) < int(closed.get("minimum_continuous_opt_in_days", 14)):
            errors.append("closed test has fewer than 14 continuous days")
        if int(closed_evidence.get("distinct_devices", 0)) < 3:
            errors.append("closed test device diversity evidence is too small (<3 distinct devices)")
        if int(closed_evidence.get("feedback_responses", 0)) < 1:
            errors.append("closed test has no recorded tester feedback")
        if int(closed_evidence.get("blocker_critical", 0)) != 0 or int(closed_evidence.get("major_open", 0)) != 0:
            errors.append("closed test retains release-blocking issue(s)")
        if int(closed_evidence.get("billing_scenarios_passed", 0)) != int(closed_evidence.get("billing_scenarios_required", 6)):
            errors.append("closed test billing scenario matrix is incomplete")
        closed_sha = str(closed_evidence.get("aab_sha256", ""))
        if not SHA256_RE.fullmatch(closed_sha):
            errors.append("closed tested AAB SHA-256 invalid/missing")

        access = plan.get("production_access", {})
        if not isinstance(access, dict):
            errors.append("production_access evidence missing")
        else:
            required = access.get("required_by_account_policy")
            if required is True and access.get("status") != "granted":
                errors.append("Play production access is required but not granted")
            if required not in {True, False}:
                errors.append("Play account production-access applicability is unresolved")
    elif pending:
        warnings.append(f"12.7 preflight retains {len(pending)} tester/Play Console placeholder(s)")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "PLAY_TEST_ROLLOUT_GATE %s: active_blocker_critical=%d pending=%d errors=%d warnings=%d"
        % (mode, active_blockers, len(pending), len(errors), len(warnings))
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"PLAY_TEST_ROLLOUT_GATE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PLAY_TEST_ROLLOUT_GATE PASS: Play testing evidence satisfies the declared project policy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
