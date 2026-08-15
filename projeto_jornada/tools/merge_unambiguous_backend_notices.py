#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
NOTICES = ROOT / "product" / "third_party_notices.json"
CANDIDATES = ROOT / "product" / "backend_notice_candidates.json"
ARCHIVE = ROOT / "product" / "backend_license_archive.json"

ACCEPTED_CANDIDATE_STATUSES = {
    "spdx_expression_from_wheel_metadata",
    "spdxish_license_field_requires_primary_review",
}
AMBIGUOUS_LICENSE_IDS = {"BSD", "Apache", "Apache 2.0", "3-Clause BSD License", ""}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def main() -> int:
    notices = read_object(NOTICES)
    candidates = read_object(CANDIDATES)
    archive = read_object(ARCHIVE)
    if notices.get("schema_version") != 1 or notices.get("roadmap_step") != "12.9":
        raise SystemExit("third-party notices schema invalid")
    if archive.get("verified_exact_wheel_count") != 29 or archive.get("components_without_archived_files") != 0:
        raise SystemExit("exact-wheel license archive is not complete for all 29 backend components")

    rows = notices.get("components", [])
    if not isinstance(rows, list):
        raise SystemExit("third_party_notices components must be an array")
    by_key = {
        str(row.get("component_key", "")): row
        for row in rows
        if isinstance(row, dict) and str(row.get("component_key", ""))
    }
    archive_by_key = {
        str(row.get("component_key", "")): row
        for row in archive.get("components", [])
        if isinstance(row, dict) and str(row.get("component_key", ""))
    }

    added = 0
    skipped_ambiguous: list[str] = []
    for candidate in candidates.get("candidates", []):
        if not isinstance(candidate, dict):
            continue
        key = str(candidate.get("component_key", ""))
        if not key or key in by_key:
            continue
        status = str(candidate.get("candidate_status", ""))
        license_id = str(candidate.get("candidate_license_id", "")).strip()
        if status not in ACCEPTED_CANDIDATE_STATUSES or license_id in AMBIGUOUS_LICENSE_IDS:
            skipped_ambiguous.append(key)
            continue
        archived = archive_by_key.get(key)
        if not isinstance(archived, dict):
            raise SystemExit(f"archive row missing for candidate {key}")
        archived_files = archived.get("archived_files", [])
        if not isinstance(archived_files, list) or not archived_files:
            raise SystemExit(f"archive files missing for candidate {key}")

        row = {
            "component_key": key,
            "provenance_id": "",
            "name": str(candidate.get("name", "")),
            "version": str(candidate.get("version", "")),
            "license_id": license_id,
            "license_source": "exact wheel METADATA from the hash-bound backend SBOM; primary-source review still required",
            "evidence": "product/backend_notice_candidates.json + product/backend_license_archive.json",
            "reviewed": False,
            "coverage_status": "archived_pending_primary_review",
            "archived_files": [
                {
                    "kind": str(file_row.get("kind", "license")),
                    "path": str(file_row.get("path", "")),
                    "sha256": str(file_row.get("sha256", "")),
                }
                for file_row in archived_files
                if isinstance(file_row, dict)
            ],
        }
        rows.append(row)
        by_key[key] = row
        added += 1

    backend_keys = {
        str(row.get("component_key", ""))
        for row in archive.get("components", [])
        if isinstance(row, dict) and str(row.get("component_key", ""))
    }
    covered_backend = backend_keys & set(by_key)
    missing = sorted(backend_keys - set(by_key))
    notices["backend_transitive_coverage"] = {
        "status": "partial_pending_primary_review",
        "source_sbom": "product/software_sbom.json",
        "source_license_archive": "product/backend_license_archive.json",
        "component_count": len(backend_keys),
        "covered_component_count": len(covered_backend),
        "missing_component_count": len(missing),
        "missing_component_keys": missing,
        "all_rows_finally_reviewed": False,
    }
    notices["finalized"] = False
    notices["formal_status"] = "in_progress"
    notices["pass_recorded"] = False

    NOTICES.write_text(json.dumps(notices, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "MERGE_UNAMBIGUOUS_BACKEND_NOTICES PASS: added=%d covered=%d/29 missing=%d"
        % (added, len(covered_backend), len(missing))
    )
    if added != 15:
        raise SystemExit(f"expected exactly 15 unambiguous new backend notice rows, got {added}")
    if len(missing) != 9:
        raise SystemExit(f"expected exactly 9 backend components still needing license identification, got {len(missing)}")
    for key in missing:
        print("PENDING_PRIMARY_IDENTIFICATION:", key)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
