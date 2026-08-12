#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / "product" / "legal_documents.json"
MANIFEST = ROOT / "localization" / "manifest.json"
PRIVACY = ROOT / "product" / "privacy_data_safety.json"
HUB = ROOT / "scenes" / "Hub.gd"
PANEL = ROOT / "ui" / "LegalPanel.gd"
EXPORT = ROOT / "export_presets.cfg"

REQUIRED_LOCALE_FIELDS = (
    "entry_label",
    "screen_title",
    "privacy_tab",
    "terms_tab",
    "done_label",
    "pre_release_notice",
    "privacy_body",
    "terms_body",
)


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit the exported in-app privacy/terms surface.")
    parser.add_argument("--release", action="store_true", help="Require final published legal content and URLs.")
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    for required in (LEGAL, MANIFEST, PRIVACY, HUB, PANEL, EXPORT):
        if not required.exists():
            errors.append(f"required legal-surface file missing: {required.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1

    legal = read_json(LEGAL)
    manifest = read_json(MANIFEST)
    privacy = read_json(PRIVACY)
    hub_text = HUB.read_text(encoding="utf-8")
    panel_text = PANEL.read_text(encoding="utf-8")
    export_text = EXPORT.read_text(encoding="utf-8")

    if legal.get("roadmap_step") != "12.3":
        errors.append("runtime legal document must identify roadmap_step 12.3")
    if legal.get("source_locale") != manifest.get("source_locale"):
        errors.append("runtime legal source locale disagrees with localization manifest")

    launch_locales = [str(value) for value in manifest.get("launch_locales", [])]
    legal_launch = [str(value) for value in legal.get("launch_locales", [])]
    if legal_launch != launch_locales:
        errors.append(f"runtime legal launch locales mismatch: legal={legal_launch} manifest={launch_locales}")
    if launch_locales != ["pt_BR", "en"]:
        errors.append(f"release legal surface expects the frozen pt_BR + en launch scope, got {launch_locales}")

    locales = legal.get("locales", {})
    if not isinstance(locales, dict):
        errors.append("runtime legal locales must be an object")
        locales = {}
    for locale_id in launch_locales:
        payload = locales.get(locale_id, {})
        if not isinstance(payload, dict):
            errors.append(f"runtime legal locale payload missing/not object: {locale_id}")
            continue
        for field in REQUIRED_LOCALE_FIELDS:
            value = str(payload.get(field, "")).strip()
            if not value:
                errors.append(f"runtime legal field missing: {locale_id}:{field}")
        if len(str(payload.get("privacy_body", ""))) < 900:
            errors.append(f"runtime privacy text is implausibly short: {locale_id}")
        if len(str(payload.get("terms_body", ""))) < 700:
            errors.append(f"runtime terms text is implausibly short: {locale_id}")

    if "LegalPanel.entry_label" not in hub_text or "_open_legal" not in hub_text:
        errors.append("Hub does not expose the runtime legal surface")
    for token in (
        "class_name LegalPanel",
        "SafeAreaMargin.new()",
        "RichTextLabel.new()",
        "AccessibilityService.apply_font_scale(self)",
        "MobilePlatformService.apply_touch_targets(self)",
    ):
        if token not in panel_text:
            errors.append(f"LegalPanel accessibility/runtime contract missing: {token}")

    exclude_matches = re.findall(r'^exclude_filter="([^"]*)"', export_text, flags=re.MULTILINE)
    if not exclude_matches:
        errors.append("Android export exclude_filter not found")
    else:
        for value in exclude_matches:
            if "product/*" in value or "product/**" in value:
                errors.append("runtime legal product resource is excluded from Android export")

    privacy_policy = privacy.get("privacy_policy", {})
    if not isinstance(privacy_policy, dict):
        errors.append("privacy_policy object missing from privacy contract")
        privacy_policy = {}
    runtime_document = str(privacy_policy.get("runtime_document", ""))
    if runtime_document != "product/legal_documents.json":
        errors.append(f"privacy contract runtime_document mismatch: {runtime_document!r}")
    in_app_access = str(privacy_policy.get("in_app_access", ""))
    if in_app_access not in ("implemented_pending_final_content", "implemented"):
        errors.append(f"privacy contract does not recognize implemented in-app legal surface: {in_app_access!r}")

    status = str(legal.get("publication_status", ""))
    if status not in ("pre_release", "final"):
        errors.append(f"invalid legal publication_status: {status!r}")

    privacy_url = str(legal.get("public_privacy_url", "")).strip()
    terms_url = str(legal.get("public_terms_url", "")).strip()
    effective_date = str(legal.get("final_effective_date", "")).strip()
    serialized = json.dumps(legal, ensure_ascii=False)

    if args.release:
        if status != "final":
            errors.append("runtime legal documents are still marked pre_release")
        if not privacy_url.startswith("https://"):
            errors.append("runtime privacy public HTTPS URL is not finalized")
        if not terms_url.startswith("https://"):
            errors.append("runtime terms public HTTPS URL is not finalized")
        if not effective_date:
            errors.append("runtime legal effective date is not finalized")
        if "PRE-RELEASE" in serialized or "PRÉ-LANÇAMENTO" in serialized:
            errors.append("runtime legal content still contains pre-release labeling")
        if in_app_access != "implemented":
            errors.append("privacy contract has not frozen final in-app policy access")
        contract_url = str(privacy_policy.get("public_url", "")).strip()
        if contract_url != privacy_url:
            errors.append("runtime privacy URL does not match privacy contract public URL")
    else:
        if status != "final":
            warnings.append("runtime legal surface is implemented but content remains pre-release")
        if not privacy_url or not terms_url:
            warnings.append("public legal URLs remain intentionally empty before publication")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "LEGAL_SURFACE %s: locales=%d status=%s privacy_url=%s terms_url=%s errors=%d warnings=%d"
        % (
            mode,
            len(launch_locales),
            status,
            "set" if privacy_url else "pending",
            "set" if terms_url else "pending",
            len(errors),
            len(warnings),
        )
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"LEGAL_SURFACE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("LEGAL_SURFACE PASS: in-app privacy/terms surface is structurally complete for the current launch scope")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
