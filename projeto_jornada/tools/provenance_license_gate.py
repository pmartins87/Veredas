#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "product" / "release_provenance.json"
BACKEND_REQUIREMENTS = ROOT / "backend" / "play_purchase_verifier" / "requirements.txt"
PLACEHOLDER_RE = re.compile(r"^(?:PENDING_|TODO|TBD|CHANGEME)", re.IGNORECASE)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
RELEASE_ONLY_EVIDENCE = [
    ROOT / "backend" / "play_purchase_verifier" / "requirements.lock",
    ROOT / "product" / "software_sbom.json",
    ROOT / "product" / "android_dependency_inventory.json",
]


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def unresolved(value: Any) -> bool:
    return not isinstance(value, str) or not value.strip() or bool(PLACEHOLDER_RE.match(value.strip()))


def tracked_files() -> list[str]:
    try:
        raw = subprocess.check_output(
            ["git", "ls-files", "-z", "--", "projeto_jornada"],
            cwd=ROOT.parent,
            stderr=subprocess.DEVNULL,
        )
        paths = [item.decode("utf-8") for item in raw.split(b"\0") if item]
        prefix = "projeto_jornada/"
        return [path[len(prefix):] for path in paths if path.startswith(prefix)]
    except Exception:  # noqa: BLE001
        return [str(path.relative_to(ROOT)).replace("\\", "/") for path in ROOT.rglob("*") if path.is_file()]


