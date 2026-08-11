#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from export_localization_catalog import build_catalog


def build_batches(max_units: int) -> dict:
    if max_units < 50:
        raise SystemExit("max-units must be >= 50")
    catalog = build_catalog()
    content = [row for row in catalog["units"] if str(row.get("key", "")).startswith("content.")]
    content.sort(key=lambda row: (str(row.get("record_id", "")), str(row.get("path", ""))))

    record_groups: list[list[dict]] = []
    current_id = None
    current: list[dict] = []
    for row in content:
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

    key_stream = "\n".join(str(row["key"]) for row in content).encode("utf-8")
    for index, batch in enumerate(batches, start=1):
        units = batch["units"]
        batch["batch_id"] = f"content-{index:03d}"
        batch["unit_count"] = len(units)
        batch["first_key"] = str(units[0]["key"])
        batch["last_key"] = str(units[-1]["key"])
    return {
        "schema_version": 1,
        "source_locale": catalog["source_locale"],
        "content_unit_count": len(content),
        "max_units_per_batch": max_units,
        "batch_count": len(batches),
        "source_key_sha256": hashlib.sha256(key_stream).hexdigest(),
        "batches": batches,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Create deterministic, record-preserving translation batches.")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--max-units", type=int, default=400)
    args = parser.parse_args()
    payload = build_batches(args.max_units)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        "LOCALIZATION_BATCHES PASS: content_units=%d batches=%d max_units=%d sha256=%s"
        % (payload["content_unit_count"], payload["batch_count"], payload["max_units_per_batch"], payload["source_key_sha256"][:12])
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
