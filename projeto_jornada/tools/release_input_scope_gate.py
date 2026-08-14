#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import re
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parents[1]
FINGERPRINT_TOOL = ROOT / "tools" / "release_input_fingerprint.py"
RUNTIME_SCAN_SUFFIXES = {".gd", ".tscn", ".tres", ".cfg", ".json", ".gdshader"}
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
    "product/release_signing_identity.json",
    "product/store_listing_google_play.json",
    "product/software_sbom.json",
    "product/android_dependency_inventory.json",
    "product/third_party_notices.json",
}


def load_fingerprint_module() -> ModuleType:
    spec = importlib.util.spec_from_file_location("veredas_release_input_fingerprint", FINGERPRINT_TOOL)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load release_input_fingerprint.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def scan_file(path: Path, found: set[str]) -> None:
    if not path.is_file() or path.suffix.lower() not in RUNTIME_SCAN_SUFFIXES:
        return
    text = path.read_text(encoding="utf-8", errors="ignore")
    for match in PRODUCT_REF_RE.finditer(text):
        found.add(match.group(1))


def runtime_product_references(input_roots: list[Path], single_files: list[Path]) -> set[str]:
    found: set[str] = set()
    product_root = (ROOT / "product").resolve()
    for directory in input_roots:
        if not isinstance(directory, Path) or not directory.exists():
            continue
        if directory.resolve() == product_root:
            continue
        for path in directory.rglob("*"):
            scan_file(path, found)
    for path in single_files:
        if not isinstance(path, Path):
            continue
        try:
            path.resolve().relative_to(product_root)
            continue
        except ValueError:
            pass
        scan_file(path, found)
    return found


def relative_root(path: Path) -> str:
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def main() -> int:
    errors: list[str] = []
    try:
        module = load_fingerprint_module()
    except Exception as exc:  # noqa: BLE001
        print(f"RELEASE_INPUT_SCOPE FAIL: {exc}")
        return 1

    runtime_files_raw = getattr(module, "RUNTIME_PRODUCT_FILES", None)
    control_files_raw = getattr(module, "CONTROL_FILES", None)
    input_roots_raw = getattr(module, "INPUT_ROOTS", None)
    single_files_raw = getattr(module, "SINGLE_FILES", None)
    collect = getattr(module, "collect", None)
    if not isinstance(runtime_files_raw, list):
        errors.append("release fingerprint must expose RUNTIME_PRODUCT_FILES as an explicit list")
        runtime_files_raw = []
    if not isinstance(control_files_raw, list):
        errors.append("release fingerprint must expose CONTROL_FILES as an explicit list")
        control_files_raw = []
    if not isinstance(input_roots_raw, list):
        errors.append("release fingerprint must expose INPUT_ROOTS as an explicit list")
        input_roots_raw = []
    if not isinstance(single_files_raw, list):
        errors.append("release fingerprint must expose SINGLE_FILES as an explicit list")
        single_files_raw = []
    if not callable(collect):
        errors.append("release fingerprint collect() missing")

    declared_runtime_product_files: set[str] = set()
    for path in runtime_files_raw:
        if not isinstance(path, Path):
            errors.append(f"RUNTIME_PRODUCT_FILES contains non-Path value: {path!r}")
            continue
        try:
            relative = relative_root(path)
        except ValueError:
            errors.append(f"runtime product file escapes project root: {path}")
            continue
        if not relative.startswith("product/"):
            errors.append(f"runtime product file must live under product/: {relative}")
            continue
        declared_runtime_product_files.add(relative)
        if not path.is_file():
            errors.append(f"declared runtime product file missing: {relative}")

    declared_control_files: set[str] = set()
    for path in control_files_raw:
        if not isinstance(path, Path):
            errors.append(f"CONTROL_FILES contains non-Path value: {path!r}")
            continue
        try:
            relative = relative_root(path)
        except ValueError:
            errors.append(f"control file escapes project root: {path}")
            continue
        if not relative.startswith("tools/"):
            errors.append(f"critical release control file must live under tools/: {relative}")
            continue
        if relative in declared_control_files:
            errors.append(f"duplicate critical control file: {relative}")
        declared_control_files.add(relative)
        if not path.is_file():
            errors.append(f"declared critical control file missing: {relative}")

    observed_runtime_product_files = runtime_product_references(input_roots_raw, single_files_raw)
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

    single_file_relatives: set[str] = set()
    for path in single_files_raw:
        if not isinstance(path, Path):
            continue
        try:
            single_file_relatives.add(relative_root(path))
        except ValueError:
            errors.append(f"SINGLE_FILES value escapes project root: {path}")
    product_single_files = {path for path in single_file_relatives if path.startswith("product/")}
    if product_single_files != declared_runtime_product_files:
        errors.append(
            "product/ SINGLE_FILES must exactly equal RUNTIME_PRODUCT_FILES: declared=%s single=%s"
            % (sorted(declared_runtime_product_files), sorted(product_single_files))
        )
    missing_controls_from_single = sorted(declared_control_files - single_file_relatives)
    if missing_controls_from_single:
        errors.append(f"CONTROL_FILES absent from SINGLE_FILES fingerprint scope: {missing_controls_from_single}")

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
    missing_controls = sorted(declared_control_files - collected_paths)
    if missing_controls:
        errors.append(f"critical release control file(s) absent from collected release inputs: {missing_controls}")

    forbidden_collected = sorted(FORBIDDEN_EVIDENCE_FILES & collected_paths)
    if forbidden_collected:
        errors.append(f"release evidence leaked into runtime/build fingerprint: {forbidden_collected}")

    if "product/release_archive_manifest.json" in collected_paths:
        errors.append("release archive manifest cannot participate in the fingerprint value it stores")

    if errors:
        print(f"RELEASE_INPUT_SCOPE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1

    print(
        "RELEASE_INPUT_SCOPE PASS: runtime_product_refs=%d control_files=%d collected_inputs=%d scan_roots=%d forbidden_evidence=0 self_reference=0"
        % (
            len(observed_runtime_product_files), len(declared_control_files),
            len(collected_paths), len(input_roots_raw),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
