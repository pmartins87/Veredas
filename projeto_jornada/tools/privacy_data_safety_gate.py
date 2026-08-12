#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PRIVACY = ROOT / "product" / "privacy_data_safety.json"
COMMERCIAL = ROOT / "product" / "commercial_model.json"
IDENTITY = ROOT / "mobile" / "release_identity.json"
EXPORT = ROOT / "export_presets.cfg"
POLICY = ROOT / "docs" / "PRIVACY_POLICY_DRAFT.md"
RUNTIME_DIRS = [ROOT / "core", ROOT / "ui", ROOT / "scenes"]
NETWORK_TOKENS = (
    "HTTPRequest",
    "HTTPClient",
    "WebSocketPeer",
    "WebSocketMultiplayerPeer",
    "StreamPeerTCP",
    "PacketPeerUDP",
)
SDK_TOKENS = (
    "Firebase",
    "AdMob",
    "GoogleAnalytics",
    "AppsFlyer",
    "Adjust",
    "Amplitude",
    "Sentry",
)


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def runtime_hits(tokens: tuple[str, ...]) -> list[dict[str, str]]:
    hits: list[dict[str, str]] = []
    for directory in RUNTIME_DIRS:
        if not directory.exists():
            continue
        for path in directory.rglob("*.gd"):
            text = path.read_text(encoding="utf-8")
            for token in tokens:
                if token in text:
                    hits.append({"path": str(path.relative_to(ROOT)), "token": token})
    return hits


def pending_markers(value: Any, path: str = "") -> list[str]:
    found: list[str] = []
    if isinstance(value, dict):
        for key, item in value.items():
            child = f"{path}.{key}" if path else str(key)
            found.extend(pending_markers(item, child))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            found.extend(pending_markers(item, f"{path}[{index}]"))
    elif isinstance(value, str) and "PENDING_" in value:
        found.append(path)
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit Veredas privacy/Data Safety release contract.")
    parser.add_argument(
        "--release",
        action="store_true",
        help="Fail on every unresolved publication placeholder and require the final Data Safety declaration.",
    )
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []

    for required in (PRIVACY, COMMERCIAL, IDENTITY, EXPORT, POLICY):
        if not required.exists():
            errors.append(f"required privacy/release file missing: {required.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1

    privacy = read_json(PRIVACY)
    commercial = read_json(COMMERCIAL)
    identity = read_json(IDENTITY)
    export_text = EXPORT.read_text(encoding="utf-8")
    policy_text = POLICY.read_text(encoding="utf-8")

    if privacy.get("roadmap_step") != "12.3":
        errors.append("privacy manifest must identify roadmap_step 12.3")

    privacy_app_id = str(privacy.get("application_id", ""))
    identity_android = identity.get("android", {})
    identity_app_id = str(identity_android.get("application_id", "")) if isinstance(identity_android, dict) else ""
    if not privacy_app_id or privacy_app_id != identity_app_id:
        errors.append(
            f"application id mismatch: privacy={privacy_app_id!r} identity={identity_app_id!r}"
        )
    if export_text.count(f'package/unique_name="{identity_app_id}"') != 2:
        errors.append("export presets are not aligned with privacy/release application id")

    principles = commercial.get("principles", {})
    behavior = privacy.get("current_application_behavior", {})
    if isinstance(principles, dict) and isinstance(behavior, dict):
        if bool(principles.get("no_ads", False)) != (not bool(behavior.get("advertising", True))):
            errors.append("commercial no-ads policy disagrees with privacy behavior")
    else:
        errors.append("commercial/privacy behavior objects missing")

    custom_permission_matches = re.findall(
        r"permissions/custom_permissions=PackedStringArray\((.*?)\)", export_text
    )
    nonempty_custom_permissions = [value for value in custom_permission_matches if value.strip()]
    if nonempty_custom_permissions:
        errors.append("custom Android permissions exist but privacy manifest currently declares none")
    if len(custom_permission_matches) != 2:
        errors.append("expected explicit custom-permission field in both Android presets")

    network_hits = runtime_hits(NETWORK_TOKENS)
    sdk_hits = runtime_hits(SDK_TOKENS)
    allowlisted = privacy.get("allowlisted_runtime_data_integrations", [])
    if not isinstance(allowlisted, list):
        allowlisted = []
    allowlisted_pairs = {
        (str(row.get("path", "")), str(row.get("token", "")))
        for row in allowlisted
        if isinstance(row, dict)
    }
    undeclared_hits = [
        hit for hit in network_hits + sdk_hits
        if (hit["path"], hit["token"]) not in allowlisted_pairs
    ]
    if undeclared_hits:
        errors.append(
            "undeclared runtime network/SDK integration(s): "
            + ", ".join(f"{hit['path']}:{hit['token']}" for hit in undeclared_hits[:20])
        )

    account_creation = bool(behavior.get("account_creation", False)) if isinstance(behavior, dict) else False
    if account_creation:
        deletion = privacy.get("account_deletion", {})
        if not isinstance(deletion, dict) or deletion.get("implemented") is not True:
            errors.append("account creation is enabled without a declared implemented account-deletion path")

    privacy_pending = pending_markers(privacy)
    policy_pending = [
        f"policy:{marker}"
        for marker in sorted(set(re.findall(r"PENDING_[A-Z0-9_]+", policy_text)))
    ]
    pending = privacy_pending + policy_pending

    data_safety = privacy.get("data_safety_candidate", {})
    production_verification = (
        privacy.get("commercial_behavior", {})
        .get("production_purchase_verification", {})
        if isinstance(privacy.get("commercial_behavior", {}), dict)
        else {}
    )
    policy = privacy.get("privacy_policy", {})

    if args.release:
        if pending:
            errors.append(f"release privacy contract has {len(pending)} unresolved PENDING field(s)")
        if not isinstance(data_safety, dict) or data_safety.get("finalized") is not True:
            errors.append("final Play Data Safety declaration has not been frozen")
        if not isinstance(production_verification, dict) or production_verification.get("status") != "frozen":
            errors.append("12.4 purchase-verification data flow is not frozen")
        if not isinstance(policy, dict) or not str(policy.get("public_url", "")).startswith("https://"):
            errors.append("privacy policy public HTTPS URL is not finalized")
        if not isinstance(policy, dict) or policy.get("in_app_access") != "implemented":
            errors.append("final privacy policy is not accessible in-app")
        if privacy.get("formal_status") != "certified":
            errors.append("12.3 privacy state is not certified")
    elif pending:
        warnings.append(f"preflight retains {len(pending)} publication placeholder(s), expected before 12.4/final store setup")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "PRIVACY_DATA_SAFETY %s: network_hits=%d sdk_hits=%d pending=%d errors=%d warnings=%d"
        % (mode, len(network_hits), len(sdk_hits), len(pending), len(errors), len(warnings))
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"PRIVACY_DATA_SAFETY FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PRIVACY_DATA_SAFETY PASS: declared app behavior is internally consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
