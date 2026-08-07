#!/usr/bin/env python3
"""Validate Phase 7 art coverage and delivery contracts.

A missing final asset is an error. This validator is intentionally expected to fail
until production is actually complete; that prevents roadmap inflation.
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "manifests" / "phase7_art_manifest.json"
PALETTES = ROOT / "ui" / "domain_palettes.json"
EXPECTED = {
    "domain_key_art": 12,
    "location_illustration": 120,
    "character_portrait": 36,
    "character_full_figure": 36,
    "character_silhouette": 36,
    "monster_family_master": 96,
    "boss_master": 60,
    "system_icon": 32,
    "mark_glyph": 48,
}


def error(errors: list[str], message: str) -> None:
    errors.append(message)


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    if not MANIFEST.exists():
        print("FAIL: manifest missing; run tools/build_phase7_manifest.py")
        return 2

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assets = manifest.get("assets", [])
    ids = [a.get("id", "") for a in assets]
    dupes = [asset_id for asset_id, count in Counter(ids).items() if count > 1]
    if dupes:
        error(errors, f"duplicate asset IDs: {dupes[:10]}")

    kinds = Counter(a.get("kind", "") for a in assets)
    for kind, expected in EXPECTED.items():
        if kinds.get(kind, 0) != expected:
            error(errors, f"{kind}: expected {expected}, manifest has {kinds.get(kind, 0)}")

    if not PALETTES.exists():
        error(errors, "domain_palettes.json missing")
    else:
        palettes = json.loads(PALETTES.read_text(encoding="utf-8"))
        if len(palettes.get("domains", {})) != 12:
            error(errors, "domain palette coverage must be exactly 12")

    missing: list[str] = []
    zero_bytes: list[str] = []
    for entry in assets:
        path = ROOT / entry["path"]
        if not path.exists():
            missing.append(entry["id"])
        elif path.is_file() and path.stat().st_size == 0:
            zero_bytes.append(entry["id"])

    if zero_bytes:
        error(errors, f"zero-byte assets: {zero_bytes[:20]}")

    # Missing assets are reported as one aggregate error to keep CI readable.
    if missing:
        error(errors, f"missing final assets: {len(missing)}/{len(assets)}")
        warnings.append("first missing IDs: " + ", ".join(missing[:20]))

    # Enforce original product naming in shipped asset paths.
    for entry in assets:
        p = entry.get("path", "")
        if "veredas" in p.lower() and "trama" not in p.lower():
            # Asset paths are normally neutral; this only guards accidental legacy folders.
            warnings.append(f"review title-bearing asset path: {p}")

    print("Phase 7 asset QA")
    print(f"contracts: {len(assets)}")
    for kind in EXPECTED:
        print(f"  {kind}: {kinds.get(kind, 0)}/{EXPECTED[kind]}")
    print(f"errors: {len(errors)}")
    print(f"warnings: {len(warnings)}")
    for msg in errors:
        print("ERROR:", msg)
    for msg in warnings[:25]:
        print("WARN:", msg)

    if errors:
        print("RESULT: FAIL (expected until all final assets exist)")
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
