from __future__ import annotations

import unittest

from verifier import (
    ACKNOWLEDGED,
    ACK_PENDING,
    APPLICATION_ID,
    GatewayError,
    RepositoryError,
    VerificationService,
)


class FakeGateway:
    def __init__(self, responses=None, ack_error: GatewayError | None = None):
        self.responses = list(responses or [])
        self.ack_error = ack_error
        self.fetch_calls = []
        self.ack_calls = []

    def fetch_purchase(self, package_name: str, purchase_token: str):
        self.fetch_calls.append((package_name, purchase_token))
        if not self.responses:
            raise AssertionError("unexpected fetch")
        value = self.responses.pop(0)
        if isinstance(value, Exception):
            raise value
        return value

    def acknowledge(self, package_name: str, product_id: str, purchase_token: str) -> None:
        self.ack_calls.append((package_name, product_id, purchase_token))
        if self.ack_error is not None:
            raise self.ack_error


class MemoryRepository:
    def __init__(self):
        self.bindings = {}
        self.records = {}

    def bind(self, token_hash: str, package_name: str, product_id: str) -> bool:
        prior = self.bindings.get(token_hash)
        if prior is not None and prior != (package_name, product_id):
            return False
        self.bindings[token_hash] = (package_name, product_id)
        return True

    def record(self, token_hash: str, values: dict) -> None:
        self.records.setdefault(token_hash, []).append(dict(values))


class FailingRepository(MemoryRepository):
    def __init__(self, *, fail_bind: bool = False, fail_record_number: int = 0):
        super().__init__()
        self.fail_bind = fail_bind
        self.fail_record_number = fail_record_number
        self.record_attempts = 0

    def bind(self, token_hash: str, package_name: str, product_id: str) -> bool:
        if self.fail_bind:
            raise RepositoryError("synthetic_bind_outage")
        return super().bind(token_hash, package_name, product_id)

    def record(self, token_hash: str, values: dict) -> None:
        self.record_attempts += 1
        if self.fail_record_number == self.record_attempts:
            raise RepositoryError("synthetic_record_outage")
        super().record(token_hash, values)


