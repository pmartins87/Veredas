#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
LOC = ROOT / "localization"
MANIFEST_PATH = LOC / "manifest.json"
EXPECTED_DATA = {
    "worlds": 12, "locations": 120, "families": 96, "monsters": 300,
    "bosses": 60, "items": 1116, "npcs": 300, "marks": 204,
    "debts": 120, "characters": 36, "abilities": 72, "events": 2544,
    "finals": 36, "pools": 144,
}
PLACEHOLDER_RE = re.compile(r"\{([A-Za-z0-9_]+)\}")


def load_object(path: Path, errors: list[str], label: str) -> dict:
    if not path.is_file():
        errors.append(f"missing {label}: {path.relative_to(ROOT)}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"invalid json {label}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{label} must be a JSON object")
        return {}
    return value


def placeholders(value: str) -> tuple[str, ...]:
    return tuple(sorted(set(PLACEHOLDER_RE.findall(value))))


def collect_source_strings(record_id: str, value, fields: set[str], path: tuple[str, ...], out: dict[str, str]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            child_path = path + (str(key),)
            if str(key) in fields and isinstance(child, str) and child.strip():
                out[f"content.{record_id}." + ".".join(child_path)] = child
            collect_source_strings(record_id, child, fields, child_path, out)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            collect_source_strings(record_id, child, fields, path + (str(index),), out)


def value_at_path(root, path: str):
    current = root
    for part in path.split("."):
        if isinstance(current, dict):
            if part not in current:
                return None, False
            current = current[part]
        elif isinstance(current, list):
            if not part.isdigit():
                return None, False
            index = int(part)
            if index < 0 or index >= len(current):
                return None, False
            current = current[index]
        else:
            return None, False
    return current, True


def main() -> int:
    errors: list[str] = []
    manifest = load_object(MANIFEST_PATH, errors, "manifest")
    source_locale = str(manifest.get("source_locale", ""))
    fallback_locale = str(manifest.get("fallback_locale", ""))
    launch_locales = [str(v) for v in manifest.get("launch_locales", []) if isinstance(v, str)]
    target_locales = [v for v in launch_locales if v != source_locale]
    locale_meta = manifest.get("locales", {}) if isinstance(manifest.get("locales", {}), dict) else {}
    required_keys = [str(v) for v in manifest.get("ui_required_keys", []) if isinstance(v, str)]
    overlay_fields = {str(v) for v in manifest.get("content_overlay_fields", []) if isinstance(v, str)}
    policy = manifest.get("policy", {}) if isinstance(manifest.get("policy", {}), dict) else {}

    if source_locale != "pt_BR" or fallback_locale != source_locale:
        errors.append("11.5 requires pt_BR as source and fallback locale")
    if launch_locales != ["pt_BR", "en", "es_419"]:
        errors.append(f"unexpected launch locale set/order: {launch_locales}")
    if len(set(launch_locales)) != 3:
        errors.append("launch locales must be unique")
    for locale_id in launch_locales:
        meta = locale_meta.get(locale_id, {})
        if not isinstance(meta, dict) or not str(meta.get("native_name", "")).strip():
            errors.append(f"missing native locale name: {locale_id}")
    if len(required_keys) < 14 or len(set(required_keys)) != len(required_keys):
        errors.append(f"expected at least 14 unique required UI keys, got {len(required_keys)}")
    if not overlay_fields:
        errors.append("content overlay field whitelist is empty")
    for key in [
        "canonical_content_immutable", "runtime_rules_use_source_records",
        "presentation_uses_stable_id_overlays", "missing_translation_falls_back_to_source",
    ]:
        if policy.get(key) is not True:
            errors.append(f"localization policy missing/false: {key}")
    if str(policy.get("translation_completeness_gate_step", "")) != "11.6":
        errors.append("translation completeness must remain assigned to 11.6")

    records: list[dict] = []
    records_by_id: dict[str, dict] = {}
    for name, expected in EXPECTED_DATA.items():
        path = DATA / f"{name}.json"
        if not path.is_file():
            errors.append(f"missing generated data: {path.relative_to(ROOT)}")
            continue
        try:
            rows = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"invalid generated data {name}: {exc}")
            continue
        if not isinstance(rows, list):
            errors.append(f"generated data {name} is not a list")
            continue
        if len(rows) != expected:
            errors.append(f"{name}: expected {expected}, got {len(rows)}")
        for row in rows:
            if not isinstance(row, dict):
                errors.append(f"{name}: non-object record")
                continue
            record_id = str(row.get("id", ""))
            if not record_id:
                errors.append(f"{name}: missing stable id")
                continue
            if record_id in records_by_id:
                errors.append(f"duplicate stable id: {record_id}")
            records_by_id[record_id] = row
            records.append(row)

    if len(records) != 5160 or len(records_by_id) != 5160:
        errors.append(f"expected 5160 stable records, got records={len(records)} ids={len(records_by_id)}")

    source_strings: dict[str, str] = {}
    for record in records:
        collect_source_strings(str(record.get("id", "")), record, overlay_fields, (), source_strings)
    if len(source_strings) < 5160:
        errors.append(f"localizable source inventory unexpectedly small: {len(source_strings)}")

    ui_catalogs: dict[str, dict] = {}
    content_catalogs: dict[str, dict] = {}
    for locale_id in launch_locales:
        ui_catalogs[locale_id] = load_object(LOC / "ui" / f"{locale_id}.json", errors, f"ui catalog {locale_id}")
        content_catalogs[locale_id] = load_object(LOC / "content" / f"{locale_id}.json", errors, f"content catalog {locale_id}")

    source_ui = ui_catalogs.get(source_locale, {})
    translated_required = 0
    for key in required_keys:
        source_value = source_ui.get(key)
        if not isinstance(source_value, str) or not source_value.strip():
            errors.append(f"source UI key missing/blank: {key}")
            continue
        source_placeholders = placeholders(source_value)
        for locale_id in launch_locales:
            value = ui_catalogs.get(locale_id, {}).get(key)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"required UI key missing/blank: {locale_id}:{key}")
                continue
            if placeholders(value) != source_placeholders:
                errors.append(f"placeholder mismatch {locale_id}:{key}")
            if locale_id != source_locale:
                translated_required += 1

    probe_key = "architecture.source_only_probe"
    if not isinstance(source_ui.get(probe_key), str) or not source_ui.get(probe_key):
        errors.append("source-only fallback probe is missing")
    for locale_id in target_locales:
        if probe_key in ui_catalogs.get(locale_id, {}):
            errors.append(f"fallback probe must be absent from target catalog: {locale_id}")

    overlay_entries = 0
    nested_overlay_entries = 0
    overlay_entries_by_locale = {locale_id: 0 for locale_id in target_locales}
    nested_by_locale = {locale_id: 0 for locale_id in target_locales}
    source_overlay = content_catalogs.get(source_locale, {})
    if source_overlay:
        errors.append("source content overlay must stay empty; pt_BR canonical data is authoritative")
    for locale_id in launch_locales:
        catalog = content_catalogs.get(locale_id, {})
        for record_id, overlay in catalog.items():
            source_record = records_by_id.get(record_id)
            if source_record is None:
                errors.append(f"overlay references unknown stable id: {locale_id}:{record_id}")
                continue
            if not isinstance(overlay, dict):
                errors.append(f"overlay record is not an object: {locale_id}:{record_id}")
                continue
            for field_path, value in overlay.items():
                path = str(field_path)
                terminal = path.split(".")[-1]
                if terminal not in overlay_fields:
                    errors.append(f"overlay terminal field not presentation-whitelisted: {locale_id}:{record_id}:{path}")
                source_value, found = value_at_path(source_record, path)
                if not found:
                    errors.append(f"overlay path does not exist in canonical record: {locale_id}:{record_id}:{path}")
                elif not isinstance(source_value, str):
                    errors.append(f"overlay path does not target a string: {locale_id}:{record_id}:{path}")
                if not isinstance(value, str) or not value.strip():
                    errors.append(f"overlay value must be non-empty string: {locale_id}:{record_id}:{path}")
                if locale_id != source_locale:
                    overlay_entries += 1
                    overlay_entries_by_locale[locale_id] += 1
                    if "." in path:
                        nested_overlay_entries += 1
                        nested_by_locale[locale_id] += 1

    # The original 11.5 bootstrap used exactly two translations per target as an
    # architecture probe. Production localization grows continuously, so the
    # invariant is now monotonic: never regress below the bootstrap and retain
    # nested-path coverage while every overlay remains validated against source.
    for locale_id in target_locales:
        if overlay_entries_by_locale[locale_id] < 2:
            errors.append(f"target overlay coverage regressed below architecture bootstrap: {locale_id}:{overlay_entries_by_locale[locale_id]}")
        if nested_by_locale[locale_id] < 1:
            errors.append(f"target lost nested overlay coverage: {locale_id}")
    if overlay_entries < 4:
        errors.append(f"target overlay total regressed below architecture bootstrap: {overlay_entries}")
    if nested_overlay_entries < 2:
        errors.append(f"nested overlay total regressed below architecture bootstrap: {nested_overlay_entries}")

    aliases = manifest.get("aliases", {}) if isinstance(manifest.get("aliases", {}), dict) else {}
    for alias in ["pt-BR", "en-US", "es-MX"]:
        if alias not in aliases:
            errors.append(f"required locale alias missing: {alias}")

    if errors:
        print(f"LOCALIZATION_INVENTORY FAIL: {len(errors)} issue(s)")
        for error in errors[:100]:
            print("ERROR:", error)
        return 1

    print(
        "LOCALIZATION_INVENTORY PASS: 11.5 records=5160 source_strings=%d launch_locales=3 ui_required=%d translated_required=%d overlay_entries=%d nested_overlays=%d per_target=%s"
        % (len(source_strings), len(required_keys), translated_required, overlay_entries, nested_overlay_entries, str(overlay_entries_by_locale))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
