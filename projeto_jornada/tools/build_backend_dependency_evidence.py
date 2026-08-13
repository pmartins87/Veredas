#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import zipfile
from email.parser import BytesParser
from email.policy import compat32
from pathlib import Path
from typing import Any

PIN_RE = re.compile(r"^([A-Za-z0-9_.-]+)==([^\s;]+)$")


def canonicalize_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


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


def wheel_metadata(path: Path) -> dict[str, Any]:
    try:
        with zipfile.ZipFile(path, "r") as archive:
            candidates = sorted(name for name in archive.namelist() if name.endswith(".dist-info/METADATA"))
            if len(candidates) != 1:
                raise ValueError(f"expected exactly one .dist-info/METADATA in {path.name}, found {len(candidates)}")
            message = BytesParser(policy=compat32).parsebytes(archive.read(candidates[0]))
    except (OSError, zipfile.BadZipFile, KeyError) as exc:
        raise ValueError(f"cannot read wheel metadata from {path.name}: {exc}") from exc

    name = str(message.get("Name", "")).strip()
    version = str(message.get("Version", "")).strip()
    if not name or not version:
        raise ValueError(f"wheel metadata lacks Name/Version: {path.name}")
    return {
        "name": name,
        "normalized_name": canonicalize_name(name),
        "version": version,
        "license_expression": str(message.get("License-Expression", "")).strip(),
        "license": str(message.get("License", "")).strip(),
        "license_files": sorted({str(value).strip() for value in message.get_all("License-File", []) if str(value).strip()}),
        "home_page": str(message.get("Home-Page", "")).strip(),
        "requires_dist": sorted(str(value).strip() for value in message.get_all("Requires-Dist", []) if str(value).strip()),
    }


def wheel_index(directory: Path) -> dict[tuple[str, str], list[tuple[Path, dict[str, Any]]]]:
    result: dict[tuple[str, str], list[tuple[Path, dict[str, Any]]]] = {}
    for path in sorted(directory.glob("*.whl")):
        metadata = wheel_metadata(path)
        key = (str(metadata["normalized_name"]), str(metadata["version"]))
        result.setdefault(key, []).append((path, metadata))
    return result


def resolver_details(resolver_python: Path) -> dict[str, str]:
    if not resolver_python.is_file():
        raise ValueError(f"resolver Python executable missing: {resolver_python}")
    script = r'''
import importlib.metadata, json, platform
print(json.dumps({
    "python": platform.python_version(),
    "implementation": platform.python_implementation(),
    "system": platform.system(),
    "machine": platform.machine(),
    "pip_version": importlib.metadata.version("pip"),
}))
'''
    try:
        raw = subprocess.check_output([str(resolver_python), "-c", script], text=True, stderr=subprocess.STDOUT).strip()
        value = json.loads(raw)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot inspect resolver environment: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError("resolver environment report is not an object")
    required = ("python", "implementation", "system", "machine", "pip_version")
    if any(not str(value.get(key, "")).strip() for key in required):
        raise ValueError(f"resolver environment report incomplete: {value}")
    return {key: str(value.get(key, "")) for key in required}


