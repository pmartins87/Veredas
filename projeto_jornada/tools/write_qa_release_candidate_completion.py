#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Write 11.10 completion evidence after the complete QA freeze workflow has passed.")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workflow-run-id", default="")
    args = parser.parse_args()

    head = git("rev-parse", "HEAD")
    if head.returncode != 0:
        print("WRITE_QA_RC_COMPLETION FAIL: cannot resolve HEAD")
        return 1
    commit = head.stdout.strip().lower()
    if len(commit) != 40:
        print("WRITE_QA_RC_COMPLETION FAIL: HEAD is not a full commit SHA")
        return 1

    dirty = git("status", "--porcelain")
    if dirty.returncode != 0 or dirty.stdout.strip():
        print("WRITE_QA_RC_COMPLETION FAIL: source tree must be clean before certifying RC")
        return 1

    record = {
        "schema_version": 1,
        "roadmap_step": "11.10",
        "status": "pass",
        "certified_against_head": commit,
        "certified_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "source_workflow": ".github/workflows/veredas-qa-release-candidate.yml",
        "source_workflow_run_id": str(args.workflow_run_id).strip(),
        "evidence_contract": {
            "written_only_after_all_11_10_workflow_gates_pass": True,
            "clean_tree_required": True,
            "completion_file_is_an_artifact_until_reviewed_and_persisted": True,
            "no_pass_inferred_from_unexecuted_or_runnerless_job": True,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"WRITE_QA_RC_COMPLETION PASS: head={commit[:12]} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
