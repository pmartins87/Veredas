#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "mobile" / "play_billing_contract.json"
COMMERCIAL = ROOT / "product" / "commercial_model.json"
PRIVACY = ROOT / "product" / "privacy_data_safety.json"
IDENTITY = ROOT / "mobile" / "release_identity.json"
EXPORT = ROOT / "export_presets.cfg"
COORDINATOR = ROOT / "core" / "systems" / "PlayBillingCoordinator.gd"
ADAPTER = ROOT / "mobile" / "GooglePlayBillingStoreAdapter.gd"
CERT = ROOT / "tests" / "PlayBillingCoordinatorCertification.gd"
CERT_SCENE = ROOT / "tests" / "play_billing_coordinator_certification.tscn"
PLUGIN_ROOT = ROOT / "addons" / "GodotGooglePlayBilling"


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def pending_paths(value: Any, path: str = "") -> list[str]:
    found: list[str] = []
    if isinstance(value, dict):
        for key, item in value.items():
            child = f"{path}.{key}" if path else str(key)
            found.extend(pending_paths(item, child))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            found.extend(pending_paths(item, f"{path}[{index}]"))
    elif isinstance(value, str) and "PENDING_12_4" in value:
        found.append(path)
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate production Google Play Billing contract for roadmap 12.4.")
    parser.add_argument("--release", action="store_true", help="Require frozen backend, installed plugin, Play Console evidence and post-billing privacy freeze.")
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    required = [CONTRACT, COMMERCIAL, PRIVACY, IDENTITY, EXPORT, COORDINATOR, ADAPTER, CERT, CERT_SCENE]
    for path in required:
        if not path.exists():
            errors.append(f"required billing file missing: {path.relative_to(ROOT)}")
    if errors:
        print("PLAY_BILLING_RELEASE_GATE FAIL")
        for error in errors:
            print("ERROR:", error)
        return 1

    contract = read_json(CONTRACT)
    commercial = read_json(COMMERCIAL)
    privacy = read_json(PRIVACY)
    identity = read_json(IDENTITY)
    export_text = EXPORT.read_text(encoding="utf-8")
    coordinator_text = COORDINATOR.read_text(encoding="utf-8")
    adapter_text = ADAPTER.read_text(encoding="utf-8")
    cert_text = CERT.read_text(encoding="utf-8")

    if contract.get("roadmap_step") != "12.4":
        errors.append("billing contract must identify roadmap_step 12.4")
    application_id = str(contract.get("application_id", ""))
    identity_android = identity.get("android", {}) if isinstance(identity, dict) else {}
    if application_id != str(identity_android.get("application_id", "")):
        errors.append("billing application id disagrees with release identity")
    if export_text.count(f'package/unique_name="{application_id}"') != 2:
        errors.append("Android export presets disagree with billing application id")

    store = contract.get("store", {})
    if not isinstance(store, dict):
        errors.append("billing store contract missing")
        store = {}
    if store.get("provider") != "Google Play Billing":
        errors.append("production billing provider must be Google Play Billing")
    if store.get("godot_plugin") != "GodotGooglePlayBilling":
        errors.append("first-party GodotGooglePlayBilling plugin not pinned")
    if str(store.get("plugin_version", "")) != "3.3.0":
        errors.append("review/update gate before changing pinned billing plugin version")
    if store.get("gradle_build_required") is not True:
        errors.append("billing contract must require Gradle Android export")

    products = contract.get("products", [])
    commercial_products = commercial.get("products", [])
    contract_ids = {
        str(row.get("product_id", ""))
        for row in products
        if isinstance(row, dict)
    }
    commercial_ids = {
        str(row.get("id", ""))
        for row in commercial_products
        if isinstance(row, dict)
    }
    expected_ids = {"full_game_unlock", "supporter_cosmetic_pack"}
    if contract_ids != expected_ids or commercial_ids != expected_ids:
        errors.append(
            f"paid product set mismatch: contract={sorted(contract_ids)} commercial={sorted(commercial_ids)}"
        )
    for row in products:
        if not isinstance(row, dict):
            errors.append("billing product row is not an object")
            continue
        if row.get("consumable") is not False or row.get("repeatable") is not False:
            errors.append(f"12.4 release product must remain non-consumable/non-repeatable: {row.get('product_id')}")

    verification = contract.get("verification_boundary", {})
    if not isinstance(verification, dict):
        errors.append("verification boundary missing")
        verification = {}
    if verification.get("mode") != "secure_backend_required":
        errors.append("client-only purchase verification is forbidden")
    if verification.get("deduplication_key") != "purchase_token":
        errors.append("purchase_token must be the deduplication key")
    if verification.get("order_id_is_not_deduplication_key") is not True:
        errors.append("order_id duplicate guard is missing")
    if verification.get("server_acknowledges_non_consumables") is not True:
        errors.append("verified non-consumables must be acknowledged by backend contract")

    for required_fragment in [
        'PURCHASED_STATE := 1',
        'PENDING_STATE := 2',
        '"acknowledged"',
        '"play_backend"',
        'apply_authoritative_snapshot',
        'apply_purchase_result',
        'partial',
    ]:
        if required_fragment not in coordinator_text and required_fragment != "partial":
            errors.append(f"coordinator security contract missing fragment: {required_fragment}")
    for required_fragment in [
        "BILLING_CLIENT_SCRIPT",
        "query_product_details",
        "query_purchases",
        "on_purchase_updated",
        "get_script_constant_map",
    ]:
        if required_fragment not in adapter_text:
            errors.append(f"billing adapter contract missing fragment: {required_fragment}")
    for required_fragment in [
        "pending_no_grant=1",
        "verify_fail_no_grant=1",
        "ack_required=1",
        "authoritative_restore=1",
        "partial_failure_cache_safe=1",
        "package_guard=1",
    ]:
        if required_fragment not in cert_text:
            errors.append(f"billing certification lacks gate marker: {required_fragment}")

    privacy_commercial = privacy.get("commercial_behavior", {})
    production_verification = (
        privacy_commercial.get("production_purchase_verification", {})
        if isinstance(privacy_commercial, dict)
        else {}
    )
    if not isinstance(production_verification, dict):
        errors.append("privacy purchase-verification section missing")
        production_verification = {}
    if production_verification.get("data_safety_reaudit_required_after_integration") is not True:
        errors.append("post-billing Data Safety re-audit must remain mandatory")

    pending = pending_paths(contract)
    plugin_installed = PLUGIN_ROOT.exists()

    if args.release:
        if pending:
            errors.append(f"12.4 release contract has {len(pending)} unresolved PENDING_12_4 field(s)")
        if contract.get("formal_status") != "certified" or contract.get("pass_recorded") is not True:
            errors.append("12.4 contract is not certified")
        if verification.get("status") != "frozen":
            errors.append("purchase verification backend is not frozen")
        endpoint = str(verification.get("backend_endpoint", ""))
        if not endpoint.startswith("https://"):
            errors.append("production purchase verification endpoint must be HTTPS")
        if not plugin_installed:
            errors.append("pinned GodotGooglePlayBilling addon is not installed")
        if production_verification.get("status") != "frozen":
            errors.append("privacy manifest has not frozen post-integration billing data flow")
        if privacy.get("formal_status") != "certified":
            errors.append("12.3 must be certified after final 12.4 integration")
    else:
        if pending:
            warnings.append(f"12.4 preflight retains {len(pending)} backend placeholder(s)")
        if not plugin_installed:
            warnings.append("pinned billing addon is not installed yet; allowed only before release certification")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "PLAY_BILLING_RELEASE_GATE %s: products=%d plugin=%s pending=%d errors=%d warnings=%d"
        % (mode, len(contract_ids), "installed" if plugin_installed else "pending", len(pending), len(errors), len(warnings))
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"PLAY_BILLING_RELEASE_GATE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PLAY_BILLING_RELEASE_GATE PASS: billing contract is internally consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
