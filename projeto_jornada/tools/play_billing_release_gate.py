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
PROJECT = ROOT / "project.godot"
COORDINATOR = ROOT / "core" / "systems" / "PlayBillingCoordinator.gd"
COMMERCIAL_ENGINE = ROOT / "core" / "systems" / "CommercialPolicyEngine.gd"
ADAPTER = ROOT / "mobile" / "GooglePlayBillingStoreAdapter.gd"
VERIFIER_CLIENT = ROOT / "mobile" / "PlayPurchaseVerificationClient.gd"
BILLING_SERVICE = ROOT / "mobile" / "BillingService.gd"
HUB = ROOT / "scenes" / "Hub.gd"
JOURNEY_SETUP = ROOT / "scenes" / "JourneySetup.gd"
SUPPORTER_SEAL = ROOT / "ui" / "SupporterSeal.gd"
LOC_MANIFEST = ROOT / "localization" / "manifest.json"
LOC_PT = ROOT / "localization" / "ui" / "pt_BR.json"
LOC_EN = ROOT / "localization" / "ui" / "en.json"
CERT = ROOT / "tests" / "PlayBillingCoordinatorCertification.gd"
CERT_SCENE = ROOT / "tests" / "play_billing_coordinator_certification.tscn"
CORRELATION_CERT = ROOT / "tests" / "PlayBillingCorrelationCertification.gd"
CORRELATION_SCENE = ROOT / "tests" / "play_billing_correlation_certification.tscn"
VERIFIER_CERT = ROOT / "tests" / "PlayPurchaseVerificationClientCertification.gd"
VERIFIER_SCENE = ROOT / "tests" / "play_purchase_verification_client_certification.tscn"
PLUGIN_ROOT = ROOT / "addons" / "GodotGooglePlayBilling"

EXPECTED_PRODUCTS = {"full_game_unlock", "supporter_cosmetic_pack"}
EXPECTED_SUPPORTER_COSMETICS = ["supporter_badge"]
EXPECTED_VERIFICATION_API = "purchases.productsv2.getproductpurchasev2"
EXPECTED_ACK_API = "purchases.products.acknowledge"
EXPECTED_CORRELATION = "verification_request_id_must_echo_exactly"
BILLING_UI_KEYS = {
    "hub.billing.section",
    "hub.billing.full_owned",
    "hub.billing.supporter_owned",
    "hub.billing.unlock_full",
    "hub.billing.buy_supporter",
    "hub.billing.restore",
    "hub.billing.unavailable",
    "hub.billing.pending",
    "hub.billing.failed",
    "hub.billing.restored",
    "hub.billing.supporter_badge",
    "journey_setup.entitlement_required",
}


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


def require_members(container: Any, expected: set[str], label: str, errors: list[str]) -> None:
    if not isinstance(container, list):
        errors.append(f"{label} must be an array")
        return
    present = {str(value) for value in container}
    missing = sorted(expected - present)
    if missing:
        errors.append(f"{label} missing required field(s): {missing}")


