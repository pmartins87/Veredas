#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DIRECT = ROOT / "backend" / "play_purchase_verifier" / "requirements.txt"
DEFAULT_LOCK = ROOT / "backend" / "play_purchase_verifier" / "requirements.lock"
DEFAULT_SBOM = ROOT / "product" / "software_sbom.json"
PROVENANCE = ROOT / "product" / "release_provenance.json"
PIN_RE = re.compile(r"^([A-Za-z0-9_.-]+)==([^\s;]+)$")
LOCK_RE = re.compile(r"^([A-Za-z0-9_.-]+)==([^\s;]+) --hash=sha256:([0-9a-f]{64})$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def canonical(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def parse_direct(path: Path) -> dict[str, tuple[str, str]]:
    rows: dict[str, tuple[str, str]] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = PIN_RE.fullmatch(line)
        if not match:
            raise ValueError(f"direct requirement is not exact name==version: {line}")
        display, version = match.groups()
        key = canonical(display)
        if key in rows:
            raise ValueError(f"duplicate direct requirement: {display}")
        rows[key] = (display, version)
    if not rows:
        raise ValueError("direct requirements are empty")
    return rows


def parse_lock(path: Path) -> dict[str, dict[str, str]]:
    rows: dict[str, dict[str, str]] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = LOCK_RE.fullmatch(line)
        if not match:
            raise ValueError(f"lock row is not exact pin + single SHA-256: {line}")
        display, version, digest = match.groups()
        key = canonical(display)
        if key in rows:
            raise ValueError(f"duplicate locked distribution: {display}")
        rows[key] = {"display": display, "version": version, "sha256": digest}
    if not rows:
        raise ValueError("dependency lock is empty")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the Veredas Billing backend hash lock and internal SBOM evidence.")
    parser.add_argument("--direct", type=Path, default=DEFAULT_DIRECT)
    parser.add_argument("--lock", type=Path, default=DEFAULT_LOCK)
    parser.add_argument("--sbom", type=Path, default=DEFAULT_SBOM)
    parser.add_argument("--require-evidence", action="store_true", help="Require supplied lock/SBOM now without requiring final 12.9 certification flags.")
    parser.add_argument("--release", action="store_true", help="Require persisted lock/SBOM plus final-release provenance status.")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    try:
        direct = parse_direct(args.direct)
        provenance = read_json(PROVENANCE)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"BACKEND_DEPENDENCY_EVIDENCE_GATE FAIL: {exc}")
        return 1

    evidence_exists = args.lock.is_file() and args.sbom.is_file()
    require_now = args.require_evidence or args.release
    if not evidence_exists:
        message = f"dependency evidence missing: lock={args.lock} sbom={args.sbom}"
        if require_now:
            errors.append(message)
        else:
            warnings.append(message + "; expected until a functioning Python 3.12/Linux resolver produces final evidence")
        lock: dict[str, dict[str, str]] = {}
        sbom: dict[str, Any] = {}
    else:
        try:
            lock = parse_lock(args.lock)
            sbom = read_json(args.sbom)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(str(exc))
            lock = {}
            sbom = {}

    if evidence_exists and not errors:
        if sbom.get("schema_version") != 2 or sbom.get("document_type") != "veredas_internal_software_bill_of_materials":
            errors.append("software SBOM schema/document_type invalid")
        if sbom.get("scope") != "billing_backend_python_runtime":
            errors.append("software SBOM scope must remain billing_backend_python_runtime")
        if sbom.get("generator") != "tools/build_backend_dependency_evidence.py":
            errors.append("software SBOM generator mismatch")
        if sbom.get("all_components_hash_bound_to_wheel") is not True:
            errors.append("software SBOM must assert all components are wheel-hash bound")

        input_row = sbom.get("input", {})
        if not isinstance(input_row, dict):
            errors.append("software SBOM input record missing")
            input_row = {}
        if input_row.get("direct_requirements_path") != "backend/play_purchase_verifier/requirements.txt":
            errors.append("software SBOM direct requirements path mismatch")
        if str(input_row.get("direct_requirements_sha256", "")).lower() != sha256_file(args.direct):
            errors.append("software SBOM direct requirements SHA-256 mismatch")

        resolver = sbom.get("resolver", {})
        if not isinstance(resolver, dict) or resolver.get("tool") != "pip" or not str(resolver.get("version", "")).strip():
            errors.append("software SBOM resolver identity/version missing")
        if not isinstance(resolver, dict) or not str(resolver.get("packaging_library_version", "")).strip():
            errors.append("software SBOM packaging parser version missing")

        environment = sbom.get("environment", {})
        if not isinstance(environment, dict):
            errors.append("software SBOM environment missing")
            environment = {}
        python_version = str(environment.get("python", ""))
        if not python_version.startswith("3.12."):
            errors.append(f"backend evidence must be resolved on Python 3.12.x, got {python_version!r}")
        if str(environment.get("system", "")) != "Linux":
            errors.append(f"backend evidence must be resolved on Linux, got {environment.get('system')!r}")

        components = sbom.get("components", [])
        if not isinstance(components, list):
            errors.append("software SBOM components must be an array")
            components = []
        component_map: dict[str, dict[str, Any]] = {}
        for index, row in enumerate(components):
            if not isinstance(row, dict):
                errors.append(f"SBOM component {index} is not an object")
                continue
            normalized = canonical(str(row.get("normalized_name", "")))
            display = str(row.get("name", ""))
            version = str(row.get("version", ""))
            digest = str(row.get("wheel_sha256", "")).lower()
            if not normalized or normalized in component_map:
                errors.append(f"SBOM normalized component name missing/duplicate: {normalized!r}")
                continue
            if normalized != canonical(display):
                errors.append(f"SBOM display/normalized package name mismatch: {display}:{normalized}")
            if not version or not SHA256_RE.fullmatch(digest):
                errors.append(f"SBOM version/wheel SHA invalid: {display}=={version}")
            expected_purl = f"pkg:pypi/{normalized}@{version}"
            if row.get("purl") != expected_purl:
                errors.append(f"SBOM purl mismatch: {display} expected={expected_purl}")
            if not str(row.get("wheel_filename", "")).endswith(".whl"):
                errors.append(f"SBOM wheel filename invalid: {display}")
            if not isinstance(row.get("metadata", {}), dict):
                errors.append(f"SBOM metadata missing: {display}")
            component_map[normalized] = row

        if int(sbom.get("component_count", -1)) != len(component_map):
            errors.append("software SBOM component_count mismatch")
        if int(sbom.get("direct_requirement_count", -1)) != len(direct):
            errors.append("software SBOM direct_requirement_count mismatch")
        if set(lock) != set(component_map):
            errors.append(
                "requirements.lock/SBOM package set mismatch: lock_only=%s sbom_only=%s"
                % (sorted(set(lock) - set(component_map)), sorted(set(component_map) - set(lock)))
            )

        for name, locked in lock.items():
            component = component_map.get(name)
            if component is None:
                continue
            if str(component.get("version", "")) != locked["version"]:
                errors.append(f"lock/SBOM version mismatch: {name}")
            if str(component.get("wheel_sha256", "")).lower() != locked["sha256"]:
                errors.append(f"lock/SBOM wheel hash mismatch: {name}")

        software = provenance.get("software_inventory", {})
        known = software.get("known_components", []) if isinstance(software, dict) else []
        known_map = {canonical(str(row.get("id", ""))): row for row in known if isinstance(row, dict)}
        for name, (_display, version) in direct.items():
            locked = lock.get(name)
            component = component_map.get(name)
            if locked is None or component is None:
                errors.append(f"direct dependency missing from lock/SBOM: {name}=={version}")
                continue
            if locked["version"] != version:
                errors.append(f"direct dependency lock version drift: {name} direct={version} lock={locked['version']}")
            if component.get("direct") is not True:
                errors.append(f"direct dependency not marked direct in SBOM: {name}")
            row = known_map.get(name)
            if row is None:
                errors.append(f"release provenance lacks direct dependency: {name}")
                continue
            expected_hash = str(row.get("primary_wheel_sha256", "")).lower()
            if expected_hash != locked["sha256"]:
                errors.append(f"direct wheel hash differs from primary provenance: {name} provenance={expected_hash} lock={locked['sha256']}")
            if str(row.get("version", "")) != version:
                errors.append(f"release provenance direct dependency version drift: {name}")

        for name, component in component_map.items():
            if bool(component.get("direct", False)) != (name in direct):
                errors.append(f"SBOM direct/transitive classification mismatch: {name}")

    if args.release and evidence_exists and not errors:
        software = provenance.get("software_inventory", {})
        if not isinstance(software, dict):
            errors.append("release provenance software_inventory missing")
        else:
            if software.get("backend_transitive_lock_status") != "complete_hash_locked_dependency_set":
                errors.append("release provenance does not mark backend transitive lock complete")
            if software.get("backend_transitive_sbom_status") != "final_container_sbom_archived":
                errors.append("release provenance does not mark final backend SBOM archived")

    report = {
        "schema_version": 2,
        "roadmap_step": "12.9",
        "mode": "release" if args.release else ("required_evidence" if args.require_evidence else "preflight"),
        "evidence_present": evidence_exists,
        "direct_requirement_count": len(direct),
        "locked_component_count": len(lock),
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print(f"BACKEND_DEPENDENCY_EVIDENCE_GATE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    mode = "RELEASE" if args.release else ("REQUIRED" if args.require_evidence else "PREFLIGHT")
    print(
        "BACKEND_DEPENDENCY_EVIDENCE_GATE %s PASS: evidence=%d direct=%d locked=%d warnings=%d resolver_bound=1 input_hash_bound=1"
        % (mode, 1 if evidence_exists else 0, len(direct), len(lock), len(warnings))
    )
    for warning in warnings:
        print("WARNING:", warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
