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

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "product" / "store_capture_manifest.json"
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git_commit_exists(sha: str) -> bool:
    result = subprocess.run(
        ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
        cwd=ROOT.parent,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Bind already-captured store screenshots to one certified RC without modifying image pixels.")
    parser.add_argument("--rc-commit", required=True)
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--version-code", required=True, type=int)
    parser.add_argument("--release-input-fingerprint", required=True)
    parser.add_argument("--device-profile", required=True)
    parser.add_argument("--android-version", required=True)
    parser.add_argument("--capture-method", required=True)
    parser.add_argument("--captured-at-utc", default="", help="UTC YYYY-MM-DDTHH:MM:SSZ applied to rows that do not already have a timestamp.")
    args = parser.parse_args()

    rc_commit = args.rc_commit.strip().lower()
    fingerprint = args.release_input_fingerprint.strip().lower()
    if not COMMIT_RE.fullmatch(rc_commit):
        print("FINALIZE_STORE_CAPTURE_MANIFEST FAIL: --rc-commit must be a full lowercase/hex commit SHA")
        return 1
    if not git_commit_exists(rc_commit):
        print("FINALIZE_STORE_CAPTURE_MANIFEST FAIL: RC commit does not exist in repository history")
        return 1
    if args.version_code <= 0 or not args.version_name.strip():
        print("FINALIZE_STORE_CAPTURE_MANIFEST FAIL: release version name/code invalid")
        return 1
    if not SHA256_RE.fullmatch(fingerprint):
        print("FINALIZE_STORE_CAPTURE_MANIFEST FAIL: release input fingerprint must be SHA-256")
        return 1

    timestamp = args.captured_at_utc.strip()
    if not timestamp:
        timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", timestamp):
        print("FINALIZE_STORE_CAPTURE_MANIFEST FAIL: --captured-at-utc must be UTC YYYY-MM-DDTHH:MM:SSZ")
        return 1

    try:
        manifest = read_json(MANIFEST)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FINALIZE_STORE_CAPTURE_MANIFEST FAIL: {exc}")
        return 1

    rows = manifest.get("screenshots", [])
    if not isinstance(rows, list) or len(rows) != 12:
        print("FINALIZE_STORE_CAPTURE_MANIFEST FAIL: expected exactly 12 screenshot rows")
        return 1

    missing: list[str] = []
    for row in rows:
        if not isinstance(row, dict):
            print("FINALIZE_STORE_CAPTURE_MANIFEST FAIL: screenshot row is not an object")
            return 1
        path_text = str(row.get("listing_path", ""))
        path = ROOT / path_text
        if not path.is_file():
            missing.append(path_text)
            continue
        row["sha256"] = sha256_file(path)
        row["status"] = "final_rc_capture"
        if not str(row.get("captured_at_utc", "")).strip():
            row["captured_at_utc"] = timestamp

    if missing:
        print("FINALIZE_STORE_CAPTURE_MANIFEST FAIL: missing screenshot file(s): " + ", ".join(missing))
        return 1

    manifest["rc_identity"] = {
        "commit_sha": rc_commit,
        "version_name": args.version_name.strip(),
        "version_code": args.version_code,
        "release_input_fingerprint_sha256": fingerprint,
    }
    manifest["capture_environment"] = {
        "device_or_emulator_profile": args.device_profile.strip(),
        "android_version": args.android_version.strip(),
        "capture_method": args.capture_method.strip(),
        "notes": "Bound to real Android RC screenshots. This tool hashes files and updates evidence metadata only; it does not edit image pixels.",
    }
    manifest["formal_status"] = "in_progress"
    manifest["pass_recorded"] = False
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "FINALIZE_STORE_CAPTURE_MANIFEST PASS: screenshots=12 rc=%s version=%s/%d hashes_recorded=12 image_pixels_modified=0"
        % (rc_commit[:12], args.version_name.strip(), args.version_code)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
