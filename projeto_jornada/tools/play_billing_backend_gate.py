#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend" / "play_purchase_verifier"
CONTRACT = BACKEND / "backend_contract.json"
BILLING = ROOT / "mobile" / "play_billing_contract.json"
EXPORT = ROOT / "export_presets.cfg"
RELEASE_STATE = ROOT / "RELEASE_12_4_STATE.json"
MERGE = BACKEND / "purchase_record_merge.py"
MERGE_TEST = BACKEND / "tests" / "test_purchase_record_merge.py"
APP_TEST = BACKEND / "tests" / "test_app.py"

REQUIRED_FILES = [
    CONTRACT,
    BACKEND / "verifier.py",
    BACKEND / "google_play_gateway.py",
    BACKEND / "firestore_repository.py",
    MERGE,
    BACKEND / "app.py",
    BACKEND / "requirements.txt",
    BACKEND / "Dockerfile",
    BACKEND / "tests" / "test_verifier.py",
    MERGE_TEST,
    APP_TEST,
    BILLING,
    EXPORT,
    RELEASE_STATE,
]

EXPECTED_REQUIREMENTS = {
    "Flask==3.1.3",
    "google-auth==2.56.3",
    "google-cloud-firestore==2.28.0",
    "gunicorn==26.0.0",
    "requests==2.34.2",
}

SECRET_MARKERS = (
    "-----BEGIN PRIVATE KEY-----",
    '"private_key":',
    '"client_secret":',
    '"type": "service_account"',
    "GOOGLE_APPLICATION_CREDENTIALS=",
)


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected object: {path}")
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
    elif isinstance(value, str) and "PENDING_" in value:
        found.append(path)
    return found


