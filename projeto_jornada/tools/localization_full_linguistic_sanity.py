#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path
from typing import Any

from export_localization_catalog import build_catalog
from localization_pack_certification import flatten_overlay, launch_targets, read_compact_pack, read_object
from localization_quality_gate import token_signature

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
FORBIDDEN_MARKERS = ("TODO", "TBD", "TRANSLATE_ME", "[MISSING]", "<MISSING>")
WORD_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿ]+", re.UNICODE)

PT_STRONG = {
    "não", "você", "vocês", "uma", "com", "sem", "seu", "sua", "aqui", "agora",
    "então", "depois", "antes", "porque", "quando", "onde", "ainda", "pelo", "pela",
    "dos", "das", "nas", "nos",
}
EN_STRONG = {
    "the", "and", "with", "without", "your", "you", "from", "into", "this", "that",
    "when", "where", "before", "after", "through", "while",
}


def normalized(value: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def words(value: str) -> list[str]:
    return [word.casefold() for word in WORD_RE.findall(value)]


def complete_locale(locale_id: str) -> tuple[dict[str, str], dict[str, Any]]:
    base = flatten_overlay(
        read_object(LOC / "content" / f"{locale_id}.json"),
        f"{locale_id}:base",
    )
    pack_catalog, pack_meta = read_compact_pack(locale_id)
    pack = flatten_overlay(pack_catalog, f"{locale_id}:pack")
    overlap = set(base) & set(pack)
    if overlap:
        raise RuntimeError(f"{locale_id}: base/pack overlap prevents linguistic audit: {len(overlap)}")
    merged = dict(base)
    merged.update(pack)
    return merged, pack_meta


def main() -> int:
    parser = argparse.ArgumentParser(description="Fail-closed linguistic sanity audit over complete launch content.")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    targets = launch_targets()
    catalog = build_catalog()
    source = {
        str(row["key"]): str(row["source"])
        for row in catalog.get("units", [])
        if isinstance(row, dict)
        and str(row.get("key", "")).startswith("content.")
        and isinstance(row.get("source"), str)
    }
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    locale_reports: dict[str, Any] = {}

    for locale_id in targets:
        try:
            target, pack_meta = complete_locale(locale_id)
        except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
            errors.append({"locale": locale_id, "kind": "fatal", "detail": str(exc)})
            continue

        missing = set(source) - set(target)
        unknown = set(target) - set(source)
        if missing:
            errors.append({"locale": locale_id, "kind": "missing", "count": len(missing)})
        if unknown:
            errors.append({"locale": locale_id, "kind": "unknown", "count": len(unknown)})

        identical_long = 0
        wrong_language = 0
        marker_count = 0
        token_errors = 0
        ratio_warnings = 0
        exclusive_diacritic_warnings = 0

        for key in sorted(set(source) & set(target)):
            src = source[key]
            dst = target[key]
            src_words = words(src)
            dst_words = words(dst)

            if token_signature(src) != token_signature(dst):
                token_errors += 1
                errors.append({"locale": locale_id, "kind": "token_parity", "key": key})

            for marker in FORBIDDEN_MARKERS:
                if marker.casefold() in dst.casefold():
                    marker_count += 1
                    errors.append({
                        "locale": locale_id,
                        "kind": "forbidden_marker",
                        "key": key,
                        "marker": marker,
                    })
                    break

            is_name = key.endswith(".name")
            if not is_name and len(src_words) >= 6 and normalized(src) == normalized(dst):
                identical_long += 1
                errors.append({"locale": locale_id, "kind": "long_source_identical", "key": key})

            counts = Counter(dst_words)
            if locale_id == "en":
                residue = sum(counts[word] for word in PT_STRONG)
                if not is_name and len(dst_words) >= 7 and residue >= 3:
                    wrong_language += 1
                    errors.append({
                        "locale": locale_id,
                        "kind": "portuguese_residue",
                        "key": key,
                        "strong_word_hits": residue,
                    })
            else:
                pt_residue = sum(counts[word] for word in PT_STRONG)
                en_residue = sum(counts[word] for word in EN_STRONG)
                if not is_name and len(dst_words) >= 7 and pt_residue >= 3:
                    wrong_language += 1
                    errors.append({
                        "locale": locale_id,
                        "kind": "portuguese_residue",
                        "key": key,
                        "strong_word_hits": pt_residue,
                    })
                if not is_name and len(dst_words) >= 7 and en_residue >= 3:
                    wrong_language += 1
                    errors.append({
                        "locale": locale_id,
                        "kind": "english_residue",
                        "key": key,
                        "strong_word_hits": en_residue,
                    })

            if not is_name and len(src) >= 40:
                ratio = len(dst) / max(1, len(src))
                if ratio < 0.25 or ratio > 3.5:
                    ratio_warnings += 1
                    warnings.append({
                        "locale": locale_id,
                        "kind": "extreme_length_ratio",
                        "key": key,
                        "ratio": round(ratio, 3),
                    })

            if not is_name and any(char in normalized(dst) for char in ("ã", "õ", "ç")):
                exclusive_diacritic_warnings += 1
                warnings.append({
                    "locale": locale_id,
                    "kind": "portuguese_specific_diacritic_review",
                    "key": key,
                })

        locale_reports[locale_id] = {
            "translated_units": len(target),
            "source_units": len(source),
            "missing": len(missing),
            "unknown": len(unknown),
            "long_source_identical": identical_long,
            "wrong_language_blocks": wrong_language,
            "forbidden_markers": marker_count,
            "token_parity_errors": token_errors,
            "extreme_length_ratio_warnings": ratio_warnings,
            "portuguese_specific_diacritic_warnings": exclusive_diacritic_warnings,
            "pack": pack_meta,
        }

    report = {
        "schema_version": 1,
        "source_units": len(source),
        "targets": list(targets),
        "locales": locale_reports,
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if errors:
        print(f"LOCALIZATION_FULL_LINGUISTIC_SANITY FAIL: {len(errors)} issue(s)")
        for row in errors[:100]:
            print("ERROR:", json.dumps(row, ensure_ascii=False, sort_keys=True))
        return 1

    print(
        "LOCALIZATION_FULL_LINGUISTIC_SANITY PASS: targets=%d source_units=%d hard_errors=0 warnings=%d"
        % (len(targets), len(source), len(warnings))
    )
    for row in warnings[:50]:
        print("WARNING:", json.dumps(row, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
