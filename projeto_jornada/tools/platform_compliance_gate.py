#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PLATFORM = ROOT / "product" / "platform_compliance.json"
IDENTITY = ROOT / "mobile" / "release_identity.json"
COMMERCIAL = ROOT / "product" / "commercial_model.json"
BILLING = ROOT / "mobile" / "play_billing_contract.json"
PRIVACY = ROOT / "product" / "privacy_data_safety.json"
LISTING = ROOT / "product" / "store_listing_google_play.json"
TERMS = ROOT / "docs" / "TERMS_OF_USE_DRAFT.md"
POLICY = ROOT / "docs" / "PRIVACY_POLICY_DRAFT.md"
EXPORT = ROOT / "export_presets.cfg"


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def product_map(rows: Any, key: str) -> dict[str, dict[str, Any]]:
    if not isinstance(rows, list):
        return {}
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        if isinstance(row, dict) and row.get(key):
            result[str(row[key])] = row
    return result


def pending_tokens(text: str) -> list[str]:
    return sorted(set(re.findall(r"PENDING_[A-Z0-9_]+", text)))


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit Veredas Google Play/platform release consistency.")
    parser.add_argument("--release", action="store_true", help="Require final external/console evidence and zero placeholders.")
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    required = [PLATFORM, IDENTITY, COMMERCIAL, BILLING, PRIVACY, LISTING, TERMS, POLICY, EXPORT]
    for path in required:
        if not path.exists():
            errors.append(f"required platform/release file missing: {path.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1

    platform = read_json(PLATFORM)
    identity = read_json(IDENTITY)
    commercial = read_json(COMMERCIAL)
    billing = read_json(BILLING)
    privacy = read_json(PRIVACY)
    listing = read_json(LISTING)
    terms_text = TERMS.read_text(encoding="utf-8")
    policy_text = POLICY.read_text(encoding="utf-8")
    export_text = EXPORT.read_text(encoding="utf-8")

    if platform.get("roadmap_step") != "12.3":
        errors.append("platform compliance contract must identify roadmap_step 12.3")

    android = identity.get("android", {}) if isinstance(identity.get("android"), dict) else {}
    toolchain = android.get("release_toolchain", {}) if isinstance(android.get("release_toolchain"), dict) else {}
    baseline = platform.get("android_release_baseline", {}) if isinstance(platform.get("android_release_baseline"), dict) else {}
    for key in ("godot_version", "min_sdk", "compile_sdk", "target_sdk", "android_build_tools"):
        if toolchain.get(key) != baseline.get(key):
            errors.append(f"Android toolchain mismatch for {key}: identity={toolchain.get(key)!r} platform={baseline.get(key)!r}")

    try:
        min_sdk = int(baseline.get("min_sdk", -1))
        compile_sdk = int(baseline.get("compile_sdk", -1))
        target_sdk = int(baseline.get("target_sdk", -1))
    except (TypeError, ValueError):
        min_sdk = compile_sdk = target_sdk = -1
    if target_sdk < 36 or compile_sdk < target_sdk:
        errors.append(f"Android release baseline is below required project floor: min={min_sdk} compile={compile_sdk} target={target_sdk}")
    if export_text.count(f'gradle_build/min_sdk="{min_sdk}"') != 2:
        errors.append("both Android presets must explicitly pin the contracted minSdk")
    if export_text.count(f'gradle_build/target_sdk="{target_sdk}"') != 2:
        errors.append("both Android presets must explicitly pin the contracted targetSdk")

    app_ids = {
        str(android.get("application_id", "")),
        str(billing.get("application_id", "")),
        str(privacy.get("application_id", "")),
        str(listing.get("application_id", "")),
    }
    if len(app_ids) != 1 or "" in app_ids:
        errors.append(f"application id mismatch across release contracts: {sorted(app_ids)!r}")

    commercial_products = product_map(commercial.get("products"), "id")
    billing_products = product_map(billing.get("products"), "product_id")
    if set(commercial_products) != set(billing_products):
        errors.append(
            "commercial/Billing product set mismatch: commercial=%s billing=%s"
            % (sorted(commercial_products), sorted(billing_products))
        )

    unlock = commercial_products.get("full_game_unlock", {})
    supporter = commercial_products.get("supporter_cosmetic_pack", {})
    if unlock.get("effect_kind") != "content_license" or unlock.get("consumable") is not False:
        errors.append("full_game_unlock must remain a non-consumable content license")
    if supporter.get("effect_kind") != "cosmetic_only" or supporter.get("consumable") is not False:
        errors.append("supporter_cosmetic_pack must remain non-consumable and cosmetic-only")
    for key in ("grants_power", "grants_currency", "grants_stats", "grants_drop_rate"):
        if supporter.get(key) is not False:
            errors.append(f"supporter cosmetic pack must not affect gameplay: {key}={supporter.get(key)!r}")

    billing_store = billing.get("store", {}) if isinstance(billing.get("store"), dict) else {}
    if billing_store.get("provider") != "Google Play Billing":
        errors.append("Google Play release must use the contracted Google Play Billing provider")
    if billing_store.get("product_type") != "INAPP":
        errors.append("non-consumable release products must remain INAPP products")

    policy_contract = platform.get("store_and_policy_contract", {}) if isinstance(platform.get("store_and_policy_contract"), dict) else {}
    required_true = (
        "privacy_policy_required_in_console",
        "privacy_policy_required_in_app",
        "data_safety_declaration_required_for_closed_open_and_production_tracks",
        "content_rating_questionnaire_required",
        "unrated_public_release_forbidden",
        "target_audience_declaration_required",
        "all_google_play_digital_products_use_google_play_billing",
        "full_game_unlock_is_single_non_consumable_purchase",
        "optional_supporter_cosmetic_pack",
    )
    for key in required_true:
        if policy_contract.get(key) is not True:
            errors.append(f"platform policy contract must keep {key}=true")
    for key in ("ads", "account_creation", "external_payment_cta_in_google_play_purchase_flow", "alternative_billing_planned", "supporter_pack_affects_gameplay_or_progression", "subscriptions", "loot_boxes", "paid_power"):
        if policy_contract.get(key) is not False:
            errors.append(f"platform policy contract must keep {key}=false")

    principles = commercial.get("principles", {}) if isinstance(commercial.get("principles"), dict) else {}
    behavior = privacy.get("current_application_behavior", {}) if isinstance(privacy.get("current_application_behavior"), dict) else {}
    if principles.get("no_ads") is not True or behavior.get("advertising") is not False:
        errors.append("commercial/privacy contracts disagree with the no-ads release policy")
    if principles.get("no_subscriptions") is not True or principles.get("no_paid_consumables") is not True:
        errors.append("commercial model must remain subscription-free and paid-consumable-free")

    listings = listing.get("listings", {}) if isinstance(listing.get("listings"), dict) else {}
    pt_desc = str((listings.get("pt-BR") or {}).get("full_description", "")) if isinstance(listings.get("pt-BR"), dict) else ""
    en_desc = str((listings.get("en-US") or {}).get("full_description", "")) if isinstance(listings.get("en-US"), dict) else ""
    if "cosmét" not in pt_desc.casefold() or "cosmetic" not in en_desc.casefold():
        errors.append("store copy must disclose the optional cosmetic supporter product in both launch locales")
    if "apoiador" not in terms_text.casefold() or "supporter" not in terms_text.casefold():
        errors.append("Terms must disclose the optional supporter cosmetic product in both languages")

    terms_pending = pending_tokens(terms_text)
    policy_pending = pending_tokens(policy_text)
    evidence = platform.get("release_evidence", {}) if isinstance(platform.get("release_evidence"), dict) else {}
    unresolved_evidence = sorted(key for key, value in evidence.items() if value is not True)

    if args.release:
        if terms_pending:
            errors.append(f"Terms retain unresolved placeholders: {terms_pending}")
        if policy_pending:
            errors.append(f"Privacy Policy retains unresolved placeholders: {policy_pending}")
        if unresolved_evidence:
            errors.append(f"platform release evidence incomplete: {unresolved_evidence}")
        if platform.get("formal_status") != "certified" or platform.get("pass_recorded") is not True:
            errors.append("12.3 platform compliance is not formally certified")
        if billing.get("formal_status") != "certified" or billing.get("pass_recorded") is not True:
            errors.append("12.4 Billing must be certified before final 12.3 platform freeze")
        if privacy.get("formal_status") != "certified" or privacy.get("pass_recorded") is not True:
            errors.append("12.3 privacy/Data Safety contract is not certified")
    else:
        if terms_pending or policy_pending:
            warnings.append(
                "preflight retains publication placeholders: terms=%d privacy=%d"
                % (len(terms_pending), len(policy_pending))
            )
        if unresolved_evidence:
            warnings.append(f"preflight release evidence still pending: {len(unresolved_evidence)} item(s)")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "PLATFORM_COMPLIANCE %s: products=%d targetSdk=%d compileSdk=%d terms_pending=%d privacy_pending=%d evidence_pending=%d errors=%d warnings=%d"
        % (
            mode,
            len(commercial_products),
            target_sdk,
            compile_sdk,
            len(terms_pending),
            len(policy_pending),
            len(unresolved_evidence),
            len(errors),
            len(warnings),
        )
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"PLATFORM_COMPLIANCE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PLATFORM_COMPLIANCE PASS: toolchain, Billing, commercial model, store copy, Terms and privacy baseline are internally consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
