#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "projeto_jornada"

REQUIRED_COMPLETIONS = {
    "11.3": "PERFORMANCE_11_3_COMPLETION.json",
    "11.6": "LOCALIZATION_11_6_COMPLETION.json",
    "11.7": "AUDIOVISUAL_11_7_COMPLETION.json",
    "11.8": "QA_11_8_COMPLETION.json",
    "11.9": "RELIABILITY_11_9_COMPLETION.json",
}


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


def main() -> int:
    errors: list[str] = []
    evidence: dict[str, Any] = {}

    head_proc = git("rev-parse", "HEAD")
    if head_proc.returncode != 0:
        print("QA_RELEASE_CANDIDATE FAIL: cannot resolve HEAD")
        return 1
    head = head_proc.stdout.strip()

    for step, filename in REQUIRED_COMPLETIONS.items():
        path = PROJECT / filename
        if not path.is_file():
            errors.append(f"{step}: completion evidence missing: {filename}")
            continue
        try:
            row = read_object(path)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(f"{step}: invalid completion evidence: {exc}")
            continue

        if str(row.get("roadmap_step", "")) != step:
            errors.append(f"{step}: roadmap_step mismatch in {filename}")
        if str(row.get("status", "")).lower() != "pass":
            errors.append(f"{step}: status is not pass in {filename}")

        certified_head = str(row.get("certified_against_head", "")).strip()
        if len(certified_head) < 12:
            errors.append(f"{step}: certified_against_head missing in {filename}")
        else:
            exists = git("cat-file", "-e", f"{certified_head}^{{commit}}")
            if exists.returncode != 0:
                errors.append(f"{step}: certified commit unavailable: {certified_head}")
            else:
                ancestor = git("merge-base", "--is-ancestor", certified_head, head)
                if ancestor.returncode != 0:
                    errors.append(
                        f"{step}: certified commit is not an ancestor of RC HEAD: {certified_head}"
                    )

        evidence[step] = {
            "file": filename,
            "status": row.get("status"),
            "certified_against_head": certified_head,
        }

    roadmap = PROJECT / "ROADMAP_STATE.md"
    if not roadmap.is_file():
        errors.append("ROADMAP_STATE.md missing")
    else:
        text = roadmap.read_text(encoding="utf-8")
        for step in ("11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9"):
            if f"- {step} ✅" not in text:
                errors.append(f"roadmap does not mark prerequisite {step} complete")

    report = {
        "schema_version": 1,
        "roadmap_step": "11.10",
        "head": head,
        "required_completions": evidence,
        "errors": errors,
    }

    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    if errors:
        print(f"QA_RELEASE_CANDIDATE FAIL: {len(errors)} prerequisite issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1

    print(
        "QA_RELEASE_CANDIDATE PASS: 11.10 prerequisites=9 completion_artifacts=%d head=%s"
        % (len(REQUIRED_COMPLETIONS), head[:12])
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
