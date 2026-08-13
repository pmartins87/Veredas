#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LISTING = ROOT / "product" / "store_listing_google_play.json"
CAPTURES = ROOT / "product" / "store_capture_manifest.json"
RC_COMPLETION = ROOT / "QA_11_10_COMPLETION.json"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
UTC_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


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


def png_header(path: Path) -> tuple[int, int, int, int]:
    with path.open("rb") as handle:
        header = handle.read(33)
    if len(header) < 33 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not_png")
    if struct.unpack(">I", header[8:12])[0] != 13 or header[12:16] != b"IHDR":
        raise ValueError("missing_ihdr")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", header[16:26])
    return width, height, bit_depth, color_type


def pending(value: Any) -> bool:
    return isinstance(value, str) and (not value.strip() or "PENDING_" in value)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate that Google Play screenshots are traceable to one certified Android RC.")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    for path in (LISTING, CAPTURES):
        if not path.is_file():
            errors.append(f"required file missing: {path.relative_to(ROOT)}")
    if errors:
        print("STORE_CAPTURE_PROVENANCE_GATE FAIL")
        for error in errors:
            print("ERROR:", error)
        return 1

    try:
        listing = read_json(LISTING)
        capture = read_json(CAPTURES)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"STORE_CAPTURE_PROVENANCE_GATE FAIL: {exc}")
        return 1

    if capture.get("roadmap_step") != "12.5":
        errors.append("capture manifest must identify roadmap_step 12.5")
    if int(capture.get("schema_version", 0)) != 1:
        errors.append("unsupported capture manifest schema")
    if capture.get("source_listing") != "product/store_listing_google_play.json":
        errors.append("capture manifest source_listing mismatch")
    if capture.get("source_rc_completion") != "QA_11_10_COMPLETION.json":
        errors.append("capture manifest must bind to QA_11_10_COMPLETION.json")

    policy = capture.get("policy", {})
    if not isinstance(policy, dict):
        errors.append("capture policy missing")
        policy = {}
    expected_policy = {
        "actual_release_candidate_runtime_only": True,
        "single_rc_commit_for_all_locales": True,
        "single_runtime_version_for_all_locales": True,
        "mockups_presented_as_gameplay_forbidden": True,
        "post_capture_gameplay_or_ui_content_edits_forbidden": True,
        "capture_platform": "Android",
        "required_per_locale": 6,
        "width": 1080,
        "height": 1920,
        "orientation": "portrait_9_16",
        "format": "PNG",
        "png_color_type": 2,
        "alpha_allowed": False,
        "sha256_required": True,
        "captured_at_utc_required": True,
        "device_or_emulator_profile_required": True,
        "release_input_fingerprint_required": True,
    }
    for key, expected in expected_policy.items():
        if policy.get(key) != expected:
            errors.append(f"capture policy drift: {key} expected={expected!r} got={policy.get(key)!r}")
    if set(policy.get("required_store_locales", [])) != {"pt-BR", "en-US"}:
        errors.append("capture locales must remain exactly pt-BR and en-US")

    listing_assets = listing.get("assets", {})
    shots = listing_assets.get("phone_screenshots", {}) if isinstance(listing_assets, dict) else {}
    if not isinstance(shots, dict):
        errors.append("listing phone_screenshots contract missing")
        shots = {}

    listing_rows: dict[str, tuple[str, int]] = {}
    for locale in ("pt-BR", "en-US"):
        rows = shots.get(locale, [])
        if not isinstance(rows, list):
            errors.append(f"listing screenshot rows missing for {locale}")
            continue
        for slot, row in enumerate(rows, start=1):
            if not isinstance(row, dict):
                errors.append(f"listing screenshot row invalid: {locale}:{slot}")
                continue
            path_text = str(row.get("path", ""))
            if not path_text or path_text in listing_rows:
                errors.append(f"listing screenshot path missing/duplicate: {locale}:{slot}:{path_text}")
                continue
            listing_rows[path_text] = (locale, slot)

    capture_rows = capture.get("screenshots", [])
    if not isinstance(capture_rows, list):
        errors.append("capture screenshots must be an array")
        capture_rows = []
    if len(capture_rows) != 12:
        errors.append(f"capture manifest must contain 12 rows, got {len(capture_rows)}")

    capture_paths: set[str] = set()
    locale_slots: set[tuple[str, int]] = set()
    for index, row in enumerate(capture_rows, start=1):
        if not isinstance(row, dict):
            errors.append(f"capture row {index} is not an object")
            continue
        locale = str(row.get("locale", ""))
        try:
            slot = int(row.get("slot", 0))
        except (TypeError, ValueError):
            slot = 0
        path_text = str(row.get("listing_path", ""))
        scene_id = str(row.get("scene_id", ""))
        if locale not in {"pt-BR", "en-US"} or slot not in range(1, 7):
            errors.append(f"capture row {index} invalid locale/slot: {locale}:{slot}")
        if (locale, slot) in locale_slots:
            errors.append(f"duplicate capture locale/slot: {locale}:{slot}")
        locale_slots.add((locale, slot))
        if not scene_id:
            errors.append(f"capture row {index} scene_id missing")
        if not path_text or path_text in capture_paths:
            errors.append(f"capture row {index} listing_path missing/duplicate: {path_text}")
        capture_paths.add(path_text)
        expected = listing_rows.get(path_text)
        if expected is None:
            errors.append(f"capture path not present in listing: {path_text}")
        elif expected != (locale, slot):
            errors.append(f"capture/listing locale-slot mismatch for {path_text}: capture={(locale, slot)} listing={expected}")

        if args.release:
            if row.get("status") != "final_rc_capture":
                errors.append(f"capture row not final_rc_capture: {locale}:{slot}")
            captured_at = str(row.get("captured_at_utc", ""))
            if not UTC_RE.fullmatch(captured_at):
                errors.append(f"capture timestamp must be UTC YYYY-MM-DDTHH:MM:SSZ: {locale}:{slot}")
            digest = str(row.get("sha256", "")).lower()
            if not SHA256_RE.fullmatch(digest):
                errors.append(f"capture SHA-256 missing/invalid: {locale}:{slot}")
                continue
            image = ROOT / path_text
            if not image.is_file():
                errors.append(f"capture image missing: {path_text}")
                continue
            actual_digest = sha256_file(image)
            if actual_digest != digest:
                errors.append(f"capture SHA-256 mismatch: {path_text}")
            try:
                width, height, bit_depth, color_type = png_header(image)
            except ValueError as exc:
                errors.append(f"capture invalid PNG: {path_text}:{exc}")
                continue
            if (width, height) != (1080, 1920):
                errors.append(f"capture dimensions invalid: {path_text}:{width}x{height}")
            if bit_depth != 8 or color_type != 2:
                errors.append(f"capture must be 8-bit 24-bit RGB PNG without alpha: {path_text}:depth={bit_depth}:type={color_type}")

    if capture_paths != set(listing_rows):
        errors.append(
            "listing/capture path set mismatch: listing_only=%s capture_only=%s"
            % (sorted(set(listing_rows) - capture_paths), sorted(capture_paths - set(listing_rows)))
        )

    if args.release:
        if not RC_COMPLETION.is_file():
            errors.append("QA_11_10_COMPLETION.json missing")
            completion: dict[str, Any] = {}
        else:
            try:
                completion = read_json(RC_COMPLETION)
            except (OSError, ValueError, json.JSONDecodeError) as exc:
                errors.append(f"invalid QA_11_10_COMPLETION.json: {exc}")
                completion = {}
        if completion.get("roadmap_step") != "11.10":
            errors.append("11.10 completion roadmap_step mismatch")
        if str(completion.get("status", "")).lower() != "pass":
            errors.append("11.10 completion status must be pass")
        certified_head = str(completion.get("certified_against_head", "")).lower()
        if not COMMIT_RE.fullmatch(certified_head):
            errors.append("11.10 completion certified_against_head must be a full commit SHA")

        identity = capture.get("rc_identity", {})
        if not isinstance(identity, dict):
            errors.append("capture rc_identity missing")
            identity = {}
        manifest_head = str(identity.get("commit_sha", "")).lower()
        if not COMMIT_RE.fullmatch(manifest_head):
            errors.append("capture rc_identity.commit_sha must be a full commit SHA")
        elif certified_head and manifest_head != certified_head:
            errors.append(f"capture RC commit differs from certified 11.10 head: capture={manifest_head} certified={certified_head}")
        version_name = str(identity.get("version_name", ""))
        if pending(version_name):
            errors.append("capture RC version_name unresolved")
        if int(identity.get("version_code", 0) or 0) <= 0:
            errors.append("capture RC version_code must be positive")
        fingerprint = str(identity.get("release_input_fingerprint_sha256", "")).lower()
        if not SHA256_RE.fullmatch(fingerprint):
            errors.append("capture release_input_fingerprint_sha256 missing/invalid")

        environment = capture.get("capture_environment", {})
        if not isinstance(environment, dict):
            errors.append("capture environment missing")
            environment = {}
        for key in ("device_or_emulator_profile", "android_version", "capture_method"):
            if pending(environment.get(key)):
                errors.append(f"capture environment unresolved: {key}")
        if capture.get("formal_status") != "certified" or capture.get("pass_recorded") is not True:
            errors.append("capture manifest is not certified")
    else:
        unresolved = 0
        identity = capture.get("rc_identity", {})
        environment = capture.get("capture_environment", {})
        for value in list(identity.values()) if isinstance(identity, dict) else []:
            if pending(value) or value == 0:
                unresolved += 1
        for value in list(environment.values()) if isinstance(environment, dict) else []:
            if pending(value):
                unresolved += 1
        if unresolved:
            warnings.append(f"capture preflight retains {unresolved} RC/environment placeholder(s), expected before 11.10 freeze")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "STORE_CAPTURE_PROVENANCE_GATE %s: listing_paths=%d capture_rows=%d errors=%d warnings=%d single_rc=1 android_real_capture=1"
        % (mode, len(listing_rows), len(capture_rows), len(errors), len(warnings))
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"STORE_CAPTURE_PROVENANCE_GATE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("STORE_CAPTURE_PROVENANCE_GATE PASS: screenshot plan is structurally bound to the listing and one certified RC")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
