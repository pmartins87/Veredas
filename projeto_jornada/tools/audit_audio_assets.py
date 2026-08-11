#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "audio" / "audio_events.json"
MIX = ROOT / "audio" / "audio_mix.json"
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
    mix = read_object(MIX)
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
            references.append({"kind": category, "id": str(event_id), "path": str(resource_path)})

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
                references.append({"kind": layer, "id": str(domain_id), "path": str(raw_domain.get(layer, ""))})

    if len(references) != EXPECTED_REFERENCES:
        errors.append(f"expected {EXPECTED_REFERENCES} audio references, got {len(references)}")

    paths = [str(row["path"]) for row in references]
    if len(set(paths)) != len(paths):
        errors.append("audio manifest contains duplicate resource paths")

    mix_report: dict[str, Any] = {}
    if mix.get("schema_version") != 1:
        errors.append("audio mix schema must be 1")
    if mix.get("principle") != "sound_supports_reading":
        errors.append("audio mix must declare sound_supports_reading principle")
    bus_levels = mix.get("buses", {})
    limits = mix.get("limits", {})
    accessibility = mix.get("accessibility", {})
    if not isinstance(bus_levels, dict):
        errors.append("audio mix buses must be an object")
        bus_levels = {}
    missing_levels = [name for name in EXPECTED_BUSES if name not in bus_levels]
    if missing_levels:
        errors.append(f"audio mix missing bus levels: {missing_levels}")
    try:
        music_db = float(bus_levels.get("Music", 0.0))
        ambience_db = float(bus_levels.get("Ambience", 0.0))
        sfx_db = float(bus_levels.get("SFX", 0.0))
        ui_db = float(bus_levels.get("UI", 0.0))
        foreground_db = min(sfx_db, ui_db)
        margin_required = float(limits.get("foreground_min_margin_db", 4.0))
        music_margin = foreground_db - music_db
        ambience_margin = foreground_db - ambience_db
        music_cap = float(limits.get("music_max_db", -12.0))
        ambience_cap = float(limits.get("ambience_max_db", -15.0))
        if music_db > music_cap:
            errors.append(f"music level {music_db} dB exceeds cap {music_cap} dB")
        if ambience_db > ambience_cap:
            errors.append(f"ambience level {ambience_db} dB exceeds cap {ambience_cap} dB")
        if music_margin < margin_required:
            errors.append(f"music/foreground margin {music_margin} dB is below {margin_required} dB")
        if ambience_margin < margin_required:
            errors.append(f"ambience/foreground margin {ambience_margin} dB is below {margin_required} dB")
        mix_report = {
            "music_db": music_db,
            "ambience_db": ambience_db,
            "sfx_db": sfx_db,
            "ui_db": ui_db,
            "music_foreground_margin_db": music_margin,
            "ambience_foreground_margin_db": ambience_margin,
            "required_margin_db": margin_required,
        }
    except (TypeError, ValueError) as exc:
        errors.append(f"invalid numeric audio mix value: {exc}")
    if bool(accessibility.get("essential_information_requires_audio", True)):
        errors.append("audio cannot be required for essential gameplay information")
    if not bool(accessibility.get("visual_text_feedback_required", False)):
        errors.append("audio mix must require parallel visual/text feedback")

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
        "mix": mix_report,
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
        "AUDIO_ASSET_AUDIT %s: references=%d present=%d missing=%d invalid=%d domains=%d signatures=%d mix=%s"
        % (
            "FINAL" if args.require_final else "PREFLIGHT",
            len(references), len(present), len(missing), len(bad_paths),
            len(domains) if isinstance(domains, dict) else 0,
            len(signature_sets),
            "reading-first" if not any("mix" in error or "level" in error or "margin" in error for error in errors) else "invalid",
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
        print("AUDIO_ASSET_AUDIT PREFLIGHT PASS: manifest/mix are coherent; final 7.8 assets remain required")
    else:
        print("AUDIO_ASSET_AUDIT PASS: 38/38 final audio references resolve")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
