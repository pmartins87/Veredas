#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art" / "final_source"
OUT = ROOT / "assets" / "art" / "mobile"
BUDGETS = ROOT / "mobile" / "asset_budgets.json"
MANIFEST = OUT / "manifest.json"


def load_budgets():
    return json.loads(BUDGETS.read_text(encoding="utf-8"))


def category_for(path: Path) -> str:
    parts = {p.lower() for p in path.parts}
    for category in ["domain_key_art","location","character","monster_family","boss","npc","ui"]:
        if category in parts:
            return category
    return "ui"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    budgets = load_budgets()
    profiles = budgets["profiles"]
    OUT.mkdir(parents=True, exist_ok=True)
    if not SOURCE.exists():
        MANIFEST.write_text(json.dumps({"schema_version":1,"assets":[],"source_missing":True}, indent=2), encoding="utf-8")
        print("MOBILE_ASSET_PREP PASS: no final_source yet; empty manifest written")
        return 0
    try:
        from PIL import Image, ImageOps
    except Exception:
        print("Pillow is required when final_source contains raster art. Install with: pip install Pillow", file=sys.stderr)
        return 2

    assets = []
    supported = {".png", ".jpg", ".jpeg", ".webp"}
    for source in sorted(p for p in SOURCE.rglob("*") if p.is_file() and p.suffix.lower() in supported):
        rel = source.relative_to(SOURCE)
        category = category_for(rel)
        profile = profiles[category]
        with Image.open(source) as image:
            image = ImageOps.exif_transpose(image)
            image.thumbnail((int(profile["max_width"]), int(profile["max_height"])), Image.Resampling.LANCZOS)
            alpha = image.mode in ("RGBA", "LA") or (image.mode == "P" and "transparency" in image.info)
            target_rel = rel.with_suffix(".png" if alpha and category == "ui" else ".webp")
            target = OUT / target_rel
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.suffix == ".png":
                if image.mode not in ("RGB", "RGBA"):
                    image = image.convert("RGBA" if alpha else "RGB")
                image.save(target, "PNG", optimize=True)
            else:
                if image.mode not in ("RGB", "RGBA"):
                    image = image.convert("RGBA" if alpha else "RGB")
                image.save(target, "WEBP", quality=int(profile["quality"]), method=6, lossless=False)
            size_kb = target.stat().st_size / 1024.0
            if size_kb > float(profile["max_file_kb"]):
                print(f"WARNING: {target_rel} is {size_kb:.1f}KB > {profile['max_file_kb']}KB budget")
            assets.append({
                "source": str(rel).replace("\\", "/"),
                "output": str(target_rel).replace("\\", "/"),
                "category": category,
                "width": image.width,
                "height": image.height,
                "bytes": target.stat().st_size,
                "sha256": sha256(target),
            })
    MANIFEST.write_text(json.dumps({"schema_version":1,"assets":assets}, ensure_ascii=False, indent=2), encoding="utf-8")
    total_mb = sum(a["bytes"] for a in assets) / 1048576.0
    print(f"MOBILE_ASSET_PREP PASS: {len(assets)} assets, {total_mb:.2f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
