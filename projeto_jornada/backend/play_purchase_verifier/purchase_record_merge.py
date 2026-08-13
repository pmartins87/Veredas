from __future__ import annotations

from typing import Any

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
    """Merge an authoritative observation without letting delayed writes regress state.

    Purchase-state order is monotonic for a token: PENDING -> PURCHASED -> CANCELLED.
    CANCELLED is terminal for the persisted snapshot. Within PURCHASED, a confirmed
    owned/acknowledged state cannot be overwritten by a delayed pre-ack observation.
    """
    current_state = str(current.get("purchase_state", ""))
    incoming_state = str(incoming.get("purchase_state", ""))
    if current_state not in PURCHASE_STATE_RANK:
        raise ValueError("current_purchase_state_invalid")
    if incoming_state not in PURCHASE_STATE_RANK:
        raise ValueError("incoming_purchase_state_invalid")

    current_rank = PURCHASE_STATE_RANK[current_state]
    incoming_rank = PURCHASE_STATE_RANK[incoming_state]
    if incoming_rank < current_rank:
        return {"stale_observation": True, "effective": {}}

    effective = dict(incoming)
    current_ack = str(current.get("acknowledgement_state", ""))
    incoming_ack = str(incoming.get("acknowledgement_state", ""))
    if current_ack not in ACK_STATE_RANK:
        raise ValueError("current_acknowledgement_state_invalid")
    if incoming_ack not in ACK_STATE_RANK:
        raise ValueError("incoming_acknowledgement_state_invalid")
    if ACK_STATE_RANK[current_ack] > ACK_STATE_RANK[incoming_ack]:
        effective["acknowledgement_state"] = current_ack

    if incoming_state == "PURCHASED" and current_state == "PURCHASED":
        prior_owned = bool(current.get("owned", False))
        incoming_owned = bool(incoming.get("owned", False))
        effective["owned"] = prior_owned or incoming_owned
        if prior_owned and not incoming_owned:
            effective["processing_stage"] = str(current.get("processing_stage", "owned_acknowledged"))
    elif incoming_state in {"PENDING", "CANCELLED"}:
        effective["owned"] = False

    return {"stale_observation": False, "effective": effective}
