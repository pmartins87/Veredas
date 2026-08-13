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
BILLING = ROOT / "mobile" / "play_billing_contract.json"
EXPORT = ROOT / "export_presets.cfg"
POLICY = ROOT / "docs" / "PRIVACY_POLICY_DRAFT.md"
VERIFIER_CLIENT = ROOT / "mobile" / "PlayPurchaseVerificationClient.gd"
PURCHASE_REFERENCE = ROOT / "core" / "systems" / "PurchaseReference.gd"
ENTITLEMENT = ROOT / "core" / "systems" / "EntitlementEngine.gd"
PLUGIN_ROOT = ROOT / "addons" / "GodotGooglePlayBilling"
RUNTIME_DIRS = [ROOT / "core", ROOT / "ui", ROOT / "scenes", ROOT / "mobile"]
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
EXPECTED_NETWORK_ALLOWLIST = {
    ("mobile/PlayPurchaseVerificationClient.gd", "HTTPRequest"),
    ("mobile/PlayPurchaseVerificationClient.gd", "HTTPClient"),
}


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
        help="Fail on every unresolved publication placeholder and require final privacy and billing data-flow declarations.",
    )
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []

    for required in (
        PRIVACY, COMMERCIAL, IDENTITY, BILLING, EXPORT, POLICY, VERIFIER_CLIENT,
        PURCHASE_REFERENCE, ENTITLEMENT,
    ):
        if not required.exists():
            errors.append(f"required privacy/release file missing: {required.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1

    privacy = read_json(PRIVACY)
    commercial = read_json(COMMERCIAL)
    identity = read_json(IDENTITY)
    billing = read_json(BILLING)
    export_text = EXPORT.read_text(encoding="utf-8")
    policy_text = POLICY.read_text(encoding="utf-8")
    verifier_text = VERIFIER_CLIENT.read_text(encoding="utf-8")
    reference_text = PURCHASE_REFERENCE.read_text(encoding="utf-8")
    entitlement_text = ENTITLEMENT.read_text(encoding="utf-8")

    if privacy.get("roadmap_step") != "12.3":
        errors.append("privacy manifest must identify roadmap_step 12.3")
    if int(privacy.get("schema_version", 0)) < 4:
        errors.append("privacy manifest schema must include Billing network plus hashed local/server persistence boundaries")
    if billing.get("roadmap_step") != "12.4":
        errors.append("billing contract must identify roadmap_step 12.4")

    privacy_app_id = str(privacy.get("application_id", ""))
    identity_android = identity.get("android", {})
    identity_app_id = str(identity_android.get("application_id", "")) if isinstance(identity_android, dict) else ""
    billing_app_id = str(billing.get("application_id", ""))
    if not privacy_app_id or privacy_app_id != identity_app_id or privacy_app_id != billing_app_id:
        errors.append(
            f"application id mismatch: privacy={privacy_app_id!r} identity={identity_app_id!r} billing={billing_app_id!r}"
        )
    if export_text.count(f'package/unique_name="{identity_app_id}"') != 2:
        errors.append("export presets are not aligned with privacy/release application id")

    principles = commercial.get("principles", {})
    behavior = privacy.get("current_application_behavior", {})
    if isinstance(principles, dict) and isinstance(behavior, dict):
        if bool(principles.get("no_ads", False)) != (not bool(behavior.get("advertising", True))):
            errors.append("commercial no-ads policy disagrees with privacy behavior")
        if behavior.get("internet_permission") is not True:
            errors.append("privacy manifest must explicitly declare INTERNET permission")
        if behavior.get("gameplay_profile_transmitted_off_device") is not False:
            errors.append("current privacy baseline forbids gameplay profile transmission")
        if behavior.get("canonical_game_content_transmitted_off_device") is not False:
            errors.append("current privacy baseline forbids canonical content transmission")
    else:
        errors.append("commercial/privacy behavior objects missing")

    if export_text.count("permissions/internet=true") != 2:
        errors.append("INTERNET permission must be explicit in both Android presets for billing verification")
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
    if allowlisted_pairs != EXPECTED_NETWORK_ALLOWLIST:
        errors.append(
            "runtime network allowlist drift: expected=%s got=%s"
            % (sorted(EXPECTED_NETWORK_ALLOWLIST), sorted(allowlisted_pairs))
        )
    for row in allowlisted:
        if not isinstance(row, dict):
            errors.append("runtime data integration allowlist row is not an object")
            continue
        if row.get("gameplay_data_allowed") is not False:
            errors.append(
                f"allowlisted network integration must forbid gameplay data: {row.get('path')}:{row.get('token')}"
            )
        if not str(row.get("purpose", "")).strip():
            errors.append("allowlisted network integration purpose missing")

    observed_network_pairs = {(hit["path"], hit["token"]) for hit in network_hits}
    undeclared_hits = [
        hit for hit in network_hits + sdk_hits
        if (hit["path"], hit["token"]) not in allowlisted_pairs
    ]
    if undeclared_hits:
        errors.append(
            "undeclared runtime network/SDK integration(s): "
            + ", ".join(f"{hit['path']}:{hit['token']}" for hit in undeclared_hits[:20])
        )
    missing_observed_allowlist = EXPECTED_NETWORK_ALLOWLIST - observed_network_pairs
    if missing_observed_allowlist:
        errors.append(f"declared billing network implementation missing from runtime scan: {sorted(missing_observed_allowlist)}")
    if sdk_hits:
        errors.append(
            "unexpected analytics/advertising/crash SDK token(s) in runtime: "
            + ", ".join(f"{hit['path']}:{hit['token']}" for hit in sdk_hits[:20])
        )

    for fragment in [
        'normalized.begins_with("https://")',
        '"Cache-Control: no-store"',
        '"verification_request_id"',
        '"purchase_token"',
        '"product_id"',
    ]:
        if fragment not in verifier_text:
            errors.append(f"billing network privacy boundary missing client fragment: {fragment}")

    commercial_behavior = privacy.get("commercial_behavior", {})
    local_cache = commercial_behavior.get("local_entitlement_cache", {}) if isinstance(commercial_behavior, dict) else {}
    if not isinstance(local_cache, dict):
        errors.append("local entitlement cache privacy section missing")
        local_cache = {}
    if local_cache.get("schema_version") != 2:
        errors.append("local entitlement cache privacy schema must match EntitlementEngine schema 2")
    if local_cache.get("raw_purchase_token_at_rest") is not False:
        errors.append("raw purchase token at rest is forbidden in local entitlement cache")
    if local_cache.get("purchase_token_sha256_reference_at_rest") is not True:
        errors.append("local entitlement cache must retain only a SHA-256 purchase reference")
    if str(local_cache.get("reference_format", "")) != "sha256:<64 lowercase hexadecimal characters>":
        errors.append("local purchase-reference format drifted")
    if int(local_cache.get("schema_version", 0)) != 2 or "const SCHEMA_VERSION := 2" not in entitlement_text:
        errors.append("privacy/local EntitlementEngine schema mismatch")
    if "purchase_token" in entitlement_text:
        errors.append("EntitlementEngine must not know or persist raw purchase tokens")
    for fragment in [
        'const PREFIX := "sha256:"',
        "HashingContext.HASH_SHA256",
        "digest.hex_encode()",
        "static func normalize_persisted",
    ]:
        if fragment not in reference_text:
            errors.append(f"local purchase-reference privacy implementation missing: {fragment}")

    account_creation = bool(behavior.get("account_creation", False)) if isinstance(behavior, dict) else False
    if account_creation:
        deletion = privacy.get("account_deletion", {})
        if not isinstance(deletion, dict) or deletion.get("implemented") is not True:
            errors.append("account creation is enabled without a declared implemented account-deletion path")

    privacy_pending = pending_markers(privacy)
    billing_pending = [f"billing:{path}" for path in pending_markers(billing)]
    policy_pending = [
        f"policy:{marker}"
        for marker in sorted(set(re.findall(r"PENDING_[A-Z0-9_]+", policy_text)))
    ]
    pending = privacy_pending + billing_pending + policy_pending

    data_safety = privacy.get("data_safety_candidate", {})
    production_verification = (
        commercial_behavior.get("production_purchase_verification", {})
        if isinstance(commercial_behavior, dict)
        else {}
    )
    policy = privacy.get("privacy_policy", {})
    billing_verification = billing.get("verification_boundary", {})

    if not isinstance(production_verification, dict):
        errors.append("production purchase-verification privacy section missing")
        production_verification = {}
    if production_verification.get("runtime_client") != "mobile/PlayPurchaseVerificationClient.gd":
        errors.append("privacy manifest runtime verification client mismatch")
    if production_verification.get("data_safety_reaudit_required_after_integration") is not True:
        errors.append("post-billing Data Safety re-audit must remain mandatory")
    excluded = production_verification.get("explicitly_excluded_from_billing_verification", [])
    if not isinstance(excluded, list) or "gameplay profile" not in excluded or "save data" not in excluded:
        errors.append("billing verification privacy boundary must explicitly exclude gameplay profile and save data")
    backend_persistence = production_verification.get("reference_backend_persistence", {})
    if not isinstance(backend_persistence, dict):
        errors.append("backend persistence privacy declaration missing")
        backend_persistence = {}
    if backend_persistence.get("raw_purchase_token_at_rest") is not False:
        errors.append("raw purchase token at rest is forbidden in reference backend")
    if backend_persistence.get("purchase_token_hash_at_rest") is not True:
        errors.append("reference backend must persist only purchase-token hash/minimum state")
    if backend_persistence.get("order_id_at_rest") is not False:
        errors.append("order id persistence is outside the minimized backend contract")
    if backend_persistence.get("durable_record_required_before_owned_response") is not True:
        errors.append("privacy/backend contract must require durable final persistence before owned response")

    if args.release:
        if pending:
            errors.append(f"release privacy/billing contract has {len(pending)} unresolved PENDING field(s)")
        if not isinstance(data_safety, dict) or data_safety.get("finalized") is not True:
            errors.append("final Play Data Safety declaration has not been frozen")
        if production_verification.get("status") != "frozen":
            errors.append("12.4 purchase-verification data flow is not frozen in privacy manifest")
        if not isinstance(billing_verification, dict) or billing_verification.get("status") != "frozen":
            errors.append("12.4 billing verification boundary is not frozen")
        if billing.get("formal_status") != "certified" or billing.get("pass_recorded") is not True:
            errors.append("12.4 production billing is not certified")
        if not PLUGIN_ROOT.exists():
            errors.append("pinned GodotGooglePlayBilling addon is not installed")
        if not isinstance(policy, dict) or not str(policy.get("public_url", "")).startswith("https://"):
            errors.append("privacy policy public HTTPS URL is not finalized")
        if not isinstance(policy, dict) or policy.get("in_app_access") != "implemented":
            errors.append("final privacy policy is not accessible in-app")
        if privacy.get("formal_status") != "certified":
            errors.append("12.3 privacy state is not certified")
    elif pending:
        warnings.append(f"preflight retains {len(pending)} publication/billing placeholder(s), expected before final 12.3/12.4 freeze")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "PRIVACY_DATA_SAFETY %s: network_hits=%d allowlisted=%d sdk_hits=%d pending=%d errors=%d warnings=%d billing_network_only=1 raw_token_local_at_rest=0 raw_token_backend_at_rest=0"
        % (
            mode,
            len(network_hits),
            len(allowlisted_pairs),
            len(sdk_hits),
            len(pending),
            len(errors),
            len(warnings),
        )
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"PRIVACY_DATA_SAFETY FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PRIVACY_DATA_SAFETY PASS: declared app behavior and minimized Billing data boundaries are internally consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