def require_fragments(text: str, fragments: list[str], label: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{label} missing fragment: {fragment}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate production Google Play Billing contract for roadmap 12.4.")
    parser.add_argument(
        "--release",
        action="store_true",
        help="Require frozen backend, installed plugin, Play Console evidence and post-billing privacy freeze.",
    )
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    required = [
        CONTRACT, COMMERCIAL, PRIVACY, IDENTITY, EXPORT, PROJECT,
        COORDINATOR, COMMERCIAL_ENGINE, ADAPTER, VERIFIER_CLIENT, BILLING_SERVICE,
        HUB, JOURNEY_SETUP, SUPPORTER_SEAL, LOC_MANIFEST, LOC_PT, LOC_EN,
        CERT, CERT_SCENE, CORRELATION_CERT, CORRELATION_SCENE, VERIFIER_CERT, VERIFIER_SCENE,
    ]
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
    loc_manifest = read_json(LOC_MANIFEST)
    loc_pt = read_json(LOC_PT)
    loc_en = read_json(LOC_EN)
    export_text = EXPORT.read_text(encoding="utf-8")
    project_text = PROJECT.read_text(encoding="utf-8")
    coordinator_text = COORDINATOR.read_text(encoding="utf-8")
    commercial_engine_text = COMMERCIAL_ENGINE.read_text(encoding="utf-8")
    adapter_text = ADAPTER.read_text(encoding="utf-8")
    verifier_text = VERIFIER_CLIENT.read_text(encoding="utf-8")
    service_text = BILLING_SERVICE.read_text(encoding="utf-8")
    hub_text = HUB.read_text(encoding="utf-8")
    journey_setup_text = JOURNEY_SETUP.read_text(encoding="utf-8")
    supporter_seal_text = SUPPORTER_SEAL.read_text(encoding="utf-8")
    cert_text = CERT.read_text(encoding="utf-8")
    correlation_cert_text = CORRELATION_CERT.read_text(encoding="utf-8")
    verifier_cert_text = VERIFIER_CERT.read_text(encoding="utf-8")

    if contract.get("roadmap_step") != "12.4":
        errors.append("billing contract must identify roadmap_step 12.4")
    if int(contract.get("schema_version", 0)) < 2:
        errors.append("billing contract schema must include async-correlation/ProductPurchaseV2 hardening")

    application_id = str(contract.get("application_id", ""))
    identity_android = identity.get("android", {}) if isinstance(identity, dict) else {}
    if application_id != str(identity_android.get("application_id", "")):
        errors.append("billing application id disagrees with release identity")
    if export_text.count(f'package/unique_name="{application_id}"') != 2:
        errors.append("Android export presets disagree with billing application id")
    if export_text.count("permissions/internet=true") != 2:
        errors.append("billing HTTPS verification requires INTERNET=true in both Android export presets")
    if 'BillingService="*res://mobile/BillingService.gd"' not in project_text:
        errors.append("BillingService runtime autoload is not registered")

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
    if str(store.get("google_play_billing_library", "")) != "9.1.0":
        errors.append("review/update gate before changing pinned Google Play Billing library version")
    if store.get("gradle_build_required") is not True:
        errors.append("billing contract must require Gradle Android export")
    if store.get("query_product_details_argument_type") != "PackedStringArray":
        errors.append("billing product query contract must use PackedStringArray for plugin 3.3.0")

    products = contract.get("products", [])
    commercial_products = commercial.get("products", [])
    contract_ids = {str(row.get("product_id", "")) for row in products if isinstance(row, dict)}
    commercial_ids = {str(row.get("id", "")) for row in commercial_products if isinstance(row, dict)}
    if contract_ids != EXPECTED_PRODUCTS or commercial_ids != EXPECTED_PRODUCTS:
        errors.append(
            f"paid product set mismatch: contract={sorted(contract_ids)} commercial={sorted(commercial_ids)}"
        )
    for row in products:
        if not isinstance(row, dict):
            errors.append("billing product row is not an object")
            continue
        product_id = str(row.get("product_id", ""))
        if row.get("consumable") is not False or row.get("repeatable") is not False:
            errors.append(f"12.4 release product must remain non-consumable/non-repeatable: {product_id}")
        if row.get("purchase_option_policy") != "single_buy_legacy_compatible":
            errors.append(f"launch product must retain a single deterministic buy option: {product_id}")
        for flag in ("offers_allowed_at_launch", "rent_allowed", "preorder_allowed"):
            if row.get(flag) is not False:
                errors.append(f"launch product option flag must remain false: {product_id}.{flag}")

    supporter_rows = [row for row in commercial_products if isinstance(row, dict) and row.get("id") == "supporter_cosmetic_pack"]
    if len(supporter_rows) != 1:
        errors.append("commercial model must contain exactly one supporter cosmetic product")
    else:
        supporter = supporter_rows[0]
        if supporter.get("effect_kind") != "cosmetic_only" or supporter.get("content_scope") != "cosmetics_only":
            errors.append("supporter product must remain cosmetics-only")
        if supporter.get("cosmetic_ids") != EXPECTED_SUPPORTER_COSMETICS:
            errors.append(f"supporter product must grant exactly {EXPECTED_SUPPORTER_COSMETICS}")
        for key in ("grants_power", "grants_currency", "grants_stats", "grants_drop_rate"):
            if supporter.get(key) is not False:
                errors.append(f"supporter cosmetic unexpectedly grants gameplay effect: {key}")

    launch_product_configuration = contract.get("launch_product_configuration", {})
    if not isinstance(launch_product_configuration, dict):
        errors.append("launch product configuration missing")
        launch_product_configuration = {}
    if launch_product_configuration.get("multi_product_bundle_allowed") is not False:
        errors.append("multi-product billing bundles are outside the 12.4 launch contract")
    if launch_product_configuration.get("personalized_price_used") is not False:
        errors.append("personalized pricing is outside the 12.4 launch contract")

    verification = contract.get("verification_boundary", {})
    if not isinstance(verification, dict):
        errors.append("verification boundary missing")
        verification = {}
    if verification.get("mode") != "secure_backend_required":
        errors.append("client-only purchase verification is forbidden")
    require_members(
        verification.get("request_fields"),
        {"verification_request_id", "application_id", "product_id", "purchase_token", "purchase_time", "package_name", "client_acknowledged_state"},
        "verification request_fields", errors,
    )
    require_members(
        verification.get("required_response_fields"),
        {"verification_request_id", "ok", "purchase_token", "product_id", "owned", "purchase_state", "acknowledged", "source"},
        "verification required_response_fields", errors,
    )
    if verification.get("client_response_correlation") != EXPECTED_CORRELATION:
        errors.append("backend response must echo exact verification_request_id")
    if verification.get("deduplication_key") != "purchase_token":
        errors.append("purchase_token must be the server deduplication key")
    if verification.get("order_id_is_not_deduplication_key") is not True:
        errors.append("order_id duplicate guard is missing")
    if verification.get("server_acknowledges_non_consumables") is not True:
        errors.append("verified non-consumables must be acknowledged by backend contract")
    if verification.get("play_developer_api_verification") != EXPECTED_VERIFICATION_API:
        errors.append("one-time purchase verification must use ProductPurchaseV2 server endpoint")
    if verification.get("play_developer_api_acknowledgement") != EXPECTED_ACK_API:
        errors.append("one-time non-consumable acknowledgement endpoint drifted")

    backend_requirements = {str(value) for value in verification.get("backend_validation_requirements", []) if isinstance(value, str)}
    for fragment in [
        "purchaseStateContext.purchaseState is PURCHASED",
        "returned productId equals the claimed configured product_id",
        "quantity is exactly 1",
        "purchase token has not granted a different product",
    ]:
        if not any(fragment in value for value in backend_requirements):
            errors.append(f"backend validation contract missing requirement: {fragment}")

    restore_policy = contract.get("restore_policy", {})
    if not isinstance(restore_policy, dict):
        errors.append("restore policy missing")
        restore_policy = {}
    for flag in [
        "verify_every_returned_PURCHASED_token",
        "apply_authoritative_snapshot_only_after_all_tokens_verify",
        "partial_verification_failure_preserves_existing_cache",
        "overlapping_purchase_and_restore_for_same_token_require_distinct_verification_requests",
        "stale_restore_response_must_not_satisfy_new_restore_generation",
    ]:
        if restore_policy.get(flag) is not True:
            errors.append(f"restore safety contract missing: {flag}")

    require_fragments(coordinator_text, [
        'PURCHASED_STATE := 1', 'PENDING_STATE := 2', '"verification_request_id"',
        '_next_verification_request_id', 'verification_for_unknown_request', '"acknowledged"',
        '"play_backend"', 'apply_authoritative_snapshot', 'apply_purchase_result', '_on_store_error', '_fail_restore',
    ], "coordinator security contract", errors)
    require_fragments(commercial_engine_text, [
        'REQUIRED_SUPPORTER_COSMETICS := ["supporter_badge"]', 'supporter_cosmetic_ids_mismatch', 'supporter_pack_not_cosmetic',
    ], "commercial policy runtime guard", errors)
    require_fragments(adapter_text, [
        "BILLING_CLIENT_SCRIPT", "PackedStringArray(product_ids)", "query_product_details", "query_purchases",
        "on_purchase_updated", "get_script_constant_map", "_started = false", "_client = null",
    ], "billing adapter contract", errors)
    require_fragments(verifier_text, [
        'normalized.begins_with("https://")', '"Cache-Control: no-store"', "HTTPRequest.RESULT_SUCCESS",
        '"verification_request_id"', '"response_request_id_mismatch"', '"response_token_mismatch"',
        '"response_product_mismatch"', "pending_count", "DEFAULT_TIMEOUT_SECONDS",
    ], "purchase verification HTTPS client", errors)
    require_fragments(service_text, [
        'OS.has_feature("android")', "NOTIFICATION_APPLICATION_RESUMED", "PlayPurchaseVerificationClient.new()",
        "GooglePlayBillingStoreAdapter.new()", "PlayBillingCoordinator.new()", '"configuration_pending"',
        "EntitlementEngine.new().ensure_state()",
    ], "billing runtime service", errors)
    require_fragments(hub_text, [
        "SupporterSeal.new()", "BillingService.purchase", "BillingService.restore", "hub.billing.unlock_full",
        "hub.billing.buy_supporter", "hub.billing.restore", "BILLING_UI_TEST_ENV",
    ], "Hub purchase/restore surface", errors)
    require_fragments(journey_setup_text, ["journey_setup.entitlement_required", '"entitlement_required" in errors'], "commercial route guidance", errors)
    require_fragments(supporter_seal_text, ["class_name SupporterSeal", "draw_arc", "draw_polyline", "draw_circle"], "supporter cosmetic visual", errors)

    required_ui = loc_manifest.get("ui_required_keys", [])
    if not isinstance(required_ui, list):
        errors.append("localization manifest UI required list missing")
        required_ui = []
    missing_required_billing_keys = BILLING_UI_KEYS - {str(value) for value in required_ui}
    if missing_required_billing_keys:
        errors.append(f"Billing UI keys missing from localization manifest: {sorted(missing_required_billing_keys)}")
    for locale_id, catalog in (("pt_BR", loc_pt), ("en", loc_en)):
        missing = [key for key in sorted(BILLING_UI_KEYS) if not isinstance(catalog.get(key), str) or not str(catalog.get(key, "")).strip()]
        if missing:
            errors.append(f"{locale_id} Billing UI translation missing: {missing}")

    require_fragments(cert_text, [
        "pending_no_grant=1", "verify_fail_no_grant=1", "ack_required=1", "authoritative_restore=1",
        "partial_failure_cache_safe=1", "package_guard=1", "request_id=1",
    ], "billing coordinator certification", errors)
    require_fragments(correlation_cert_text, [
        "request_correlation=1", "overlap_safe=1", "stale_response_isolation=1", "store_error_restore_safe=1",
    ], "billing correlation certification", errors)
    require_fragments(verifier_cert_text, [
        "https_only=1", "concurrent_requests=1", "correlation_fail_closed=1", "http_fail_closed=1",
        "malformed_json_fail_closed=1", "payload_guard=1",
    ], "purchase verification client certification", errors)

    privacy_behavior = privacy.get("current_application_behavior", {})
    if not isinstance(privacy_behavior, dict):
        errors.append("privacy current_application_behavior section missing")
        privacy_behavior = {}
    if privacy_behavior.get("internet_permission") is not True:
        errors.append("privacy contract must declare INTERNET permission used by billing verification")
    privacy_commercial = privacy.get("commercial_behavior", {})
    production_verification = privacy_commercial.get("production_purchase_verification", {}) if isinstance(privacy_commercial, dict) else {}
    if not isinstance(production_verification, dict):
        errors.append("privacy purchase-verification section missing")
        production_verification = {}
    if production_verification.get("runtime_client") != "mobile/PlayPurchaseVerificationClient.gd":
        errors.append("privacy manifest does not identify the billing HTTPS runtime client")
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
        "PLAY_BILLING_RELEASE_GATE %s: products=%d plugin=%s pending=%d ui_keys=%d errors=%d warnings=%d correlation=exact ProductPurchaseV2=1 runtime_service=1 https_client=1 purchase_surface=1 supporter_badge=1"
        % (mode, len(contract_ids), "installed" if plugin_installed else "pending", len(pending), len(BILLING_UI_KEYS), len(errors), len(warnings))
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"PLAY_BILLING_RELEASE_GATE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PLAY_BILLING_RELEASE_GATE PASS: billing contract, runtime integration and product surface are internally consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
