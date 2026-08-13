#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import platform
import re
import sys
from pathlib import Path
from typing import Any

from packaging.utils import canonicalize_name, parse_wheel_filename

PIN_RE = re.compile(r"^([A-Za-z0-9_.-]+)==([^\s;]+)$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def parse_pin_file(path: Path) -> dict[str, tuple[str, str]]:
    result: dict[str, tuple[str, str]] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = PIN_RE.fullmatch(line)
        if not match:
            raise ValueError(f"expected exact name==version pin in {path}: {line}")
        display_name, version = match.groups()
        key = canonicalize_name(display_name)
        if key in result:
            raise ValueError(f"duplicate normalized package pin in {path}: {display_name}")
        result[key] = (display_name, version)
    if not result:
        raise ValueError(f"no dependency pins found in {path}")
    return result


def wheel_index(directory: Path) -> dict[tuple[str, str], list[Path]]:
    result: dict[tuple[str, str], list[Path]] = {}
    for path in sorted(directory.glob("*.whl")):
        try:
            name, version, _build, _tags = parse_wheel_filename(path.name)
        except Exception as exc:  # noqa: BLE001
            raise ValueError(f"cannot parse wheel filename {path.name}: {exc}") from exc
        key = (canonicalize_name(str(name)), str(version))
        result.setdefault(key, []).append(path)
    return result


def metadata_value(metadata: Any, *keys: str) -> str:
    for key in keys:
        value = metadata.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def component_row(
    normalized_name: str,
    display_name: str,
    version: str,
    wheel: Path,
    direct_names: set[str],
) -> dict[str, Any]:
    try:
        dist = importlib.metadata.distribution(display_name)
    except importlib.metadata.PackageNotFoundError as exc:
        raise ValueError(f"resolved package is not installed in evidence environment: {display_name}=={version}") from exc
    installed_version = dist.version
    if installed_version != version:
        raise ValueError(
            f"installed/resolved version mismatch for {display_name}: installed={installed_version} resolved={version}"
        )
    metadata = dist.metadata
    license_expression = metadata_value(metadata, "License-Expression")
    license_field = metadata_value(metadata, "License")
    license_files = sorted({value.strip() for value in metadata.get_all("License-File", []) if value.strip()})
    requires = sorted(dist.requires or [])
    return {
        "name": display_name,
        "normalized_name": normalized_name,
        "version": version,
        "direct": normalized_name in direct_names,
        "purl": f"pkg:pypi/{normalized_name}@{version}",
        "wheel_filename": wheel.name,
        "wheel_sha256": sha256_file(wheel),
        "metadata": {
            "license_expression": license_expression,
            "license": license_field,
            "license_files": license_files,
            "home_page": metadata_value(metadata, "Home-Page"),
            "requires_dist": requires,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build a hash-locked Python dependency set and internal SBOM from an already-resolved backend environment."
    )
    parser.add_argument("--direct", type=Path, required=True, help="Direct requirements.txt with exact pins.")
    parser.add_argument("--resolved", type=Path, required=True, help="pip freeze output for the resolved environment.")
    parser.add_argument("--wheel-dir", type=Path, required=True, help="Directory containing one compatible wheel per resolved package.")
    parser.add_argument("--lock-output", type=Path, required=True)
    parser.add_argument("--sbom-output", type=Path, required=True)
    args = parser.parse_args()

    try:
        direct = parse_pin_file(args.direct)
        resolved = parse_pin_file(args.resolved)
        wheels = wheel_index(args.wheel_dir)
    except (OSError, ValueError) as exc:
        print(f"BACKEND_DEPENDENCY_EVIDENCE FAIL: {exc}")
        return 1

    missing_direct = sorted(set(direct) - set(resolved))
    if missing_direct:
        print(f"BACKEND_DEPENDENCY_EVIDENCE FAIL: direct package(s) absent from resolved set: {missing_direct}")
        return 1
    for name, (_display, direct_version) in direct.items():
        resolved_version = resolved[name][1]
        if resolved_version != direct_version:
            print(
                "BACKEND_DEPENDENCY_EVIDENCE FAIL: direct pin drift %s direct=%s resolved=%s"
                % (name, direct_version, resolved_version)
            )
            return 1

    components: list[dict[str, Any]] = []
    lock_rows: list[str] = []
    errors: list[str] = []
    direct_names = set(direct)
    for normalized_name in sorted(resolved):
        display_name, version = resolved[normalized_name]
        matches = wheels.get((normalized_name, version), [])
        if len(matches) != 1:
            errors.append(
                f"expected exactly one compatible wheel for {display_name}=={version}, found {len(matches)}"
            )
            continue
        wheel = matches[0]
        digest = sha256_file(wheel)
        lock_rows.append(f"{display_name}=={version} --hash=sha256:{digest}")
        try:
            components.append(component_row(normalized_name, display_name, version, wheel, direct_names))
        except ValueError as exc:
            errors.append(str(exc))

    extra_wheels = sorted(
        path.name
        for key, paths in wheels.items()
        if key not in {(name, version) for name, (_display, version) in resolved.items()}
        for path in paths
    )
    if extra_wheels:
        errors.append(f"wheel directory contains package(s) outside resolved set: {extra_wheels}")

    if errors:
        print(f"BACKEND_DEPENDENCY_EVIDENCE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1

    args.lock_output.parent.mkdir(parents=True, exist_ok=True)
    args.lock_output.write_text(
        "# Veredas da Trama Billing backend dependency lock\n"
        "# Generated from the exact Python 3.12/Linux evidence environment.\n"
        "# Install with: python -m pip install --require-hashes -r requirements.lock\n"
        + "\n".join(lock_rows)
        + "\n",
        encoding="utf-8",
    )

    sbom = {
        "schema_version": 1,
        "document_type": "veredas_internal_software_bill_of_materials",
        "scope": "billing_backend_python_runtime",
        "generator": "tools/build_backend_dependency_evidence.py",
        "environment": {
            "python": platform.python_version(),
            "implementation": platform.python_implementation(),
            "system": platform.system(),
            "machine": platform.machine(),
        },
        "direct_requirement_count": len(direct),
        "component_count": len(components),
        "all_components_hash_bound_to_wheel": True,
        "components": components,
    }
    args.sbom_output.parent.mkdir(parents=True, exist_ok=True)
    args.sbom_output.write_text(json.dumps(sbom, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(
        "BACKEND_DEPENDENCY_EVIDENCE PASS: direct=%d resolved=%d wheels=%d hash_locked=1 sbom_components=%d"
        % (len(direct), len(resolved), sum(len(paths) for paths in wheels.values()), len(components))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
