#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import gzip
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path
from typing import Any

from export_localization_catalog import build_catalog

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
PACK_ROOT = LOC / "content_packs"

PRINTF_RE = re.compile(r"%(?:\d+\$)?[-+#0 ]*\d*(?:\.\d+)?[diouxXeEfFgGcrs]")
BRACE_RE = re.compile(r"(?<!\{)\{(?:[A-Za-z_][A-Za-z0-9_]*|\d+)\}(?!\})")
BBCODE_RE = re.compile(r"\[/?[A-Za-z_][A-Za-z0-9_]*(?:=[^\]]+)?\]")
WORDISH_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿ0-9_]")


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected JSON object: {path}")
    return value


def flatten_content(catalog: dict[str, Any]) -> dict[str, str]:
    out: dict[str, str] = {}
    for record_id, overlay in catalog.items():
        if not isinstance(overlay, dict):
            continue
        for path, value in overlay.items():
            if isinstance(value, str) and value.strip():
                out[f"content.{record_id}.{path}"] = value
    return out


def flatten_labels(catalog: dict[str, Any]) -> dict[str, str]:
    out: dict[str, str] = {}
    for field, values in catalog.items():
        if not isinstance(values, dict):
            continue
        for canonical, translated in values.items():
            if isinstance(translated, str) and translated.strip():
                out[f"label.{field}.{canonical}"] = translated
    return out


def flatten_ui(catalog: dict[str, Any]) -> dict[str, str]:
    return {
        f"ui.{key}": value
        for key, value in catalog.items()
        if isinstance(value, str) and value.strip()
    }


def compact_pack_content(locale_id: str) -> dict[str, str]:
    single = PACK_ROOT / f"{locale_id}.json.gz.b64"
    part_dir = PACK_ROOT / locale_id
    if single.exists() and part_dir.exists():
        raise SystemExit(f"{locale_id}: both single and multipart compact packs exist")
    if single.exists():
        encoded = "".join(single.read_text(encoding="utf-8").split())
    elif part_dir.exists():
        parts = sorted(part_dir.glob("*.b64part"))
        if not parts:
            return {}
        expected = [f"part_{index:03d}.b64part" for index in range(len(parts))]
        actual = [part.name for part in parts]
        if actual != expected:
            raise SystemExit(f"{locale_id}: non-contiguous compact pack parts: {actual}")
        encoded = "".join("".join(part.read_text(encoding="utf-8").split()) for part in parts)
    else:
        return {}
    try:
        raw = gzip.decompress(base64.b64decode(encoded, validate=True))
        parsed = json.loads(raw.decode("utf-8"))
    except Exception as exc:  # noqa: BLE001 - quality gate must fail closed.
        raise SystemExit(f"{locale_id}: compact pack decode failed: {exc}") from exc
    if not isinstance(parsed, dict):
        raise SystemExit(f"{locale_id}: decoded compact pack is not an object")
    return flatten_content(parsed)


def locale_values(locale_id: str) -> dict[str, str]:
    merged: dict[str, str] = {}
    merged.update(flatten_ui(read_object(LOC / "ui" / f"{locale_id}.json")))
    merged.update(flatten_labels(read_object(LOC / "labels" / f"{locale_id}.json")))
    base_content = flatten_content(read_object(LOC / "content" / f"{locale_id}.json"))
    pack_content = compact_pack_content(locale_id)
    collisions = set(base_content) & set(pack_content)
    if collisions:
        raise SystemExit(f"{locale_id}: {len(collisions)} base/pack content collision(s)")
    merged.update(base_content)
    merged.update(pack_content)
    return merged


def token_signature(text: str) -> dict[str, Counter[str]]:
    return {
        "printf": Counter(PRINTF_RE.findall(text)),
        "braces": Counter(BRACE_RE.findall(text)),
        "bbcode": Counter(BBCODE_RE.findall(text)),
    }


