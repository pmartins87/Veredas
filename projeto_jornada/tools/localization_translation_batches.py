#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from collections import defaultdict
from pathlib import Path

from export_localization_catalog import build_catalog
from localization_pack_certification import PACK_ROOT, flatten_overlay, launch_targets, read_compact_pack

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected JSON object: {path}")
    return value


def translated_keys(locale_id: str) -> set[str]:
    base = flatten_overlay(
        read_object(LOC / "content" / f"{locale_id}.json"),
        f"{locale_id}:base",
    )
    translated = set(base)

    single_pack = PACK_ROOT / f"{locale_id}.json.gz.b64"
    multipart_pack = PACK_ROOT / locale_id
    if single_pack.exists() or multipart_pack.exists():
        try:
            pack_catalog, _ = read_compact_pack(locale_id)
            pack = flatten_overlay(pack_catalog, f"{locale_id}:pack")
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            raise SystemExit(f"{locale_id}: compact pack cannot be incorporated into translation batches: {exc}") from exc
        collisions = translated & set(pack)
        if collisions:
            raise SystemExit(
                f"{locale_id}: base/compact-pack collision prevents reliable remaining-unit calculation: {len(collisions)}"
            )
        translated.update(pack)
    return translated


def pack_batches(rows: list[dict], max_units: int, prefix: str) -> list[dict]:
    record_groups: list[list[dict]] = []
    current_id = None
    current: list[dict] = []
    for row in rows:
        record_id = str(row.get("record_id", ""))
        if current and record_id != current_id:
            record_groups.append(current)
            current = []
        current_id = record_id
        current.append(row)
    if current:
        record_groups.append(current)

    batches: list[dict] = []
    pending: list[dict] = []
    for group in record_groups:
        if pending and len(pending) + len(group) > max_units:
            batches.append({"units": pending})
            pending = []
        if len(group) > max_units:
            if pending:
                batches.append({"units": pending})
                pending = []
            for start in range(0, len(group), max_units):
                batches.append({"units": group[start:start + max_units]})
        else:
            pending.extend(group)
    if pending:
        batches.append({"units": pending})

    for index, batch in enumerate(batches, start=1):
        units = batch["units"]
        batch["batch_id"] = f"{prefix}-{index:03d}"
        batch["unit_count"] = len(units)
        batch["record_count"] = len({str(row.get("record_id", "")) for row in units})
        batch["first_key"] = str(units[0]["key"])
        batch["last_key"] = str(units[-1]["key"])
    return batches


def memory_candidates(rows: list[dict]) -> list[dict]:
    by_source: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        by_source[str(row.get("source", ""))].append(row)
    candidates: list[dict] = []
    for source, occurrences in by_source.items():
        if len(occurrences) < 2:
            continue
        candidates.append({
            "source": source,
            "occurrences": len(occurrences),
            "keys": [str(row["key"]) for row in occurrences],
            "paths": sorted({str(row.get("path", "")) for row in occurrences}),
        })
    candidates.sort(key=lambda row: (-int(row["occurrences"]), str(row["source"])))
    return candidates


def build_payload(max_units: int) -> dict:
    if max_units < 50:
        raise SystemExit("max-units must be >= 50")
    targets = launch_targets()
    catalog = build_catalog()
    content = [row for row in catalog["units"] if str(row.get("key", "")).startswith("content.")]
    content.sort(key=lambda row: (str(row.get("record_id", "")), str(row.get("path", ""))))
    all_keys = {str(row["key"]) for row in content}
    source_key_stream = "\n".join(sorted(all_keys)).encode("utf-8")

    locales: dict[str, dict] = {}
    pending_sets: dict[str, set[str]] = {}
    for locale_id in targets:
        done = translated_keys(locale_id) & all_keys
        pending_rows = [row for row in content if str(row["key"]) not in done]
        pending_keys = {str(row["key"]) for row in pending_rows}
        pending_sets[locale_id] = pending_keys
        unique_sources = {str(row.get("source", "")) for row in pending_rows}
        candidates = memory_candidates(pending_rows)
        repeated_occurrences = sum(int(row["occurrences"]) - 1 for row in candidates)
        pending_stream = "\n".join(sorted(pending_keys)).encode("utf-8")
        batches = pack_batches(pending_rows, max_units, f"{locale_id}-remaining")
        locales[locale_id] = {
            "translated_units": len(done),
            "remaining_units": len(pending_rows),
            "remaining_unique_source_strings": len(unique_sources),
            "translation_memory_candidate_groups": len(candidates),
            "translation_memory_repeat_occurrences": repeated_occurrences,
            "remaining_key_sha256": hashlib.sha256(pending_stream).hexdigest(),
            "batch_count": len(batches),
            "batches": batches,
            "translation_memory_candidates": candidates,
        }

    common_pending = set.intersection(*(pending_sets[locale_id] for locale_id in targets))
    any_pending = set.union(*(pending_sets[locale_id] for locale_id in targets))
    return {
        "schema_version": 3,
        "source_locale": catalog["source_locale"],
        "target_locales": list(targets),
        "content_unit_count": len(content),
        "max_units_per_batch": max_units,
        "source_key_sha256": hashlib.sha256(source_key_stream).hexdigest(),
        "common_remaining_units": len(common_pending),
        "union_remaining_units": len(any_pending),
        "locales": locales,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create deterministic remaining-only translation batches for manifest launch targets, incorporating compact packs."
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--max-units", type=int, default=400)
    args = parser.parse_args()
    payload = build_payload(args.max_units)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    summary = []
    for locale_id in payload["target_locales"]:
        row = payload["locales"][locale_id]
        summary.append(
            "%s=%d_done/%d_remaining/%d_batches/%d_unique_sources/%d_repeat_savings"
            % (
                locale_id,
                row["translated_units"], row["remaining_units"], row["batch_count"],
                row["remaining_unique_source_strings"], row["translation_memory_repeat_occurrences"],
            )
        )
    print(
        "LOCALIZATION_BATCHES PASS: targets=%s content_units=%d max_units=%d common_remaining=%d %s sha256=%s"
        % (
            ",".join(payload["target_locales"]),
            payload["content_unit_count"],
            payload["max_units_per_batch"],
            payload["common_remaining_units"],
            " ".join(summary),
            payload["source_key_sha256"][:12],
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
