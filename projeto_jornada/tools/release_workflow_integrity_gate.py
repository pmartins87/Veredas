#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
CONTRACT = ROOT / "mobile" / "release_artifact_contract.json"
BLOB40 = re.compile(r"^[0-9a-f]{40}$")
WORKFLOWS = {
    "qa_11_10": REPO / ".github" / "workflows" / "veredas-qa-release-candidate.yml",
    "signed_release_aab": REPO / ".github" / "workflows" / "veredas-release-aab.yml",
}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def git_blob(path: Path) -> str:
    proc = subprocess.run(
        ["git", "hash-object", str(path)],
        cwd=REPO,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise ValueError(f"cannot hash workflow: {path}")
    value = proc.stdout.strip().lower()
    if not BLOB40.fullmatch(value):
        raise ValueError(f"invalid Git blob id for workflow: {path}")
    return value


def main() -> int:
    errors: list[str] = []
    actual: dict[str, str] = {}
    try:
        contract = read_object(CONTRACT)
        expected = contract.get("workflow_integrity", {})
        if not isinstance(expected, dict):
            raise ValueError("release artifact contract has no workflow_integrity object")
        for key, path in WORKFLOWS.items():
            if not path.is_file():
                errors.append(f"critical workflow missing: {path.relative_to(REPO)}")
                continue
            actual_blob = git_blob(path)
            actual[key] = actual_blob
            expected_blob = str(expected.get(f"{key}_git_blob_sha", "")).lower()
            if not BLOB40.fullmatch(expected_blob):
                errors.append(f"contract has no valid pinned Git blob for {key}")
            elif actual_blob != expected_blob:
                errors.append(
                    f"critical workflow drift for {key}: expected={expected_blob} actual={actual_blob}"
                )
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as exc:
        errors.append(str(exc))

    if errors:
        print(f"RELEASE_WORKFLOW_INTEGRITY FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print(
        "RELEASE_WORKFLOW_INTEGRITY PASS: qa_11_10=%s signed_aab=%s"
        % (actual["qa_11_10"][:12], actual["signed_release_aab"][:12])
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
