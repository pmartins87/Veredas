#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "rating": ROOT / "product/content_rating_target_audience.json",
    "platform": ROOT / "product/platform_compliance.json",
    "privacy": ROOT / "product/privacy_data_safety.json",
    "commercial": ROOT / "product/commercial_model.json",
    "listing": ROOT / "product/store_listing_google_play.json",
}
ALLOWED_GROUPS = {"5_and_under", "6_8", "9_12", "13_15", "16_17", "18_plus"}
UNDER_13 = {"5_and_under", "6_8", "9_12"}


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected object: {path}")
    return value


def unresolved(value: Any) -> bool:
    return isinstance(value, str) and (value.startswith("pending_") or "PENDING_" in value)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    errors: list[str] = []
    warnings: list[str] = []

    for path in FILES.values():
        if not path.is_file():
            errors.append(f"missing file: {path.relative_to(ROOT)}")
    if errors:
        print("CONTENT_RATING_TARGET_AUDIENCE_GATE FAIL")
        return 1

    try:
        data = {key: read_json(path) for key, path in FILES.items()}
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"CONTENT_RATING_TARGET_AUDIENCE_GATE FAIL: {exc}")
        return 1

    rating = data["rating"]
    platform = data["platform"]
    privacy = data["privacy"]
    commercial = data["commercial"]
    listing = data["listing"]

    if rating.get("roadmap_step") != "12.3":
        errors.append("rating contract roadmap_step mismatch")
    baseline = rating.get("policy_baseline", {})
    for key in (
        "content_rating_required_for_google_play",
        "unrated_public_release_forbidden",
        "target_audience_declaration_separate_from_iarc_rating",
        "selecting_any_child_age_group_triggers_google_play_families_requirements",
        "age_groups_must_reflect_who_the_app_was_designed_for_not_maximize_availability",
    ):
        if not isinstance(baseline, dict) or baseline.get(key) is not True:
            errors.append(f"policy invariant missing: {key}")

    store_policy = platform.get("store_and_policy_contract", {})
    for key in ("content_rating_questionnaire_required", "unrated_public_release_forbidden", "target_audience_declaration_required"):
        if not isinstance(store_policy, dict) or store_policy.get(key) is not True:
            errors.append(f"platform policy mismatch: {key}")

    facts = rating.get("proven_product_facts", {})
    if not isinstance(facts, dict) or facts.get("fictional_fantasy_combat") is not True:
        errors.append("fantasy combat must be declared")
    if not isinstance(facts, dict) or facts.get("monsters_and_bosses") is not True:
        errors.append("monsters/bosses must be declared")

    principles = commercial.get("principles", {})
    expected_false = {
        "advertising": "no_ads",
        "subscriptions": "no_subscriptions",
        "loot_boxes": "no_loot_boxes",
        "paid_random_rewards": "no_paid_random_rewards",
    }
    for fact, principle in expected_false.items():
        if not isinstance(facts, dict) or facts.get(fact) is not False:
            errors.append(f"rating fact must remain false: {fact}")
        if not isinstance(principles, dict) or principles.get(principle) is not True:
            errors.append(f"commercial principle mismatch: {principle}")

    behavior = privacy.get("current_application_behavior", {})
    if isinstance(behavior, dict) and facts.get("user_accounts") != bool(behavior.get("user_accounts", False)):
        errors.append("privacy/rating account fact mismatch")

    listing_rows = listing.get("listings", {})
    listing_text = "\n".join(str(row.get("full_description", "")) for row in listing_rows.values() if isinstance(row, dict)) if isinstance(listing_rows, dict) else ""
    if "combate" not in listing_text.lower() and "combat" not in listing_text.lower():
        errors.append("store listing no longer discloses combat")

    review = rating.get("final_content_review_required", {})
    pending_review = [key for key, value in review.items() if unresolved(value)] if isinstance(review, dict) else []
    target = rating.get("target_audience", {})
    raw_groups = target.get("final_selected_google_play_age_groups") if isinstance(target, dict) else None
    groups = set(raw_groups) if isinstance(raw_groups, list) else set()
    iarc = rating.get("iarc", {})

    if args.release:
        if pending_review:
            errors.append(f"final content review pending: {pending_review}")
        if not groups or not groups.issubset(ALLOWED_GROUPS):
            errors.append("final target age groups missing/invalid")
        if groups & UNDER_13 and target.get("families_policy_final_review_complete") is not True:
            errors.append("under-13 audience selected without Families review")
        if not isinstance(iarc, dict) or iarc.get("questionnaire_completed_in_play_console") is not True:
            errors.append("IARC questionnaire incomplete")
        if not isinstance(iarc, dict) or iarc.get("certificate_received") is not True:
            errors.append("IARC certificate missing")
        if not isinstance(iarc, dict) or not iarc.get("final_regional_ratings"):
            errors.append("IARC regional ratings missing")
        if rating.get("formal_status") != "certified" or rating.get("pass_recorded") is not True:
            errors.append("rating/audience contract not certified")
    else:
        if pending_review:
            warnings.append(f"{len(pending_review)} final rating-content categories remain pending")
        if not groups:
            warnings.append("final target age groups intentionally remain pending")
        if not isinstance(iarc, dict) or iarc.get("questionnaire_completed_in_play_console") is not True:
            warnings.append("IARC Play Console questionnaire remains pending")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(f"CONTENT_RATING_TARGET_AUDIENCE_GATE {mode}: pending_review={len(pending_review)} groups={len(groups)} errors={len(errors)} warnings={len(warnings)}")
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1
    print("CONTENT_RATING_TARGET_AUDIENCE_GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
