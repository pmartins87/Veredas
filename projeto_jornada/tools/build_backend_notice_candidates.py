#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SBOM = ROOT / "product" / "software_sbom.json"
NOTICES = ROOT / "product" / "third_party_notices.json"
DEFAULT_OUTPUT = ROOT / "product" / "backend_notice_candidates.json"

SPDXISH_RE = re.compile(r"^[A-Za-z0-9.+-]+(?:\s+(?:AND|OR|WITH)\s+[A-Za-z0-9.+-]+)*$")


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def canonical(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def component_key(name: str, version: str) -> str:
    return f"pypi:{canonical(name)}@{version}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build review candidates for backend third-party notices from the exact persisted wheel-derived SBOM."
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    sbom = read_object(SBOM)
    notices = read_object(NOTICES)
    if sbom.get("schema_version") != 3 or sbom.get("document_type") != "veredas_internal_software_bill_of_materials":
        raise SystemExit("backend SBOM schema/document type invalid")
    rows = notices.get("components", [])
    if not isinstance(rows, list):
        raise SystemExit("third_party_notices components must be an array")
    covered = {
        str(row.get("component_key", "")).strip()
        for row in rows
        if isinstance(row, dict) and str(row.get("component_key", "")).strip()
    }

    candidates: list[dict[str, Any]] = []
    counts = {
        "spdx_expression_from_wheel_metadata": 0,
        "spdxish_license_field_requires_primary_review": 0,
        "freeform_license_field_requires_primary_review": 0,
        "no_license_identity_in_wheel_metadata": 0,
    }

    components = sbom.get("components", [])
    if not isinstance(components, list):
        raise SystemExit("backend SBOM components must be an array")

    for component in components:
        if not isinstance(component, dict):
            continue
        name = str(component.get("normalized_name", component.get("name", ""))).strip()
        version = str(component.get("version", "")).strip()
        key = component_key(name, version)
        if key in covered:
            continue
        metadata = component.get("metadata", {})
        if not isinstance(metadata, dict):
            metadata = {}
        expression = str(metadata.get("license_expression", "")).strip()
        license_text = str(metadata.get("license", "")).strip()
        license_files = metadata.get("license_files", [])
        if not isinstance(license_files, list):
            license_files = []

        candidate_license_id = ""
        if expression:
            status = "spdx_expression_from_wheel_metadata"
            candidate_license_id = expression
        elif license_text and SPDXISH_RE.fullmatch(license_text):
            status = "spdxish_license_field_requires_primary_review"
            candidate_license_id = license_text
        elif license_text:
            status = "freeform_license_field_requires_primary_review"
        else:
            status = "no_license_identity_in_wheel_metadata"
        counts[status] += 1

        candidates.append({
            "component_key": key,
            "name": str(component.get("name", name)),
            "normalized_name": canonical(name),
            "version": version,
            "direct": bool(component.get("direct", False)),
            "wheel_filename": str(component.get("wheel_filename", "")),
            "wheel_sha256": str(component.get("wheel_sha256", "")),
            "wheel_metadata": {
                "license_expression": expression,
                "license": license_text,
                "license_files": [str(value) for value in license_files],
                "home_page": str(metadata.get("home_page", "")),
            },
            "candidate_license_id": candidate_license_id,
            "candidate_status": status,
            "requires_primary_source_review": True,
            "reviewed": False,
            "eligible_for_final_notice_manifest_without_review": False,
        })

    candidates.sort(key=lambda row: row["component_key"])
    report = {
        "schema_version": 1,
        "roadmap_step": "12.9",
        "source": {
            "sbom": "product/software_sbom.json",
            "notices": "product/third_party_notices.json",
            "sbom_component_count": int(sbom.get("component_count", len(components))),
        },
        "policy": {
            "wheel_metadata_is_candidate_evidence_not_final_legal_review": True,
            "package_name_only_inference_forbidden": True,
            "primary_source_review_required_before_notice_row_is_final": True,
            "archived_license_notice_file_hash_required_before_release": True,
        },
        "missing_notice_candidate_count": len(candidates),
        "candidate_status_counts": counts,
        "candidates": candidates,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "BACKEND_NOTICE_CANDIDATES PASS: missing=%d spdx_expression=%d spdxish_field=%d freeform=%d unresolved=%d"
        % (
            len(candidates),
            counts["spdx_expression_from_wheel_metadata"],
            counts["spdxish_license_field_requires_primary_review"],
            counts["freeform_license_field_requires_primary_review"],
            counts["no_license_identity_in_wheel_metadata"],
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
