#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCOPES = [ROOT / "scenes", ROOT / "ui"]
EXCLUDE = {
    ROOT / "ui" / "LocalizationService.gd",
}
PATTERNS = [
    ("property", re.compile(r"\.(?:text|tooltip_text|placeholder_text)\s*=\s*\"([^\"]*[A-Za-zÀ-ÿ][^\"]*)\"")),
    ("item", re.compile(r"\.add_item\(\s*\"([^\"]*[A-Za-zÀ-ÿ][^\"]*)\"")),
]


def scan() -> list[dict]:
    rows: list[dict] = []
    for scope in SCOPES:
        for path in sorted(scope.glob("*.gd")):
            if path in EXCLUDE:
                continue
            text = path.read_text(encoding="utf-8")
            for line_no, line in enumerate(text.splitlines(), 1):
                stripped = line.strip()
                if stripped.startswith("#"):
                    continue
                for kind, regex in PATTERNS:
                    for match in regex.finditer(line):
                        value = match.group(1).strip()
                        if not value:
                            continue
                        rows.append({
                            "file": str(path.relative_to(ROOT)),
                            "line": line_no,
                            "kind": kind,
                            "literal": value,
                        })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Inventory hardcoded user-facing UI literals in GDScript scenes/UI.")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--require-zero", action="store_true")
    args = parser.parse_args()
    rows = scan()
    by_file: dict[str, int] = {}
    for row in rows:
        by_file[row["file"]] = by_file.get(row["file"], 0) + 1
    report = {"candidate_count": len(rows), "by_file": by_file, "candidates": rows}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("UI_LOCALIZATION_INVENTORY: candidates=%d files=%d" % (len(rows), len(by_file)))
    for file_name, count in sorted(by_file.items(), key=lambda item: (-item[1], item[0])):
        print("UI_HARDCODED %s: %d" % (file_name, count))
    if args.require_zero and rows:
        print("UI_LOCALIZATION_INVENTORY FAIL: hardcoded user-facing literals remain")
        return 1
    print("UI_LOCALIZATION_INVENTORY PASS: report_only require_zero=%s" % str(args.require_zero).lower())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
