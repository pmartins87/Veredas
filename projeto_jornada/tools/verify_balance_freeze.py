#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "projeto_jornada" / "BALANCE_FREEZE.json"


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=check,
    )


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)
    print(f"BALANCE_FREEZE ERROR: {message}")


def main() -> int:
    failures: list[str] = []
    if not MANIFEST.exists():
        print("BALANCE_FREEZE FAIL: manifest missing")
        return 1

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if int(manifest.get("schema", 0)) != 1:
        fail("unsupported manifest schema", failures)

    baseline = str(manifest.get("baseline_commit", "")).strip()
    if len(baseline) < 12:
        fail("baseline_commit missing", failures)
    else:
        exists = git("cat-file", "-e", f"{baseline}^{{commit}}", check=False)
        if exists.returncode != 0:
            fail(f"baseline commit {baseline} is not available; checkout must use full history", failures)
        else:
            ancestor = git("merge-base", "--is-ancestor", baseline, "HEAD", check=False)
            if ancestor.returncode != 0:
                fail(f"baseline {baseline} is not an ancestor of HEAD", failures)

    evidence = manifest.get("certification", {})
    if str(evidence.get("phase10_certified_through", "")) != "10.9":
        fail("manifest does not record certification through 10.9", failures)
    if str(evidence.get("main_ci_result", "")) != "PASS":
        fail("main CI evidence is not PASS", failures)
    if str(evidence.get("adversarial_result", "")) != "PASS":
        fail("adversarial evidence is not PASS", failures)
    if int(evidence.get("main_ci_run_id", 0)) <= 0 or int(evidence.get("adversarial_run_id", 0)) <= 0:
        fail("certification run IDs are missing", failures)

    protected_paths = manifest.get("protected_paths", [])
    if not isinstance(protected_paths, list) or not protected_paths:
        fail("protected_paths is empty", failures)
    elif baseline:
        changed = git("diff", "--name-only", baseline, "--", *[str(p) for p in protected_paths], check=False)
        names = [line.strip() for line in changed.stdout.splitlines() if line.strip()]
        if changed.returncode != 0:
            fail(f"git diff failed: {changed.stderr.strip()}", failures)
        elif names:
            fail("balance drift since certified baseline: " + ", ".join(names[:40]), failures)

    for path, expected_sha in (manifest.get("self_protected_files", {}) or {}).items():
        full = ROOT / str(path)
        if not full.is_file():
            fail(f"self-protected file missing: {path}", failures)
            continue
        actual = git("hash-object", str(path), check=False)
        if actual.returncode != 0:
            fail(f"cannot hash {path}: {actual.stderr.strip()}", failures)
            continue
        actual_sha = actual.stdout.strip()
        if actual_sha != str(expected_sha):
            fail(f"self-protected file changed: {path} expected={expected_sha} actual={actual_sha}", failures)

    expected_scenarios = int(manifest.get("adversarial_scenarios", 0))
    if expected_scenarios < 9:
        fail("freeze must retain at least the 9 certified adversarial scenarios", failures)

    if failures:
        print(f"BALANCE_FREEZE FAIL: {len(failures)} issue(s)")
        return 1

    print(
        "BALANCE_FREEZE PASS: 10.10 baseline=%s protected_paths=%d self_protected=%d scenarios=%d"
        % (
            baseline[:12],
            len(protected_paths),
            len(manifest.get("self_protected_files", {})),
            expected_scenarios,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
