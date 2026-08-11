#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from export_localization_catalog import build_catalog

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected JSON object: {path}")
    return value


def flatten_overlay(catalog: dict) -> set[str]:
    keys: set[str] = set()
    for record_id, overlay in catalog.items():
        if not isinstance(overlay, dict):
            continue
        for path, value in overlay.items():
            if isinstance(value, str) and value.strip():
                keys.add(f"content.{record_id}.{path}")
    return keys


def main() -> int:
    parser = argparse.ArgumentParser(description="Report linguistic coverage and glossary integrity.")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--require-complete", action="store_true", help="Fail unless every launch target covers every source unit.")
    args = parser.parse_args()

    manifest = read_object(LOC / "manifest.json")
    glossary = read_object(LOC / "glossary.json")
    catalog = build_catalog()
    source_locale = str(manifest.get("source_locale", "pt_BR"))
    launch_locales = [str(v) for v in manifest.get("launch_locales", [])]
    targets = [v for v in launch_locales if v != source_locale]
    source_content_keys = {row["key"] for row in catalog["units"] if str(row["key"]).startswith("content.")}
    required_ui = {str(v) for v in manifest.get("ui_required_keys", [])}

    errors: list[str] = []
    terms = glossary.get("terms", {})
    if not isinstance(terms, dict) or not terms:
        errors.append("glossary terms missing")
        terms = {}
    for term_id, entry in terms.items():
        if not isinstance(entry, dict):
            errors.append(f"glossary entry is not object: {term_id}")
            continue
        for locale_id in launch_locales:
            value = entry.get(locale_id)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"glossary translation missing: {term_id}:{locale_id}")
        if not isinstance(entry.get("class"), str) or not str(entry.get("class", "")).strip():
            errors.append(f"glossary class missing: {term_id}")

    locale_reports: dict[str, dict] = {}
    for locale_id in targets:
        content_catalog = read_object(LOC / "content" / f"{locale_id}.json")
        translated_content = flatten_overlay(content_catalog)
        unknown = translated_content - source_content_keys
        if unknown:
            errors.append(f"{locale_id}: {len(unknown)} translated content keys are outside source inventory")
        translated_content &= source_content_keys

        ui_catalog = read_object(LOC / "ui" / f"{locale_id}.json")
        translated_ui = {key for key in required_ui if isinstance(ui_catalog.get(key), str) and str(ui_catalog[key]).strip()}
        content_total = len(source_content_keys)
        ui_total = len(required_ui)
        locale_reports[locale_id] = {
            "content_translated": len(translated_content),
            "content_total": content_total,
            "content_coverage": round(len(translated_content) / content_total, 6) if content_total else 1.0,
            "ui_translated": len(translated_ui),
            "ui_total": ui_total,
            "ui_coverage": round(len(translated_ui) / ui_total, 6) if ui_total else 1.0,
            "missing_content": content_total - len(translated_content),
            "missing_ui": ui_total - len(translated_ui),
        }
        if args.require_complete:
            if len(translated_content) != content_total:
                errors.append(f"{locale_id}: content translation incomplete {len(translated_content)}/{content_total}")
            if len(translated_ui) != ui_total:
                errors.append(f"{locale_id}: UI translation incomplete {len(translated_ui)}/{ui_total}")

    report = {
        "schema_version": 1,
        "source_locale": source_locale,
        "targets": targets,
        "source_records": catalog["record_count"],
        "source_content_units": len(source_content_keys),
        "required_ui_units": len(required_ui),
        "glossary_terms": len(terms),
        "locales": locale_reports,
        "complete_gate_requested": args.require_complete,
        "errors": errors,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    for locale_id in targets:
        row = locale_reports[locale_id]
        print(
            "LINGUISTIC_COVERAGE %s: content=%d/%d (%.4f%%) ui=%d/%d (%.2f%%) missing_content=%d"
            % (
                locale_id,
                row["content_translated"], row["content_total"], row["content_coverage"] * 100.0,
                row["ui_translated"], row["ui_total"], row["ui_coverage"] * 100.0,
                row["missing_content"],
            )
        )
    if errors:
        print(f"LINGUISTIC_REPORT FAIL: {len(errors)} issue(s)")
        for error in errors[:50]:
            print("ERROR:", error)
        return 1
    print(
        "LINGUISTIC_REPORT PASS: structure_only glossary_terms=%d source_content_units=%d require_complete=%s"
        % (len(terms), len(source_content_keys), str(args.require_complete).lower())
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
