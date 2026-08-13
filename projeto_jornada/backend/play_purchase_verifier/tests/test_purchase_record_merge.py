from __future__ import annotations

import unittest

from purchase_record_merge import merge_purchase_record

ACK_PENDING = "ACKNOWLEDGEMENT_STATE_PENDING"
ACKNOWLEDGED = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"


def record(state: str, *, owned: bool, ack: str, stage: str) -> dict:
    return {
        "package_name": "com.pmartins87.veredasdatrama",
        "product_id": "full_game_unlock",
        "purchase_state": state,
        "acknowledgement_state": ack,
        "owned": owned,
        "processing_stage": stage,
        "purchase_completion_time": "2026-08-12T23:59:00Z" if state != "PENDING" else "",
        "test_purchase": False,
    }


class PurchaseRecordMergeTests(unittest.TestCase):
    def test_pending_can_advance_to_purchased_owned(self):
        current = record("PENDING", owned=False, ack=ACK_PENDING, stage="not_purchased")
        incoming = record("PURCHASED", owned=True, ack=ACKNOWLEDGED, stage="owned_acknowledged")
        merged = merge_purchase_record(current, incoming)
        self.assertFalse(merged["stale_observation"])
        self.assertEqual(merged["effective"]["purchase_state"], "PURCHASED")
        self.assertTrue(merged["effective"]["owned"])
        self.assertEqual(merged["effective"]["acknowledgement_state"], ACKNOWLEDGED)

    def test_late_pending_cannot_regress_purchased_owned(self):
        current = record("PURCHASED", owned=True, ack=ACKNOWLEDGED, stage="owned_acknowledged")
        incoming = record("PENDING", owned=False, ack=ACK_PENDING, stage="not_purchased")
        merged = merge_purchase_record(current, incoming)
        self.assertTrue(merged["stale_observation"])
        self.assertEqual(merged["effective"], {})

    def test_late_pre_ack_purchased_write_cannot_clear_owned(self):
        current = record("PURCHASED", owned=True, ack=ACKNOWLEDGED, stage="owned_acknowledged")
        incoming = record("PURCHASED", owned=False, ack=ACK_PENDING, stage="verified_pending_ack")
        merged = merge_purchase_record(current, incoming)
        self.assertFalse(merged["stale_observation"])
        self.assertTrue(merged["effective"]["owned"])
        self.assertEqual(merged["effective"]["acknowledgement_state"], ACKNOWLEDGED)
        self.assertEqual(merged["effective"]["processing_stage"], "owned_acknowledged")

    def test_acknowledgement_cannot_regress_within_purchased(self):
        current = record("PURCHASED", owned=False, ack=ACKNOWLEDGED, stage="ack_not_confirmed")
        incoming = record("PURCHASED", owned=False, ack=ACK_PENDING, stage="verified_pending_ack")
        merged = merge_purchase_record(current, incoming)
        self.assertEqual(merged["effective"]["acknowledgement_state"], ACKNOWLEDGED)

    def test_cancelled_after_purchased_is_terminal_revocation(self):
        current = record("PURCHASED", owned=True, ack=ACKNOWLEDGED, stage="owned_acknowledged")
        incoming = record("CANCELLED", owned=True, ack=ACKNOWLEDGED, stage="not_purchased")
        merged = merge_purchase_record(current, incoming)
        self.assertFalse(merged["stale_observation"])
        self.assertEqual(merged["effective"]["purchase_state"], "CANCELLED")
        self.assertFalse(merged["effective"]["owned"])

    def test_late_purchased_cannot_resurrect_cancelled(self):
        current = record("CANCELLED", owned=False, ack=ACKNOWLEDGED, stage="not_purchased")
        incoming = record("PURCHASED", owned=True, ack=ACKNOWLEDGED, stage="owned_acknowledged")
        merged = merge_purchase_record(current, incoming)
        self.assertTrue(merged["stale_observation"])
        self.assertEqual(merged["effective"], {})

    def test_unknown_purchase_state_fails_closed(self):
        current = record("PURCHASED", owned=True, ack=ACKNOWLEDGED, stage="owned_acknowledged")
        incoming = record("FUTURE_UNKNOWN", owned=True, ack=ACKNOWLEDGED, stage="owned_acknowledged")
        with self.assertRaisesRegex(ValueError, "incoming_purchase_state_invalid"):
            merge_purchase_record(current, incoming)

    def test_unknown_acknowledgement_state_fails_closed(self):
        current = record("PURCHASED", owned=False, ack=ACK_PENDING, stage="verified_pending_ack")
        incoming = record("PURCHASED", owned=True, ack="FUTURE_UNKNOWN", stage="owned_acknowledged")
        with self.assertRaisesRegex(ValueError, "incoming_acknowledgement_state_invalid"):
            merge_purchase_record(current, incoming)


if __name__ == "__main__":
    unittest.main()
