#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPONENT_GATES = [
    (ROOT / "tools" / "play_billing_release_gate.py", True),
    (ROOT / "tools" / "play_billing_backend_gate.py", True),
    (ROOT / "tools" / "play_billing_timeout_budget_gate.py", False),
    (ROOT / "tools" / "play_billing_local_reference_gate.py", False),
]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run the complete Google Play Billing 12.4 client + backend + timeout + local-reference gate bundle."
    )
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()

    for gate, accepts_release in COMPONENT_GATES:
        command = [sys.executable, str(gate)]
        if args.release and accepts_release:
            command.append("--release")
        result = subprocess.run(command, cwd=ROOT, check=False)
        if result.returncode != 0:
            print(f"PLAY_BILLING_12_4_GATE FAIL: component={gate.name} code={result.returncode}")
            return result.returncode

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        f"PLAY_BILLING_12_4_GATE PASS: mode={mode} client_runtime=1 backend=1 timeout_budget=1 local_reference=1"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
