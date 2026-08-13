from __future__ import annotations

import os
from typing import Any

from google.cloud import firestore

from purchase_record_merge import merge_purchase_record
from verifier import RepositoryError

DEFAULT_COLLECTION = "play_purchase_tokens_v1"


class FirestorePurchaseRepository:
    def __init__(self, client: firestore.Client | None = None, collection_name: str | None = None):
        try:
            self._client = client or firestore.Client()
        except Exception as exc:  # Google ADC/Firestore initialization failures are runtime availability failures.
            raise RepositoryError("repository_client_initialization_failed") from exc
        self._collection_name = collection_name or os.environ.get("FIRESTORE_COLLECTION", DEFAULT_COLLECTION)
        if not self._collection_name or "/" in self._collection_name:
            raise RepositoryError("invalid_firestore_collection")
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

        try:
            return bool(bind_transaction(transaction))
        except RepositoryError:
            raise
        except Exception as exc:
            raise RepositoryError("repository_bind_failed") from exc

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
                raise RepositoryError("purchase_record_missing_binding")
            current = snapshot.to_dict() or {}
            if str(current.get("package_name", "")) != incoming["package_name"]:
                raise RepositoryError("purchase_record_package_binding_mismatch")
            if str(current.get("product_id", "")) != incoming["product_id"]:
                raise RepositoryError("purchase_record_product_binding_mismatch")

            try:
                merged = merge_purchase_record(current, incoming)
            except ValueError as exc:
                raise RepositoryError(str(exc)) from exc
            if bool(merged.get("stale_observation", False)):
                txn.set(document, {"last_seen_at": firestore.SERVER_TIMESTAMP}, merge=True)
                return
            effective = dict(merged.get("effective", {}))
            effective["updated_at"] = firestore.SERVER_TIMESTAMP
            effective["last_seen_at"] = firestore.SERVER_TIMESTAMP
            txn.set(document, effective, merge=True)

        try:
            record_transaction(transaction)
        except RepositoryError:
            raise
        except Exception as exc:
            raise RepositoryError("repository_record_failed") from exc
