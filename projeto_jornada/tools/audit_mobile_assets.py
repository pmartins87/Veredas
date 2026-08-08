#!/usr/bin/env python3
from pathlib import Path
import json, sys

ROOT = Path(__file__).resolve().parents[1]
BUDGET_PATH = ROOT / "mobile" / "asset_budgets.json"
MOBILE_ART = ROOT / "assets" / "art" / "mobile"

EXCLUDE_TOP = {".git", ".godot", "art", "docs", "tests", "tools"}


def exported_files():
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if rel.parts and rel.parts[0] in EXCLUDE_TOP:
            continue
        if any(part.startswith(".") for part in rel.parts):
            continue
        yield path


def main():
    budget = json.loads(BUDGET_PATH.read_text(encoding="utf-8"))
    errors = []
    warnings = []
    forbidden = set(budget["forbidden_exported_extensions"])
    allowed_raster = set(budget["allowed_exported_raster_extensions"])
    for path in exported_files():
        suffix = path.suffix.lower()
        if suffix in forbidden:
            errors.append(f"forbidden exported asset: {path.relative_to(ROOT)}")
        if path.is_relative_to(MOBILE_ART) and suffix in {".jpg", ".jpeg", ".webp", ".png"} and suffix not in allowed_raster:
            errors.append(f"unsupported mobile raster: {path.relative_to(ROOT)}")

    package_bytes = sum(path.stat().st_size for path in exported_files())
    package_mb = package_bytes / 1048576.0
    hard_mb = float(budget["package"]["hard_mb"])
    soft_mb = float(budget["package"]["soft_mb"])
    if package_mb > hard_mb:
        errors.append(f"estimated package source footprint {package_mb:.1f}MB exceeds hard {hard_mb:.1f}MB")
    elif package_mb > soft_mb:
        warnings.append(f"estimated package source footprint {package_mb:.1f}MB exceeds soft {soft_mb:.1f}MB")

    manifest = MOBILE_ART / "manifest.json"
    if manifest.exists():
        data = json.loads(manifest.read_text(encoding="utf-8"))
        for entry in data.get("assets", []):
            output = MOBILE_ART / entry["output"]
            if not output.exists():
                errors.append(f"manifest output missing: {entry['output']}")
                continue
            category = entry.get("category", "ui")
            profile = budget["profiles"].get(category, budget["profiles"]["ui"])
            if output.stat().st_size / 1024.0 > float(profile["max_file_kb"]):
                errors.append(f"mobile derivative over file budget: {entry['output']}")
            if int(entry.get("width", 0)) > int(profile["max_width"]) or int(entry.get("height", 0)) > int(profile["max_height"]):
                errors.append(f"mobile derivative over dimension budget: {entry['output']}")

    if errors:
        print("MOBILE_ASSET_AUDIT FAIL")
        for error in errors:
            print(" -", error)
        sys.exit(1)
    print(f"MOBILE_ASSET_AUDIT PASS: estimated exported-source footprint {package_mb:.2f} MB")
    for warning in warnings:
        print(" WARNING:", warning)


if __name__ == "__main__":
    main()
