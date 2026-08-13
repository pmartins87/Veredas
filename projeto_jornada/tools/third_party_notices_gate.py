#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
NOTICES = ROOT / "product" / "third_party_notices.json"
PROVENANCE = ROOT / "product" / "release_provenance.json"
BACKEND_SBOM = ROOT / "product" / "software_sbom.json"
ANDROID_INVENTORY = ROOT / "product" / "android_dependency_inventory.json"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_pypi(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def pypi_key(name: str, version: str) -> str:
    return f"pypi:{canonical_pypi(name)}@{version}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate third-party license/notice coverage for Veredas release dependencies.")
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    try:
        notices = read_json(NOTICES)
        provenance = read_json(PROVENANCE)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"THIRD_PARTY_NOTICES FAIL: {exc}")
        return 1

    if notices.get("schema_version") != 1 or notices.get("roadmap_step") != "12.9":
        errors.append("third-party notices schema/roadmap_step invalid")
    policy = notices.get("policy", {})
    if not isinstance(policy, dict):
        errors.append("third-party notice policy missing")
        policy = {}
    for key in (
        "every_final_runtime_or_redistributed_component_must_be_covered",
        "license_identification_is_not_final_review",
        "archived_files_must_be_versioned_and_sha256_bound",
        "license_or_notice_obligations_must_not_be_inferred_from_package_name_only",
        "final_notice_bundle_must_match_exact_release_dependency_inventories",
    ):
        if policy.get(key) is not True:
            errors.append(f"third-party notice policy flag must remain true: {key}")

    rows = notices.get("components", [])
    if not isinstance(rows, list):
        errors.append("third-party notices components must be an array")
        rows = []
    by_key: dict[str, dict[str, Any]] = {}
    by_provenance: dict[str, dict[str, Any]] = {}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append(f"notice component {index} is not an object")
            continue
        component_key = str(row.get("component_key", "")).strip()
        provenance_id = str(row.get("provenance_id", "")).strip()
        if not component_key or component_key in by_key:
            errors.append(f"notice component_key missing/duplicate: {component_key!r}")
            continue
        by_key[component_key] = row
        if provenance_id:
            if provenance_id in by_provenance:
                errors.append(f"notice provenance_id duplicate: {provenance_id}")
            else:
                by_provenance[provenance_id] = row
        if not str(row.get("name", "")).strip() or not str(row.get("version", "")).strip():
            errors.append(f"notice component name/version missing: {component_key}")
        if not str(row.get("license_id", "")).strip():
            errors.append(f"notice component license id missing: {component_key}")
        archived_files = row.get("archived_files", [])
        if not isinstance(archived_files, list):
            errors.append(f"notice archived_files must be an array: {component_key}")
            continue
        if args.release:
            if row.get("reviewed") is not True:
                errors.append(f"notice component final review incomplete: {component_key}")
            if row.get("coverage_status") != "complete":
                errors.append(f"notice component coverage is not complete: {component_key}")
            if not archived_files:
                errors.append(f"notice component has no archived license/notice files: {component_key}")
        for file_row in archived_files:
            if not isinstance(file_row, dict):
                errors.append(f"notice archived file row invalid: {component_key}")
                continue
            kind = str(file_row.get("kind", ""))
            relative = str(file_row.get("path", ""))
            expected_hash = str(file_row.get("sha256", "")).lower()
            if kind not in {"license", "notice", "copyright", "attribution"}:
                errors.append(f"notice archived file kind invalid: {component_key}:{kind}")
            if not relative.startswith("product/third_party_licenses/"):
                errors.append(f"notice archived file must be versioned under product/third_party_licenses/: {component_key}:{relative}")
                continue
            path = ROOT / relative
            if not path.is_file():
                errors.append(f"notice archived file missing: {component_key}:{relative}")
                continue
            if not SHA256_RE.fullmatch(expected_hash) or sha256_file(path) != expected_hash:
                errors.append(f"notice archived file SHA-256 mismatch: {component_key}:{relative}")

    software = provenance.get("software_inventory", {})
    known = software.get("known_components", []) if isinstance(software, dict) else []
    if not isinstance(known, list):
        errors.append("release provenance known software list missing")
        known = []
    for component in known:
        if not isinstance(component, dict):
            continue
        provenance_id = str(component.get("id", ""))
        row = by_provenance.get(provenance_id)
        if row is None:
            errors.append(f"known release software lacks notice row: {provenance_id}")
            continue
        if str(row.get("version", "")) != str(component.get("version", "")):
            errors.append(f"notice/provenance version mismatch: {provenance_id}")
        if str(row.get("license_id", "")) != str(component.get("license_id", "")):
            errors.append(f"notice/provenance license mismatch: {provenance_id}")

    backend_missing: list[str] = []
    if BACKEND_SBOM.is_file():
        try:
            sbom = read_json(BACKEND_SBOM)
            components = sbom.get("components", [])
            if not isinstance(components, list):
                errors.append("backend SBOM components missing for notice coverage")
                components = []
            for component in components:
                if not isinstance(component, dict):
                    continue
                key = pypi_key(str(component.get("normalized_name", "")), str(component.get("version", "")))
                if key not in by_key:
                    backend_missing.append(key)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(f"cannot audit backend SBOM notice coverage: {exc}")
    else:
        warnings.append("final backend SBOM absent; transitive notice coverage cannot yet be frozen")

    android_missing: list[str] = []
    if ANDROID_INVENTORY.is_file():
        try:
            android = read_json(ANDROID_INVENTORY)
            components = android.get("components", [])
            if not isinstance(components, list):
                errors.append("Android dependency inventory components missing for notice coverage")
                components = []
            for component in components:
                if not isinstance(component, dict) or component.get("third_party") is False:
                    continue
                key = str(component.get("component_key", "")).strip()
                if not key:
                    errors.append("Android third-party dependency lacks component_key")
                elif key not in by_key:
                    android_missing.append(key)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(f"cannot audit Android notice coverage: {exc}")
    else:
        warnings.append("final Android dependency inventory absent; Android notice coverage cannot yet be frozen")

    if backend_missing:
        errors.append(f"backend SBOM component(s) lack notice coverage: {backend_missing[:50]}")
    if android_missing:
        errors.append(f"Android dependency component(s) lack notice coverage: {android_missing[:50]}")

    backend_status = notices.get("backend_transitive_coverage", {})
    android_status = notices.get("android_dependency_coverage", {})
    if args.release:
        if not isinstance(backend_status, dict) or backend_status.get("status") != "complete" or backend_status.get("missing_component_count") != 0:
            errors.append("backend transitive notice coverage is not recorded complete")
        if not isinstance(android_status, dict) or android_status.get("status") != "complete" or android_status.get("missing_component_count") != 0:
            errors.append("Android notice coverage is not recorded complete")
        if notices.get("finalized") is not True:
            errors.append("third-party notices manifest is not finalized")
        if notices.get("formal_status") != "certified" or notices.get("pass_recorded") is not True:
            errors.append("third-party notices manifest is not certified")
    else:
        pending_reviews = sum(1 for row in rows if isinstance(row, dict) and row.get("reviewed") is not True)
        if pending_reviews:
            warnings.append(f"{pending_reviews} known notice component review(s) pending")

    report = {
        "schema_version": 1,
        "roadmap_step": "12.9",
        "mode": "release" if args.release else "preflight",
        "known_notice_rows": len(by_key),
        "backend_missing_notice_rows": len(backend_missing),
        "android_missing_notice_rows": len(android_missing),
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print(f"THIRD_PARTY_NOTICES FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "THIRD_PARTY_NOTICES %s PASS: rows=%d backend_missing=%d android_missing=%d warnings=%d"
        % (mode, len(by_key), len(backend_missing), len(android_missing), len(warnings))
    )
    for warning in warnings:
        print("WARNING:", warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
