#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "audio" / "audio_events.json"
EXPECTED_BUSES = ["Master", "Music", "Ambience", "SFX", "UI"]
EXPECTED_UI = 7
EXPECTED_COMBAT = 7
EXPECTED_DOMAINS = 12
EXPECTED_REFERENCES = 38
AUDIO_EXTENSIONS = {".ogg", ".wav", ".mp3"}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected JSON object: {path}")
    return value


def res_to_path(resource_path: str) -> Path:
    prefix = "res://"
    if not resource_path.startswith(prefix):
        return Path("/__invalid_resource_path__")
    return ROOT / resource_path[len(prefix):]


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit the final audiovisual asset contract for Veredas da Trama.")
    parser.add_argument("--require-final", action="store_true", help="Fail if any launch audio asset is missing.")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    manifest = read_object(MANIFEST)
    errors: list[str] = []
    warnings: list[str] = []
    references: list[dict[str, Any]] = []

    if manifest.get("schema_version") != 1:
        errors.append("audio manifest schema must be 1")

    buses = manifest.get("buses", [])
    if buses != EXPECTED_BUSES:
        errors.append(f"audio buses must be exactly {EXPECTED_BUSES}, got {buses!r}")

    ui = manifest.get("ui", {})
    combat = manifest.get("combat", {})
    domains = manifest.get("domains", {})
    if not isinstance(ui, dict) or len(ui) != EXPECTED_UI:
        errors.append(f"expected {EXPECTED_UI} UI events")
    if not isinstance(combat, dict) or len(combat) != EXPECTED_COMBAT:
        errors.append(f"expected {EXPECTED_COMBAT} combat events")
    if not isinstance(domains, dict) or len(domains) != EXPECTED_DOMAINS:
        errors.append(f"expected {EXPECTED_DOMAINS} domains")

    for category, events in (("ui", ui), ("combat", combat)):
        if not isinstance(events, dict):
            continue
        for event_id, resource_path in sorted(events.items()):
            path_text = str(resource_path)
            references.append({"kind": category, "id": str(event_id), "path": path_text})

    signature_sets: set[tuple[str, ...]] = set()
    if isinstance(domains, dict):
        for domain_id, raw_domain in sorted(domains.items()):
            if not isinstance(raw_domain, dict):
                errors.append(f"domain is not object: {domain_id}")
                continue
            signature = raw_domain.get("signature", [])
            if not isinstance(signature, list) or len(signature) < 3:
                errors.append(f"domain requires >=3 signature motifs: {domain_id}")
            else:
                normalized = tuple(str(value).strip() for value in signature)
                if len(set(normalized)) != len(normalized):
                    errors.append(f"domain signature contains duplicate motif: {domain_id}")
                if normalized in signature_sets:
                    errors.append(f"duplicate complete domain signature: {domain_id}")
                signature_sets.add(normalized)
            for layer in ("music", "ambience"):
                path_text = str(raw_domain.get(layer, ""))
                references.append({"kind": layer, "id": str(domain_id), "path": path_text})

    if len(references) != EXPECTED_REFERENCES:
        errors.append(f"expected {EXPECTED_REFERENCES} audio references, got {len(references)}")

    paths = [str(row["path"]) for row in references]
    if len(set(paths)) != len(paths):
        errors.append("audio manifest contains duplicate resource paths")

    missing: list[dict[str, Any]] = []
    bad_paths: list[dict[str, Any]] = []
    present: list[dict[str, Any]] = []
    total_bytes = 0
    for row in references:
        resource_path = str(row["path"])
        if not resource_path.startswith("res://assets/audio/"):
            bad_paths.append({**row, "reason": "outside res://assets/audio"})
            continue
        suffix = Path(resource_path).suffix.lower()
        if suffix not in AUDIO_EXTENSIONS:
            bad_paths.append({**row, "reason": f"unsupported extension {suffix}"})
            continue
        physical = res_to_path(resource_path)
        if not physical.is_file():
            missing.append(row)
            continue
        size = physical.stat().st_size
        if size <= 0:
            bad_paths.append({**row, "reason": "empty file"})
            continue
        present.append({**row, "bytes": size})
        total_bytes += size

    if bad_paths:
        errors.append(f"{len(bad_paths)} invalid audio resource path(s)")
    if missing:
        message = f"{len(missing)}/{EXPECTED_REFERENCES} final audio asset(s) missing"
        if args.require_final:
            errors.append(message)
        else:
            warnings.append(message)

    report = {
        "schema_version": 1,
        "require_final": args.require_final,
        "contract": {
            "buses": EXPECTED_BUSES,
            "ui_events": EXPECTED_UI,
            "combat_events": EXPECTED_COMBAT,
            "domains": EXPECTED_DOMAINS,
            "references": EXPECTED_REFERENCES,
        },
        "present": len(present),
        "missing": len(missing),
        "invalid": len(bad_paths),
        "present_bytes": total_bytes,
        "missing_references": missing,
        "invalid_references": bad_paths,
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        "AUDIO_ASSET_AUDIT %s: references=%d present=%d missing=%d invalid=%d domains=%d signatures=%d"
        % (
            "FINAL" if args.require_final else "PREFLIGHT",
            len(references), len(present), len(missing), len(bad_paths),
            len(domains) if isinstance(domains, dict) else 0,
            len(signature_sets),
        )
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"AUDIO_ASSET_AUDIT FAIL: {len(errors)} issue group(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    if missing:
        print("AUDIO_ASSET_AUDIT PREFLIGHT PASS: manifest is coherent; final 7.8 assets remain required")
    else:
        print("AUDIO_ASSET_AUDIT PASS: 38/38 final audio references resolve")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
