#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SBOM = ROOT / "product" / "software_sbom.json"
DEFAULT_WHEELS = Path("/tmp/veredas-notice-wheels")
DEFAULT_ARCHIVE = ROOT / "product" / "third_party_licenses" / "backend"
DEFAULT_REPORT = ROOT / "product" / "backend_license_archive.json"
LICENSE_BASENAME_RE = re.compile(r"^(?:licen[cs]e|notice|copying|copyright)(?:[._-].*)?$", re.IGNORECASE)


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.@+-]+", "_", value)


def archive_kind(name: str) -> str:
    lowered = name.lower()
    if lowered.startswith("notice"):
        return "notice"
    if lowered.startswith("copyright"):
        return "copyright"
    if lowered.startswith("copying"):
        return "license"
    return "license"


def main() -> int:
    parser = argparse.ArgumentParser(description="Archive license/notice files from the exact wheel set bound by the backend SBOM.")
    parser.add_argument("--wheel-dir", type=Path, default=DEFAULT_WHEELS)
    parser.add_argument("--archive-root", type=Path, default=DEFAULT_ARCHIVE)
    parser.add_argument("--output", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()

    sbom = read_object(SBOM)
    if sbom.get("schema_version") != 3 or sbom.get("document_type") != "veredas_internal_software_bill_of_materials":
        raise SystemExit("backend SBOM schema/document type invalid")
    components = sbom.get("components", [])
    if not isinstance(components, list) or not components:
        raise SystemExit("backend SBOM components missing")

    args.archive_root.mkdir(parents=True, exist_ok=True)
    expected_dirs: set[str] = set()
    rows: list[dict[str, Any]] = []
    errors: list[str] = []

    wheel_files = {path.name: path for path in args.wheel_dir.glob("*.whl") if path.is_file()}
    if len(wheel_files) != len(components):
        errors.append(f"wheel/component count mismatch wheels={len(wheel_files)} components={len(components)}")

    for component in components:
        if not isinstance(component, dict):
            errors.append("non-object SBOM component")
            continue
        display = str(component.get("name", ""))
        normalized = canonical(str(component.get("normalized_name", display)))
        version = str(component.get("version", ""))
        filename = str(component.get("wheel_filename", ""))
        expected_hash = str(component.get("wheel_sha256", "")).lower()
        wheel = wheel_files.get(filename)
        key = f"pypi:{normalized}@{version}"
        if wheel is None:
            errors.append(f"exact SBOM wheel missing: {key}:{filename}")
            continue
        actual_hash = sha256_file(wheel)
        if actual_hash != expected_hash:
            errors.append(f"wheel SHA-256 mismatch: {key} expected={expected_hash} actual={actual_hash}")
            continue

        target_dir_name = safe_name(f"{normalized}@{version}")
        expected_dirs.add(target_dir_name)
        target_dir = args.archive_root / target_dir_name
        if target_dir.exists():
            shutil.rmtree(target_dir)
        target_dir.mkdir(parents=True, exist_ok=True)

        archived: list[dict[str, Any]] = []
        with zipfile.ZipFile(wheel) as archive:
            for member in sorted(archive.namelist()):
                pure = PurePosixPath(member)
                if member.endswith("/") or not LICENSE_BASENAME_RE.match(pure.name):
                    continue
                # License evidence must originate from distribution metadata or
                # an explicit license directory, not an arbitrary package file.
                if not any(part.endswith(".dist-info") for part in pure.parts) and "licenses" not in [part.lower() for part in pure.parts]:
                    continue
                data = archive.read(member)
                out_name = safe_name(pure.name)
                # Disambiguate duplicate basenames deterministically.
                if any(row["archive_filename"] == out_name for row in archived):
                    out_name = safe_name("__".join(pure.parts[-3:]))
                output_path = target_dir / out_name
                output_path.write_bytes(data)
                relative = output_path.relative_to(ROOT).as_posix()
                archived.append({
                    "kind": archive_kind(pure.name),
                    "wheel_member": member,
                    "archive_filename": out_name,
                    "path": relative,
                    "sha256": sha256_bytes(data),
                    "size_bytes": len(data),
                })

        metadata = component.get("metadata", {}) if isinstance(component.get("metadata"), dict) else {}
        rows.append({
            "component_key": key,
            "name": display,
            "version": version,
            "wheel_filename": filename,
            "wheel_sha256": expected_hash,
            "metadata_license_expression": str(metadata.get("license_expression", "")),
            "metadata_license": str(metadata.get("license", "")),
            "metadata_license_files": [str(value) for value in metadata.get("license_files", [])] if isinstance(metadata.get("license_files", []), list) else [],
            "archived_file_count": len(archived),
            "archived_files": archived,
        })

    # Remove stale component directories that are no longer present in the exact SBOM.
    for child in args.archive_root.iterdir():
        if child.is_dir() and child.name not in expected_dirs:
            shutil.rmtree(child)

    rows.sort(key=lambda row: row["component_key"])
    no_archived_files = [row["component_key"] for row in rows if row["archived_file_count"] == 0]
    report = {
        "schema_version": 1,
        "roadmap_step": "12.9",
        "source_sbom": "product/software_sbom.json",
        "source_component_count": len(components),
        "verified_exact_wheel_count": len(rows),
        "components_with_archived_files": len(rows) - len(no_archived_files),
        "components_without_archived_files": len(no_archived_files),
        "components_without_archived_files_keys": no_archived_files,
        "policy": {
            "wheel_sha256_must_match_sbom_before_extraction": True,
            "only_distribution_license_notice_files_are_archived": True,
            "archive_does_not_imply_legal_review": True,
            "reviewed_flags_are_not_modified_by_this_tool": True,
        },
        "components": rows,
        "errors": errors,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print(f"BACKEND_WHEEL_LICENSE_ARCHIVE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print(
        "BACKEND_WHEEL_LICENSE_ARCHIVE PASS: wheels=%d with_files=%d without_files=%d"
        % (len(rows), len(rows) - len(no_archived_files), len(no_archived_files))
    )
    for key in no_archived_files:
        print("WARNING: no embedded license/notice file:", key)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
