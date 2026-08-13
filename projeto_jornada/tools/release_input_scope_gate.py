#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import re
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parents[1]
FINGERPRINT_TOOL = ROOT / "tools" / "release_input_fingerprint.py"
RUNTIME_SCAN_ROOTS = [ROOT / "core", ROOT / "ui", ROOT / "scenes", ROOT / "mobile"]
RUNTIME_SCAN_SUFFIXES = {".gd", ".tscn", ".tres", ".cfg", ".json"}
PRODUCT_REF_RE = re.compile(r"res://(product/[A-Za-z0-9_.\-/]+)")
FORBIDDEN_EVIDENCE_FILES = {
    "product/continuity_support_contract.json",
    "product/final_release_contract.json",
    "product/platform_compliance.json",
    "product/play_test_rollout_plan.json",
    "product/privacy_data_safety.json",
    "product/release_archive_manifest.json",
    "product/release_candidate_final_contract.json",
    "product/release_completion_record_schema.json",
    "product/release_provenance.json",
    "product/store_listing_google_play.json",
    "product/software_sbom.json",
    "product/android_dependency_inventory.json",
}


def load_fingerprint_module() -> ModuleType:
    spec = importlib.util.spec_from_file_location("veredas_release_input_fingerprint", FINGERPRINT_TOOL)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load release_input_fingerprint.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def runtime_product_references() -> set[str]:
    found: set[str] = set()
    for directory in RUNTIME_SCAN_ROOTS:
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in RUNTIME_SCAN_SUFFIXES:
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            for match in PRODUCT_REF_RE.finditer(text):
                found.add(match.group(1))
    return found


def main() -> int:
    errors: list[str] = []
    try:
        module = load_fingerprint_module()
    except Exception as exc:  # noqa: BLE001
        print(f"RELEASE_INPUT_SCOPE FAIL: {exc}")
        return 1

    runtime_files_raw = getattr(module, "RUNTIME_PRODUCT_FILES", None)
    input_roots_raw = getattr(module, "INPUT_ROOTS", None)
    collect = getattr(module, "collect", None)
    if not isinstance(runtime_files_raw, list):
        errors.append("release fingerprint must expose RUNTIME_PRODUCT_FILES as an explicit list")
        runtime_files_raw = []
    if not isinstance(input_roots_raw, list):
        errors.append("release fingerprint must expose INPUT_ROOTS as an explicit list")
        input_roots_raw = []
    if not callable(collect):
        errors.append("release fingerprint collect() missing")

    declared_runtime_product_files: set[str] = set()
    for path in runtime_files_raw:
        if not isinstance(path, Path):
            errors.append(f"RUNTIME_PRODUCT_FILES contains non-Path value: {path!r}")
            continue
        try:
            relative = path.resolve().relative_to(ROOT.resolve()).as_posix()
        except ValueError:
            errors.append(f"runtime product file escapes repository root: {path}")
            continue
        if not relative.startswith("product/"):
            errors.append(f"runtime product file must live under product/: {relative}")
            continue
        declared_runtime_product_files.add(relative)
        if not path.is_file():
            errors.append(f"declared runtime product file missing: {relative}")

    observed_runtime_product_files = runtime_product_references()
    if observed_runtime_product_files != declared_runtime_product_files:
        missing = sorted(observed_runtime_product_files - declared_runtime_product_files)
        stale = sorted(declared_runtime_product_files - observed_runtime_product_files)
        if missing:
            errors.append(f"runtime product reference(s) missing from release fingerprint scope: {missing}")
        if stale:
            errors.append(f"declared runtime product fingerprint file(s) are not referenced by runtime scan: {stale}")

    product_root = (ROOT / "product").resolve()
    for root in input_roots_raw:
        if isinstance(root, Path) and root.resolve() == product_root:
            errors.append("whole product/ directory must never be an INPUT_ROOT; release evidence would create fingerprint self-reference")

    collected_paths: set[str] = set()
    if callable(collect):
        try:
            rows = collect()
            for row in rows:
                if isinstance(row, dict):
                    collected_paths.add(str(row.get("path", "")))
        except Exception as exc:  # noqa: BLE001
            errors.append(f"release fingerprint collect() failed: {exc}")

    missing_runtime = sorted(declared_runtime_product_files - collected_paths)
    if missing_runtime:
        errors.append(f"declared runtime product file(s) absent from collected release inputs: {missing_runtime}")

    forbidden_collected = sorted(FORBIDDEN_EVIDENCE_FILES & collected_paths)
    if forbidden_collected:
        errors.append(f"release evidence leaked into runtime/build fingerprint: {forbidden_collected}")

    archive_manifest = "product/release_archive_manifest.json"
    if archive_manifest in collected_paths:
        errors.append("release archive manifest cannot participate in the fingerprint value it stores")

    if errors:
        print(f"RELEASE_INPUT_SCOPE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1

    print(
        "RELEASE_INPUT_SCOPE PASS: runtime_product_refs=%d collected_inputs=%d forbidden_evidence=0 self_reference=0"
        % (len(observed_runtime_product_files), len(collected_paths))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
