from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

TTL_FIELD = "expires_at"
ACTIVE_VERIFIED_DAYS = 730
NON_OWNED_DAYS = 30
TEST_PURCHASE_DAYS = 7


def retention_days(record: dict[str, Any]) -> int:
    if bool(record.get("test_purchase", False)):
        return TEST_PURCHASE_DAYS
    purchase_state = str(record.get("purchase_state", "")).upper()
    owned = bool(record.get("owned", False))
    if purchase_state == "PURCHASED" and owned:
        return ACTIVE_VERIFIED_DAYS
    return NON_OWNED_DAYS


def retention_expiry(record: dict[str, Any], now: datetime | None = None) -> datetime:
    observed_at = now or datetime.now(timezone.utc)
    if observed_at.tzinfo is None or observed_at.utcoffset() is None:
        raise ValueError("retention_clock_must_be_timezone_aware")
    return observed_at.astimezone(timezone.utc) + timedelta(days=retention_days(record))


def policy_summary() -> dict[str, Any]:
    return {
        "ttl_field": TTL_FIELD,
        "active_verified_nonconsumable_days_since_last_activity": ACTIVE_VERIFIED_DAYS,
        "non_owned_pending_bound_cancelled_days_since_last_activity": NON_OWNED_DAYS,
        "test_purchase_days_since_last_activity": TEST_PURCHASE_DAYS,
        "refresh_on_backend_activity": True,
        "expired_record_recreation_requires_authoritative_google_verification": True,
    }
