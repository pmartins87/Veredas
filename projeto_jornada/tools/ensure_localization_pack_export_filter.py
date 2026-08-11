#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESETS = ROOT / "export_presets.cfg"
REQUIRED_FILTERS = (
    "localization/content_packs/*/*.b64part",
    "localization/content_packs/*.json.gz.b64",
)
INCLUDE_RE = re.compile(r'^(include_filter)="(.*)"$', re.MULTILINE)


def parse_filters(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Require compact localization files to be included in Godot exports."
    )
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.apply == args.check:
        raise SystemExit("choose exactly one of --apply or --check")

    text = PRESETS.read_text(encoding="utf-8")
    matches = list(INCLUDE_RE.finditer(text))
    if not matches:
        raise SystemExit("export_presets.cfg has no include_filter entry")

    # export_presets.cfg may contain more than one preset. Every preset that can
    # become a release artifact must retain the compact localization payload, so
    # update/check every include_filter line rather than silently choosing one.
    missing_by_index: list[tuple[int, list[str]]] = []
    rewritten = text
    offset = 0
    for index, match in enumerate(matches):
        current = parse_filters(match.group(2))
        missing = [value for value in REQUIRED_FILTERS if value not in current]
        if missing:
            missing_by_index.append((index, missing))
        if args.apply and missing:
            merged = current + missing
            replacement = 'include_filter="%s"' % ",".join(merged)
            start = match.start() + offset
            end = match.end() + offset
            rewritten = rewritten[:start] + replacement + rewritten[end:]
            offset += len(replacement) - (match.end() - match.start())

    if args.check and missing_by_index:
        for index, missing in missing_by_index:
            print("ERROR: preset include_filter #%d missing %s" % (index, ", ".join(missing)))
        print("LOCALIZATION_PACK_EXPORT_FILTER FAIL: %d preset(s) incomplete" % len(missing_by_index))
        return 1

    if args.apply and rewritten != text:
        PRESETS.write_text(rewritten, encoding="utf-8")

    # Re-read in apply mode so success means the final file, not the intended edit.
    final_text = PRESETS.read_text(encoding="utf-8")
    final_matches = list(INCLUDE_RE.finditer(final_text))
    final_missing = []
    for index, match in enumerate(final_matches):
        current = parse_filters(match.group(2))
        missing = [value for value in REQUIRED_FILTERS if value not in current]
        if missing:
            final_missing.append((index, missing))
    if final_missing:
        print("LOCALIZATION_PACK_EXPORT_FILTER FAIL: patch did not converge")
        return 1

    print(
        "LOCALIZATION_PACK_EXPORT_FILTER PASS: presets=%d required_filters=%d mode=%s"
        % (len(final_matches), len(REQUIRED_FILTERS), "apply" if args.apply else "check")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
