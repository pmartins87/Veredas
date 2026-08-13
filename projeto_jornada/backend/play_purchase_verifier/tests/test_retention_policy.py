from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone

from retention_policy import (
    ACTIVE_VERIFIED_DAYS,
    NON_OWNED_DAYS,
    TEST_PURCHASE_DAYS,
    policy_summary,
    retention_days,
    retention_expiry,
)


class RetentionPolicyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 8, 13, 12, 0, tzinfo=timezone.utc)

    def test_verified_owned_purchase_uses_long_finite_window(self) -> None:
        record = {"purchase_state": "PURCHASED", "owned": True, "test_purchase": False}
        self.assertEqual(retention_days(record), ACTIVE_VERIFIED_DAYS)
        self.assertEqual(retention_expiry(record, self.now), self.now + timedelta(days=730))

    def test_pending_bound_and_cancelled_records_use_short_window(self) -> None:
        cases = [
            {"processing_stage": "bound", "owned": False},
            {"purchase_state": "PENDING", "owned": False},
            {"purchase_state": "CANCELLED", "owned": False},
            {"purchase_state": "PURCHASED", "owned": False},
        ]
        for record in cases:
            with self.subTest(record=record):
                self.assertEqual(retention_days(record), NON_OWNED_DAYS)
                self.assertEqual(retention_expiry(record, self.now), self.now + timedelta(days=30))

    def test_test_purchase_always_uses_shortest_window(self) -> None:
        record = {"purchase_state": "PURCHASED", "owned": True, "test_purchase": True}
        self.assertEqual(retention_days(record), TEST_PURCHASE_DAYS)
        self.assertEqual(retention_expiry(record, self.now), self.now + timedelta(days=7))

    def test_expiry_is_normalized_to_utc(self) -> None:
        local = datetime(2026, 8, 13, 7, 0, tzinfo=timezone(timedelta(hours=-5)))
        expiry = retention_expiry({"purchase_state": "PENDING", "owned": False}, local)
        self.assertEqual(expiry.tzinfo, timezone.utc)
        self.assertEqual(expiry, datetime(2026, 9, 12, 12, 0, tzinfo=timezone.utc))

    def test_naive_clock_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "retention_clock_must_be_timezone_aware"):
            retention_expiry({}, datetime(2026, 8, 13, 12, 0))

    def test_policy_summary_matches_frozen_contract(self) -> None:
        summary = policy_summary()
        self.assertEqual(summary["ttl_field"], "expires_at")
        self.assertEqual(summary["active_verified_nonconsumable_days_since_last_activity"], 730)
        self.assertEqual(summary["non_owned_pending_bound_cancelled_days_since_last_activity"], 30)
        self.assertEqual(summary["test_purchase_days_since_last_activity"], 7)
        self.assertTrue(summary["refresh_on_backend_activity"])
        self.assertTrue(summary["expired_record_recreation_requires_authoritative_google_verification"])


if __name__ == "__main__":
    unittest.main()
