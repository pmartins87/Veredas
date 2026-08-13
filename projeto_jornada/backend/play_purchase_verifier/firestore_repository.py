from __future__ import annotations

import os
from typing import Any

from google.cloud import firestore

DEFAULT_COLLECTION = "play_purchase_tokens_v1"


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
                txn.set(
                    document,
                    {"last_seen_at": firestore.SERVER_TIMESTAMP},
                    merge=True,
                )
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
        safe_values = {
            "package_name": str(values.get("package_name", "")),
            "product_id": str(values.get("product_id", "")),
            "purchase_state": str(values.get("purchase_state", "")),
            "acknowledgement_state": str(values.get("acknowledgement_state", "")),
            "owned": bool(values.get("owned", False)),
            "processing_stage": str(values.get("processing_stage", "")),
            "purchase_completion_time": str(values.get("purchase_completion_time", "")),
            "test_purchase": bool(values.get("test_purchase", False)),
            "updated_at": firestore.SERVER_TIMESTAMP,
        }
        self._collection.document(token_hash).set(safe_values, merge=True)