def normalized_phrase(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold()
    value = " ".join(value.split())
    return value


def contains_phrase(text: str, phrase: str) -> bool:
    haystack = normalized_phrase(text)
    needle = normalized_phrase(phrase)
    if not needle:
        return False
    start = 0
    while True:
        index = haystack.find(needle, start)
        if index < 0:
            return False
        before_ok = index == 0 or not WORDISH_RE.match(haystack[index - 1])
        after_index = index + len(needle)
        after_ok = after_index == len(haystack) or not WORDISH_RE.match(haystack[after_index])
        if before_ok and after_ok:
            return True
        start = index + 1


def same_visible_text(source: str, target: str) -> bool:
    return normalized_phrase(source) == normalized_phrase(target)


def exact_proper_title(
    source: str,
    target: str,
    glossary_terms: dict[str, Any],
    source_locale: str,
    locale_id: str,
) -> tuple[str, str] | None:
    """Return the matched proper-title id/target when the whole source is a title.

    Proper titles are indivisible glossary units. Once the exact title matches,
    nested lore terms (for example "Trama" inside "Veredas da Trama") must not
    be reinterpreted as independently translatable terminology.
    """
    for term_id, entry in glossary_terms.items():
        if not isinstance(entry, dict) or str(entry.get("class", "")) != "proper_title":
            continue
        source_term = entry.get(source_locale)
        target_term = entry.get(locale_id)
        if not isinstance(source_term, str) or not isinstance(target_term, str):
            continue
        if normalized_phrase(source) != normalized_phrase(source_term):
            continue
        return str(term_id), target_term
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate localization token parity, glossary terminology and UI expansion risks."
    )
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument(
        "--require-terminology",
        action="store_true",
        help="Fail when a translated unit containing a canonical glossary term omits its required target term.",
    )
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="Fail when any launch target is missing any exported source localization unit.",
    )
    args = parser.parse_args()

    manifest = read_object(LOC / "manifest.json")
    glossary = read_object(LOC / "glossary.json")
    catalog = build_catalog()
    source_locale = str(manifest.get("source_locale", "pt_BR"))
    launch_locales = [str(value) for value in manifest.get("launch_locales", [])]
    targets = [locale for locale in launch_locales if locale != source_locale]

    source_units = {
        str(row["key"]): str(row["source"])
        for row in catalog.get("units", [])
        if isinstance(row, dict) and isinstance(row.get("key"), str) and isinstance(row.get("source"), str)
    }
    glossary_terms = glossary.get("terms", {})
    if not isinstance(glossary_terms, dict):
        raise SystemExit("glossary terms must be an object")

    errors: list[str] = []
    warnings: list[str] = []
    locale_reports: dict[str, Any] = {}

    for locale_id in targets:
        translated = locale_values(locale_id)
        unknown = sorted(set(translated) - set(source_units))
        if unknown:
            errors.append(f"{locale_id}: {len(unknown)} translation key(s) outside source catalog")

        token_errors: list[dict[str, Any]] = []
        terminology_errors: list[dict[str, str]] = []
        identical_suspects: list[str] = []
        ui_expansion_risks: list[dict[str, Any]] = []
        covered = 0

        for key, source in source_units.items():
            target = translated.get(key)
            if not isinstance(target, str) or not target.strip():
                continue
            covered += 1
            source_sig = token_signature(source)
            target_sig = token_signature(target)
            for family in ("printf", "braces", "bbcode"):
                if source_sig[family] != target_sig[family]:
                    token_errors.append({
                        "key": key,
                        "family": family,
                        "source": dict(source_sig[family]),
                        "target": dict(target_sig[family]),
                    })

            proper_title = exact_proper_title(source, target, glossary_terms, source_locale, locale_id)
            if proper_title is not None:
                term_id, expected_title = proper_title
                if normalized_phrase(target) != normalized_phrase(expected_title):
                    terminology_errors.append({
                        "key": key,
                        "term_id": term_id,
                        "class": "proper_title",
                        "expected": expected_title,
                        "source_text": source,
                        "target_text": target,
                    })
            else:
                for term_id, entry in glossary_terms.items():
                    if not isinstance(entry, dict):
                        continue
                    source_term = entry.get(source_locale)
                    target_term = entry.get(locale_id)
                    term_class = str(entry.get("class", ""))
                    if not isinstance(source_term, str) or not isinstance(target_term, str):
                        continue
                    if not contains_phrase(source, source_term):
                        continue
                    if source_term == target_term:
                        continue
                    if not contains_phrase(target, target_term):
                        terminology_errors.append({
                            "key": key,
                            "term_id": str(term_id),
                            "class": term_class,
                            "expected": target_term,
                            "source_text": source,
                            "target_text": target,
                        })

            if same_visible_text(source, target) and any(ch.isalpha() for ch in source) and len(source.strip()) >= 4:
                sanctioned_same = any(
                    isinstance(entry, dict)
                    and entry.get(source_locale) == source.strip()
                    and entry.get(locale_id) == target.strip()
                    for entry in glossary_terms.values()
                )
                if not sanctioned_same:
                    identical_suspects.append(key)

            if key.startswith("ui."):
                source_len = len(source.strip())
                target_len = len(target.strip())
                ratio = (target_len / source_len) if source_len else 1.0
                if (source_len >= 12 and ratio > 1.75) or target_len > 180:
                    ui_expansion_risks.append({
                        "key": key,
                        "source_chars": source_len,
                        "target_chars": target_len,
                        "ratio": round(ratio, 3),
                    })

        missing = sorted(set(source_units) - set(translated))
        if token_errors:
            errors.append(f"{locale_id}: {len(token_errors)} token/BBCode parity violation(s)")
        if terminology_errors:
            message = f"{locale_id}: {len(terminology_errors)} glossary terminology violation(s)"
            if args.require_terminology:
                errors.append(message)
            else:
                warnings.append(message)
        if identical_suspects:
            warnings.append(f"{locale_id}: {len(identical_suspects)} source-identical translation suspect(s)")
        if ui_expansion_risks:
            warnings.append(f"{locale_id}: {len(ui_expansion_risks)} UI text expansion risk(s) require render/overflow QA")
        if args.require_complete and missing:
            errors.append(f"{locale_id}: incomplete localization {covered}/{len(source_units)}")

        locale_reports[locale_id] = {
            "covered_units": covered,
            "total_units": len(source_units),
            "coverage": round(covered / len(source_units), 6) if source_units else 1.0,
            "missing_units": len(missing),
            "token_parity_errors": token_errors,
            "terminology_errors": terminology_errors,
            "identical_translation_suspects": identical_suspects,
            "ui_expansion_risks": ui_expansion_risks,
            "unknown_keys": unknown,
            "first_missing_keys": missing[:100],
        }

    report = {
        "schema_version": 2,
        "source_locale": source_locale,
        "targets": targets,
        "source_units": len(source_units),
        "require_terminology": args.require_terminology,
        "require_complete": args.require_complete,
        "proper_title_nested_term_masking": True,
        "locales": locale_reports,
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    for locale_id in targets:
        row = locale_reports[locale_id]
        print(
            "LOCALIZATION_QUALITY %s: covered=%d/%d token_errors=%d terminology_errors=%d identical_suspects=%d ui_expansion_risks=%d"
            % (
                locale_id,
                row["covered_units"],
                row["total_units"],
                len(row["token_parity_errors"]),
                len(row["terminology_errors"]),
                len(row["identical_translation_suspects"]),
                len(row["ui_expansion_risks"]),
            )
        )
    for warning in warnings[:50]:
        print("WARNING:", warning)
    if errors:
        print(f"LOCALIZATION_QUALITY FAIL: {len(errors)} issue group(s)")
        for error in errors[:50]:
            print("ERROR:", error)
        return 1
    print("LOCALIZATION_QUALITY PASS: translated units preserve runtime tokens and glossary terminology")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
