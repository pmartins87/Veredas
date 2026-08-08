#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "data" / "characters.json"


def main() -> None:
    rows = json.loads(PATH.read_text(encoding="utf-8"))
    if len(rows) != 36:
        raise SystemExit(f"Expected 36 characters, got {len(rows)}")
    for row in rows:
        # Horizontal metaprogression contract: unlocking another Andarilho never
        # grants a larger raw health/vigor pool. Learning curves live in posture,
        # guard and signature-resource efficiency instead.
        row["base_health"] = 16
        row["base_vigor"] = 8
    PATH.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print("CHARACTER_HORIZONTAL_BUDGET PASS: all 36 use 16 health / 8 vigor")


if __name__ == "__main__":
    main()
