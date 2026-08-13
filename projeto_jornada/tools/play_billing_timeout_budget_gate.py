#!/usr/bin/env python3
from __future__ import annotations

import ast
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MOBILE_CONTRACT = ROOT / "mobile" / "play_billing_contract.json"
BACKEND_CONTRACT = ROOT / "backend" / "play_purchase_verifier" / "backend_contract.json"
CLIENT = ROOT / "mobile" / "PlayPurchaseVerificationClient.gd"
GATEWAY = ROOT / "backend" / "play_purchase_verifier" / "google_play_gateway.py"
MIN_MARGIN_SECONDS = 5.0


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected object: {path}")
    return value


def py_number(text: str, name: str) -> float:
    tree = ast.parse(text)
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if isinstance(target, ast.Name) and target.id == name:
            value = ast.literal_eval(node.value)
            if type(value) not in {int, float}:
                break
            return float(value)
    raise ValueError(f"missing numeric Python constant: {name}")


def gd_number(text: str, name: str) -> float:
    match = re.search(rf"^const\s+{re.escape(name)}\s*:=\s*([0-9]+(?:\.[0-9]+)?)\s*$", text, re.MULTILINE)
    if not match:
        raise ValueError(f"missing numeric GDScript constant: {name}")
    return float(match.group(1))


def close(a: float, b: float) -> bool:
    return abs(a - b) <= 1e-9


def main() -> int:
    errors: list[str] = []
    try:
        mobile = read_json(MOBILE_CONTRACT)
        backend = read_json(BACKEND_CONTRACT)
        client_text = CLIENT.read_text(encoding="utf-8")
        gateway_text = GATEWAY.read_text(encoding="utf-8")
        mobile_timeout_code = gd_number(client_text, "DEFAULT_TIMEOUT_SECONDS")
        attempts = int(py_number(gateway_text, "MAX_ATTEMPTS"))
        connect = py_number(gateway_text, "CONNECT_TIMEOUT_SECONDS")
        read = py_number(gateway_text, "READ_TIMEOUT_SECONDS")
        backoff = py_number(gateway_text, "BACKOFF_BASE_SECONDS")
    except (OSError, ValueError, json.JSONDecodeError, SyntaxError) as exc:
        print(f"PLAY_BILLING_TIMEOUT_BUDGET FAIL: {exc}")
        return 1

    backend_budget = backend.get("timeout_budget", {})
    mobile_budget = mobile.get("verification_boundary", {}).get("timeout_budget", {})
    if not isinstance(backend_budget, dict) or not isinstance(mobile_budget, dict):
        print("PLAY_BILLING_TIMEOUT_BUDGET FAIL: timeout contract missing")
        return 1

    max_calls = int(backend_budget.get("maximum_google_calls_in_acknowledgement_path", 0))
    if attempts < 1:
        errors.append("MAX_ATTEMPTS must be >= 1")
    if min(connect, read, backoff) < 0:
        errors.append("timeout/backoff values cannot be negative")
    if max_calls != 3:
        errors.append("acknowledgement path must account for fetch + acknowledge + refetch")

    backoff_sum = sum(backoff * (2**attempt) for attempt in range(max(0, attempts - 1)))
    per_call_upper = attempts * (connect + read) + backoff_sum
    google_io_upper = per_call_upper * max_calls
    margin = mobile_timeout_code - google_io_upper

    expected_backend = {
        "mobile_http_timeout_seconds": mobile_timeout_code,
        "google_max_attempts_per_call": attempts,
        "google_connect_timeout_seconds": connect,
        "google_read_timeout_seconds": read,
        "retry_backoff_base_seconds": backoff,
        "conservative_google_io_upper_bound_seconds": google_io_upper,
        "nominal_mobile_margin_seconds": margin,
    }
    for key, value in expected_backend.items():
        actual = backend_budget.get(key)
        try:
            actual_number = float(actual)
        except (TypeError, ValueError):
            errors.append(f"backend timeout_budget.{key} missing/non-numeric")
            continue
        if not close(actual_number, float(value)):
            errors.append(f"backend timeout_budget.{key} drift: contract={actual_number} code={value}")

    for key, value in {
        "mobile_http_timeout_seconds": mobile_timeout_code,
        "backend_google_io_upper_bound_seconds": google_io_upper,
        "minimum_nominal_margin_seconds": margin,
    }.items():
        actual = mobile_budget.get(key)
        try:
            actual_number = float(actual)
        except (TypeError, ValueError):
            errors.append(f"mobile timeout_budget.{key} missing/non-numeric")
            continue
        if not close(actual_number, float(value)):
            errors.append(f"mobile timeout_budget.{key} drift: contract={actual_number} code={value}")

    if margin < MIN_MARGIN_SECONDS:
        errors.append(f"mobile timeout margin too small: {margin:.2f}s < {MIN_MARGIN_SECONDS:.2f}s")
    if google_io_upper >= mobile_timeout_code:
        errors.append("backend Google-I/O budget must remain below mobile request timeout")

    if errors:
        print(f"PLAY_BILLING_TIMEOUT_BUDGET FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1

    print(
        "PLAY_BILLING_TIMEOUT_BUDGET PASS: client=%.2fs google_io_upper=%.2fs margin=%.2fs attempts=%d calls=%d"
        % (mobile_timeout_code, google_io_upper, margin, attempts, max_calls)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
