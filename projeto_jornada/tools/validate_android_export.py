#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESET = ROOT / "export_presets.cfg"
IDENTITY = ROOT / "mobile" / "release_identity.json"
errors: list[str] = []

if not PRESET.exists():
    errors.append("export_presets.cfg missing")
    text = ""
else:
    text = PRESET.read_text(encoding="utf-8")

if not IDENTITY.exists():
    errors.append("mobile/release_identity.json missing")
    identity = {}
else:
    try:
        identity = json.loads(IDENTITY.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"release identity invalid JSON: {exc}")
        identity = {}

android = identity.get("android", {}) if isinstance(identity, dict) else {}
package_id = str(android.get("application_id", ""))
version_name = str(android.get("current_version_name", ""))
try:
    version_code = int(android.get("current_version_code", -1))
except (TypeError, ValueError):
    version_code = -1

if not re.fullmatch(r"[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*){2,}", package_id):
    errors.append(f"invalid stable Android application id: {package_id!r}")
if version_code < 1:
    errors.append("current_version_code must be a positive integer")
if not version_name:
    errors.append("current_version_name missing")

for name in ["Android Debug APK", "Android Play AAB (Unsigned CI Template)"]:
    if f'name="{name}"' not in text:
        errors.append(f"missing preset {name}")

for secret_key in ["keystore/release", "keystore/release_user", "keystore/release_password"]:
    for match in re.finditer(rf'{re.escape(secret_key)}="([^"]*)"', text):
        if match.group(1).strip():
            errors.append(f"release credential/path must not be committed: {secret_key}")

if package_id:
    package_occurrences = text.count(f'package/unique_name="{package_id}"')
    if package_occurrences != 2:
        errors.append(
            f"stable package id must appear in both Android presets: expected=2 got={package_occurrences}"
        )
if version_name:
    version_name_occurrences = text.count(f'version/name="{version_name}"')
    if version_name_occurrences != 2:
        errors.append(
            f"version name must match identity in both presets: expected=2 got={version_name_occurrences}"
        )
if version_code >= 1:
    version_code_occurrences = text.count(f"version/code={version_code}")
    if version_code_occurrences != 2:
        errors.append(
            f"version code must match identity in both presets: expected=2 got={version_code_occurrences}"
        )

if 'architectures/arm64-v8a=true' not in text:
    errors.append("arm64 export must be enabled")

if "[preset.0.options]" in text and "[preset.1]" in text:
    debug = text.split("[preset.0.options]", 1)[1].split("[preset.1]", 1)[0]
    if "architectures/x86_64=true" not in debug:
        errors.append("debug APK must retain x86_64 for emulator certification")

if "[preset.1.options]" in text:
    aab = text.split("[preset.1.options]", 1)[-1]
    for expected in [
        "gradle_build/use_gradle_build=true",
        "gradle_build/export_format=1",
        "architectures/arm64-v8a=true",
        "architectures/x86_64=false",
        "package/signed=true",
    ]:
        if expected not in aab:
            errors.append(f"AAB preset missing {expected}")

signing = android.get("release_signing", {}) if isinstance(android, dict) else {}
if isinstance(signing, dict):
    if signing.get("repository_contains_release_keystore") is not False:
        errors.append("release identity must forbid release keystore in repository")
    if signing.get("repository_contains_release_passwords") is not False:
        errors.append("release identity must forbid release passwords in repository")
else:
    errors.append("release_signing contract missing")

if errors:
    print("ANDROID_EXPORT_CONFIG FAIL")
    for error in errors:
        print(" -", error)
    sys.exit(1)

print(
    "ANDROID_EXPORT_CONFIG PASS: package=%s version=%s(%d) debug APK + arm64 Gradle AAB; no release credentials committed"
    % (package_id, version_name, version_code)
)
