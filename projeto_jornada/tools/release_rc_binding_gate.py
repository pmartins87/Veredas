#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
SHA40 = re.compile(r"^[0-9a-f]{40}$")


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("completion evidence must be a JSON object")
    return value


def git_head() -> str:
    proc = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise ValueError("cannot resolve repository HEAD")
    return proc.stdout.strip().lower()


def main() -> int:
    parser = argparse.ArgumentParser(description="Bind release production to the exact successful 11.10 RC completion artifact.")
    parser.add_argument("--completion", type=Path, required=True)
    parser.add_argument("--workflow-run-id", required=True)
    parser.add_argument("--expected-head", default="")
    args = parser.parse_args()

    errors: list[str] = []
    try:
        row = read_object(args.completion)
        head = git_head()
        expected_head = str(args.expected_head).strip().lower() or head
        certified_head = str(row.get("certified_against_head", "")).strip().lower()
        source_run_id = str(row.get("source_workflow_run_id", "")).strip()
        contract = row.get("evidence_contract", {})

        if not SHA40.fullmatch(head):
            errors.append("repository HEAD is not a full 40-character SHA")
        if not SHA40.fullmatch(expected_head):
            errors.append("expected release HEAD is not a full 40-character SHA")
        if expected_head != head:
            errors.append(f"checked-out HEAD differs from requested release HEAD: checkout={head} requested={expected_head}")
        if row.get("roadmap_step") != "11.10":
            errors.append("completion roadmap_step is not 11.10")
        if str(row.get("status", "")).lower() != "pass":
            errors.append("11.10 completion status is not pass")
        if not SHA40.fullmatch(certified_head):
            errors.append("11.10 certified_against_head is not a full SHA")
        elif certified_head != expected_head:
            errors.append(f"11.10 completion belongs to a different RC: certified={certified_head} release={expected_head}")
        if source_run_id != str(args.workflow_run_id).strip():
            errors.append("11.10 completion source_workflow_run_id does not match the explicitly selected run")
        if str(row.get("source_workflow", "")) != ".github/workflows/veredas-qa-release-candidate.yml":
            errors.append("11.10 completion source workflow is unexpected")
        if not isinstance(contract, dict):
            errors.append("11.10 evidence_contract missing")
        else:
            for key in (
                "written_only_after_all_11_10_workflow_gates_pass",
                "clean_tree_required",
                "no_pass_inferred_from_unexecuted_or_runnerless_job",
            ):
                if contract.get(key) is not True:
                    errors.append(f"11.10 evidence contract invariant missing: {key}")
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        errors.append(str(exc))

    if errors:
        print(f"RELEASE_RC_BINDING FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print(f"RELEASE_RC_BINDING PASS: exact_11_10_head={expected_head[:12]} source_run={args.workflow_run_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