def require_fragment(text: str, fragment: str, label: str, errors: list[str]) -> None:
    if fragment not in text:
        errors.append(f"{label} missing security fragment: {fragment}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the production reference backend for Google Play Billing step 12.4.")
    parser.add_argument("--release", action="store_true", help="Require deployed endpoint, service identity, rate limiting and frozen retention.")
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []
    for path in REQUIRED_FILES:
        if not path.exists():
            errors.append(f"required backend file missing: {path.relative_to(ROOT)}")
    if errors:
        print("PLAY_BILLING_BACKEND_GATE FAIL")
        for error in errors:
            print("ERROR:", error)
        return 1

    contract = read_json(CONTRACT)
    billing = read_json(BILLING)
    release_state = read_json(RELEASE_STATE)
    verifier = (BACKEND / "verifier.py").read_text(encoding="utf-8")
    gateway = (BACKEND / "google_play_gateway.py").read_text(encoding="utf-8")
    repository = (BACKEND / "firestore_repository.py").read_text(encoding="utf-8")
    merge_text = MERGE.read_text(encoding="utf-8")
    app = (BACKEND / "app.py").read_text(encoding="utf-8")
    dockerfile = (BACKEND / "Dockerfile").read_text(encoding="utf-8")
    tests = (BACKEND / "tests" / "test_verifier.py").read_text(encoding="utf-8")
    merge_tests = MERGE_TEST.read_text(encoding="utf-8")
    app_tests = APP_TEST.read_text(encoding="utf-8")
    export_text = EXPORT.read_text(encoding="utf-8")
    requirements = {
        line.strip()
        for line in (BACKEND / "requirements.txt").read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }

    if contract.get("roadmap_step") != "12.4":
        errors.append("backend contract must identify roadmap step 12.4")
    if contract.get("application_id") != "com.pmartins87.veredasdatrama":
        errors.append("backend application id mismatch")
    if billing.get("application_id") != contract.get("application_id"):
        errors.append("backend and mobile billing application ids disagree")
    if release_state.get("roadmap_step") != "12.4":
        errors.append("release state must identify roadmap step 12.4")

    auth = contract.get("authentication_model", {})
    if not isinstance(auth, dict):
        errors.append("backend authentication_model missing")
        auth = {}
    if auth.get("client_to_backend") != "public_https_no_reusable_client_secret":
        errors.append("native client authentication model drifted")
    if auth.get("client_secret_embedded_in_app") is not False:
        errors.append("reusable backend client secret must never be embedded in the app")
    if auth.get("backend_to_google") != "attached_service_account_via_application_default_credentials":
        errors.append("backend must authenticate to Google with attached service identity/ADC")
    if auth.get("service_account_key_file_in_repository_or_image") is not False:
        errors.append("service-account key files are forbidden in repository/image")

    persistence = contract.get("persistence", {})
    if not isinstance(persistence, dict):
        errors.append("backend persistence contract missing")
        persistence = {}
    if persistence.get("deduplication_document_id") != "sha256(purchase_token)":
        errors.append("purchase-token deduplication must use SHA-256 document id")
    if persistence.get("raw_purchase_token_persisted") is not False:
        errors.append("raw purchase token persistence is forbidden")
    if persistence.get("order_id_persisted") is not False:
        errors.append("order id is outside the minimal backend persistence contract")
    if persistence.get("token_product_binding_transactional") is not True:
        errors.append("token-to-product binding must remain transactional")

    abuse = contract.get("abuse_and_data_minimization", {})
    if not isinstance(abuse, dict):
        errors.append("abuse/data-minimization contract missing")
        abuse = {}
    if abuse.get("purchase_token_logged_by_application") is not False:
        errors.append("application logging of purchase tokens is forbidden")
    if abuse.get("edge_or_platform_rate_limiting_required_before_production") is not True:
        errors.append("production endpoint must retain an explicit rate-limit requirement")
    if abuse.get("play_integrity_attestation_required_at_launch") is not False:
        errors.append("Play Integrity cannot be silently added without privacy/product scope review")

    for fragment in [
        "hashlib.sha256",
        "class RepositoryError",
        "len(line_items) != 1",
        "quantity != 1",
        'purchase_option_id = str(offer_details.get("purchaseOptionId", "")).strip()',
        'if "offerId" in offer_details:',
        'if "rentOfferDetails" in offer_details:',
        'if "preorderOfferDetails" in offer_details:',
        "purchase.purchase_state != PURCHASED",
        "play_offer_not_allowed_at_launch",
        "play_rent_not_allowed_at_launch",
        "play_preorder_not_allowed_at_launch",
        "purchase_token_bound_to_different_product",
        'return self._failure(request, "repository_unavailable"), 503',
        'if not self._record(request, purchase, owned=True, stage="owned_acknowledged"):',
        "ACK_PENDING",
        "ACKNOWLEDGED",
    ]:
        require_fragment(verifier, fragment, "verifier", errors)
    if 'offer_details.get("rentOfferDetails") not in (None, {})' in verifier:
        errors.append("rentOfferDetails must be rejected by key presence; empty object is a real rental marker")
    if 'offer_details.get("preorderOfferDetails") not in (None, {})' in verifier:
        errors.append("preorderOfferDetails must be rejected by key presence")
    parse_index = verifier.find("self._parse_authoritative(raw, request.product_id)")
    bind_index = verifier.find("self._repository.bind(request.token_hash")
    if parse_index < 0 or bind_index < 0 or bind_index < parse_index:
        errors.append("token/product binding must occur only after authoritative product validation")
    final_record_index = verifier.find('if not self._record(request, purchase, owned=True, stage="owned_acknowledged"):')
    success_index = verifier.find('"owned": True,', final_record_index)
    if final_record_index < 0 or success_index < final_record_index:
        errors.append("owned=true response must occur only after durable final record")

    for fragment in [
        "google.auth.default",
        "google_auth_exceptions.GoogleAuthError",
        "AuthorizedSession",
        "/purchases/productsv2/tokens/",
        "/purchases/products/",
        ":acknowledge",
        "MAX_ATTEMPTS = 2",
        "CONNECT_TIMEOUT_SECONDS = 1.5",
        "READ_TIMEOUT_SECONDS = 2.5",
        "RETRYABLE_STATUS",
    ]:
        require_fragment(gateway, fragment, "Google Play gateway", errors)

    for fragment in [
        "from purchase_record_merge import merge_purchase_record",
        "from verifier import RepositoryError",
        "firestore.transactional",
        "record_transaction",
        "repository_bind_failed",
        "repository_record_failed",
        "token_hash",
        "last_seen_at",
        "SERVER_TIMESTAMP",
    ]:
        require_fragment(repository, fragment, "Firestore repository", errors)
    if repository.count("@firestore.transactional") < 2:
        errors.append("both token binding and purchase-state recording must be Firestore transactions")
    if "purchase_token" in repository:
        errors.append("Firestore repository source must never accept/store the raw purchase_token")

    for fragment in [
        '"PENDING": 1',
        '"PURCHASED": 2',
        '"CANCELLED": 3',
        "incoming_rank < current_rank",
        'effective["owned"] = prior_owned or incoming_owned',
        'effective["acknowledgement_state"] = current_ack',
        "incoming_purchase_state_invalid",
        "incoming_acknowledgement_state_invalid",
    ]:
        require_fragment(merge_text, fragment, "monotonic purchase-record merge", errors)

    for fragment in [
        "class VerificationServiceProvider",
        "Lock()",
        'app.get("/healthz")',
        'app.get("/readyz")',
        '"kind": "liveness"',
        '"kind": "readiness"',
        "repository_initialization_unavailable",
        "google_identity_unavailable",
        "verification_service_initialization_failed",
        "MAX_BODY_BYTES = 16 * 1024",
        '"Cache-Control"] = "no-store"',
        '"/v1/play/verify"',
    ]:
        require_fragment(app, fragment, "HTTP service", errors)
    if "CORS" in app or "Access-Control-Allow-Origin" in app:
        errors.append("browser CORS surface is not part of the native billing backend contract")
    if "except Exception as exc" in app:
        errors.append("HTTP initialization fallback must not expose or retain exception objects/messages")

    if "USER appuser" not in dockerfile:
        errors.append("backend container must run as non-root appuser")
    if "purchase_record_merge.py" not in dockerfile:
        errors.append("backend container must include the monotonic purchase-record merge module")
    if requirements != EXPECTED_REQUIREMENTS:
        errors.append(f"backend dependency pins drifted: got={sorted(requirements)}")

    for fragment in [
        "test_unacknowledged_purchase_is_acknowledged_refetched_and_granted",
        "test_pending_authoritative_state_never_grants",
        "test_claimed_product_must_equal_authoritative_line_item_before_binding",
        "test_purchase_option_id_is_required",
        "test_launch_offer_rent_and_preorder_presence_are_rejected",
        "rent_marker=True",
        "test_existing_token_binding_cannot_switch_product",
        "test_repository_bind_outage_never_grants_or_acknowledges",
        "test_repository_pre_ack_record_outage_stops_before_acknowledgement",
        "test_repository_final_record_outage_never_returns_owned_true",
        "test_concurrent_ack_error_is_safe_if_refetch_confirms_acknowledged",
        "test_failed_ack_never_grants_if_refetch_stays_pending",
        "test_play_outage_returns_service_unavailable_without_grant",
    ]:
        require_fragment(tests, fragment, "backend verifier tests", errors)

    for fragment in [
        "test_pending_can_advance_to_purchased_owned",
        "test_late_pending_cannot_regress_purchased_owned",
        "test_late_pre_ack_purchased_write_cannot_clear_owned",
        "test_acknowledgement_cannot_regress_within_purchased",
        "test_cancelled_after_purchased_is_terminal_revocation",
        "test_late_purchased_cannot_resurrect_cancelled",
        "test_unknown_purchase_state_fails_closed",
        "test_unknown_acknowledgement_state_fails_closed",
    ]:
        require_fragment(merge_tests, fragment, "purchase-record merge tests", errors)

    for fragment in [
        "test_liveness_does_not_initialize_dependencies",
        "test_ready_service_reports_readiness_without_external_call",
        "test_failed_readiness_can_recover_on_next_probe",
        "test_initialization_exception_message_is_not_exposed",
        "test_unavailable_service_never_returns_owned_true",
        "test_ready_service_forwards_verification_result",
    ]:
        require_fragment(app_tests, fragment, "backend HTTP tests", errors)

    backend_text = "\n".join(
        path.read_text(encoding="utf-8", errors="ignore")
        for path in BACKEND.rglob("*")
        if path.is_file()
    )
    for marker in SECRET_MARKERS:
        if marker in backend_text:
            errors.append(f"possible credential material/unsafe credential instruction found: {marker}")

    expected_exclude = 'exclude_filter="art/final_source/*,docs/*,tools/*,tests/*,backend/*,backend/**/*"'
    if export_text.count(expected_exclude) != 2:
        errors.append("backend sources must be explicitly excluded from both Android export presets")

    deployment = contract.get("deployment", {})
    if not isinstance(deployment, dict):
        errors.append("backend deployment contract missing")
        deployment = {}
    pending = pending_paths(contract)
    if args.release:
        if pending:
            errors.append(f"release backend contract has {len(pending)} unresolved PENDING field(s)")
        if contract.get("formal_status") != "certified" or contract.get("pass_recorded") is not True:
            errors.append("backend contract is not certified")
        endpoint = str(deployment.get("endpoint", ""))
        if not endpoint.startswith("https://"):
            errors.append("production verification endpoint must be HTTPS")
        for flag in [
            "android_publisher_api_enabled",
            "play_console_service_account_access_configured",
            "firestore_access_configured",
            "public_https_ingress_configured",
            "rate_limit_configured",
            "deployed",
        ]:
            if deployment.get(flag) is not True:
                errors.append(f"backend deployment flag not complete: {flag}")
        verification = billing.get("verification_boundary", {})
        if not isinstance(verification, dict) or verification.get("backend_endpoint") != endpoint:
            errors.append("mobile billing endpoint does not match deployed backend endpoint")
    elif pending:
        warnings.append(f"backend preflight retains {len(pending)} deployment/privacy placeholder(s)")

    mode = "RELEASE" if args.release else "PREFLIGHT"
    print(
        "PLAY_BILLING_BACKEND_GATE %s: files=%d pending=%d errors=%d warnings=%d raw_token_persisted=0 embedded_secret=0 option_presence_guard=1 monotonic_persistence=1 durable_before_grant=1 readiness=1"
        % (mode, len(REQUIRED_FILES), len(pending), len(errors), len(warnings))
    )
    for warning in warnings:
        print("WARNING:", warning)
    if errors:
        print(f"PLAY_BILLING_BACKEND_GATE FAIL: {len(errors)} issue(s)")
        for error in errors:
            print("ERROR:", error)
        return 1
    print("PLAY_BILLING_BACKEND_GATE PASS: backend implementation is internally consistent and fail-closed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
