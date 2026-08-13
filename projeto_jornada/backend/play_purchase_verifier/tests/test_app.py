from __future__ import annotations

import unittest

from app import create_app
from verifier import RepositoryError


class FakeService:
    def verify(self, payload):
        return {
            "verification_request_id": str((payload or {}).get("verification_request_id", "")),
            "ok": True,
            "purchase_token": str((payload or {}).get("purchase_token", "")),
            "product_id": str((payload or {}).get("product_id", "")),
            "owned": True,
            "purchase_state": "PURCHASED",
            "acknowledged": True,
            "source": "play_backend",
        }, 200


class BackendAppTests(unittest.TestCase):
    def payload(self):
        return {
            "verification_request_id": "vreq-test-1",
            "application_id": "com.pmartins87.veredasdatrama",
            "package_name": "com.pmartins87.veredasdatrama",
            "product_id": "full_game_unlock",
            "purchase_token": "synthetic-test-token",
            "purchase_time": 1,
            "client_acknowledged_state": False,
        }

    def test_liveness_does_not_initialize_dependencies(self):
        calls = []

        def factory():
            calls.append("called")
            raise RepositoryError("should_not_run")

        client = create_app(service_factory=factory).test_client()
        response = client.get("/healthz")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["kind"], "liveness")
        self.assertEqual(calls, [])
        self.assertEqual(response.headers["Cache-Control"], "no-store")

    def test_ready_service_reports_readiness_without_external_call(self):
        client = create_app(service=FakeService()).test_client()
        response = client.get("/readyz")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {
            "kind": "readiness",
            "ok": True,
            "service": "veredas-play-purchase-verifier",
        })

    def test_failed_readiness_can_recover_on_next_probe(self):
        calls = []

        def factory():
            calls.append(len(calls) + 1)
            if len(calls) == 1:
                raise RepositoryError("temporary_firestore_init")
            return FakeService()

        client = create_app(service_factory=factory).test_client()
        first = client.get("/readyz")
        second = client.get("/readyz")
        self.assertEqual(first.status_code, 503)
        self.assertEqual(first.get_json()["error"], "repository_initialization_unavailable")
        self.assertEqual(second.status_code, 200)
        self.assertTrue(second.get_json()["ok"])
        self.assertEqual(calls, [1, 2])

    def test_initialization_exception_message_is_not_exposed(self):
        def factory():
            raise RuntimeError("sensitive-configuration-detail")

        client = create_app(service_factory=factory).test_client()
        response = client.get("/readyz")
        self.assertEqual(response.status_code, 503)
        body = response.get_json()
        self.assertEqual(body["error"], "verification_service_initialization_failed")
        self.assertNotIn("sensitive", response.get_data(as_text=True))

    def test_unavailable_service_never_returns_owned_true(self):
        def factory():
            raise RepositoryError("temporary_firestore_init")

        client = create_app(service_factory=factory).test_client()
        response = client.post("/v1/play/verify", json=self.payload())
        self.assertEqual(response.status_code, 503)
        body = response.get_json()
        self.assertFalse(body["ok"])
        self.assertFalse(body["owned"])
        self.assertEqual(body["error"], "repository_initialization_unavailable")
        self.assertEqual(body["verification_request_id"], "vreq-test-1")
        self.assertEqual(response.headers["Cache-Control"], "no-store")

    def test_ready_service_forwards_verification_result(self):
        client = create_app(service=FakeService()).test_client()
        response = client.post("/v1/play/verify", json=self.payload())
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertTrue(body["ok"])
        self.assertTrue(body["owned"])
        self.assertEqual(body["verification_request_id"], "vreq-test-1")
        self.assertEqual(response.headers["X-Content-Type-Options"], "nosniff")
        self.assertEqual(response.headers["Referrer-Policy"], "no-referrer")


if __name__ == "__main__":
    unittest.main()
