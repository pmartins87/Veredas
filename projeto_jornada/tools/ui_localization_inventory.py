#!/usr/bin/env python3
from __future__ import annotations

import argparse
import ast
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    *(sorted((ROOT / "scenes").glob("*.gd"))),
    ROOT / "ui" / "AccessibilityPanel.gd",
    ROOT / "ui" / "LegalPanel.gd",
]
STRING_RE = re.compile(r'"(?:\\.|[^"\\])*"')
ALPHA_RE = re.compile(r"[A-Za-zÀ-ÿ]")
INTERNAL_PREFIXES = (
    "res://", "user://", "world.", "location.", "character.", "monster.", "boss.",
    "item.", "npc.", "mark.", "debt.", "event.", "ending.", "ability.", "family.",
    "arc.", "pool.", "mode.", "modifier.", "achievement.", "entitlement.", "meta.",
)
TECHNICAL_EXACT = {"mata_fio_verde", "normal", "selected", "compact", "detailed", "cosmetic", "plain"}
LOWER_TOKEN_RE = re.compile(r"^_?[a-z][a-z0-9_]*(?:\.[a-z0-9_]+)*$")
FORMAT_TOKEN_RE = re.compile(r"%(?:\d+\$)?[-+0-9.]*[sdif]|\{[A-Za-z0-9_]+\}")
BB_TAG_RE = re.compile(r"\[/?[A-Za-z_]+(?:=[^\]]+)?\]")
ESCAPE_RE = re.compile(r"\\[nrt\\\"]")
TECHNICAL_LINE_MARKERS = (
    "push_error(", "push_warning(", "printerr(", "file.store_string(",
    "add_theme_constant_override(", ".name =", " name =", "call_deferred(", "_add_toggle(",
)


def decode_literal(token: str) -> str:
    try:
        return ast.literal_eval(token)
    except Exception:
        return token[1:-1]


def language_payload(value: str) -> str:
    cleaned = ESCAPE_RE.sub(" ", value)
    cleaned = FORMAT_TOKEN_RE.sub(" ", cleaned)
    cleaned = BB_TAG_RE.sub(" ", cleaned)
    cleaned = re.sub(r"[•★✓×—–:;,.!?()/%+\-\d\s]+", " ", cleaned)
    return cleaned.strip()


def is_user_facing_candidate(value: str, source_line: str) -> bool:
    if any(marker in source_line for marker in TECHNICAL_LINE_MARKERS):
        return False
    raw = value.strip()
    if not raw or raw.startswith(INTERNAL_PREFIXES) or raw in TECHNICAL_EXACT:
        return False
    if LOWER_TOKEN_RE.fullmatch(raw):
        return False
    payload = language_payload(raw)
    return bool(ALPHA_RE.search(payload))


def scan() -> list[dict]:
    rows: list[dict] = []
    for path in FILES:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for line_no, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            for match in STRING_RE.finditer(line):
                value = decode_literal(match.group(0))
                if not is_user_facing_candidate(value, stripped):
                    continue
                rows.append({
                    "file": str(path.relative_to(ROOT)),
                    "line": line_no,
                    "literal": value,
                    "source_line": stripped,
                })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Inventory hardcoded user-facing string literals in primary GDScript UI surfaces.")
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
        for row in rows[:100]:
            print("UI_LITERAL %s:%d: %s" % (row["file"], row["line"], row["literal"].replace("\n", "\\n")))
        return 1
    print("UI_LOCALIZATION_INVENTORY PASS: report_only require_zero=%s" % str(args.require_zero).lower())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
