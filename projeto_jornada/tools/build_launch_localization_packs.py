#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import gzip
import importlib.util
import json
import shutil
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
LOC = ROOT / "localization"
PACK_ROOT = LOC / "content_packs"
TARGETS = ("en", "es_419")
EXPECTED_SOURCE_UNITS = 18_804
EXPECTED_DELTA_UNITS = 15_334
PART_CHARS = 16_000

# These scripts are deliberately ordered from structured/mechanical names to
# freer narrative text. Applying them twice must be idempotent.
APPLIERS = (
    "seed_structured_localization.py",
    "seed_structured_name_localization.py",
    "seed_boss_name_localization.py",
    "seed_item_name_localization.py",
    "seed_family_monster_name_localization.py",
    "seed_world_location_derived_name_localization.py",
    "seed_structured_narrative_localization.py",
    "seed_event_localization.py",
)
OPTIONAL_APPLIERS = {"seed_family_monster_name_localization.py"}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def _inject_known_editorial_overrides(module: Any) -> None:
    """Patch a legacy material lexicon in memory without mutating translator source.

    The narrative translator predates the explicit luminous-moss entry. Different
    revisions used either locale->source maps or source->locale maps, so support
    both shapes. Adding the key only to dictionaries that already look like a
    bilingual lexicon is harmless and makes the compiler reproducible across the
    recovery revisions.
    """
    source = "musgo luminoso"
    targets = {"en": "Luminous Moss", "es_419": "Musgo Luminoso"}
    for value in vars(module).values():
        if not isinstance(value, dict):
            continue
        en_map = value.get("en")
        es_map = value.get("es_419")
        if isinstance(en_map, dict) and isinstance(es_map, dict):
            en_map.setdefault(source, targets["en"])
            es_map.setdefault(source, targets["es_419"])
        nested = [item for item in value.values() if isinstance(item, dict)]
        if nested and any("en" in item or "es_419" in item for item in nested):
            value.setdefault(source, dict(targets))


