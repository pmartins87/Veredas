#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
SHA64 = re.compile(r"^[0-9a-f]{64}$")


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Write 11.10 completion evidence after the complete QA freeze workflow has passed.")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workflow-run-id", default="")
    parser.add_argument("--release-input-manifest", type=Path, required=True)
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

    try:
        manifest = read_object(args.release_input_manifest)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"WRITE_QA_RC_COMPLETION FAIL: invalid release input manifest: {exc}")
        return 1
    aggregate = str(manifest.get("aggregate_sha256", "")).lower()
    if not SHA64.fullmatch(aggregate):
        print("WRITE_QA_RC_COMPLETION FAIL: release input manifest has no valid aggregate SHA-256")
        return 1
    file_count = int(manifest.get("file_count", 0))
    if file_count <= 0:
        print("WRITE_QA_RC_COMPLETION FAIL: release input manifest file_count is invalid")
        return 1

    record = {
        "schema_version": 2,
        "roadmap_step": "11.10",
        "status": "pass",
        "certified_against_head": commit,
        "certified_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "source_workflow": ".github/workflows/veredas-qa-release-candidate.yml",
        "source_workflow_run_id": str(args.workflow_run_id).strip(),
        "release_input_evidence": {
            "manifest_artifact_filename": "QA_11_10_RELEASE_INPUT_MANIFEST.json",
            "manifest_sha256": sha256_file(args.release_input_manifest),
            "aggregate_sha256": aggregate,
            "file_count": file_count,
            "scope_policy": str(manifest.get("scope_policy", "")),
        },
        "evidence_contract": {
            "written_only_after_all_11_10_workflow_gates_pass": True,
            "clean_tree_required": True,
            "public_release_version_frozen_before_certification": True,
            "release_input_fingerprint_certified": True,
            "later_evidence_only_commits_allowed_only_when_release_input_fingerprint_is_identical": True,
            "runtime_build_input_change_requires_new_11_10": True,
            "completion_file_is_an_artifact_until_reviewed_and_persisted": True,
            "no_pass_inferred_from_unexecuted_or_runnerless_job": True,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"WRITE_QA_RC_COMPLETION PASS: head={commit[:12]} inputs={aggregate[:12]} files={file_count} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
