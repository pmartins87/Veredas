#!/usr/bin/env python3
from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]
PRESET = ROOT / "export_presets.cfg"
errors = []

if not PRESET.exists():
    errors.append("export_presets.cfg missing")
    text = ""
else:
    text = PRESET.read_text(encoding="utf-8")

for name in ["Android Debug APK", "Android Play AAB (Unsigned CI Template)"]:
    if f'name="{name}"' not in text:
        errors.append(f"missing preset {name}")

blocks = re.split(r"\[preset\.(\d+)\]", text)
# Simple global requirements deliberately avoid persisting any release secret.
for secret_key in ["keystore/release_user", "keystore/release_password"]:
    match = re.search(rf'{re.escape(secret_key)}="([^"]*)"', text)
    if match and match.group(1).strip():
        errors.append(f"release secret must not be committed: {secret_key}")

if 'package/unique_name="com.veredasdatrama.preview"' not in text:
    errors.append("preview package id missing")
if 'architectures/arm64-v8a=true' not in text:
    errors.append("arm64 export must be enabled")
if 'name="Android Play AAB (Unsigned CI Template)"' in text:
    # Inspect the AAB preset options after preset.1.options.
    aab = text.split("[preset.1.options]", 1)[-1]
    for expected in ["gradle_build/use_gradle_build=true", "gradle_build/export_format=1", "architectures/arm64-v8a=true", "architectures/x86_64=false"]:
        if expected not in aab:
            errors.append(f"AAB preset missing {expected}")

if errors:
    print("ANDROID_EXPORT_CONFIG FAIL")
    for error in errors:
        print(" -", error)
    sys.exit(1)

print("ANDROID_EXPORT_CONFIG PASS: debug APK + arm64 Gradle AAB presets, no release credentials committed")
