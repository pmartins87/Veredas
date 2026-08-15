#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "qa" / "physical_android_soak_11_3.json"
PACKAGE_ID = "com.pmartins87.veredasdatrama"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
FULL_SHA_RE = re.compile(r"^[0-9a-f]{40}$")

MIN_SOAK_SECONDS = 1800
MAX_COLD_LAUNCH_MS = 3000
REQUIRED_RESUME_SAMPLES = 12
MAX_RESUME_P95_MS = 1500
MAX_PSS_KB = 420 * 1024
MAX_SOAK_PSS_DRIFT_KB = 96 * 1024


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def parse_dt(value: Any, field: str, errors: list[str]) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        errors.append(f"{field} missing")
        return None
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        errors.append(f"{field} must be ISO-8601")
        return None
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        errors.append(f"{field} must include timezone")
        return None
    return parsed


def require_bool(container: dict[str, Any], key: str, errors: list[str]) -> None:
    if container.get(key) is not True:
        errors.append(f"{key} must be true")


def main() -> int:
    parser = argparse.ArgumentParser(description="Fail-closed certification gate for Veredas roadmap step 11.3 physical Android soak.")
    parser.add_argument("--evidence", type=Path, default=EVIDENCE)
    parser.add_argument("--certify", action="store_true", help="Require complete real-device evidence and formal PASS.")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []

    if not args.evidence.is_file():
        errors.append(f"physical soak evidence file missing: {args.evidence}")
        evidence: dict[str, Any] = {}
    else:
        try:
            evidence = read_object(args.evidence)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(f"cannot read physical soak evidence: {exc}")
            evidence = {}

    if evidence:
        if evidence.get("schema_version") != 1:
            errors.append("physical soak evidence schema_version must be 1")
        if evidence.get("roadmap_step") != "11.3":
            errors.append("physical soak evidence roadmap_step must be 11.3")
        if evidence.get("application_id") != PACKAGE_ID:
            errors.append("physical soak evidence application_id mismatch")

        candidate = evidence.get("candidate", {})
        if not isinstance(candidate, dict):
            errors.append("candidate evidence must be an object")
            candidate = {}
        source_head = str(candidate.get("source_head", "")).lower()
        apk_sha = str(candidate.get("apk_sha256", "")).lower()
        if not FULL_SHA_RE.fullmatch(source_head):
            errors.append("candidate.source_head must be a full 40-character Git SHA")
        if not SHA256_RE.fullmatch(apk_sha):
            errors.append("candidate.apk_sha256 must be a lowercase SHA-256")
        for integer_key in ("workflow_run_id", "apk_artifact_id"):
            try:
                if int(candidate.get(integer_key, 0)) <= 0:
                    raise ValueError
            except (TypeError, ValueError):
                errors.append(f"candidate.{integer_key} must be a positive integer")

        emulator = evidence.get("emulator_preflight", {})
        if not isinstance(emulator, dict):
            errors.append("emulator_preflight must be an object")
            emulator = {}
        if emulator.get("is_physical_evidence") is not False:
            errors.append("emulator_preflight.is_physical_evidence must remain false")
        for api_key in ("api_29", "api_34"):
            row = emulator.get(api_key, {})
            if not isinstance(row, dict):
                errors.append(f"emulator_preflight.{api_key} must be an object")
                continue
            if row.get("status") != "pass":
                errors.append(f"emulator_preflight.{api_key}.status must be pass")
            if row.get("low_memory_kill_detected") is not False:
                errors.append(f"emulator_preflight.{api_key} must have no low-memory kill")
            try:
                max_pss = int(row.get("max_pss_kb", -1))
            except (TypeError, ValueError):
                max_pss = -1
            if max_pss < 0 or max_pss > MAX_PSS_KB:
                errors.append(f"emulator_preflight.{api_key}.max_pss_kb exceeds {MAX_PSS_KB}")

        physical = evidence.get("physical_device", {})
        if not isinstance(physical, dict):
            errors.append("physical_device must be an object")
            physical = {}

        if args.certify:
            if physical.get("source") != "physical":
                errors.append("physical_device.source must be physical")
            for field in ("manufacturer", "model", "android_release"):
                if not str(physical.get(field, "")).strip():
                    errors.append(f"physical_device.{field} missing")
            try:
                api_level = int(physical.get("api_level", 0))
            except (TypeError, ValueError):
                api_level = 0
            if api_level < 24:
                errors.append("physical_device.api_level must be >= 24")

            start = parse_dt(physical.get("started_at"), "physical_device.started_at", errors)
            end = parse_dt(physical.get("ended_at"), "physical_device.ended_at", errors)
            try:
                soak_seconds = int(physical.get("soak_seconds", 0))
            except (TypeError, ValueError):
                soak_seconds = 0
            if soak_seconds < MIN_SOAK_SECONDS:
                errors.append(f"physical_device.soak_seconds must be >= {MIN_SOAK_SECONDS}")
            if start is not None and end is not None:
                elapsed = int((end - start).total_seconds())
                if elapsed < MIN_SOAK_SECONDS:
                    errors.append(f"physical device timestamps prove only {elapsed}s; need >= {MIN_SOAK_SECONDS}s")
                if soak_seconds > elapsed + 10:
                    errors.append("physical_device.soak_seconds cannot materially exceed timestamp duration")

            if str(physical.get("tested_apk_sha256", "")).lower() != apk_sha:
                errors.append("physical device tested APK SHA-256 does not match candidate APK")

            metrics = physical.get("metrics", {})
            if not isinstance(metrics, dict):
                errors.append("physical_device.metrics must be an object")
                metrics = {}
            limits = {
                "cold_launch_ms": MAX_COLD_LAUNCH_MS,
                "resume_p95_ms": MAX_RESUME_P95_MS,
                "max_pss_kb": MAX_PSS_KB,
                "soak_pss_drift_kb": MAX_SOAK_PSS_DRIFT_KB,
            }
            for key, limit in limits.items():
                try:
                    value = int(metrics.get(key, -1))
                except (TypeError, ValueError):
                    value = -1
                if value < 0 or value > limit:
                    errors.append(f"physical_device.metrics.{key} must be between 0 and {limit}")
            try:
                resume_samples = int(metrics.get("resume_samples", 0))
            except (TypeError, ValueError):
                resume_samples = 0
            if resume_samples != REQUIRED_RESUME_SAMPLES:
                errors.append(f"physical_device.metrics.resume_samples must equal {REQUIRED_RESUME_SAMPLES}")
            failures = metrics.get("failures", None)
            if failures != []:
                errors.append("physical_device.metrics.failures must be an empty array")
            try:
                crash_or_anr_count = int(metrics.get("crash_or_anr_count", -1))
            except (TypeError, ValueError):
                crash_or_anr_count = -1
            if crash_or_anr_count != 0:
                errors.append("physical_device.metrics.crash_or_anr_count must be 0")

            raw = physical.get("raw_evidence", {})
            if not isinstance(raw, dict):
                errors.append("physical_device.raw_evidence must be an object")
                raw = {}
            for key in (
                "battery_before_captured",
                "battery_after_captured",
                "thermal_before_captured",
                "thermal_after_captured",
                "logcat_captured",
            ):
                require_bool(raw, key, errors)
            archive_sha = str(raw.get("archive_sha256", "")).lower()
            if not SHA256_RE.fullmatch(archive_sha):
                errors.append("physical_device.raw_evidence.archive_sha256 must be a SHA-256")

            observations = physical.get("operator_observations", {})
            if not isinstance(observations, dict):
                errors.append("physical_device.operator_observations must be an object")
                observations = {}
            for key in (
                "no_crash",
                "no_unusable_thermal_condition",
                "no_visual_corruption",
                "input_remained_responsive",
            ):
                require_bool(observations, key, errors)
            if not str(physical.get("operator", "")).strip():
                errors.append("physical_device.operator missing")

            if evidence.get("formal_status") != "certified":
                errors.append("formal_status must be certified in --certify mode")
            if evidence.get("pass_recorded") is not True:
                errors.append("pass_recorded must be true in --certify mode")
        else:
            if evidence.get("pass_recorded") is True or evidence.get("formal_status") == "certified":
                warnings.append("evidence already claims certification; use --certify to verify the final record")
            elif physical.get("source") != "physical" or int(physical.get("soak_seconds", 0) or 0) < MIN_SOAK_SECONDS:
                warnings.append("physical device run >=1800s is still pending")

    report = {
        "schema_version": 1,
        "roadmap_step": "11.3",
        "mode": "certify" if args.certify else "preflight",
        "evidence_path": str(args.evidence),
        "thresholds": {
            "minimum_soak_seconds": MIN_SOAK_SECONDS,
            "max_cold_launch_ms": MAX_COLD_LAUNCH_MS,
            "required_resume_samples": REQUIRED_RESUME_SAMPLES,
            "max_resume_p95_ms": MAX_RESUME_P95_MS,
            "max_pss_kb": MAX_PSS_KB,
            "max_soak_pss_drift_kb": MAX_SOAK_PSS_DRIFT_KB,
        },
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print(f"PHYSICAL_ANDROID_SOAK_GATE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    mode = "CERTIFY" if args.certify else "PREFLIGHT"
    print(f"PHYSICAL_ANDROID_SOAK_GATE {mode} PASS: warnings={len(warnings)}")
    for warning in warnings:
        print("WARNING:", warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
