#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INVENTORY = ROOT / "product" / "android_dependency_inventory.json"
BILLING = ROOT / "mobile" / "play_billing_contract.json"
PROVENANCE = ROOT / "product" / "release_provenance.json"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate exact Android releaseRuntimeClasspath evidence for Veredas 12.9.")
    parser.add_argument("--inventory", type=Path, default=DEFAULT_INVENTORY)
    parser.add_argument("--require-evidence", action="store_true")
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    try:
        billing = read_json(BILLING)
        provenance = read_json(PROVENANCE)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ANDROID_DEPENDENCY_INVENTORY FAIL: {exc}")
        return 1

    required_now = args.require_evidence or args.release
    evidence_exists = args.inventory.is_file()
    if not evidence_exists:
        message = f"Android dependency inventory missing: {args.inventory}"
        if required_now:
            errors.append(message)
        else:
            warnings.append(message + "; expected until the final Billing plugin/Gradle release project exists")
        inventory: dict[str, Any] = {}
    else:
        try:
            inventory = read_json(args.inventory)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            errors.append(str(exc))
            inventory = {}

    component_count = 0
    billing_components: list[dict[str, Any]] = []
    local_components = 0
    if evidence_exists and not errors:
        if inventory.get("schema_version") != 1 or inventory.get("roadmap_step") != "12.9":
            errors.append("Android dependency inventory schema/roadmap_step invalid")
        if inventory.get("application_id") != billing.get("application_id"):
            errors.append("Android dependency inventory application id mismatch")
        if inventory.get("scope") != "android_release_runtime_classpath":
            errors.append("Android dependency inventory scope must be android_release_runtime_classpath")
        if inventory.get("generator") != "tools/gradle_dependency_inventory.init.gradle":
            errors.append("Android dependency inventory generator mismatch")
        if inventory.get("all_artifacts_sha256_bound") is not True:
            errors.append("Android dependency inventory must hash-bind every resolved artifact")

        configurations = inventory.get("configurations", [])
        if not isinstance(configurations, list) or not configurations:
            errors.append("Android dependency inventory configurations missing")
            configurations = []
        for row in configurations:
            if not isinstance(row, dict) or row.get("configuration") != "releaseRuntimeClasspath":
                errors.append(f"Android inventory contains non-release runtime configuration: {row}")

        components = inventory.get("components", [])
        if not isinstance(components, list) or not components:
            errors.append("Android dependency inventory components missing")
            components = []
        artifact_keys: set[str] = set()
        for index, row in enumerate(components):
            if not isinstance(row, dict):
                errors.append(f"Android dependency row {index} is not an object")
                continue
            component_count += 1
            artifact_key = str(row.get("artifact_key", ""))
            if not artifact_key or artifact_key in artifact_keys:
                errors.append(f"Android artifact_key missing/duplicate: {artifact_key!r}")
            artifact_keys.add(artifact_key)
            digest = str(row.get("file_sha256", "")).lower()
            if not SHA256_RE.fullmatch(digest):
                errors.append(f"Android artifact SHA-256 missing/invalid: {artifact_key}")
            if not isinstance(row.get("bytes"), int) or int(row.get("bytes", 0)) <= 0:
                errors.append(f"Android artifact byte size invalid: {artifact_key}")
            if row.get("third_party") is not True:
                errors.append(f"Android dependency rows must default fail-closed as third_party=true: {artifact_key}")
            consumers = row.get("consumers", [])
            if not isinstance(consumers, list) or not consumers:
                errors.append(f"Android dependency consumer list missing: {artifact_key}")
            elif any(not str(value).endswith(":releaseRuntimeClasspath") for value in consumers):
                errors.append(f"Android dependency has non-release-runtime consumer: {artifact_key}:{consumers}")

            kind = str(row.get("kind", ""))
            component_key = str(row.get("component_key", ""))
            if kind == "maven_module":
                group = str(row.get("group", ""))
                name = str(row.get("name", ""))
                version = str(row.get("version", ""))
                expected_key = f"maven:{group}:{name}@{version}"
                if not group or not name or not version or component_key != expected_key:
                    errors.append(f"Android Maven identity/component_key mismatch: {artifact_key}")
                if group == "com.android.billingclient":
                    billing_components.append(row)
            elif kind == "local_file":
                local_components += 1
                if not component_key.startswith("local:") or "@sha256:" not in component_key:
                    errors.append(f"Android local dependency component_key invalid: {artifact_key}")
            else:
                errors.append(f"Android dependency kind invalid: {artifact_key}:{kind}")

        if int(inventory.get("component_count", -1)) != component_count:
            errors.append("Android dependency inventory component_count mismatch")

        store = billing.get("store", {})
        expected_billing_version = str(store.get("google_play_billing_library", "")) if isinstance(store, dict) else ""
        if not expected_billing_version:
            errors.append("Billing contract expected library version missing")
        if not billing_components:
            errors.append("final Android releaseRuntimeClasspath contains no com.android.billingclient component")
        else:
            observed_versions = {str(row.get("version", "")) for row in billing_components}
            if observed_versions != {expected_billing_version}:
                errors.append(
                    f"Google Play Billing runtime version drift: expected={expected_billing_version} observed={sorted(observed_versions)}"
                )

    if args.release and evidence_exists and not errors:
        if inventory.get("formal_status") != "certified" or inventory.get("pass_recorded") is not True:
            errors.append("persisted Android dependency inventory is not certified")
        software = provenance.get("software_inventory", {})
        if not isinstance(software, dict) or software.get("android_final_dependency_inventory_status") != "final_gradle_dependency_report_archived":
            errors.append("release provenance does not mark final Android dependency inventory archived")
    elif evidence_exists and local_components:
        warnings.append(f"Android inventory contains {local_components} local file dependency/dependencies; each requires explicit notice/provenance coverage")

    report = {
        "schema_version": 1,
        "roadmap_step": "12.9",
        "mode": "release" if args.release else ("required_evidence" if args.require_evidence else "preflight"),
        "evidence_present": evidence_exists,
        "component_count": component_count,
        "billing_component_count": len(billing_components),
        "local_component_count": local_components,
        "errors": errors,
        "warnings": warnings,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if errors:
        print(f"ANDROID_DEPENDENCY_INVENTORY FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    mode = "RELEASE" if args.release else ("REQUIRED" if args.require_evidence else "PREFLIGHT")
    print(
        "ANDROID_DEPENDENCY_INVENTORY %s PASS: evidence=%d components=%d billing_components=%d local=%d warnings=%d"
        % (mode, 1 if evidence_exists else 0, component_count, len(billing_components), local_components, len(warnings))
    )
    for warning in warnings:
        print("WARNING:", warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
