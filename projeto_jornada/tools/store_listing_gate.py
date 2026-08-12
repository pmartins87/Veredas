#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import struct
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LISTING = ROOT / "product" / "store_listing_google_play.json"
LOCALE_MANIFEST = ROOT / "localization" / "manifest.json"
NAME_STATE = ROOT / "RELEASE_12_1_NAME_STATE.json"
RC_COMPLETION = ROOT / "QA_11_10_COMPLETION.json"

PROMOTIONAL_PATTERNS = [
    re.compile(r"(?i)(?:^|\W)#?1(?:\W|$)"),
    re.compile(r"(?i)\bbest\s+(?:game|rpg|gamebook)\b"),
    re.compile(r"(?i)\btop\s+\d+\b"),
    re.compile(r"(?i)\bdownload\s+now\b"),
    re.compile(r"(?i)\binstall\s+now\b"),
    re.compile(r"(?i)\bmelhor\s+(?:jogo|rpg|livro-jogo)\b"),
    re.compile(r"(?i)\bbaixe\s+agora\b"),
    re.compile(r"(?i)\binstale\s+agora\b"),
    re.compile(r"(?i)\b\d+%\s*(?:off|de\s+desconto)\b"),
]


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def png_header(path: Path) -> dict[str, int]:
    with path.open("rb") as handle:
        header = handle.read(33)
    if len(header) < 33 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not_png")
    length = struct.unpack(">I", header[8:12])[0]
    chunk_type = header[12:16]
    if length != 13 or chunk_type != b"IHDR":
        raise ValueError("missing_ihdr")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", header[16:26])
    return {
        "width": width,
        "height": height,
        "bit_depth": bit_depth,
        "color_type": color_type,
    }


def has_alpha(color_type: int) -> bool:
    return color_type in {4, 6}


