from __future__ import annotations

from flask import Flask, jsonify, request

from firestore_repository import FirestorePurchaseRepository
from google_play_gateway import GooglePlayPublisherGateway
from verifier import VerificationService

MAX_BODY_BYTES = 16 * 1024


def create_app(service: VerificationService | None = None) -> Flask:
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = MAX_BODY_BYTES
    verification_service = service or VerificationService(
        GooglePlayPublisherGateway(),
        FirestorePurchaseRepository(),
    )

    @app.get("/healthz")
    def healthz():
        response = jsonify({"ok": True, "service": "veredas-play-purchase-verifier"})
        response.headers["Cache-Control"] = "no-store"
        return response, 200

    @app.post("/v1/play/verify")
    def verify_purchase():
        payload = request.get_json(silent=True)
        result, status = verification_service.verify(payload)
        response = jsonify(result)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response, status

    @app.after_request
    def harden_response(response):
        response.headers.setdefault("Cache-Control", "no-store")
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("Referrer-Policy", "no-referrer")
        return response

    return app


app = create_app()
