#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
NOTICES = ROOT / "product" / "third_party_notices.json"
SBOM = ROOT / "product" / "software_sbom.json"
ARCHIVE = ROOT / "product" / "backend_license_archive.json"

EXACT_TEXT_IDENTITIES = {
    "pypi:blinker@1.9.0": ("MIT", ["Permission is hereby granted, free of charge", "THE SOFTWARE IS PROVIDED \"AS IS\""]),
    "pypi:google-api-core@2.34.0": ("Apache-2.0", ["Apache License", "Version 2.0, January 2004"]),
    "pypi:google-cloud-core@2.6.1": ("Apache-2.0", ["Apache License", "Version 2.0, January 2004"]),
    "pypi:googleapis-common-protos@1.75.1": ("Apache-2.0", ["Apache License", "Version 2.0, January 2004"]),
    "pypi:itsdangerous@2.2.0": ("BSD-3-Clause", ["Redistribution and use in source and binary forms", "Neither the name of the copyright holder nor the names of its contributors"]),
    "pypi:jinja2@3.1.6": ("BSD-3-Clause", ["Redistribution and use in source and binary forms", "Neither the name of the copyright holder nor the names of its contributors"]),
    "pypi:proto-plus@1.28.3": ("Apache-2.0", ["Apache License", "Version 2.0, January 2004"]),
    "pypi:protobuf@7.35.1": ("BSD-3-Clause", ["Redistribution and use in source and binary forms", "Neither the name of Google Inc. nor the names of its"]),
    "pypi:pyasn1-modules@0.4.2": ("BSD-2-Clause", ["Redistribution and use in source and binary forms", "Redistributions in binary form must reproduce"]),
}


def read_object(path: Path) -> dict[str, Any]:
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


def normalized_text(value: str) -> str:
    return " ".join(value.split())


def backend_key(component: dict[str, Any]) -> str:
    name = str(component.get("normalized_name", component.get("name", ""))).replace("_", "-").lower()
    version = str(component.get("version", ""))
    return f"pypi:{name}@{version}"


def verified_archived_files(archive_row: dict[str, Any]) -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    files = archive_row.get("archived_files", [])
    if not isinstance(files, list) or not files:
        raise SystemExit(f"no archived license evidence: {archive_row.get('component_key')}")
    for file_row in files:
        if not isinstance(file_row, dict):
            raise SystemExit("invalid archived file row")
        relative = str(file_row.get("path", ""))
        expected = str(file_row.get("sha256", "")).lower()
        path = ROOT / relative
        if not path.is_file() or sha256_file(path) != expected:
            raise SystemExit(f"archived license evidence hash mismatch: {relative}")
        result.append({
            "kind": str(file_row.get("kind", "license")),
            "path": relative,
            "sha256": expected,
        })
    return result


def exact_text_license(key: str, archived_files: list[dict[str, str]]) -> str:
    expected = EXACT_TEXT_IDENTITIES.get(key)
    if expected is None:
        raise SystemExit(f"no exact-text identity rule for missing backend component: {key}")
    license_id, markers = expected
    texts: list[str] = []
    for file_row in archived_files:
        if file_row["kind"] != "license":
            continue
        raw = (ROOT / file_row["path"]).read_bytes()
        texts.append(raw.decode("utf-8", errors="replace"))
    joined = "\n".join(texts)
    normalized = normalized_text(joined)
    for marker in markers:
        if normalized_text(marker) not in normalized:
            raise SystemExit(f"exact license marker missing for {key}: {marker!r}")
    if key == "pypi:pyasn1-modules@0.4.2" and "Neither the name" in normalized:
        raise SystemExit("pyasn1-modules exact text unexpectedly contains BSD-3-Clause endorsement clause")
    return license_id