class VerificationServiceTests(unittest.TestCase):
    def request(self, product_id="full_game_unlock", token="token-123"):
        return {
            "verification_request_id": "vreq-purchase-0-1",
            "application_id": APPLICATION_ID,
            "package_name": APPLICATION_ID,
            "product_id": product_id,
            "purchase_token": token,
            "purchase_time": 1786540000000,
            "client_acknowledged_state": False,
        }

    def play_purchase(
        self,
        product_id="full_game_unlock",
        state="PURCHASED",
        acknowledgement=ACK_PENDING,
        quantity=1,
        offer_id_marker=False,
        rent_marker=False,
        preorder_marker=False,
        purchase_option_id="buy",
    ):
        offer = {"quantity": quantity, "purchaseOptionId": purchase_option_id}
        if offer_id_marker:
            offer["offerId"] = "promo"
        if rent_marker:
            offer["rentOfferDetails"] = {}
        if preorder_marker:
            offer["preorderOfferDetails"] = {"preorderReleaseTime": "2027-01-01T00:00:00Z"}
        return {
            "productLineItem": [{"productId": product_id, "productOfferDetails": offer}],
            "purchaseStateContext": {"purchaseState": state},
            "acknowledgementState": acknowledgement,
            "purchaseCompletionTime": "2026-08-12T23:59:00Z" if state == "PURCHASED" else "",
        }

    def test_unacknowledged_purchase_is_acknowledged_refetched_and_granted(self):
        gateway = FakeGateway([
            self.play_purchase(),
            self.play_purchase(acknowledgement=ACKNOWLEDGED),
        ])
        repository = MemoryRepository()
        result, status = VerificationService(gateway, repository).verify(self.request())
        self.assertEqual(status, 200)
        self.assertTrue(result["ok"])
        self.assertTrue(result["owned"])
        self.assertTrue(result["acknowledged"])
        self.assertEqual(len(gateway.ack_calls), 1)
        self.assertEqual(len(gateway.fetch_calls), 2)
        token_hash = next(iter(repository.records))
        self.assertNotEqual(token_hash, "token-123")
        self.assertFalse(repository.records[token_hash][0]["owned"])
        self.assertTrue(repository.records[token_hash][-1]["owned"])

    def test_already_acknowledged_purchase_grants_without_ack_call(self):
        gateway = FakeGateway([self.play_purchase(acknowledgement=ACKNOWLEDGED)])
        result, status = VerificationService(gateway, MemoryRepository()).verify(self.request())
        self.assertEqual(status, 200)
        self.assertTrue(result["ok"])
        self.assertEqual(gateway.ack_calls, [])

    def test_pending_authoritative_state_never_grants(self):
        gateway = FakeGateway([self.play_purchase(state="PENDING")])
        repository = MemoryRepository()
        result, status = VerificationService(gateway, repository).verify(self.request())
        self.assertEqual(status, 200)
        self.assertFalse(result["ok"])
        self.assertFalse(result["owned"])
        self.assertEqual(result["purchase_state"], "PENDING")
        self.assertEqual(gateway.ack_calls, [])
        token_hash = next(iter(repository.records))
        self.assertFalse(repository.records[token_hash][-1]["owned"])

    def test_cancelled_authoritative_state_never_grants(self):
        gateway = FakeGateway([self.play_purchase(state="CANCELLED", acknowledgement=ACKNOWLEDGED)])
        result, status = VerificationService(gateway, MemoryRepository()).verify(self.request())
        self.assertEqual(status, 200)
        self.assertFalse(result["ok"])
        self.assertEqual(result["purchase_state"], "CANCELLED")
        self.assertFalse(result["owned"])

    def test_claimed_product_must_equal_authoritative_line_item_before_binding(self):
        gateway = FakeGateway([self.play_purchase(product_id="supporter_cosmetic_pack")])
        repository = MemoryRepository()
        result, status = VerificationService(gateway, repository).verify(self.request("full_game_unlock"))
        self.assertEqual(status, 200)
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "play_product_claim_mismatch")
        self.assertEqual(repository.bindings, {})

    def test_quantity_must_be_exactly_one(self):
        gateway = FakeGateway([self.play_purchase(quantity=2)])
        repository = MemoryRepository()
        result, status = VerificationService(gateway, repository).verify(self.request())
        self.assertEqual(status, 200)
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "play_product_quantity_invalid")
        self.assertEqual(repository.bindings, {})

    def test_purchase_option_id_is_required(self):
        gateway = FakeGateway([self.play_purchase(purchase_option_id="")])
        repository = MemoryRepository()
        result, status = VerificationService(gateway, repository).verify(self.request())
        self.assertEqual(status, 200)
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "play_purchase_option_id_missing")
        self.assertEqual(repository.bindings, {})

    def test_launch_offer_rent_and_preorder_presence_are_rejected(self):
        for purchase, error in [
            (self.play_purchase(offer_id_marker=True), "play_offer_not_allowed_at_launch"),
            (self.play_purchase(rent_marker=True), "play_rent_not_allowed_at_launch"),
            (self.play_purchase(preorder_marker=True), "play_preorder_not_allowed_at_launch"),
        ]:
            repository = MemoryRepository()
            result, status = VerificationService(FakeGateway([purchase]), repository).verify(self.request())
            self.assertEqual(status, 200)
            self.assertFalse(result["ok"])
            self.assertEqual(result["error"], error)
            self.assertEqual(repository.bindings, {})

    def test_existing_token_binding_cannot_switch_product(self):
        gateway = FakeGateway([self.play_purchase()])
        repository = MemoryRepository()
        from hashlib import sha256
        token_hash = sha256(b"token-123").hexdigest()
        repository.bindings[token_hash] = (APPLICATION_ID, "supporter_cosmetic_pack")
        result, status = VerificationService(gateway, repository).verify(self.request())
        self.assertEqual(status, 200)
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "purchase_token_bound_to_different_product")
        self.assertEqual(gateway.ack_calls, [])

    def test_repository_bind_outage_never_grants_or_acknowledges(self):
        gateway = FakeGateway([self.play_purchase(acknowledgement=ACKNOWLEDGED)])
        result, status = VerificationService(gateway, FailingRepository(fail_bind=True)).verify(self.request())
        self.assertEqual(status, 503)
        self.assertFalse(result["ok"])
        self.assertFalse(result["owned"])
        self.assertEqual(result["error"], "repository_unavailable")
        self.assertEqual(gateway.ack_calls, [])

    def test_repository_pre_ack_record_outage_stops_before_acknowledgement(self):
        gateway = FakeGateway([self.play_purchase()])
        repository = FailingRepository(fail_record_number=1)
        result, status = VerificationService(gateway, repository).verify(self.request())
        self.assertEqual(status, 503)
        self.assertFalse(result["ok"])
        self.assertFalse(result["owned"])
        self.assertEqual(result["error"], "repository_unavailable")
        self.assertEqual(gateway.ack_calls, [])

    def test_repository_final_record_outage_never_returns_owned_true(self):
        gateway = FakeGateway([
            self.play_purchase(),
            self.play_purchase(acknowledgement=ACKNOWLEDGED),
        ])
        repository = FailingRepository(fail_record_number=2)
        result, status = VerificationService(gateway, repository).verify(self.request())
        self.assertEqual(status, 503)
        self.assertFalse(result["ok"])
        self.assertFalse(result["owned"])
        self.assertEqual(result["error"], "repository_unavailable")
        self.assertEqual(len(gateway.ack_calls), 1)
        self.assertEqual(repository.record_attempts, 2)

    def test_concurrent_ack_error_is_safe_if_refetch_confirms_acknowledged(self):
        gateway = FakeGateway(
            [self.play_purchase(), self.play_purchase(acknowledgement=ACKNOWLEDGED)],
            ack_error=GatewayError("already_acknowledged", 409),
        )
        result, status = VerificationService(gateway, MemoryRepository()).verify(self.request())
        self.assertEqual(status, 200)
        self.assertTrue(result["ok"])
        self.assertTrue(result["acknowledged"])

    def test_failed_ack_never_grants_if_refetch_stays_pending(self):
        gateway = FakeGateway(
            [self.play_purchase(), self.play_purchase(acknowledgement=ACK_PENDING)],
            ack_error=GatewayError("ack_failed", 503),
        )
        repository = MemoryRepository()
        result, status = VerificationService(gateway, repository).verify(self.request())
        self.assertEqual(status, 503)
        self.assertFalse(result["ok"])
        self.assertFalse(result["owned"])
        token_hash = next(iter(repository.records))
        self.assertFalse(repository.records[token_hash][-1]["owned"])

    def test_invalid_token_is_structured_verification_failure(self):
        gateway = FakeGateway([GatewayError("not_found", 404)])
        result, status = VerificationService(gateway, MemoryRepository()).verify(self.request())
        self.assertEqual(status, 200)
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "play_purchase_not_found")

    def test_play_outage_returns_service_unavailable_without_grant(self):
        gateway = FakeGateway([GatewayError("unavailable", 503)])
        result, status = VerificationService(gateway, MemoryRepository()).verify(self.request())
        self.assertEqual(status, 503)
        self.assertFalse(result["ok"])
        self.assertFalse(result["owned"])

    def test_wrong_package_is_rejected_before_google_call(self):
        payload = self.request()
        payload["package_name"] = "com.example.impostor"
        gateway = FakeGateway([])
        result, status = VerificationService(gateway, MemoryRepository()).verify(payload)
        self.assertEqual(status, 400)
        self.assertFalse(result["ok"])
        self.assertEqual(gateway.fetch_calls, [])


if __name__ == "__main__":
    unittest.main()
