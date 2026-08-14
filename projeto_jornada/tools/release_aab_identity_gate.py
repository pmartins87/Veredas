#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
IDENTITY = ROOT / "mobile" / "release_identity.json"
ARTIFACT = ROOT / "mobile" / "release_artifact_contract.json"
PRIVACY = ROOT / "product" / "privacy_data_safety.json"
BUNDLETOOL_VERSION = "1.18.3"
BUNDLETOOL_SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
A = "{%s}" % ANDROID_NS
FORBIDDEN_PRIVACY_PERMISSIONS = {
    "android.permission.CAMERA",
    "android.permission.RECORD_AUDIO",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.READ_CONTACTS",
    "android.permission.WRITE_CONTACTS",
    "android.permission.READ_CALL_LOG",
    "android.permission.WRITE_CALL_LOG",
    "android.permission.READ_SMS",
    "android.permission.RECEIVE_SMS",
    "android.permission.SEND_SMS",
    "android.permission.BODY_SENSORS",
    "android.permission.BODY_SENSORS_BACKGROUND",
    "android.permission.ACTIVITY_RECOGNITION",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.WRITE_EXTERNAL_STORAGE",
    "android.permission.MANAGE_EXTERNAL_STORAGE",
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VIDEO",
    "android.permission.READ_MEDIA_AUDIO",
    "com.google.android.gms.permission.AD_ID",
    "android.permission.ACCESS_ADSERVICES_AD_ID",
}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(*args: str) -> str:
    proc = subprocess.run(args, text=True, capture_output=True, check=False)
    if proc.returncode != 0:
        raise ValueError(f"command failed ({proc.returncode}): {' '.join(args)}\n{proc.stderr.strip()}")
    return proc.stdout.strip()


def parse_int(value: str | None, label: str) -> int:
    if value is None:
        raise ValueError(f"manifest missing {label}")
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"manifest {label} is not integer: {value!r}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect the exact signed AAB manifest with a pinned official bundletool and compare it to release contracts.")
    parser.add_argument("--aab", type=Path, required=True)
    parser.add_argument("--bundletool", type=Path, required=True)
    parser.add_argument("--evidence-output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    evidence: dict[str, Any] = {
        "schema_version": 1,
        "bundletool_version_expected": BUNDLETOOL_VERSION,
        "bundletool_sha256_expected": BUNDLETOOL_SHA256,
    }
    try:
        identity = read_object(IDENTITY)
        artifact = read_object(ARTIFACT)
        privacy = read_object(PRIVACY)
        if not args.aab.is_file() or args.aab.stat().st_size <= 0:
            raise ValueError("signed AAB missing or empty")
        if not args.bundletool.is_file():
            raise ValueError("bundletool jar missing")

        bt_sha = file_sha256(args.bundletool)
        evidence["bundletool_sha256_actual"] = bt_sha
        if bt_sha.lower() != BUNDLETOOL_SHA256:
            errors.append("bundletool SHA-256 does not match pinned official release digest")
        bt_version = run("java", "-jar", str(args.bundletool), "version")
        evidence["bundletool_version_actual"] = bt_version
        if bt_version.strip() != BUNDLETOOL_VERSION:
            errors.append(f"bundletool version drift: expected={BUNDLETOOL_VERSION} got={bt_version!r}")

        manifest_xml = run("java", "-jar", str(args.bundletool), "dump", "manifest", f"--bundle={args.aab}")
        root = ET.fromstring(manifest_xml)
        uses_sdk = root.find("uses-sdk")
        application = root.find("application")
        if uses_sdk is None:
            errors.append("AAB manifest has no uses-sdk element")
        if application is None:
            errors.append("AAB manifest has no application element")

        actual_package = root.attrib.get("package", "")
        actual_version_name = root.attrib.get(A + "versionName", "")
        actual_version_code = parse_int(root.attrib.get(A + "versionCode"), "versionCode")
        actual_min_sdk = parse_int(uses_sdk.attrib.get(A + "minSdkVersion") if uses_sdk is not None else None, "minSdkVersion")
        actual_target_sdk = parse_int(uses_sdk.attrib.get(A + "targetSdkVersion") if uses_sdk is not None else None, "targetSdkVersion")
        debuggable = False if application is None else application.attrib.get(A + "debuggable", "false").lower() == "true"
        permissions = sorted({
            node.attrib.get(A + "name", "")
            for node in root.findall("uses-permission")
            if node.attrib.get(A + "name", "")
        })

        android = identity.get("android", {})
        toolchain = android.get("release_toolchain", {})
        expected_package = str(android.get("application_id", ""))
        expected_version_name = str(android.get("current_version_name", ""))
        expected_version_code = int(android.get("current_version_code", 0))
        expected_min_sdk = int(toolchain.get("min_sdk", 0))
        expected_target_sdk = int(toolchain.get("target_sdk", 0))

        if actual_package != expected_package or actual_package != str(artifact.get("application_id", "")):
            errors.append(f"AAB applicationId mismatch: actual={actual_package} expected={expected_package}")
        if actual_version_name != expected_version_name:
            errors.append(f"AAB versionName mismatch: actual={actual_version_name} expected={expected_version_name}")
        if actual_version_code != expected_version_code:
            errors.append(f"AAB versionCode mismatch: actual={actual_version_code} expected={expected_version_code}")
        if actual_min_sdk != expected_min_sdk:
            errors.append(f"AAB minSdk mismatch: actual={actual_min_sdk} expected={expected_min_sdk}")
        if actual_target_sdk != expected_target_sdk:
            errors.append(f"AAB targetSdk mismatch: actual={actual_target_sdk} expected={expected_target_sdk}")
        if debuggable:
            errors.append("release AAB is debuggable")

        behavior = privacy.get("current_application_behavior", {})
        if behavior.get("internet_permission") is True and "android.permission.INTERNET" not in permissions:
            errors.append("AAB is missing android.permission.INTERNET required by frozen Billing verification behavior")
        forbidden_found = sorted(FORBIDDEN_PRIVACY_PERMISSIONS.intersection(permissions))
        if forbidden_found:
            errors.append("AAB contains privacy-sensitive/ad permission(s) forbidden by current product behavior: " + ", ".join(forbidden_found))

        evidence.update({
            "aab_path": str(args.aab),
            "aab_sha256": file_sha256(args.aab),
            "aab_size_bytes": args.aab.stat().st_size,
            "application_id": actual_package,
            "version_name": actual_version_name,
            "version_code": actual_version_code,
            "min_sdk": actual_min_sdk,
            "target_sdk": actual_target_sdk,
            "debuggable": debuggable,
            "effective_permissions": permissions,
            "forbidden_privacy_permissions_found": forbidden_found,
            "manifest_contract_match": not errors,
        })
    except (OSError, ValueError, TypeError, json.JSONDecodeError, ET.ParseError) as exc:
        errors.append(str(exc))

    evidence["errors"] = errors
    evidence["manifest_contract_match"] = not errors
    if args.evidence_output is not None:
        args.evidence_output.parent.mkdir(parents=True, exist_ok=True)
        args.evidence_output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print(f"RELEASE_AAB_IDENTITY FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print(
        "RELEASE_AAB_IDENTITY PASS: package=%s version=%s(%d) minSdk=%d targetSdk=%d permissions=%d aab_sha256=%s"
        % (
            evidence["application_id"], evidence["version_name"], evidence["version_code"],
            evidence["min_sdk"], evidence["target_sdk"], len(evidence["effective_permissions"]),
            evidence["aab_sha256"][:12],
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
