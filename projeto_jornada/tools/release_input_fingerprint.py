#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_PRODUCT_FILES = [
    ROOT / "product" / "commercial_model.json",
    ROOT / "product" / "legal_documents.json",
]
SINGLE_FILES = [ROOT / "project.godot", ROOT / "export_presets.cfg", *RUNTIME_PRODUCT_FILES]
INPUT_ROOTS = [
    ROOT / "core",
    ROOT / "ui",
    ROOT / "scenes",
    ROOT / "localization",
    ROOT / "data",
    ROOT / "assets",
    ROOT / "mobile",
]
IGNORE_NAMES = {".DS_Store", "Thumbs.db"}
IGNORE_SUFFIXES = {".tmp", ".bak", ".swp"}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def collect() -> list[dict[str, Any]]:
    candidates: set[Path] = set()
    for path in SINGLE_FILES:
        if path.is_file():
            candidates.add(path)
    for directory in INPUT_ROOTS:
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if not path.is_file():
                continue
            if path.name in IGNORE_NAMES or path.suffix.lower() in IGNORE_SUFFIXES:
                continue
            candidates.add(path)
    rows: list[dict[str, Any]] = []
    for path in sorted(candidates, key=lambda value: value.relative_to(ROOT).as_posix()):
        relative = path.relative_to(ROOT).as_posix()
        rows.append({
            "path": relative,
            "bytes": path.stat().st_size,
            "sha256": sha256_file(path),
        })
    return rows


def aggregate(rows: list[dict[str, Any]]) -> str:
    digest = hashlib.sha256()
    for row in rows:
        digest.update(str(row["path"]).encode("utf-8"))
        digest.update(b"\0")
        digest.update(str(row["bytes"]).encode("ascii"))
        digest.update(b"\0")
        digest.update(str(row["sha256"]).encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Create or compare a deterministic fingerprint of Veredas runtime/release build inputs.")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--compare", type=Path, default=None)
    args = parser.parse_args()

    rows = collect()
    if not rows:
        print("RELEASE_INPUT_FINGERPRINT FAIL: no release inputs found")
        return 1
    report = {
        "schema_version": 2,
        "scope_policy": "runtime/build inputs only; release evidence and archive metadata are intentionally excluded to avoid self-reference",
        "runtime_product_files": [path.relative_to(ROOT).as_posix() for path in RUNTIME_PRODUCT_FILES],
        "file_count": len(rows),
        "total_bytes": sum(int(row["bytes"]) for row in rows),
        "aggregate_sha256": aggregate(rows),
        "files": rows,
    }

    if args.compare is not None:
        expected = read_json(args.compare)
        expected_sha = str(expected.get("aggregate_sha256", ""))
        if expected_sha != report["aggregate_sha256"]:
            expected_rows = {
                str(row.get("path", "")): str(row.get("sha256", ""))
                for row in expected.get("files", [])
                if isinstance(row, dict)
            }
            actual_rows = {str(row["path"]): str(row["sha256"]) for row in rows}
            changed = sorted(
                path for path in set(expected_rows) | set(actual_rows)
                if expected_rows.get(path) != actual_rows.get(path)
            )
            print(
                "RELEASE_INPUT_FINGERPRINT FAIL: aggregate mismatch expected=%s actual=%s changed=%d"
                % (expected_sha, report["aggregate_sha256"], len(changed))
            )
            for path in changed[:100]:
                print("CHANGED:", path)
            return 1

    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        "RELEASE_INPUT_FINGERPRINT PASS: files=%d bytes=%d sha256=%s runtime_product_files=%d"
        % (report["file_count"], report["total_bytes"], report["aggregate_sha256"], len(RUNTIME_PRODUCT_FILES))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