def git_blob_sha(relative_path: str) -> str:
    path = ROOT / relative_path
    if not path.is_file():
        return ""
    try:
        return subprocess.check_output(
            ["git", "hash-object", str(path)],
            cwd=ROOT.parent,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:  # noqa: BLE001
        return ""


def parse_requirements() -> dict[str, str]:
    result: dict[str, str] = {}
    for raw_line in BACKEND_REQUIREMENTS.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "==" not in line:
            raise ValueError(f"backend requirement is not exactly pinned: {line}")
        name, version = line.split("==", 1)
        result[name.strip().lower()] = version.strip()
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate release asset provenance, third-party software and external-service evidence for roadmap 12.9.")
    parser.add_argument("--release", action="store_true", help="Require final archived provenance/licenses/SBOM evidence.")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    try:
        contract = read_object(CONTRACT)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"PROVENANCE_LICENSE FAIL: {exc}")
        return 1

    if contract.get("schema_version") != 3 or contract.get("roadmap_step") != "12.9":
        errors.append("release provenance contract schema/roadmap_step invalid")

    assets = contract.get("asset_provenance", {})
    if not isinstance(assets, dict):
        errors.append("asset_provenance section missing")
        assets = {}
    extensions = assets.get("tracked_extensions", [])
    if not isinstance(extensions, list) or not extensions:
        errors.append("tracked asset extensions missing")
        extensions = []
    normalized_ext = {str(value).lower() for value in extensions}
    rows = assets.get("current_rows", [])
    if not isinstance(rows, list):
        errors.append("asset provenance rows must be an array")
        rows = []

    discovered = sorted(path for path in tracked_files() if Path(path).suffix.lower() in normalized_ext)
    declared_paths: list[str] = []
    allowed_origins = {str(value) for value in assets.get("allowed_origin_classes", [])}
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append(f"asset provenance row {index} is not an object")
            continue
        path = str(row.get("path", "")).replace("\\", "/")
        if not path:
            errors.append(f"asset provenance row {index} path missing")
            continue
        declared_paths.append(path)
        origin = str(row.get("origin_class", ""))
        if origin not in allowed_origins:
            errors.append(f"asset origin class invalid: {path}:{origin}")
        if not str(row.get("rights_basis", "")).strip():
            errors.append(f"asset rights_basis missing: {path}")
        if unresolved(row.get("source_record")):
            errors.append(f"asset source_record unresolved: {path}")
        expected_blob = str(row.get("repository_blob_sha", "")).lower()
        actual_blob = git_blob_sha(path).lower()
        if not re.fullmatch(r"[0-9a-f]{40}", expected_blob) or expected_blob != actual_blob:
            errors.append(f"asset provenance blob binding mismatch: {path} expected={expected_blob} actual={actual_blob}")
        if args.release:
            if row.get("rights_reviewed") is not True:
                errors.append(f"asset final rights review incomplete: {path}")
            if row.get("release_eligible") is not True:
                errors.append(f"asset is not explicitly release eligible: {path}")
            if origin in {"commissioned_with_release_rights", "licensed_third_party", "public_domain_verified"}:
                if unresolved(row.get("rights_evidence_archive")):
                    errors.append(f"asset rights evidence is not archived: {path}")

    if len(set(declared_paths)) != len(declared_paths):
        errors.append("asset provenance contains duplicate paths")
    if set(discovered) != set(declared_paths):
        missing = sorted(set(discovered) - set(declared_paths))
        stale = sorted(set(declared_paths) - set(discovered))
        if missing:
            errors.append(f"versioned release asset(s) lack provenance: {missing[:25]}")
        if stale:
            errors.append(f"provenance row(s) point to missing asset(s): {stale[:25]}")
    if int(assets.get("current_binary_asset_count", -1)) != len(discovered):
        errors.append("asset_provenance.current_binary_asset_count does not match repository scan")

    software = contract.get("software_inventory", {})
    if not isinstance(software, dict):
        errors.append("software_inventory section missing")
        software = {}
    components = software.get("known_components", [])
    if not isinstance(components, list):
        errors.append("known_components must be an array")
        components = []
    component_map: dict[str, dict[str, Any]] = {}
    for row in components:
        if not isinstance(row, dict):
            errors.append("software component row is not an object")
            continue
        component_id = str(row.get("id", "")).strip()
        key = component_id.lower()
        if not component_id or key in component_map:
            errors.append(f"software component id missing/duplicate: {component_id!r}")
            continue
        component_map[key] = row
        if unresolved(row.get("license_id")):
            errors.append(f"software license id is not identified from primary source: {component_id}")
        if row.get("license_identified_from_primary_source") is not True:
            errors.append(f"software primary-source license identification missing: {component_id}")
        if unresolved(row.get("license_source_record")):
            errors.append(f"software license source record missing: {component_id}")

    try:
        direct_requirements = parse_requirements()
    except (OSError, ValueError) as exc:
        errors.append(str(exc))
        direct_requirements = {}
    for name, version in direct_requirements.items():
        row = component_map.get(name)
        if row is None:
            errors.append(f"backend direct dependency missing from software inventory: {name}=={version}")
            continue
        if str(row.get("version", "")) != version:
            errors.append(f"software inventory version mismatch: {name} requirements={version} inventory={row.get('version')}")
        wheel_sha = str(row.get("primary_wheel_sha256", "")).lower()
        if not SHA256_RE.fullmatch(wheel_sha):
            errors.append(f"backend direct dependency primary wheel SHA-256 missing/invalid: {name}=={version}")
    for required_id in ("godot-engine", "godotgoogleplaybilling"):
        if required_id not in component_map:
            errors.append(f"required release software component missing: {required_id}")

    if args.release:
        if assets.get("finalized") is not True:
            errors.append("asset provenance is not finalized")
        if unresolved(assets.get("final_archive_path")):
            errors.append("asset provenance final archive path unresolved")
        for row in components:
            if not isinstance(row, dict):
                continue
            component_id = str(row.get("id", ""))
            if row.get("reviewed") is not True:
                errors.append(f"software license/source review incomplete: {component_id}")
            if unresolved(row.get("license_notice_archive")):
                errors.append(f"software license notice archive unresolved: {component_id}")
        if software.get("backend_transitive_lock_status") != "complete_hash_locked_dependency_set":
            errors.append("backend transitive dependencies are not completely hash locked")
        if software.get("backend_transitive_sbom_status") != "final_container_sbom_archived":
            errors.append("backend final container SBOM is not archived")
        if software.get("android_final_dependency_inventory_status") != "final_gradle_dependency_report_archived":
            errors.append("final Android dependency inventory is not archived")
        if software.get("finalized") is not True:
            errors.append("software inventory is not finalized")
        for path in RELEASE_ONLY_EVIDENCE:
            if not path.exists():
                errors.append(f"release provenance evidence missing: {path.relative_to(ROOT)}")

    services = contract.get("external_services", {})
    if not isinstance(services, dict):
        errors.append("external_services section missing")
        services = {}
    known_services = services.get("known_services", [])
    if not isinstance(known_services, list) or not known_services:
        errors.append("known external-service inventory missing")
        known_services = []
    if args.release:
        if services.get("finalized") is not True:
            errors.append("external service inventory is not finalized")
        for row in known_services:
            if not isinstance(row, dict) or row.get("production_terms_reviewed") is not True:
                errors.append(f"external service production terms not reviewed: {row.get('id') if isinstance(row, dict) else 'invalid-row'}")
        if contract.get("formal_status") != "certified" or contract.get("pass_recorded") is not True:
            errors.append("release provenance contract is not certified")
    else:
        pending_reviews = sum(1 for row in components if isinstance(row, dict) and row.get("reviewed") is not True)
        if pending_reviews:
            warnings.append(f"{pending_reviews} software component final review/notice archive(s) pending")
        if software.get("backend_transitive_lock_status") != "complete_hash_locked_dependency_set":
            warnings.append("backend transitive hash lock is still pending")
        if software.get("android_final_dependency_inventory_status") != "final_gradle_dependency_report_archived":
            warnings.append("final Android Gradle dependency inventory is still pending")
        pending_rights = sum(1 for row in rows if isinstance(row, dict) and row.get("rights_reviewed") is not True)
        if pending_rights:
            warnings.append(f"{pending_rights} asset rights review(s) pending before release eligibility")

    report = {
        "schema_version": 3,
        "roadmap_step": "12.9",
        "mode": "release" if args.release else "preflight",
        "discovered_asset_count": len(discovered),
        "declared_asset_count": len(declared_paths),
        "direct_backend_dependency_count": len(direct_requirements),
        "known_software_component_count": len(component_map),
        "primary_source_license_identifications": sum(
            1 for row in components if isinstance(row, dict) and row.get("license_identified_from_primary_source") is True
        ),
        "known_external_service_count": len(known_services),
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if errors:
        print(f"PROVENANCE_LICENSE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "PROVENANCE_LICENSE %s PASS: assets=%d dependencies=%d primary_licenses=%d services=%d warnings=%d blob_binding=1"
        % (
            mode,
            len(discovered),
            len(component_map),
            report["primary_source_license_identifications"],
            len(known_services),
            len(warnings),
        )
    )
    for warning in warnings:
        print("WARNING:", warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
