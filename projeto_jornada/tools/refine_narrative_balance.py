#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

ARC_CHUNKS = (6, 6, 5)  # 17 arc events per Domain -> three finite causal threads.


def read(name: str) -> list[dict[str, Any]]:
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def write(name: str, rows: list[dict[str, Any]]) -> None:
    (DATA / f"{name}.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def effects(choice: dict[str, Any]) -> list[dict[str, Any]]:
    effect = choice.get("effect", {})
    if isinstance(effect, list):
        return [row for row in effect if isinstance(row, dict)]
    if isinstance(effect, dict) and effect:
        return [effect]
    return []


def set_effects(choice: dict[str, Any], rows: list[dict[str, Any]]) -> None:
    choice["effect"] = rows[0] if len(rows) == 1 else rows


def append_effect(choice: dict[str, Any], effect: dict[str, Any]) -> None:
    rows = effects(choice)
    signature = json.dumps(effect, ensure_ascii=False, sort_keys=True)
    existing = {json.dumps(row, ensure_ascii=False, sort_keys=True) for row in rows}
    if signature not in existing:
        rows.append(effect)
    set_effects(choice, rows)


def replace_first_mark_effect(choice: dict[str, Any], mark_id: str) -> None:
    rows = effects(choice)
    for row in rows:
        if str(row.get("op", "")) == "mark_add":
            row["mark_id"] = mark_id
            set_effects(choice, rows)
            return
    raise SystemExit("Expected first debt-origin choice to contain mark_add")


def combine_condition(existing: Any, extra: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(existing, dict) or not existing:
        return extra
    return {"op": "and", "conditions": [existing, extra]}


def main() -> None:
    events = read("events")
    debts = read("debts")
    marks = read("marks")
    worlds = read("worlds")

    if len(events) != 2544 or len(debts) != 120 or len(marks) != 204 or len(worlds) != 12:
        raise SystemExit(
            f"Unexpected narrative catalog events={len(events)} debts={len(debts)} marks={len(marks)} worlds={len(worlds)}"
        )

    debt_by_location: dict[str, dict[str, Any]] = {}
    debts_by_world: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for debt in debts:
        location_id = str(debt.get("origin_location_id", ""))
        if not location_id or location_id in debt_by_location:
            raise SystemExit(f"Debt origin is not 1:1 at {location_id!r}")
        debt_by_location[location_id] = debt
        debts_by_world[str(debt.get("world_id", ""))].append(debt)
    if len(debt_by_location) != 120:
        raise SystemExit(f"Expected 120 unique debt origins, got {len(debt_by_location)}")

    marks_by_world: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for mark in marks:
        marks_by_world[str(mark.get("world_id", ""))].append(mark)
    for world_id, rows in marks_by_world.items():
        rows.sort(key=lambda row: str(row.get("id", "")))
        if len(rows) != 17:
            raise SystemExit(f"{world_id} has {len(rows)} marks instead of 17")

    # Allocate one distinct memory Mark to each debt in a Domain. We reuse ten
    # of the seventeen canonical Marks; the other seven remain available for
    # broader world/arc/event consequences.
    memory_mark_by_debt: dict[str, str] = {}
    for world in worlds:
        world_id = str(world.get("id", ""))
        world_debts = sorted(
            debts_by_world.get(world_id, []),
            key=lambda row: str(row.get("origin_location_id", "")),
        )
        world_marks = marks_by_world.get(world_id, [])
        if len(world_debts) != 10 or len(world_marks) != 17:
            raise SystemExit(f"{world_id} cannot allocate 10 distinct debt memory marks")
        for index, debt in enumerate(world_debts):
            memory_mark_by_debt[str(debt.get("id", ""))] = str(world_marks[index].get("id", ""))

    debt_events: dict[str, dict[str, Any]] = {}
    callback_events: dict[str, dict[str, Any]] = {}
    transit_callbacks: list[dict[str, Any]] = []
    arcs_by_world: dict[str, list[dict[str, Any]]] = defaultdict(list)

    for event in events:
        pool = str(event.get("pool", ""))
        location_id = str(event.get("location_id", ""))
        if pool == "debt":
            debt_events[location_id] = event
        elif pool == "callback":
            callback_events[location_id] = event
        elif pool == "transit_callback":
            transit_callbacks.append(event)
        elif pool == "arc":
            arcs_by_world[str(event.get("world_id", ""))].append(event)

    if set(debt_events) != set(debt_by_location) or set(callback_events) != set(debt_by_location):
        raise SystemExit("Debt/callback event locations do not match the 120 debt origins")
    if len(transit_callbacks) != 12:
        raise SystemExit(f"Expected 12 transit callbacks, got {len(transit_callbacks)}")

    # One finite obligation loop per location. Encountering a debt event creates
    # the obligation regardless of response; the three responses preserve their
    # original consequences. Its callback only exists while that exact debt is
    # active and closes that exact obligation, never an unrelated one.
    linked_marks: set[str] = set()
    for location_id, debt in debt_by_location.items():
        debt_id = str(debt.get("id", ""))
        origin = debt_events[location_id]
        callback = callback_events[location_id]
        mark_id = memory_mark_by_debt[debt_id]

        origin["debt_id"] = debt_id
        origin["memory_mark_id"] = mark_id
        origin["narrative_role"] = "debt_origin"
        origin["condition"] = {"op": "not", "condition": {"op": "debt_active", "debt_id": debt_id}}
        origin_choices = origin.get("choices", [])
        if len(origin_choices) != 3:
            raise SystemExit(f"Debt origin {origin.get('id')} does not have three choices")
        replace_first_mark_effect(origin_choices[0], mark_id)
        for choice in origin_choices:
            if isinstance(choice, dict):
                append_effect(choice, {"op": "debt_create", "debt_id": debt_id})
        linked_marks.add(mark_id)

        callback["debt_id"] = debt_id
        callback["callback_mark_id"] = mark_id
        callback["narrative_role"] = "debt_callback"
        callback["condition"] = {"op": "debt_active", "debt_id": debt_id}
        choices = callback.get("choices", [])
        if len(choices) != 3:
            raise SystemExit(f"Callback {callback.get('id')} does not have three choices")
        # The first callback answer is the 'I remember this thread' answer; it is
        # only available if the origin's Mark was actually taken. Other answers
        # remain available, so the debt can always be closed without soft-lock.
        choices[0]["condition"] = combine_condition(
            choices[0].get("condition", {}),
            {"op": "mark_has", "mark_id": mark_id},
        )
        for choice in choices:
            append_effect(choice, {"op": "debt_resolve", "debt_id": debt_id})

    if len(linked_marks) != 120:
        raise SystemExit(f"Expected 120 distinct debt memory marks, got {len(linked_marks)}")

    # Transit consequences are a pressure-release valve for any unresolved debt,
    # not ambient events that appear when nothing is owed.
    for event in transit_callbacks:
        event["narrative_role"] = "debt_transit_pressure"
        event["condition"] = {"op": "debt_any"}

    # Convert the 17 loose arc events per Domain into three finite causal threads.
    # Existing prose/choice effects are untouched; every response advances the
    # thread, while later stages remain unavailable until the previous stage ran.
    # Stage one has deliberate discovery pressure and, once a thread starts,
    # later stages gain progressively more continuity pressure. Only one next
    # stage per thread can be eligible, so this favors finishing stories without
    # allowing the arc pool to flood the event director.
    for world in worlds:
        world_id = str(world.get("id", ""))
        rows = sorted(arcs_by_world.get(world_id, []), key=lambda row: str(row.get("id", "")))
        if len(rows) != sum(ARC_CHUNKS):
            raise SystemExit(f"{world_id} has {len(rows)} arc events instead of {sum(ARC_CHUNKS)}")
        cursor = 0
        world_slug = world_id.split(".", 1)[-1]
        for arc_index, length in enumerate(ARC_CHUNKS, start=1):
            arc_id = f"arc.{world_slug}.{arc_index:02d}"
            previous_flag = ""
            for stage, event in enumerate(rows[cursor:cursor + length], start=1):
                completion_flag = f"narrative.{arc_id}.stage.{stage:02d}"
                event["arc_id"] = arc_id
                event["stage"] = stage
                event["arc_length"] = length
                event["narrative_role"] = "arc_stage"
                event["weight"] = round(1.8 + min(stage - 1, 4) * 0.30, 2)
                if previous_flag:
                    event["condition"] = combine_condition(
                        event.get("condition", {}),
                        {"op": "flag_is", "key": previous_flag, "value": True},
                    )
                for choice in event.get("choices", []):
                    if isinstance(choice, dict):
                        append_effect(choice, {"op": "flag_set", "key": completion_flag, "value": True})
                previous_flag = completion_flag
            cursor += length

    # Assert exact causal coverage before writing.
    linked_debt_ids = {str(event.get("debt_id", "")) for event in events if str(event.get("pool", "")) in {"debt", "callback"}}
    expected_debt_ids = {str(row.get("id", "")) for row in debts}
    if linked_debt_ids != expected_debt_ids:
        raise SystemExit("Not every canonical debt is linked to origin+callback events")

    arc_rows = [row for row in events if str(row.get("pool", "")) == "arc"]
    if len(arc_rows) != 204 or len({str(row.get("arc_id", "")) for row in arc_rows}) != 36:
        raise SystemExit("Arc refinement did not produce 36 causal threads / 204 stages")

    write("events", events)
    print(
        "NARRATIVE_BALANCE_REFINEMENT PASS: "
        "120 debt loops + 120 unique memory Marks + 12 transit pressure callbacks + "
        "36 causal arcs / 204 stages"
    )


if __name__ == "__main__":
    main()
