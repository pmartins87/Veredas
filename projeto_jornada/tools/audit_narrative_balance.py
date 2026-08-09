#!/usr/bin/env python3
from __future__ import annotations

import collections
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"


def read(name: str) -> list[dict[str, Any]]:
    path = DATA / f"{name}.json"
    if not path.exists():
        raise SystemExit(f"Missing canonical dataset: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise SystemExit(f"Expected list in {path}, got {type(payload).__name__}")
    return payload


def walk_ops(value: Any, bucket: collections.Counter[str]) -> None:
    if isinstance(value, dict):
        op = value.get("op")
        if isinstance(op, str) and op:
            bucket[op] += 1
        for child in value.values():
            walk_ops(child, bucket)
    elif isinstance(value, list):
        for child in value:
            walk_ops(child, bucket)


def walk_refs(value: Any, key_name: str, bucket: collections.Counter[str]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if key == key_name and isinstance(child, str) and child:
                bucket[child] += 1
            walk_refs(child, key_name, bucket)
    elif isinstance(value, list):
        for child in value:
            walk_refs(child, key_name, bucket)


def main() -> None:
    events = read("events")
    marks = read("marks")
    debts = read("debts")
    pools = read("pools")
    worlds = read("worlds")

    print("NARRATIVE_AUDIT catalog events=%d marks=%d debts=%d pools=%d worlds=%d" % (
        len(events), len(marks), len(debts), len(pools), len(worlds)
    ))

    event_keys = collections.Counter[str]()
    for row in events:
        event_keys.update(row.keys())
    debt_keys = collections.Counter[str]()
    for row in debts:
        debt_keys.update(row.keys())
    mark_keys = collections.Counter[str]()
    for row in marks:
        mark_keys.update(row.keys())
    pool_keys = collections.Counter[str]()
    for row in pools:
        pool_keys.update(row.keys())

    print("NARRATIVE_AUDIT event_keys", sorted(event_keys))
    print("NARRATIVE_AUDIT debt_keys", sorted(debt_keys))
    print("NARRATIVE_AUDIT mark_keys", sorted(mark_keys))
    print("NARRATIVE_AUDIT pool_keys", sorted(pool_keys))

    pool_counts = collections.Counter(str(row.get("pool", "<none>")) for row in events)
    world_counts = collections.Counter(str(row.get("world_id", "<none>")) for row in events)
    max_counts = collections.Counter(int(row.get("max_per_run", 99)) for row in events)
    weights = collections.Counter(float(row.get("weight", 1.0)) for row in events)
    print("NARRATIVE_AUDIT event_pools", dict(sorted(pool_counts.items())))
    print("NARRATIVE_AUDIT events_per_world", dict(sorted(world_counts.items())))
    print("NARRATIVE_AUDIT max_per_run", dict(sorted(max_counts.items())))
    print("NARRATIVE_AUDIT base_weights", dict(sorted(weights.items())))

    condition_ops: collections.Counter[str] = collections.Counter()
    effect_ops: collections.Counter[str] = collections.Counter()
    mark_refs: collections.Counter[str] = collections.Counter()
    debt_refs: collections.Counter[str] = collections.Counter()
    flag_refs: collections.Counter[str] = collections.Counter()
    item_refs: collections.Counter[str] = collections.Counter()
    for event in events:
        walk_ops(event.get("condition", {}), condition_ops)
        for choice in event.get("choices", []):
            if not isinstance(choice, dict):
                continue
            walk_ops(choice.get("condition", {}), condition_ops)
            walk_ops(choice.get("effect", {}), effect_ops)
        walk_refs(event, "mark_id", mark_refs)
        walk_refs(event, "debt_id", debt_refs)
        walk_refs(event, "key", flag_refs)
        walk_refs(event, "item_id", item_refs)
    print("NARRATIVE_AUDIT condition_ops", dict(sorted(condition_ops.items())))
    print("NARRATIVE_AUDIT effect_ops", dict(sorted(effect_ops.items())))
    print("NARRATIVE_AUDIT event_mark_refs unique=%d total=%d" % (len(mark_refs), sum(mark_refs.values())))
    print("NARRATIVE_AUDIT event_debt_refs unique=%d total=%d" % (len(debt_refs), sum(debt_refs.values())))
    print("NARRATIVE_AUDIT event_flag_refs unique=%d total=%d" % (len(flag_refs), sum(flag_refs.values())))
    print("NARRATIVE_AUDIT event_item_refs unique=%d total=%d" % (len(item_refs), sum(item_refs.values())))

    debt_ids = {str(row.get("id", "")) for row in debts}
    mark_ids = {str(row.get("id", "")) for row in marks}
    missing_debt_refs = sorted(ref for ref in debt_refs if ref not in debt_ids)
    missing_mark_refs = sorted(ref for ref in mark_refs if ref not in mark_ids)
    unreferenced_debts = sorted(debt_ids - set(debt_refs))
    unreferenced_marks = sorted(mark_ids - set(mark_refs))
    print("NARRATIVE_AUDIT debt_refs missing=%d unreferenced=%d" % (len(missing_debt_refs), len(unreferenced_debts)))
    print("NARRATIVE_AUDIT mark_refs missing=%d unreferenced=%d" % (len(missing_mark_refs), len(unreferenced_marks)))

    # Inspect how callback/debt rows advertise their relationship to a debt.
    callback_like = [row for row in events if str(row.get("pool", "")) in {"callback", "transit_callback", "debt"}]
    explicit_link_keys = collections.Counter[str]()
    explicit_link_values = collections.Counter[str]()
    for event in callback_like:
        for key, value in event.items():
            lower = str(key).lower()
            if "debt" in lower or "callback" in lower or "arc" in lower:
                explicit_link_keys[str(key)] += 1
                if isinstance(value, str):
                    explicit_link_values[value] += 1
    print("NARRATIVE_AUDIT callback_like=%d link_keys=%s" % (len(callback_like), dict(sorted(explicit_link_keys.items()))))
    print("NARRATIVE_AUDIT callback_link_values unique=%d sample=%s" % (
        len(explicit_link_values), list(sorted(explicit_link_values.items()))[:20]
    ))

    # Per pool/world coverage shows whether one Domain or pool can starve another.
    pool_world: dict[str, collections.Counter[str]] = collections.defaultdict(collections.Counter)
    for event in events:
        pool_world[str(event.get("pool", "<none>"))][str(event.get("world_id", "<none>"))] += 1
    for pool_name in sorted(pool_world):
        counts = pool_world[pool_name]
        values = list(counts.values())
        print("NARRATIVE_AUDIT pool_world %s worlds=%d min=%d max=%d total=%d" % (
            pool_name, len(counts), min(values), max(values), sum(values)
        ))

    # Debt deadline/growth distributions matter for callback pressure.
    soft = collections.Counter(int(row.get("soft_deadline", 4)) for row in debts)
    hard = collections.Counter(int(row.get("hard_deadline", 10)) for row in debts)
    growth = collections.Counter(float(row.get("pressure_growth", 0.2)) for row in debts)
    debt_world = collections.Counter(str(row.get("world_id", "<none>")) for row in debts)
    print("NARRATIVE_AUDIT debt_soft_deadline", dict(sorted(soft.items())))
    print("NARRATIVE_AUDIT debt_hard_deadline", dict(sorted(hard.items())))
    print("NARRATIVE_AUDIT debt_pressure_growth", dict(sorted(growth.items())))
    print("NARRATIVE_AUDIT debts_per_world", dict(sorted(debt_world.items())))

    # Show representative callback/debt rows without dumping narrative prose.
    for event in callback_like[:12]:
        compact = {
            key: event.get(key)
            for key in event.keys()
            if key in {"id", "world_id", "location_id", "pool", "weight", "max_per_run", "debt_id", "callback_for", "arc_id", "stage"}
        }
        refs: collections.Counter[str] = collections.Counter()
        walk_refs(event, "debt_id", refs)
        compact["nested_debt_refs"] = sorted(refs)
        print("NARRATIVE_AUDIT callback_example", json.dumps(compact, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