def contains_promotional_claim(text: str) -> bool:
    return any(pattern.search(text) for pattern in PROMOTIONAL_PATTERNS)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Google Play listing copy and final store assets for roadmap 12.5.")
    parser.add_argument("--release", action="store_true", help="Require final RC screenshots and all mandatory graphics.")
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    for required in (LISTING, LOCALE_MANIFEST, NAME_STATE):
        if not required.exists():
            errors.append(f"required store metadata file missing: {required.relative_to(ROOT)}")
    if errors:
        print("STORE_LISTING_GATE FAIL")
        for error in errors:
            print("ERROR:", error)
        return 1

    listing = read_json(LISTING)
    locale_manifest = read_json(LOCALE_MANIFEST)
    name_state = read_json(NAME_STATE)

    if listing.get("roadmap_step") != "12.5":
        errors.append("store listing must identify roadmap_step 12.5")
    if str(listing.get("application_id", "")) != "com.pmartins87.veredasdatrama":
        errors.append("store listing application id mismatch")
    if str(name_state.get("candidate_name", "")) != "Veredas da Trama":
        errors.append("store title candidate disagrees with 12.1 name state")

    launch_locales = [str(value) for value in locale_manifest.get("launch_locales", [])]
    locale_mapping = listing.get("launch_locale_mapping", {})
    if not isinstance(locale_mapping, dict):
        errors.append("launch_locale_mapping must be an object")
        locale_mapping = {}
    if set(locale_mapping.keys()) != set(launch_locales):
        errors.append(
            f"store locale mapping does not match launch locales: store={sorted(locale_mapping)} launch={sorted(launch_locales)}"
        )
    expected_store_locales = {str(value) for value in locale_mapping.values()}

    listings = listing.get("listings", {})
    if not isinstance(listings, dict):
        errors.append("listings must be an object")
        listings = {}
    if set(listings.keys()) != expected_store_locales:
        errors.append(
            f"localized listing set mismatch: got={sorted(listings)} expected={sorted(expected_store_locales)}"
        )

    copy_policy = listing.get("copy_policy", {})
    title_limit = int(copy_policy.get("title_max_chars", 30)) if isinstance(copy_policy, dict) else 30
    short_limit = int(copy_policy.get("short_description_max_chars", 80)) if isinstance(copy_policy, dict) else 80
    full_limit = int(copy_policy.get("full_description_max_chars", 4000)) if isinstance(copy_policy, dict) else 4000

    for locale_id, row_variant in listings.items():
        if not isinstance(row_variant, dict):
            errors.append(f"{locale_id}: listing row must be an object")
            continue
        row: dict[str, Any] = row_variant
        title = str(row.get("title", "")).strip()
        short = str(row.get("short_description", "")).strip()
        full = str(row.get("full_description", "")).strip()
        if not title or len(title) > title_limit:
            errors.append(f"{locale_id}: title length {len(title)}/{title_limit}")
        if not short or len(short) > short_limit:
            errors.append(f"{locale_id}: short description length {len(short)}/{short_limit}")
        if not full or len(full) > full_limit:
            errors.append(f"{locale_id}: full description length {len(full)}/{full_limit}")
        if title != str(name_state.get("candidate_name", "")):
            errors.append(f"{locale_id}: title differs from candidate commercial name")
        for label, text in (("title", title), ("short", short), ("full", full)):
            if contains_promotional_claim(text):
                errors.append(f"{locale_id}: promotional/ranking/CTA claim in {label}")
        recorded_counts = row.get("character_counts", {})
        if isinstance(recorded_counts, dict):
            actual = {
                "title": len(title),
                "short_description": len(short),
                "full_description": len(full),
            }
            for key, count in actual.items():
                if int(recorded_counts.get(key, -1)) != count:
                    errors.append(f"{locale_id}: stale recorded character count for {key}")

    assets = listing.get("assets", {})
    if not isinstance(assets, dict):
        errors.append("assets must be an object")
        assets = {}

    def check_png_asset(label: str, row: dict[str, Any], require_alpha: bool | None, max_bytes: int | None = None) -> None:
        path_text = str(row.get("path", ""))
        if not path_text:
            errors.append(f"{label}: path missing")
            return
        path = ROOT / path_text
        if not path.exists():
            message = f"{label}: final asset missing: {path_text}"
            if args.release:
                errors.append(message)
            else:
                warnings.append(message)
            return
        if max_bytes is not None and path.stat().st_size > max_bytes:
            errors.append(f"{label}: file too large {path.stat().st_size}>{max_bytes}")
        try:
            header = png_header(path)
        except ValueError as exc:
            errors.append(f"{label}: invalid PNG ({exc})")
            return
        if header["width"] != int(row.get("width", -1)) or header["height"] != int(row.get("height", -1)):
            errors.append(
                f"{label}: dimensions {header['width']}x{header['height']} do not match contract {row.get('width')}x{row.get('height')}"
            )
        if header["bit_depth"] != 8:
            errors.append(f"{label}: PNG bit depth must be 8, got {header['bit_depth']}")
        alpha = has_alpha(header["color_type"])
        if require_alpha is True and not alpha:
            errors.append(f"{label}: alpha channel required")
        if require_alpha is False and alpha:
            errors.append(f"{label}: alpha channel forbidden")
        if require_alpha is False and header["color_type"] != 2:
            errors.append(f"{label}: store graphic must be 24-bit RGB PNG color_type=2")

    icon = assets.get("icon", {})
    feature = assets.get("feature_graphic", {})
    if isinstance(icon, dict):
        check_png_asset("icon", icon, True, int(icon.get("max_bytes", 1048576)))
    else:
        errors.append("icon contract missing")
    if isinstance(feature, dict):
        check_png_asset("feature_graphic", feature, False)
    else:
        errors.append("feature graphic contract missing")

    shots = assets.get("phone_screenshots", {})
    if not isinstance(shots, dict):
        errors.append("phone screenshot contract missing")
        shots = {}
    required_shots = int(shots.get("required_for_release_per_locale", 6))
    shot_width = int(shots.get("width", 1080))
    shot_height = int(shots.get("height", 1920))
    for locale_id in sorted(expected_store_locales):
        rows = shots.get(locale_id, [])
        if not isinstance(rows, list):
            errors.append(f"{locale_id}: screenshot list missing")
            continue
        if len(rows) != required_shots:
            errors.append(f"{locale_id}: expected {required_shots} screenshots, got {len(rows)}")
        seen_paths: set[str] = set()
        for index, row_variant in enumerate(rows, start=1):
            if not isinstance(row_variant, dict):
                errors.append(f"{locale_id}: screenshot {index} row invalid")
                continue
            row = dict(row_variant)
            path_text = str(row.get("path", ""))
            if path_text in seen_paths:
                errors.append(f"{locale_id}: duplicate screenshot path {path_text}")
            seen_paths.add(path_text)
            alt = str(row.get("alt_text", "")).strip()
            if not alt or len(alt) > 140:
                errors.append(f"{locale_id}: screenshot {index} alt text length {len(alt)}/140")
            image_contract = {
                "path": path_text,
                "width": shot_width,
                "height": shot_height,
            }
            check_png_asset(f"{locale_id}:screenshot:{index}", image_contract, False)
            if args.release and str(row.get("status", "")) != "final_rc_capture":
                errors.append(f"{locale_id}: screenshot {index} not marked final_rc_capture")

    if args.release:
        if listing.get("formal_status") != "certified" or listing.get("pass_recorded") is not True:
            errors.append("12.5 listing state is not certified")
        if name_state.get("formal_status") != "certified":
            errors.append("12.1 commercial name must be certified before final store listing")
        if not RC_COMPLETION.exists():
            errors.append("11.10 Release Candidate completion evidence is required before final screenshots")
        for label, row in (("icon", icon), ("feature_graphic", feature)):
            if isinstance(row, dict) and str(row.get("status", "")) != "final":
                errors.append(f"{label}: status is not final")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "STORE_LISTING_GATE %s: locales=%d screenshots=%d errors=%d warnings=%d"
        % (mode, len(listings), required_shots * len(expected_store_locales), len(errors), len(warnings))
    )
    for warning in warnings[:50]:
        print("WARNING:", warning)
    if errors:
        print(f"STORE_LISTING_GATE FAIL: {len(errors)} issue(s)")
        for error in errors[:100]:
            print("ERROR:", error)
        return 1
    print("STORE_LISTING_GATE PASS: copy and store assets satisfy the declared Google Play contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
