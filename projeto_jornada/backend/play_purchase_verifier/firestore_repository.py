from __future__ import annotations

import os
from typing import Any

from google.cloud import firestore

DEFAULT_COLLECTION = "play_purchase_tokens_v1"
PURCHASE_STATE_RANK = {
    "": 0,
    "PENDING": 1,
    "PURCHASED": 2,
    "CANCELLED": 3,
}
ACK_STATE_RANK = {
    "": 0,
    "ACKNOWLEDGEMENT_STATE_PENDING": 1,
    "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED": 2,
}


def merge_purchase_record(current: dict[str, Any], incoming: dict[str, Any]) -> dict[str, Any]:
    current_state = str(current.get("purchase_state", ""))
    incoming_state = str(incoming.get("purchase_state", ""))
    current_rank = PURCHASE_STATE_RANK.get(current_state, 0)
    incoming_rank = PURCHASE_STATE_RANK.get(incoming_state, 0)

    if incoming_rank < current_rank:
        return {
            "stale_observation": True,
            "effective": {},
        }

    effective = dict(incoming)
    current_ack = str(current.get("acknowledgement_state", ""))
    incoming_ack = str(incoming.get("acknowledgement_state", ""))
    if ACK_STATE_RANK.get(current_ack, 0) > ACK_STATE_RANK.get(incoming_ack, 0):
        effective["acknowledgement_state"] = current_ack

    if incoming_state == "PURCHASED" and current_state == "PURCHASED":
        effective["owned"] = bool(current.get("owned", False)) or bool(incoming.get("owned", False))
        if bool(current.get("owned", False)) and not bool(incoming.get("owned", False)):
            effective["processing_stage"] = str(current.get("processing_stage", "owned_acknowledged"))
    elif incoming_state in {"PENDING", "CANCELLED"}:
        effective["owned"] = False

    return {
        "stale_observation": False,
        "effective": effective,
    }


class FirestorePurchaseRepository:
    def __init__(self, client: firestore.Client | None = None, collection_name: str | None = None):
        self._client = client or firestore.Client()
        self._collection_name = collection_name or os.environ.get("FIRESTORE_COLLECTION", DEFAULT_COLLECTION)
        if not self._collection_name or "/" in self._collection_name:
            raise RuntimeError("invalid FIRESTORE_COLLECTION")
        self._collection = self._client.collection(self._collection_name)

    def bind(self, token_hash: str, package_name: str, product_id: str) -> bool:
        document = self._collection.document(token_hash)
        transaction = self._client.transaction()

        @firestore.transactional
        def bind_transaction(txn: firestore.Transaction) -> bool:
            snapshot = document.get(transaction=txn)
            if snapshot.exists:
                current = snapshot.to_dict() or {}
                if str(current.get("package_name", "")) != package_name:
                    return False
                if str(current.get("product_id", "")) != product_id:
                    return False
                txn.set(document, {"last_seen_at": firestore.SERVER_TIMESTAMP}, merge=True)
                return True
            txn.set(
                document,
                {
                    "package_name": package_name,
                    "product_id": product_id,
                    "owned": False,
                    "processing_stage": "bound",
                    "created_at": firestore.SERVER_TIMESTAMP,
                    "last_seen_at": firestore.SERVER_TIMESTAMP,
                },
            )
            return True

        return bool(bind_transaction(transaction))

    def record(self, token_hash: str, values: dict[str, Any]) -> None:
        incoming = {
            "package_name": str(values.get("package_name", "")),
            "product_id": str(values.get("product_id", "")),
            "purchase_state": str(values.get("purchase_state", "")),
            "acknowledgement_state": str(values.get("acknowledgement_state", "")),
            "owned": bool(values.get("owned", False)),
            "processing_stage": str(values.get("processing_stage", "")),
            "purchase_completion_time": str(values.get("purchase_completion_time", "")),
            "test_purchase": bool(values.get("test_purchase", False)),
        }
        document = self._collection.document(token_hash)
        transaction = self._client.transaction()

        @firestore.transactional
        def record_transaction(txn: firestore.Transaction) -> None:
            snapshot = document.get(transaction=txn)
            if not snapshot.exists:
                raise RuntimeError("purchase_record_missing_binding")
            current = snapshot.to_dict() or {}
            if str(current.get("package_name", "")) != incoming["package_name"]:
                raise RuntimeError("purchase_record_package_binding_mismatch")
            if str(current.get("product_id", "")) != incoming["product_id"]:
                raise RuntimeError("purchase_record_product_binding_mismatch")

            merged = merge_purchase_record(current, incoming)
            if bool(merged.get("stale_observation", False)):
                txn.set(document, {"last_seen_at": firestore.SERVER_TIMESTAMP}, merge=True)
                return
            effective = dict(merged.get("effective", {}))
            effective["updated_at"] = firestore.SERVER_TIMESTAMP
            effective["last_seen_at"] = firestore.SERVER_TIMESTAMP
            txn.set(document, effective, merge=True)

        record_transaction(transaction)
