#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import gzip
import json
from collections import Counter
from pathlib import Path
from typing import Any

from export_localization_catalog import build_catalog
from localization_quality_gate import token_signature

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
PACK_ROOT = LOC / "content_packs"
TARGETS = ("en", "es_419")
EXPECTED_SOURCE_UNITS = 18_804
EXPECTED_PACK_UNITS = 15_334


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def flatten_overlay(catalog: dict[str, Any], origin: str) -> dict[str, str]:
    flat: dict[str, str] = {}
    for record_id, overlay in catalog.items():
        if not isinstance(record_id, str) or not record_id:
            raise ValueError(f"{origin}: invalid record id")
        if not isinstance(overlay, dict):
            raise ValueError(f"{origin}: overlay is not object for {record_id}")
        for path, value in overlay.items():
            if not isinstance(path, str) or not path:
                raise ValueError(f"{origin}: invalid path for {record_id}")
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"{origin}: empty/non-string value for {record_id}.{path}")
            key = f"content.{record_id}.{path}"
            if key in flat:
                raise ValueError(f"{origin}: duplicate flattened key {key}")
            flat[key] = value
    return flat


def read_compact_pack(locale_id: str) -> tuple[dict[str, Any], dict[str, Any]]:
    single = PACK_ROOT / f"{locale_id}.json.gz.b64"
    part_dir = PACK_ROOT / locale_id
    if single.exists() and part_dir.exists():
        raise ValueError(f"{locale_id}: both single-file and multipart packs exist")

    if single.exists():
        encoded = "".join(single.read_text(encoding="utf-8").split())
        part_names = [single.name]
    elif part_dir.exists():
        parts = sorted(part_dir.glob("*.b64part"))
        if not parts:
            raise ValueError(f"{locale_id}: multipart directory is empty")
        expected_names = [f"part_{index:03d}.b64part" for index in range(len(parts))]
        actual_names = [path.name for path in parts]
        if actual_names != expected_names:
            raise ValueError(
                f"{locale_id}: multipart sequence is not contiguous: {actual_names}"
            )
        encoded = "".join("".join(path.read_text(encoding="utf-8").split()) for path in parts)
        part_names = actual_names
    else:
        raise ValueError(f"{locale_id}: compact content pack missing")

    try:
        compressed = base64.b64decode(encoded, validate=True)
        raw = gzip.decompress(compressed)
        parsed = json.loads(raw.decode("utf-8"))
    except Exception as exc:  # noqa: BLE001 - certification must fail closed.
        raise ValueError(f"{locale_id}: compact pack decode failed: {exc}") from exc
    if not isinstance(parsed, dict):
        raise ValueError(f"{locale_id}: decoded compact pack is not an object")
    return parsed, {
        "parts": part_names,
        "base64_chars": len(encoded),
        "compressed_bytes": len(compressed),
        "json_bytes": len(raw),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Certify launch localization compact packs against the canonical source inventory."
    )
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    catalog = build_catalog()
    source_rows = [
        row for row in catalog.get("units", [])
        if isinstance(row, dict) and str(row.get("key", "")).startswith("content.")
    ]
    source: dict[str, str] = {
        str(row["key"]): str(row["source"])
        for row in source_rows
        if isinstance(row.get("source"), str)
    }
    errors: list[str] = []
    if len(source) != EXPECTED_SOURCE_UNITS:
        errors.append(
            f"source inventory changed: expected {EXPECTED_SOURCE_UNITS}, got {len(source)}"
        )

    reports: dict[str, Any] = {}
    pack_key_sets: dict[str, set[str]] = {}
    for locale_id in TARGETS:
        try:
            base = flatten_overlay(
                read_object(LOC / "content" / f"{locale_id}.json"),
                f"{locale_id}:base",
            )
            pack_catalog, pack_meta = read_compact_pack(locale_id)
            pack = flatten_overlay(pack_catalog, f"{locale_id}:pack")
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(str(exc))
            reports[locale_id] = {"fatal": str(exc)}
            continue

        pack_keys = set(pack)
        pack_key_sets[locale_id] = pack_keys
        source_keys = set(source)
        base_keys = set(base)
        collisions = sorted(base_keys & pack_keys)
        unknown_base = sorted(base_keys - source_keys)
        unknown_pack = sorted(pack_keys - source_keys)
        union_keys = base_keys | pack_keys
        missing = sorted(source_keys - union_keys)
        token_errors: list[dict[str, Any]] = []

        for key in sorted(union_keys & source_keys):
            translated = pack.get(key, base.get(key, ""))
            source_sig = token_signature(source[key])
            target_sig = token_signature(translated)
            for family in ("printf", "braces", "bbcode"):
                if source_sig[family] != target_sig[family]:
                    token_errors.append({
                        "key": key,
                        "family": family,
                        "source": dict(source_sig[family]),
                        "target": dict(target_sig[family]),
                    })

        if len(pack) != EXPECTED_PACK_UNITS:
            errors.append(
                f"{locale_id}: expected {EXPECTED_PACK_UNITS} pack units, got {len(pack)}"
            )
        if collisions:
            errors.append(f"{locale_id}: {len(collisions)} base/pack collision(s)")
        if unknown_base:
            errors.append(f"{locale_id}: {len(unknown_base)} unknown base key(s)")
        if unknown_pack:
            errors.append(f"{locale_id}: {len(unknown_pack)} unknown pack key(s)")
        if missing:
            errors.append(
                f"{locale_id}: incomplete content coverage {len(union_keys & source_keys)}/{len(source_keys)}"
            )
        if token_errors:
            errors.append(f"{locale_id}: {len(token_errors)} token/BBCode parity violation(s)")

        reports[locale_id] = {
            "base_units": len(base),
            "pack_units": len(pack),
            "covered_units": len(union_keys & source_keys),
            "source_units": len(source_keys),
            "collisions": len(collisions),
            "unknown_base": len(unknown_base),
            "unknown_pack": len(unknown_pack),
            "missing": len(missing),
            "token_errors": token_errors,
            "first_missing": missing[:100],
            "pack": pack_meta,
        }

    if all(locale_id in pack_key_sets for locale_id in TARGETS):
        if pack_key_sets["en"] != pack_key_sets["es_419"]:
            only_en = pack_key_sets["en"] - pack_key_sets["es_419"]
            only_es = pack_key_sets["es_419"] - pack_key_sets["en"]
            errors.append(
                "target pack key sets differ: en_only=%d es_only=%d"
                % (len(only_en), len(only_es))
            )

    report = {
        "schema_version": 1,
        "expected_source_units": EXPECTED_SOURCE_UNITS,
        "expected_pack_units": EXPECTED_PACK_UNITS,
        "locales": reports,
        "errors": errors,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if errors:
        print(f"LOCALIZATION_PACK_CERTIFICATION FAIL: {len(errors)} issue group(s)")
        for error in errors[:50]:
            print("ERROR:", error)
        return 1

    en = reports["en"]
    es = reports["es_419"]
    print(
        "LOCALIZATION_PACK_CERTIFICATION PASS: en=%d/%d es_419=%d/%d pack_each=%d collisions=0 unknown=0 token_errors=0"
        % (
            en["covered_units"], en["source_units"],
            es["covered_units"], es["source_units"],
            EXPECTED_PACK_UNITS,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
