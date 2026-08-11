#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
LOC = ROOT / "localization"
MANIFEST = LOC / "manifest.json"
DATASETS = [
    "worlds", "locations", "families", "monsters", "bosses", "items", "npcs",
    "marks", "debts", "characters", "abilities", "events", "finals", "pools",
]


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def walk_units(
    record_id: str,
    value: Any,
    overlay_fields: set[str],
    label_fields: set[str],
    path: tuple[str, ...],
    content_out: list[dict],
    labels_out: dict[str, set[str]],
) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            key_s = str(key)
            child_path = path + (key_s,)
            if isinstance(child, str) and child.strip():
                if key_s in overlay_fields:
                    content_out.append({
                        "key": f"content.{record_id}." + ".".join(child_path),
                        "record_id": record_id,
                        "path": ".".join(child_path),
                        "source": child,
                    })
                if key_s in label_fields:
                    labels_out.setdefault(key_s, set()).add(child)
            walk_units(record_id, child, overlay_fields, label_fields, child_path, content_out, labels_out)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk_units(record_id, child, overlay_fields, label_fields, path + (str(index),), content_out, labels_out)


def source_label(catalog: dict, field: str, canonical: str) -> str:
    field_map = catalog.get(field, {})
    if isinstance(field_map, dict):
        value = field_map.get(canonical)
        if isinstance(value, str) and value.strip():
            return value
    return canonical


def build_catalog() -> dict:
    manifest = read_json(MANIFEST)
    overlay_fields = {str(v) for v in manifest.get("content_overlay_fields", [])}
    label_fields = {str(v) for v in manifest.get("content_label_fields", [])}
    content_units: list[dict] = []
    label_values: dict[str, set[str]] = {}
    record_count = 0
    for dataset in DATASETS:
        rows = read_json(DATA / f"{dataset}.json")
        if not isinstance(rows, list):
            raise SystemExit(f"dataset is not a list: {dataset}")
        for record in rows:
            if not isinstance(record, dict) or not str(record.get("id", "")):
                raise SystemExit(f"invalid record in {dataset}")
            record_count += 1
            walk_units(
                str(record["id"]), record, overlay_fields, label_fields, (), content_units, label_values
            )

    source_locale = str(manifest.get("source_locale", "pt_BR"))
    source_ui = read_json(LOC / "ui" / f"{source_locale}.json")
    ui_units = [
        {"key": f"ui.{key}", "path": str(key), "source": str(value)}
        for key, value in sorted(source_ui.items())
        if isinstance(value, str) and value.strip()
    ]
    source_labels = read_json(LOC / "labels" / f"{source_locale}.json")
    label_units: list[dict] = []
    for field in sorted(label_values):
        for canonical in sorted(label_values[field]):
            label_units.append({
                "key": f"label.{field}.{canonical}",
                "field": field,
                "canonical": canonical,
                "source": source_label(source_labels, field, canonical),
            })
    content_units.sort(key=lambda row: row["key"])
    label_units.sort(key=lambda row: row["key"])
    return {
        "schema_version": 2,
        "source_locale": source_locale,
        "record_count": record_count,
        "content_unit_count": len(content_units),
        "label_unit_count": len(label_units),
        "ui_unit_count": len(ui_units),
        "units": ui_units + label_units + content_units,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Export stable localization units with source context.")
    parser.add_argument("--output", type=Path, default=None, help="Optional JSON output path. Defaults to stdout summary only.")
    args = parser.parse_args()
    catalog = build_catalog()
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        "LOCALIZATION_CATALOG PASS: records=%d content_units=%d label_units=%d ui_units=%d total_units=%d"
        % (
            catalog["record_count"], catalog["content_unit_count"], catalog["label_unit_count"],
            catalog["ui_unit_count"], len(catalog["units"]),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
