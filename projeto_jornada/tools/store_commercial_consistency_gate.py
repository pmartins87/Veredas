#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LISTING = ROOT / "product" / "store_listing_google_play.json"
COMMERCIAL = ROOT / "product" / "commercial_model.json"
BILLING = ROOT / "mobile" / "play_billing_contract.json"
TERMS = ROOT / "docs" / "TERMS_OF_USE_DRAFT.md"


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Cross-check 12.5 store copy against the commercial model, Billing products and Terms.")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()

    errors: list[str] = []
    for path in (LISTING, COMMERCIAL, BILLING, TERMS):
        if not path.is_file():
            errors.append(f"required commercial consistency file missing: {path.relative_to(ROOT)}")
    if errors:
        print("STORE_COMMERCIAL_CONSISTENCY_GATE FAIL")
        for error in errors:
            print("ERROR:", error)
        return 1

    try:
        listing = read_json(LISTING)
        commercial = read_json(COMMERCIAL)
        billing = read_json(BILLING)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"STORE_COMMERCIAL_CONSISTENCY_GATE FAIL: {exc}")
        return 1
    terms = TERMS.read_text(encoding="utf-8")

    if commercial.get("model_id") != "free_trial_one_time_unlock":
        errors.append("commercial model id drifted")
    principles = commercial.get("principles", {})
    if not isinstance(principles, dict):
        errors.append("commercial principles missing")
        principles = {}
    for key in ("no_ads", "no_subscriptions", "no_paid_consumables", "no_loot_boxes", "no_pay_to_win"):
        if principles.get(key) is not True:
            errors.append(f"commercial launch principle must remain true: {key}")

    commercial_rows = commercial.get("products", [])
    billing_rows = billing.get("products", [])
    if not isinstance(commercial_rows, list) or not isinstance(billing_rows, list):
        errors.append("commercial/Billing product arrays missing")
        commercial_rows = []
        billing_rows = []
    commercial_map = {str(row.get("id", "")): row for row in commercial_rows if isinstance(row, dict)}
    billing_map = {str(row.get("product_id", "")): row for row in billing_rows if isinstance(row, dict)}
    expected_products = {"full_game_unlock", "supporter_cosmetic_pack"}
    if set(commercial_map) != expected_products:
        errors.append(f"commercial product set drift: {sorted(commercial_map)}")
    if set(billing_map) != expected_products:
        errors.append(f"Billing product set drift: {sorted(billing_map)}")

    for product_id in sorted(expected_products):
        commercial_row = commercial_map.get(product_id, {})
        billing_row = billing_map.get(product_id, {})
        if commercial_row.get("store_type") != "one_time_non_consumable":
            errors.append(f"{product_id}: commercial store_type must be one_time_non_consumable")
        if billing_row.get("kind") != "one_time_non_consumable":
            errors.append(f"{product_id}: Billing kind must be one_time_non_consumable")
        for label, row in (("commercial", commercial_row), ("billing", billing_row)):
            if row.get("consumable") is not False:
                errors.append(f"{product_id}: {label} consumable must be false")
            if row.get("repeatable") is not False:
                errors.append(f"{product_id}: {label} repeatable must be false")

    full_unlock = commercial_map.get("full_game_unlock", {})
    if full_unlock.get("effect_kind") != "content_license" or full_unlock.get("content_scope") != "all_game_content":
        errors.append("full_game_unlock must remain a content-only full-game license")
    supporter = commercial_map.get("supporter_cosmetic_pack", {})
    if supporter.get("effect_kind") != "cosmetic_only":
        errors.append("supporter_cosmetic_pack must remain cosmetic_only")
    if supporter.get("cosmetic_ids") != ["supporter_badge"]:
        errors.append("supporter cosmetic id must remain exactly supporter_badge")
    for key in ("grants_power", "grants_currency", "grants_stats", "grants_drop_rate"):
        if supporter.get(key) is not False:
            errors.append(f"supporter product must not grant gameplay advantage: {key}")

    launch_config = billing.get("launch_product_configuration", {})
    if not isinstance(launch_config, dict):
        errors.append("Billing launch_product_configuration missing")
        launch_config = {}
    if launch_config.get("multi_product_bundle_allowed") is not False:
        errors.append("launch multi-product bundle must remain disabled")
    if launch_config.get("personalized_price_used") is not False:
        errors.append("personalized pricing must remain disabled at launch")
    for product_id, row in billing_map.items():
        for key in ("offers_allowed_at_launch", "rent_allowed", "preorder_allowed"):
            if row.get(key) is not False:
                errors.append(f"{product_id}: launch {key} must remain false")

    listings = listing.get("listings", {})
    if not isinstance(listings, dict):
        errors.append("store listings missing")
        listings = {}
    pt = str(listings.get("pt-BR", {}).get("full_description", "")) if isinstance(listings.get("pt-BR", {}), dict) else ""
    en = str(listings.get("en-US", {}).get("full_description", "")) if isinstance(listings.get("en-US", {}), dict) else ""
    required_pt = [
        "parte inicial",
        "compra única e não consumível",
        "Selo de Apoiador",
        "apenas um ornamento visual",
        "Não há anúncios, assinaturas, loot boxes nem venda de poder de combate",
    ]
    required_en = [
        "opening portion",
        "single non-consumable purchase",
        "Supporter Seal",
        "only a visual ornament",
        "There are no ads, subscriptions, loot boxes, or paid combat power",
    ]
    for fragment in required_pt:
        if fragment not in pt:
            errors.append(f"pt-BR listing missing commercial truth fragment: {fragment}")
    for fragment in required_en:
        if fragment not in en:
            errors.append(f"en-US listing missing commercial truth fragment: {fragment}")

    required_terms = [
        "único desbloqueio digital não consumível",
        "Selo de Apoiador",
        "somente um ornamento visual",
        "single non-consumable digital unlock",
        "Supporter Seal",
        "adds only a visual ornament",
    ]
    for fragment in required_terms:
        if fragment not in terms:
            errors.append(f"Terms commercial model drift: missing {fragment}")

    if args.release:
        if billing.get("formal_status") != "certified" or billing.get("pass_recorded") is not True:
            errors.append("12.4 Billing must be certified before final 12.5 commercial copy freeze")
        if listing.get("formal_status") != "certified" or listing.get("pass_recorded") is not True:
            errors.append("12.5 listing must be certified in release mode")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "STORE_COMMERCIAL_CONSISTENCY_GATE %s: products=%d errors=%d full_unlock_content_only=1 supporter_visual_only=1 no_ads_subs_lootboxes=1"
        % (mode, len(expected_products), len(errors))
    )
    if errors:
        print(f"STORE_COMMERCIAL_CONSISTENCY_GATE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("STORE_COMMERCIAL_CONSISTENCY_GATE PASS: listing, commercial model, Billing products and Terms agree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
