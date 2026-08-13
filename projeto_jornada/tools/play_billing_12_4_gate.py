#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPONENT_GATES = [
    ROOT / "tools" / "play_billing_release_gate.py",
    ROOT / "tools" / "play_billing_backend_gate.py",
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the complete Google Play Billing 12.4 client + backend gate bundle.")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()

    mode_arg = ["--release"] if args.release else []
    for gate in COMPONENT_GATES:
        result = subprocess.run(
            [sys.executable, str(gate), *mode_arg],
            cwd=ROOT,
            check=False,
        )
        if result.returncode != 0:
            print(f"PLAY_BILLING_12_4_GATE FAIL: component={gate.name} code={result.returncode}")
            return result.returncode

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(f"PLAY_BILLING_12_4_GATE PASS: mode={mode} client_runtime=1 backend=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
