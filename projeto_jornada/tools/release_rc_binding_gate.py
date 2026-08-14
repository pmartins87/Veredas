#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"evidence must be a JSON object: {path}")
    return value


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=ROOT, text=True, capture_output=True, check=False
    )


def git_head() -> str:
    proc = git("rev-parse", "HEAD")
    if proc.returncode != 0:
        raise ValueError("cannot resolve repository HEAD")
    return proc.stdout.strip().lower()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Bind release production to a successful 11.10 RC whose runtime/build fingerprint is unchanged.")
    parser.add_argument("--completion", type=Path, required=True)
    parser.add_argument("--release-input-manifest", type=Path, required=True)
    parser.add_argument("--workflow-run-id", required=True)
    parser.add_argument("--release-head", default="")
    args = parser.parse_args()

    errors: list[str] = []
    certified_head = ""
    release_head = ""
    aggregate = ""
    try:
        row = read_object(args.completion)
        manifest = read_object(args.release_input_manifest)
        head = git_head()
        release_head = str(args.release_head).strip().lower() or head
        certified_head = str(row.get("certified_against_head", "")).strip().lower()
        source_run_id = str(row.get("source_workflow_run_id", "")).strip()
        contract = row.get("evidence_contract", {})
        input_evidence = row.get("release_input_evidence", {})
        aggregate = str(manifest.get("aggregate_sha256", "")).strip().lower()

        if not SHA40.fullmatch(head):
            errors.append("repository HEAD is not a full 40-character SHA")
        if not SHA40.fullmatch(release_head):
            errors.append("release HEAD is not a full 40-character SHA")
        if release_head != head:
            errors.append(f"checked-out HEAD differs from requested release HEAD: checkout={head} requested={release_head}")
        if row.get("roadmap_step") != "11.10":
            errors.append("completion roadmap_step is not 11.10")
        if str(row.get("status", "")).lower() != "pass":
            errors.append("11.10 completion status is not pass")
        if not SHA40.fullmatch(certified_head):
            errors.append("11.10 certified_against_head is not a full SHA")
        else:
            exists = git("cat-file", "-e", f"{certified_head}^{{commit}}")
            if exists.returncode != 0:
                errors.append(f"11.10 certified commit is unavailable: {certified_head}")
            else:
                ancestor = git("merge-base", "--is-ancestor", certified_head, release_head)
                if ancestor.returncode != 0:
                    errors.append("11.10 certified commit is not an ancestor of the release HEAD")
        if source_run_id != str(args.workflow_run_id).strip():
            errors.append("11.10 completion source_workflow_run_id does not match the explicitly selected run")
        if str(row.get("source_workflow", "")) != ".github/workflows/veredas-qa-release-candidate.yml":
            errors.append("11.10 completion source workflow is unexpected")

        if not isinstance(input_evidence, dict):
            errors.append("11.10 release_input_evidence missing")
        else:
            completion_aggregate = str(input_evidence.get("aggregate_sha256", "")).strip().lower()
            manifest_sha = str(input_evidence.get("manifest_sha256", "")).strip().lower()
            if not SHA64.fullmatch(aggregate):
                errors.append("certified release input manifest has invalid aggregate SHA-256")
            if completion_aggregate != aggregate:
                errors.append("completion release-input aggregate does not match the downloaded certified manifest")
            if not SHA64.fullmatch(manifest_sha) or manifest_sha != sha256_file(args.release_input_manifest):
                errors.append("downloaded certified release-input manifest file SHA-256 does not match completion evidence")
            if int(input_evidence.get("file_count", 0)) != int(manifest.get("file_count", -1)):
                errors.append("completion release-input file_count does not match certified manifest")

        if not isinstance(contract, dict):
            errors.append("11.10 evidence_contract missing")
        else:
            for key in (
                "written_only_after_all_11_10_workflow_gates_pass",
                "clean_tree_required",
                "public_release_version_frozen_before_certification",
                "release_input_fingerprint_certified",
                "later_evidence_only_commits_allowed_only_when_release_input_fingerprint_is_identical",
                "runtime_build_input_change_requires_new_11_10",
                "no_pass_inferred_from_unexecuted_or_runnerless_job",
            ):
                if contract.get(key) is not True:
                    errors.append(f"11.10 evidence contract invariant missing: {key}")
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as exc:
        errors.append(str(exc))

    if errors:
        print(f"RELEASE_RC_BINDING FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print(
        "RELEASE_RC_BINDING PASS: certified_head=%s release_head=%s inputs=%s source_run=%s"
        % (certified_head[:12], release_head[:12], aggregate[:12], args.workflow_run_id)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