def main() -> int:
    notices = read_object(NOTICES)
    sbom = read_object(SBOM)
    archive = read_object(ARCHIVE)
    if notices.get("schema_version") != 1 or notices.get("roadmap_step") != "12.9":
        raise SystemExit("third-party notices schema invalid")
    if sbom.get("component_count") != 29:
        raise SystemExit(f"expected exact persisted backend SBOM with 29 components, got {sbom.get('component_count')}")
    if archive.get("verified_exact_wheel_count") != 29 or archive.get("components_without_archived_files") != 0:
        raise SystemExit("backend exact-wheel license archive incomplete")

    rows = notices.get("components", [])
    if not isinstance(rows, list):
        raise SystemExit("third-party notices components must be an array")
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

    backend_components = sbom.get("components", [])
    if not isinstance(backend_components, list):
        raise SystemExit("backend SBOM components missing")
    backend_keys: set[str] = set()
    exact_text_added: list[str] = []

    for component in backend_components:
        if not isinstance(component, dict):
            raise SystemExit("non-object backend SBOM component")
        key = backend_key(component)
        backend_keys.add(key)
        archive_row = archive_by_key.get(key)
        if not isinstance(archive_row, dict):
            raise SystemExit(f"archive row missing for backend component: {key}")
        archived_files = verified_archived_files(archive_row)

        row = by_key.get(key)
        if row is None:
            license_id = exact_text_license(key, archived_files)
            row = {
                "component_key": key,
                "provenance_id": "",
                "name": str(component.get("name", component.get("normalized_name", ""))),
                "version": str(component.get("version", "")),
                "scope": "backend_runtime_transitive",
                "license_id": license_id,
                "license_source": "exact hash-bound wheel-embedded license text; primary-source/final legal review still required",
                "evidence": "product/backend_license_archive.json",
                "reviewed": False,
                "coverage_status": "archived_pending_primary_review",
                "archived_files": archived_files,
            }
            rows.append(row)
            by_key[key] = row
            exact_text_added.append(key)
        else:
            if str(row.get("version", "")) != str(component.get("version", "")):
                raise SystemExit(f"notice/SBOM version mismatch: {key}")
            if not str(row.get("license_id", "")).strip():
                raise SystemExit(f"existing backend notice row lacks license identity: {key}")
            row["archived_files"] = archived_files
            row["evidence"] = "product/backend_license_archive.json"
            if row.get("reviewed") is not True:
                row["coverage_status"] = "archived_pending_primary_review"
            if not str(row.get("scope", "")).strip():
                row["scope"] = "backend_runtime_direct" if bool(component.get("direct", False)) else "backend_runtime_transitive"

    if set(EXACT_TEXT_IDENTITIES) != set(exact_text_added):
        raise SystemExit(
            "exact-text completion set drifted: expected=%s added=%s"
            % (sorted(EXACT_TEXT_IDENTITIES), sorted(exact_text_added))
        )

    covered = backend_keys & set(by_key)
    missing = sorted(backend_keys - set(by_key))
    if missing or len(covered) != 29:
        raise SystemExit(f"backend notice identity coverage incomplete: covered={len(covered)} missing={missing}")
    for key in sorted(backend_keys):
        row = by_key[key]
        if not row.get("archived_files"):
            raise SystemExit(f"backend notice row lacks archived files: {key}")

    rows.sort(key=lambda row: str(row.get("component_key", "")))
    notices["updated_on"] = "2026-08-14"
    notices["backend_transitive_coverage"] = {
        "status": "identity_complete_pending_primary_review",
        "source_sbom": "product/software_sbom.json",
        "source_license_archive": "product/backend_license_archive.json",
        "component_count": 29,
        "covered_component_count": 29,
        "missing_component_count": 0,
        "missing_component_keys": [],
        "all_rows_have_sha_bound_archived_license_evidence": True,
        "all_rows_finally_reviewed": all(by_key[key].get("reviewed") is True for key in backend_keys),
    }
    notices["finalized"] = False
    notices["formal_status"] = "in_progress"
    notices["pass_recorded"] = False
    NOTICES.write_text(json.dumps(notices, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "COMPLETE_BACKEND_NOTICE_IDENTITY PASS: backend=29/29 exact_text_added=9 archived=29 reviewed_final=%s"
        % notices["backend_transitive_coverage"]["all_rows_finally_reviewed"]
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
