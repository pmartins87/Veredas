from __future__ import annotations

from threading import Lock
from typing import Callable

from flask import Flask, jsonify, request
from google.auth import exceptions as google_auth_exceptions

from firestore_repository import FirestorePurchaseRepository
from google_play_gateway import GooglePlayPublisherGateway
from verifier import RepositoryError, VerificationService

MAX_BODY_BYTES = 16 * 1024
SERVICE_ID = "veredas-play-purchase-verifier"


class VerificationServiceProvider:
    def __init__(
        self,
        factory: Callable[[], VerificationService],
        initial_service: VerificationService | None = None,
    ):
        self._factory = factory
        self._service = initial_service
        self._lock = Lock()
        self._last_error = ""

    def get(self) -> VerificationService | None:
        if self._service is not None:
            return self._service
        with self._lock:
            if self._service is not None:
                return self._service
            try:
                self._service = self._factory()
                self._last_error = ""
            except RepositoryError:
                self._last_error = "repository_initialization_unavailable"
            except google_auth_exceptions.GoogleAuthError:
                self._last_error = "google_identity_unavailable"
            except Exception:
                # Do not leak exception messages or configuration details through HTTP.
                self._last_error = "verification_service_initialization_failed"
            return self._service

    def last_error(self) -> str:
        return self._last_error


def _default_service() -> VerificationService:
    return VerificationService(
        GooglePlayPublisherGateway(),
        FirestorePurchaseRepository(),
    )


def _failure_from_request(error: str) -> dict:
    payload = request.get_json(silent=True)
    source = payload if isinstance(payload, dict) else {}
    return {
        "verification_request_id": str(source.get("verification_request_id", "")),
        "ok": False,
        "purchase_token": str(source.get("purchase_token", "")),
        "product_id": str(source.get("product_id", "")),
        "owned": False,
        "purchase_state": "UNSPECIFIED",
        "acknowledged": False,
        "source": "play_backend",
        "error": error,
    }


def create_app(
    service: VerificationService | None = None,
    service_factory: Callable[[], VerificationService] | None = None,
) -> Flask:
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = MAX_BODY_BYTES
    provider = VerificationServiceProvider(service_factory or _default_service, service)

    @app.get("/healthz")
    def healthz():
        return jsonify({"ok": True, "service": SERVICE_ID, "kind": "liveness"}), 200

    @app.get("/readyz")
    def readyz():
        ready = provider.get() is not None
        body = {"ok": ready, "service": SERVICE_ID, "kind": "readiness"}
        if not ready:
            body["error"] = provider.last_error() or "verification_service_unavailable"
        return jsonify(body), 200 if ready else 503

    @app.post("/v1/play/verify")
    def verify_purchase():
        verification_service = provider.get()
        if verification_service is None:
            response = jsonify(
                _failure_from_request(provider.last_error() or "verification_service_unavailable")
            )
            return response, 503
        payload = request.get_json(silent=True)
        result, status = verification_service.verify(payload)
        return jsonify(result), status

    @app.after_request
    def harden_response(response):
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        return response

    return app


app = create_app()
