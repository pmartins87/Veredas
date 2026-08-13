from __future__ import annotations

import time
from typing import Any
from urllib.parse import quote

import google.auth
from google.auth import exceptions as google_auth_exceptions
from google.auth.transport.requests import AuthorizedSession
import requests

from verifier import GatewayError

ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
API_ROOT = "https://androidpublisher.googleapis.com/androidpublisher/v3"
RETRYABLE_STATUS = {429, 500, 502, 503, 504}
MAX_ATTEMPTS = 2
CONNECT_TIMEOUT_SECONDS = 1.5
READ_TIMEOUT_SECONDS = 2.5
BACKOFF_BASE_SECONDS = 0.25


class GooglePlayPublisherGateway:
    def __init__(self, session: AuthorizedSession | None = None):
        if session is None:
            credentials, _ = google.auth.default(scopes=[ANDROID_PUBLISHER_SCOPE])
            session = AuthorizedSession(credentials)
        self._session = session

    def fetch_purchase(self, package_name: str, purchase_token: str) -> dict[str, Any]:
        url = (
            f"{API_ROOT}/applications/{quote(package_name, safe='')}"
            f"/purchases/productsv2/tokens/{quote(purchase_token, safe='')}"
        )
        response = self._request("GET", url)
        try:
            payload = response.json()
        except ValueError as exc:
            raise GatewayError("play_response_invalid_json", response.status_code) from exc
        if not isinstance(payload, dict):
            raise GatewayError("play_response_not_object", response.status_code)
        return payload

    def acknowledge(self, package_name: str, product_id: str, purchase_token: str) -> None:
        url = (
            f"{API_ROOT}/applications/{quote(package_name, safe='')}"
            f"/purchases/products/{quote(product_id, safe='')}"
            f"/tokens/{quote(purchase_token, safe='')}:acknowledge"
        )
        self._request("POST", url, json_body={})

    def _request(self, method: str, url: str, json_body: dict[str, Any] | None = None):
        last_error: Exception | None = None
        for attempt in range(MAX_ATTEMPTS):
            try:
                response = self._session.request(
                    method,
                    url,
                    json=json_body,
                    timeout=(CONNECT_TIMEOUT_SECONDS, READ_TIMEOUT_SECONDS),
                    headers={"Accept": "application/json", "Cache-Control": "no-store"},
                )
            except (requests.RequestException, google_auth_exceptions.GoogleAuthError) as exc:
                last_error = exc
                if attempt + 1 < MAX_ATTEMPTS:
                    time.sleep(BACKOFF_BASE_SECONDS * (2**attempt))
                    continue
                raise GatewayError("play_transport_or_auth_error") from exc

            if 200 <= response.status_code < 300:
                return response
            if response.status_code in RETRYABLE_STATUS and attempt + 1 < MAX_ATTEMPTS:
                time.sleep(BACKOFF_BASE_SECONDS * (2**attempt))
                continue
            raise GatewayError("play_http_error", response.status_code)

        raise GatewayError("play_transport_or_auth_error") from last_error