def run_applier(path: Path) -> None:
    module_name = f"_veredas_pack_{path.stem}"
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import translator: {path.name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if path.name == "seed_structured_narrative_localization.py":
        _inject_known_editorial_overrides(module)
    main = getattr(module, "main", None)
    if not callable(main):
        raise RuntimeError(f"translator has no main(): {path.name}")
    old_argv = sys.argv[:]
    try:
        sys.argv = [str(path), "--apply"]
        result = main()
    finally:
        sys.argv = old_argv
    if result not in (None, 0):
        raise RuntimeError(f"translator failed ({result}): {path.name}")


def unit_count(catalog: dict[str, Any]) -> int:
    total = 0
    for overlay in catalog.values():
        if not isinstance(overlay, dict):
            raise RuntimeError("content overlay record is not an object")
        total += sum(1 for value in overlay.values() if isinstance(value, str) and value.strip())
    return total


def build_delta(base: dict[str, Any], full: dict[str, Any], locale_id: str) -> dict[str, dict[str, str]]:
    delta: dict[str, dict[str, str]] = {}
    for record_id, full_overlay in full.items():
        if not isinstance(full_overlay, dict):
            raise RuntimeError(f"{locale_id}: full overlay record is not object: {record_id}")
        base_overlay = base.get(record_id, {})
        if base_overlay is None:
            base_overlay = {}
        if not isinstance(base_overlay, dict):
            raise RuntimeError(f"{locale_id}: base overlay record is not object: {record_id}")
        for path, value in full_overlay.items():
            if not isinstance(path, str) or not isinstance(value, str) or not value.strip():
                raise RuntimeError(f"{locale_id}: invalid translated value {record_id}.{path}")
            if path in base_overlay:
                if base_overlay[path] != value:
                    raise RuntimeError(
                        f"{locale_id}: compiler attempted to rewrite protected base translation {record_id}.{path}"
                    )
                continue
            delta.setdefault(str(record_id), {})[path] = value
    return delta


def encode_pack(delta: dict[str, Any]) -> str:
    raw = json.dumps(
        delta,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    compressed = gzip.compress(raw, compresslevel=9, mtime=0)
    return base64.b64encode(compressed).decode("ascii")


def current_pack_text(locale_id: str) -> str | None:
    single = PACK_ROOT / f"{locale_id}.json.gz.b64"
    part_dir = PACK_ROOT / locale_id
    if single.exists() and part_dir.exists():
        raise RuntimeError(f"{locale_id}: both single and multipart compact packs exist")
    if single.exists():
        return "".join(single.read_text(encoding="utf-8").split())
    if not part_dir.exists():
        return None
    parts = sorted(part_dir.glob("*.b64part"))
    if not parts:
        return None
    expected = [f"part_{index:03d}.b64part" for index in range(len(parts))]
    actual = [part.name for part in parts]
    if actual != expected:
        raise RuntimeError(f"{locale_id}: non-contiguous pack parts: {actual}")
    return "".join("".join(part.read_text(encoding="utf-8").split()) for part in parts)


def decode_pack_text(encoded: str) -> dict[str, Any]:
    try:
        raw = gzip.decompress(base64.b64decode(encoded, validate=True))
        value = json.loads(raw.decode("utf-8"))
    except Exception as exc:  # noqa: BLE001 - compiler must fail closed.
        raise RuntimeError(f"cannot decode existing compact pack: {exc}") from exc
    if not isinstance(value, dict):
        raise RuntimeError("decoded existing compact pack is not an object")
    return value


def write_pack(locale_id: str, encoded: str) -> list[str]:
    single = PACK_ROOT / f"{locale_id}.json.gz.b64"
    if single.exists():
        single.unlink()
    part_dir = PACK_ROOT / locale_id
    if part_dir.exists():
        shutil.rmtree(part_dir)
    part_dir.mkdir(parents=True, exist_ok=True)
    names: list[str] = []
    for index, start in enumerate(range(0, len(encoded), PART_CHARS)):
        name = f"part_{index:03d}.b64part"
        (part_dir / name).write_text(encoded[start:start + PART_CHARS], encoding="utf-8")
        names.append(name)
    return names


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Reproducibly compile complete launch localization into compact delta packs."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--build", action="store_true", help="Write deterministic compact packs.")
    mode.add_argument("--check", action="store_true", help="Recompile in memory and compare semantic pack contents.")
    args = parser.parse_args()

    sys.path.insert(0, str(TOOLS))
    catalog_paths = {locale: LOC / "content" / f"{locale}.json" for locale in TARGETS}
    original_text = {locale: path.read_text(encoding="utf-8") for locale, path in catalog_paths.items()}
    base_catalogs = {locale: json.loads(text) for locale, text in original_text.items()}
    if any(not isinstance(value, dict) for value in base_catalogs.values()):
        raise SystemExit("base launch content catalogs must be JSON objects")

    try:
        for script_name in APPLIERS:
            script_path = TOOLS / script_name
            if not script_path.exists():
                if script_name in OPTIONAL_APPLIERS:
                    print(f"BUILD_LOCALIZATION_PACKS optional translator absent: {script_name}")
                    continue
                raise RuntimeError(f"required translator missing: {script_name}")
            run_applier(script_path)
        full_catalogs = {locale: read_object(path) for locale, path in catalog_paths.items()}
    finally:
        # Canonical/base overlay catalogs are inputs, never compiler outputs.
        for locale, path in catalog_paths.items():
            path.write_text(original_text[locale], encoding="utf-8")

    deltas: dict[str, dict[str, Any]] = {}
    for locale_id in TARGETS:
        full_count = unit_count(full_catalogs[locale_id])
        if full_count != EXPECTED_SOURCE_UNITS:
            raise SystemExit(
                f"{locale_id}: expected complete {EXPECTED_SOURCE_UNITS}-unit catalog, got {full_count}"
            )
        delta = build_delta(base_catalogs[locale_id], full_catalogs[locale_id], locale_id)
        delta_count = unit_count(delta)
        if delta_count != EXPECTED_DELTA_UNITS:
            raise SystemExit(
                f"{locale_id}: expected {EXPECTED_DELTA_UNITS} delta units, got {delta_count}"
            )
        deltas[locale_id] = delta

    en_keys = {(record_id, path) for record_id, overlay in deltas["en"].items() for path in overlay}
    es_keys = {(record_id, path) for record_id, overlay in deltas["es_419"].items() for path in overlay}
    if en_keys != es_keys:
        raise SystemExit(
            "target delta key sets differ: en_only=%d es_only=%d"
            % (len(en_keys - es_keys), len(es_keys - en_keys))
        )

    if args.check:
        for locale_id in TARGETS:
            existing_text = current_pack_text(locale_id)
            if existing_text is None:
                raise SystemExit(f"{locale_id}: compact pack missing")
            existing = decode_pack_text(existing_text)
            if existing != deltas[locale_id]:
                raise SystemExit(f"{locale_id}: compact pack does not match reproducible compiler output")
        print(
            "BUILD_LOCALIZATION_PACKS PASS: semantic packs reproducible targets=2 full_each=%d delta_each=%d"
            % (EXPECTED_SOURCE_UNITS, EXPECTED_DELTA_UNITS)
        )
        return 0

    for locale_id in TARGETS:
        encoded = encode_pack(deltas[locale_id])
        names = write_pack(locale_id, encoded)
        print(
            "BUILD_LOCALIZATION_PACKS wrote %s: units=%d base64_chars=%d parts=%d"
            % (locale_id, EXPECTED_DELTA_UNITS, len(encoded), len(names))
        )
    print(
        "BUILD_LOCALIZATION_PACKS PASS: targets=2 full_each=%d delta_each=%d"
        % (EXPECTED_SOURCE_UNITS, EXPECTED_DELTA_UNITS)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
