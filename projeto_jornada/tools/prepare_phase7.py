#!/usr/bin/env python3
"""Prepare and validate all deterministic Phase 7 assets.

Usage from project root:
    python tools/prepare_phase7.py

The command is expected to return non-zero until every required final illustration
exists. Generated vector systems are deterministic; authored raster illustrations are
never fabricated by this script.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"

STEPS = [
    "build_phase7_manifest.py",
    "generate_system_icons.py",
    "generate_mark_glyphs.py",
]


def run(script: str) -> None:
    result = subprocess.run([sys.executable, str(TOOLS / script)], cwd=ROOT)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def main() -> int:
    for script in STEPS:
        run(script)
    result = subprocess.run([sys.executable, str(TOOLS / "validate_phase7_assets.py")], cwd=ROOT)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