def component_row(normalized_name: str, display_name: str, version: str, wheel: Path, metadata: dict[str, Any], direct_names: set[str]) -> dict[str, Any]:
    if canonicalize_name(str(metadata.get("name", ""))) != normalized_name or str(metadata.get("version", "")) != version:
        raise ValueError(f"wheel metadata identity mismatch for {display_name}=={version}: {wheel.name}")
    return {
        "name": display_name,
        "normalized_name": normalized_name,
        "version": version,
        "direct": normalized_name in direct_names,
        "purl": f"pkg:pypi/{normalized_name}@{version}",
        "wheel_filename": wheel.name,
        "wheel_sha256": sha256_file(wheel),
        "metadata": {
            "license_expression": str(metadata.get("license_expression", "")),
            "license": str(metadata.get("license", "")),
            "license_files": list(metadata.get("license_files", [])),
            "home_page": str(metadata.get("home_page", "")),
            "requires_dist": list(metadata.get("requires_dist", [])),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a hash-locked Python dependency set and internal SBOM from an already-resolved backend environment.")
    parser.add_argument("--direct", type=Path, required=True)
    parser.add_argument("--resolved", type=Path, required=True)
    parser.add_argument("--wheel-dir", type=Path, required=True)
    parser.add_argument("--resolver-python", type=Path, required=True)
    parser.add_argument("--lock-output", type=Path, required=True)
    parser.add_argument("--sbom-output", type=Path, required=True)
    args = parser.parse_args()

    try:
        direct = parse_pin_file(args.direct)
        resolved = parse_pin_file(args.resolved)
        wheels = wheel_index(args.wheel_dir)
        resolver = resolver_details(args.resolver_python)
    except (OSError, ValueError) as exc:
        print(f"BACKEND_DEPENDENCY_EVIDENCE FAIL: {exc}")
        return 1

    if not resolver["python"].startswith("3.12.") or resolver["system"] != "Linux":
        print(f"BACKEND_DEPENDENCY_EVIDENCE FAIL: resolver must be Python 3.12/Linux, got {resolver}")
        return 1

    missing_direct = sorted(set(direct) - set(resolved))
    if missing_direct:
        print(f"BACKEND_DEPENDENCY_EVIDENCE FAIL: direct package(s) absent from resolved set: {missing_direct}")
        return 1
    for name, (_display, direct_version) in direct.items():
        if resolved[name][1] != direct_version:
            print(f"BACKEND_DEPENDENCY_EVIDENCE FAIL: direct pin drift {name} direct={direct_version} resolved={resolved[name][1]}")
            return 1

    components: list[dict[str, Any]] = []
    lock_rows: list[str] = []
    errors: list[str] = []
    direct_names = set(direct)
    resolved_keys = {(name, version) for name, (_display, version) in resolved.items()}
    for normalized_name in sorted(resolved):
        display_name, version = resolved[normalized_name]
        matches = wheels.get((normalized_name, version), [])
        if len(matches) != 1:
            errors.append(f"expected exactly one compatible wheel for {display_name}=={version}, found {len(matches)}")
            continue
        wheel, metadata = matches[0]
        digest = sha256_file(wheel)
        lock_rows.append(f"{display_name}=={version} --hash=sha256:{digest}")
        try:
            components.append(component_row(normalized_name, display_name, version, wheel, metadata, direct_names))
        except ValueError as exc:
            errors.append(str(exc))

    extra_wheels = sorted(path.name for key, rows in wheels.items() if key not in resolved_keys for path, _metadata in rows)
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
        "# Generated from the exact Python 3.12/Linux runtime resolver environment.\n"
        "# Install with: python -m pip install --require-hashes -r requirements.lock\n"
        + "\n".join(lock_rows) + "\n",
        encoding="utf-8",
    )

    sbom = {
        "schema_version": 3,
        "document_type": "veredas_internal_software_bill_of_materials",
        "scope": "billing_backend_python_runtime",
        "generator": "tools/build_backend_dependency_evidence.py",
        "wheel_metadata_parser": "python_stdlib_zipfile_email",
        "input": {"direct_requirements_path": "backend/play_purchase_verifier/requirements.txt", "direct_requirements_sha256": sha256_file(args.direct)},
        "resolver": {"tool": "pip", "version": resolver["pip_version"]},
        "environment": {"python": resolver["python"], "implementation": resolver["implementation"], "system": resolver["system"], "machine": resolver["machine"]},
        "direct_requirement_count": len(direct),
        "component_count": len(components),
        "all_components_hash_bound_to_wheel": True,
        "components": components,
    }
    args.sbom_output.parent.mkdir(parents=True, exist_ok=True)
    args.sbom_output.write_text(json.dumps(sbom, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(
        "BACKEND_DEPENDENCY_EVIDENCE PASS: direct=%d resolved=%d wheels=%d hash_locked=1 sbom_components=%d pip=%s tooling_contamination=0"
        % (len(direct), len(resolved), sum(len(rows) for rows in wheels.values()), len(components), resolver["pip_version"])
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
