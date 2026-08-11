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


def flatten_labels(catalog: dict) -> set[str]:
    keys: set[str] = set()
    for field, values in catalog.items():
        if not isinstance(values, dict):
            continue
        for canonical, translated in values.items():
            if isinstance(translated, str) and translated.strip():
                keys.add(f"label.{field}.{canonical}")
    return keys


def coverage(translated: set[str], source: set[str]) -> dict:
    valid = translated & source
    total = len(source)
    return {
        "translated": len(valid),
        "total": total,
        "coverage": round(len(valid) / total, 6) if total else 1.0,
        "missing": total - len(valid),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Report linguistic coverage and glossary integrity.")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--require-complete", action="store_true", help="Fail unless every launch target covers every source unit.")
    parser.add_argument("--require-complete-labels", action="store_true", help="Fail unless every launch locale, including the source locale, covers every canonical label.")
    parser.add_argument("--require-complete-ui", action="store_true", help="Fail unless every launch locale covers every required UI key.")
    args = parser.parse_args()

    manifest = read_object(LOC / "manifest.json")
    glossary = read_object(LOC / "glossary.json")
    catalog = build_catalog()
    source_locale = str(manifest.get("source_locale", "pt_BR"))
    launch_locales = [str(v) for v in manifest.get("launch_locales", [])]
    targets = [v for v in launch_locales if v != source_locale]
    source_content_keys = {row["key"] for row in catalog["units"] if str(row["key"]).startswith("content.")}
    source_label_keys = {row["key"] for row in catalog["units"] if str(row["key"]).startswith("label.")}
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

    source_label_catalog = read_object(LOC / "labels" / f"{source_locale}.json")
    source_labels = flatten_labels(source_label_catalog)
    unknown_source_labels = source_labels - source_label_keys
    if unknown_source_labels:
        errors.append(f"{source_locale}: {len(unknown_source_labels)} source label keys are outside source inventory")
    source_label_report = coverage(source_labels, source_label_keys)
    if args.require_complete or args.require_complete_labels:
        if source_label_report["translated"] != source_label_report["total"]:
            errors.append(
                f"{source_locale}: source label catalog incomplete "
                f"{source_label_report['translated']}/{source_label_report['total']}"
            )

    source_ui_catalog = read_object(LOC / "ui" / f"{source_locale}.json")
    source_ui = {key for key in required_ui if isinstance(source_ui_catalog.get(key), str) and str(source_ui_catalog[key]).strip()}
    source_ui_report = coverage(source_ui, required_ui)
    if args.require_complete or args.require_complete_ui:
        if source_ui_report["translated"] != source_ui_report["total"]:
            errors.append(
                f"{source_locale}: source UI catalog incomplete "
                f"{source_ui_report['translated']}/{source_ui_report['total']}"
            )

    locale_reports: dict[str, dict] = {}
    for locale_id in targets:
        content_catalog = read_object(LOC / "content" / f"{locale_id}.json")
        translated_content = flatten_overlay(content_catalog)
        unknown_content = translated_content - source_content_keys
        if unknown_content:
            errors.append(f"{locale_id}: {len(unknown_content)} translated content keys are outside source inventory")
        content_report = coverage(translated_content, source_content_keys)

        label_catalog = read_object(LOC / "labels" / f"{locale_id}.json")
        translated_labels = flatten_labels(label_catalog)
        unknown_labels = translated_labels - source_label_keys
        if unknown_labels:
            errors.append(f"{locale_id}: {len(unknown_labels)} translated label keys are outside source inventory")
        label_report = coverage(translated_labels, source_label_keys)

        ui_catalog = read_object(LOC / "ui" / f"{locale_id}.json")
        translated_ui = {key for key in required_ui if isinstance(ui_catalog.get(key), str) and str(ui_catalog[key]).strip()}
        ui_report = coverage(translated_ui, required_ui)

        locale_reports[locale_id] = {
            "content_translated": content_report["translated"],
            "content_total": content_report["total"],
            "content_coverage": content_report["coverage"],
            "labels_translated": label_report["translated"],
            "labels_total": label_report["total"],
            "labels_coverage": label_report["coverage"],
            "ui_translated": ui_report["translated"],
            "ui_total": ui_report["total"],
            "ui_coverage": ui_report["coverage"],
            "missing_content": content_report["missing"],
            "missing_labels": label_report["missing"],
            "missing_ui": ui_report["missing"],
        }
        if args.require_complete or args.require_complete_labels:
            if label_report["translated"] != label_report["total"]:
                errors.append(f"{locale_id}: label translation incomplete {label_report['translated']}/{label_report['total']}")
        if args.require_complete or args.require_complete_ui:
            if ui_report["translated"] != ui_report["total"]:
                errors.append(f"{locale_id}: UI translation incomplete {ui_report['translated']}/{ui_report['total']}")
        if args.require_complete and content_report["translated"] != content_report["total"]:
            errors.append(f"{locale_id}: content translation incomplete {content_report['translated']}/{content_report['total']}")

    report = {
        "schema_version": 4,
        "source_locale": source_locale,
        "targets": targets,
        "source_records": catalog["record_count"],
        "source_content_units": len(source_content_keys),
        "source_label_units": len(source_label_keys),
        "required_ui_units": len(required_ui),
        "glossary_terms": len(terms),
        "source_catalog": {
            "labels_translated": source_label_report["translated"],
            "labels_total": source_label_report["total"],
            "labels_coverage": source_label_report["coverage"],
            "missing_labels": source_label_report["missing"],
            "ui_translated": source_ui_report["translated"],
            "ui_total": source_ui_report["total"],
            "ui_coverage": source_ui_report["coverage"],
            "missing_ui": source_ui_report["missing"],
        },
        "locales": locale_reports,
        "complete_gate_requested": args.require_complete,
        "complete_labels_gate_requested": args.require_complete_labels,
        "complete_ui_gate_requested": args.require_complete_ui,
        "errors": errors,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        "LINGUISTIC_COVERAGE %s: labels=%d/%d (%.2f%%) ui=%d/%d (%.2f%%) [source]"
        % (
            source_locale,
            source_label_report["translated"], source_label_report["total"], source_label_report["coverage"] * 100.0,
            source_ui_report["translated"], source_ui_report["total"], source_ui_report["coverage"] * 100.0,
        )
    )
    for locale_id in targets:
        row = locale_reports[locale_id]
        print(
            "LINGUISTIC_COVERAGE %s: content=%d/%d (%.4f%%) labels=%d/%d (%.2f%%) ui=%d/%d (%.2f%%)"
            % (
                locale_id,
                row["content_translated"], row["content_total"], row["content_coverage"] * 100.0,
                row["labels_translated"], row["labels_total"], row["labels_coverage"] * 100.0,
                row["ui_translated"], row["ui_total"], row["ui_coverage"] * 100.0,
            )
        )
    if errors:
        print(f"LINGUISTIC_REPORT FAIL: {len(errors)} issue(s)")
        for error in errors[:50]:
            print("ERROR:", error)
        return 1
    print(
        "LINGUISTIC_REPORT PASS: glossary_terms=%d source_content_units=%d source_label_units=%d require_complete=%s require_labels=%s require_ui=%s"
        % (
            len(terms), len(source_content_keys), len(source_label_keys),
            str(args.require_complete).lower(), str(args.require_complete_labels).lower(), str(args.require_complete_ui).lower(),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
