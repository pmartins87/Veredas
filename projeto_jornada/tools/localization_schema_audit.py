#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
LOC = ROOT / "localization"


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def walk(value: Any, path: tuple[str, ...], counts: Counter, samples: dict[str, list[str]]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            key_s = str(key)
            child_path = path + (key_s,)
            if isinstance(child, str) and child.strip():
                counts[key_s] += 1
                bucket = samples[key_s]
                if len(bucket) < 5:
                    bucket.append(".".join(child_path) + " = " + child[:140])
            walk(child, child_path, counts, samples)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk(child, path + (str(index),), counts, samples)


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit every string-bearing content field against localization classification.")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--require-classified", action="store_true")
    args = parser.parse_args()

    manifest = read_json(LOC / "manifest.json")
    overlay = {str(v) for v in manifest.get("content_overlay_fields", [])}
    internal = {str(v) for v in manifest.get("content_internal_string_fields", [])}
    labels = {str(v) for v in manifest.get("content_label_fields", [])}
    classified = overlay | internal | labels

    counts: Counter = Counter()
    samples: dict[str, list[str]] = defaultdict(list)
    for path in sorted(DATA.glob("*.json")):
        rows = read_json(path)
        walk(rows, (path.stem,), counts, samples)

    unknown = {field: count for field, count in sorted(counts.items()) if field not in classified}
    overlap = {
        "overlay_internal": sorted(overlay & internal),
        "overlay_labels": sorted(overlay & labels),
        "internal_labels": sorted(internal & labels),
    }
    overlaps = [item for values in overlap.values() for item in values]
    report = {
        "schema_version": 1,
        "field_counts": dict(sorted(counts.items())),
        "overlay_fields": sorted(overlay),
        "internal_fields": sorted(internal),
        "label_fields": sorted(labels),
        "unknown_fields": unknown,
        "overlaps": overlap,
        "samples": {field: samples[field] for field in sorted(samples)},
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        "LOCALIZATION_SCHEMA_AUDIT: string_fields=%d overlay=%d internal=%d labels=%d unknown=%d overlaps=%d"
        % (len(counts), len(overlay), len(internal), len(labels), len(unknown), len(overlaps))
    )
    for field, count in unknown.items():
        print("UNCLASSIFIED_STRING_FIELD %s: %d sample=%s" % (field, count, samples[field][0] if samples[field] else ""))
    if overlaps:
        print("LOCALIZATION_SCHEMA_AUDIT FAIL: field classifications overlap")
        return 1
    if args.require_classified and unknown:
        print("LOCALIZATION_SCHEMA_AUDIT FAIL: unclassified string fields remain")
        return 1
    print("LOCALIZATION_SCHEMA_AUDIT PASS: report_only=%s" % str(not args.require_classified).lower())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
