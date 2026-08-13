from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Any, Protocol

APPLICATION_ID = "com.pmartins87.veredasdatrama"
EXPECTED_PRODUCTS = frozenset({"full_game_unlock", "supporter_cosmetic_pack"})
SOURCE_ID = "play_backend"
PURCHASED = "PURCHASED"
PENDING = "PENDING"
CANCELLED = "CANCELLED"
ACK_PENDING = "ACKNOWLEDGEMENT_STATE_PENDING"
ACKNOWLEDGED = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
MAX_REQUEST_ID_CHARS = 160
MAX_PURCHASE_TOKEN_CHARS = 4096


class GatewayError(RuntimeError):
    def __init__(self, code: str, status_code: int = 0):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


class PlayGateway(Protocol):
    def fetch_purchase(self, package_name: str, purchase_token: str) -> dict[str, Any]: ...
    def acknowledge(self, package_name: str, product_id: str, purchase_token: str) -> None: ...


class PurchaseRepository(Protocol):
    def bind(self, token_hash: str, package_name: str, product_id: str) -> bool: ...
    def record(self, token_hash: str, values: dict[str, Any]) -> None: ...


@dataclass(frozen=True)
class ValidatedRequest:
    verification_request_id: str
    product_id: str
    purchase_token: str

    @property
    def token_hash(self) -> str:
        return hashlib.sha256(self.purchase_token.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class AuthoritativePurchase:
    purchase_state: str
    acknowledgement_state: str
    product_id: str
    quantity: int
    purchase_completion_time: str
    test_purchase: bool


class VerificationService:
    def __init__(self, gateway: PlayGateway, repository: PurchaseRepository):
        self._gateway = gateway
        self._repository = repository

    def verify(self, payload: Any) -> tuple[dict[str, Any], int]:
        try:
            request = self._validate_request(payload)
        except ValueError as exc:
            return self._failure_from_payload(payload, str(exc)), 400

        try:
            raw = self._gateway.fetch_purchase(APPLICATION_ID, request.purchase_token)
        except GatewayError as exc:
            if exc.status_code in {400, 404}:
                return self._failure(request, "play_purchase_not_found"), 200
            return self._failure(request, "play_verification_unavailable"), 503

        try:
            purchase = self._parse_authoritative(raw, request.product_id)
        except ValueError as exc:
            return self._failure(request, str(exc)), 200

        if not self._repository.bind(request.token_hash, APPLICATION_ID, purchase.product_id):
            return self._failure(request, "purchase_token_bound_to_different_product"), 200

        if purchase.purchase_state != PURCHASED:
            self._record(request, purchase, owned=False, stage="not_purchased")
            return self._failure(
                request,
                "authoritative_purchase_state_not_purchased",
                purchase_state=purchase.purchase_state,
                acknowledged=purchase.acknowledgement_state == ACKNOWLEDGED,
            ), 200

        if purchase.acknowledgement_state == ACK_PENDING:
            self._record(request, purchase, owned=False, stage="verified_pending_ack")
            try:
                self._gateway.acknowledge(APPLICATION_ID, purchase.product_id, request.purchase_token)
            except GatewayError:
                # Another concurrent request may have acknowledged this globally unique token.
                # Refetch before deciding whether the acknowledgement actually failed.
                pass
            try:
                raw_after_ack = self._gateway.fetch_purchase(APPLICATION_ID, request.purchase_token)
            except GatewayError:
                return self._failure(request, "play_acknowledgement_confirmation_unavailable"), 503
            try:
                purchase = self._parse_authoritative(raw_after_ack, request.product_id)
            except ValueError as exc:
                return self._failure(request, str(exc)), 200

        if purchase.purchase_state != PURCHASED:
            self._record(request, purchase, owned=False, stage="state_changed_after_ack")
            return self._failure(
                request,
                "purchase_state_changed_before_grant",
                purchase_state=purchase.purchase_state,
                acknowledged=purchase.acknowledgement_state == ACKNOWLEDGED,
            ), 200
        if purchase.acknowledgement_state != ACKNOWLEDGED:
            self._record(request, purchase, owned=False, stage="ack_not_confirmed")
            return self._failure(request, "acknowledgement_not_confirmed"), 503

        self._record(request, purchase, owned=True, stage="owned_acknowledged")
        return {
            "verification_request_id": request.verification_request_id,
            "ok": True,
            "purchase_token": request.purchase_token,
            "product_id": request.product_id,
            "owned": True,
            "purchase_state": PURCHASED,
            "acknowledged": True,
            "source": SOURCE_ID,
        }, 200

    def _validate_request(self, payload: Any) -> ValidatedRequest:
        if not isinstance(payload, dict):
            raise ValueError("request_not_json_object")
        request_id = str(payload.get("verification_request_id", "")).strip()
        application_id = str(payload.get("application_id", "")).strip()
        package_name = str(payload.get("package_name", "")).strip()
        product_id = str(payload.get("product_id", "")).strip()
        purchase_token = str(payload.get("purchase_token", "")).strip()
        purchase_time = payload.get("purchase_time", 0)
        acknowledged = payload.get("client_acknowledged_state", False)

        if not request_id or len(request_id) > MAX_REQUEST_ID_CHARS:
            raise ValueError("verification_request_id_invalid")
        if application_id != APPLICATION_ID or package_name != APPLICATION_ID:
            raise ValueError("application_id_mismatch")
        if product_id not in EXPECTED_PRODUCTS:
            raise ValueError("product_id_invalid")
        if not purchase_token or len(purchase_token) > MAX_PURCHASE_TOKEN_CHARS:
            raise ValueError("purchase_token_invalid")
        if type(purchase_time) is not int or purchase_time < 0:
            raise ValueError("purchase_time_invalid")
        if type(acknowledged) is not bool:
            raise ValueError("client_acknowledged_state_invalid")
        return ValidatedRequest(request_id, product_id, purchase_token)

    def _parse_authoritative(self, raw: Any, claimed_product_id: str) -> AuthoritativePurchase:
        if not isinstance(raw, dict):
            raise ValueError("play_response_not_object")
        state_context = raw.get("purchaseStateContext", {})
        if not isinstance(state_context, dict):
            raise ValueError("play_purchase_state_context_missing")
        purchase_state = str(state_context.get("purchaseState", ""))
        if purchase_state not in {PURCHASED, PENDING, CANCELLED}:
            raise ValueError("play_purchase_state_invalid")

        line_items = raw.get("productLineItem", [])
        if not isinstance(line_items, list) or len(line_items) != 1 or not isinstance(line_items[0], dict):
            raise ValueError("play_product_line_item_cardinality_invalid")
        line_item = line_items[0]
        authoritative_product_id = str(line_item.get("productId", ""))
        if authoritative_product_id not in EXPECTED_PRODUCTS:
            raise ValueError("play_product_not_configured")
        if authoritative_product_id != claimed_product_id:
            raise ValueError("play_product_claim_mismatch")

        offer_details = line_item.get("productOfferDetails")
        if not isinstance(offer_details, dict):
            raise ValueError("play_product_offer_details_missing")
        quantity = offer_details.get("quantity", 0)
        if type(quantity) is not int or quantity != 1:
            raise ValueError("play_product_quantity_invalid")
        purchase_option_id = str(offer_details.get("purchaseOptionId", "")).strip()
        if not purchase_option_id:
            raise ValueError("play_purchase_option_id_missing")
        if "offerId" in offer_details:
            raise ValueError("play_offer_not_allowed_at_launch")
        # RentOfferDetails intentionally has no fields in ProductPurchaseV2, therefore
        # rentOfferDetails: {} is meaningful presence and must not be treated as absent.
        if "rentOfferDetails" in offer_details:
            raise ValueError("play_rent_not_allowed_at_launch")
        if "preorderOfferDetails" in offer_details:
            raise ValueError("play_preorder_not_allowed_at_launch")

        acknowledgement_state = str(raw.get("acknowledgementState", ""))
        if acknowledgement_state not in {ACK_PENDING, ACKNOWLEDGED}:
            raise ValueError("play_acknowledgement_state_invalid")
        test_context = raw.get("testPurchaseContext")
        test_purchase = isinstance(test_context, dict) and str(test_context.get("fopType", "")) == "TEST"
        return AuthoritativePurchase(
            purchase_state=purchase_state,
            acknowledgement_state=acknowledgement_state,
            product_id=authoritative_product_id,
            quantity=quantity,
            purchase_completion_time=str(raw.get("purchaseCompletionTime", "")),
            test_purchase=test_purchase,
        )

    def _record(
        self,
        request: ValidatedRequest,
        purchase: AuthoritativePurchase,
        *,
        owned: bool,
        stage: str,
    ) -> None:
        self._repository.record(
            request.token_hash,
            {
                "package_name": APPLICATION_ID,
                "product_id": purchase.product_id,
                "purchase_state": purchase.purchase_state,
                "acknowledgement_state": purchase.acknowledgement_state,
                "owned": owned,
                "processing_stage": stage,
                "purchase_completion_time": purchase.purchase_completion_time,
                "test_purchase": purchase.test_purchase,
            },
        )

    def _failure(
        self,
        request: ValidatedRequest,
        error: str,
        *,
        purchase_state: str = "UNSPECIFIED",
        acknowledged: bool = False,
    ) -> dict[str, Any]:
        return {
            "verification_request_id": request.verification_request_id,
            "ok": False,
            "purchase_token": request.purchase_token,
            "product_id": request.product_id,
            "owned": False,
            "purchase_state": purchase_state,
            "acknowledged": acknowledged,
            "source": SOURCE_ID,
            "error": error,
        }

    def _failure_from_payload(self, payload: Any, error: str) -> dict[str, Any]:
        source = payload if isinstance(payload, dict) else {}
        return {
            "verification_request_id": str(source.get("verification_request_id", "")),
            "ok": False,
            "purchase_token": str(source.get("purchase_token", "")),
            "product_id": str(source.get("product_id", "")),
            "owned": False,
            "purchase_state": "UNSPECIFIED",
            "acknowledged": False,
            "source": SOURCE_ID,
            "error": error,
        }
