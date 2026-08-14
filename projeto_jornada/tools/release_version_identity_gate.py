#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
IDENTITY = ROOT / "mobile" / "release_identity.json"
ARTIFACT = ROOT / "mobile" / "release_artifact_contract.json"
STATE_12_2 = ROOT / "RELEASE_12_2_STATE.json"
PRESETS = ROOT / "export_presets.cfg"
SEMVER_RELEASE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Android public version identity and fail closed until the release version is frozen before 11.10.")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()

    errors: list[str] = []
    try:
        identity = read_object(IDENTITY)
        artifact = read_object(ARTIFACT)
        state = read_object(STATE_12_2)
        presets = PRESETS.read_text(encoding="utf-8")

        android = identity.get("android", {})
        state_android = state.get("android", {})
        freeze = android.get("version_freeze", {})
        current_name = str(android.get("current_version_name", ""))
        current_code = int(android.get("current_version_code", 0))
        target_name = str(android.get("target_first_public_version_name", ""))
        artifact_target = str(artifact.get("target_public_version_name", ""))
        state_name = str(state_android.get("version_name", ""))
        state_code = int(state_android.get("version_code", 0))
        state_target = str(state_android.get("target_public_version", ""))

        if not current_name or current_code < 1:
            errors.append("current Android version name/code are invalid")
        if not target_name or target_name != artifact_target or target_name != state_target:
            errors.append("target public version drift across identity/artifact/12.2 state")
        if state_name != current_name or state_code != current_code:
            errors.append("current version drift between release_identity.json and RELEASE_12_2_STATE.json")
        if presets.count(f'version/name="{current_name}"') != 2:
            errors.append("both Android presets must use the current release_identity version name")
        if presets.count(f"version/code={current_code}") != 2:
            errors.append("both Android presets must use the current release_identity version code")
        if freeze.get("freeze_must_happen_before_11_10_certification") is not True:
            errors.append("version contract must require freeze before 11.10")
        if freeze.get("any_version_change_after_11_10_requires_new_11_10_certification") is not True:
            errors.append("version contract must invalidate 11.10 after any version change")
        if freeze.get("current_version_name_must_equal_target_when_frozen") is not True:
            errors.append("frozen public version must equal target version")

        if args.release:
            if freeze.get("public_release_version_frozen") is not True:
                errors.append("public release version is not frozen")
            if str(freeze.get("play_console_version_code_confirmation", "")).lower() != "unused_confirmed":
                errors.append("version code is not confirmed unused in Play Console")
            if current_name != target_name:
                errors.append(f"release version must equal target: current={current_name} target={target_name}")
            if not SEMVER_RELEASE.fullmatch(current_name):
                errors.append("public release version name must be stable x.y.z without dev/alpha/beta/rc suffix")
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as exc:
        errors.append(str(exc))

    if errors:
        print(f"RELEASE_VERSION_IDENTITY FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    mode = "release" if args.release else "preflight"
    print(f"RELEASE_VERSION_IDENTITY PASS: mode={mode} current={current_name}({current_code}) target={target_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
