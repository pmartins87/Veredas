extends Node

const SEEDS_PER_CHARACTER := 6
const STEPS_PER_RUN := 60
const EXPECTED_SELECTIONS := 36 * SEEDS_PER_CHARACTER * STEPS_PER_RUN
const EXPECTED_POOLS := [
    "arc", "callback", "choice", "creature", "debt", "exploration", "faction",
    "hazard", "knowledge", "mark", "memory", "moral", "personal_story",
    "resource", "ritual", "route", "social", "trade", "transit_callback", "weather",
]

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    EventDirector.clear_candidate_cache()
    _catalog_gate()
    _causal_debt_gate()
    _causal_arc_gate()
    var stats := _run_statistical_gate()
    _assert_statistical_gate(stats)
    _finish(stats)

func _catalog_gate() -> void:
    var events := ContentRegistry.all("events")
    var debts := ContentRegistry.all("debts")
    var marks := ContentRegistry.all("marks")
    expect(events.size() == 2544, "10.5 requires exactly 2544 events")
    expect(debts.size() == 120, "10.5 requires exactly 120 debts")
    expect(marks.size() == 204, "10.5 requires exactly 204 Marks")

    var pool_counts: Dictionary = {}
    var debt_origin_by_id: Dictionary = {}
    var callback_by_id: Dictionary = {}
    var memory_marks: Dictionary = {}
    var arcs: Dictionary = {}
    var personal_count := 0

    for event_variant in events:
        var event: Dictionary = event_variant as Dictionary
        var event_id := str(event.get("id", ""))
        var pool := str(event.get("pool", ""))
        pool_counts[pool] = int(pool_counts.get(pool, 0)) + 1
        expect(event.get("choices", []).size() == 3, "%s does not have exactly three choices" % event_id)
        expect(int(event.get("cooldown_turns", -1)) >= 0, "%s has invalid cooldown" % event_id)

        if pool == "personal_story":
            personal_count += 1
            expect(str(event.get("character_id", "")) != "", "%s personal story has no character_id" % event_id)
        elif pool == "debt":
            var debt_id := str(event.get("debt_id", ""))
            var mark_id := str(event.get("memory_mark_id", ""))
            expect(debt_id != "", "%s debt origin has no debt_id" % event_id)
            expect(mark_id != "", "%s debt origin has no memory Mark" % event_id)
            expect(not debt_origin_by_id.has(debt_id), "Debt %s has multiple origin events" % debt_id)
            expect(not memory_marks.has(mark_id), "Memory Mark %s is shared by multiple debts" % mark_id)
            debt_origin_by_id[debt_id] = event
            memory_marks[mark_id] = debt_id
            expect(_condition_has(event.get("condition", {}), "debt_active", debt_id), "%s origin is not gated by its debt state" % event_id)
            for choice_variant in event.get("choices", []):
                var choice: Dictionary = choice_variant as Dictionary
                expect(_effect_has(choice.get("effect", {}), "debt_create", debt_id), "%s choice does not create exact debt %s" % [event_id, debt_id])
        elif pool == "callback":
            var debt_id := str(event.get("debt_id", ""))
            var mark_id := str(event.get("callback_mark_id", ""))
            expect(debt_id != "", "%s callback has no debt_id" % event_id)
            expect(mark_id != "", "%s callback has no memory Mark" % event_id)
            expect(not callback_by_id.has(debt_id), "Debt %s has multiple exact callbacks" % debt_id)
            callback_by_id[debt_id] = event
            expect(_condition_has(event.get("condition", {}), "debt_active", debt_id), "%s callback is not gated by exact debt" % event_id)
            var choices: Array = event.get("choices", []) as Array
            expect(_condition_has((choices[0] as Dictionary).get("condition", {}), "mark_has", mark_id), "%s memory choice is not gated by exact Mark" % event_id)
            for choice_variant in choices:
                var choice: Dictionary = choice_variant as Dictionary
                expect(_effect_has(choice.get("effect", {}), "debt_resolve", debt_id), "%s choice does not resolve exact debt %s" % [event_id, debt_id])
        elif pool == "transit_callback":
            expect(_condition_has(event.get("condition", {}), "debt_any", ""), "%s transit callback is not debt-gated" % event_id)
        elif pool == "arc":
            var arc_id := str(event.get("arc_id", ""))
            var stage := int(event.get("stage", 0))
            var length := int(event.get("arc_length", 0))
            expect(arc_id != "" and stage > 0 and length in [5, 6], "%s has invalid arc metadata" % event_id)
            var row: Array = arcs.get(arc_id, []) as Array
            row.append(stage)
            arcs[arc_id] = row
            expect(float(event.get("weight", 0.0)) >= 1.8 and float(event.get("weight", 0.0)) <= 3.0, "%s arc weight outside calibrated envelope" % event_id)

    expect(int(pool_counts.get("debt", 0)) == 120, "10.5 debt-event count mismatch")
    expect(int(pool_counts.get("callback", 0)) == 120, "10.5 callback count mismatch")
    expect(int(pool_counts.get("transit_callback", 0)) == 12, "10.5 transit callback count mismatch")
    expect(int(pool_counts.get("arc", 0)) == 204, "10.5 arc-stage count mismatch")
    expect(personal_count == 288, "10.5 personal-story count mismatch")
    expect(debt_origin_by_id.size() == 120, "10.5 does not link all 120 debt origins")
    expect(callback_by_id.size() == 120, "10.5 does not link all 120 exact callbacks")
    expect(memory_marks.size() == 120, "10.5 does not allocate 120 distinct debt-memory Marks")
    expect(arcs.size() == 36, "10.5 requires exactly 36 causal arcs")

    for debt_variant in debts:
        var debt: Dictionary = debt_variant as Dictionary
        var debt_id := str(debt.get("id", ""))
        expect(debt_origin_by_id.has(debt_id), "%s has no origin event" % debt_id)
        expect(callback_by_id.has(debt_id), "%s has no exact callback" % debt_id)
        if debt_origin_by_id.has(debt_id) and callback_by_id.has(debt_id):
            var origin: Dictionary = debt_origin_by_id[debt_id] as Dictionary
            var callback: Dictionary = callback_by_id[debt_id] as Dictionary
            expect(str(origin.get("location_id", "")) == str(debt.get("origin_location_id", "")), "%s origin location mismatch" % debt_id)
            expect(str(callback.get("location_id", "")) == str(debt.get("origin_location_id", "")), "%s callback location mismatch" % debt_id)
            expect(str(origin.get("memory_mark_id", "")) == str(callback.get("callback_mark_id", "")), "%s origin/callback memory Mark mismatch" % debt_id)

    for arc_id_variant in arcs.keys():
        var arc_id := str(arc_id_variant)
        var stages: Array = arcs[arc_id] as Array
        stages.sort()
        expect(stages.size() in [5, 6], "%s has invalid stage count" % arc_id)
        for index in range(stages.size()):
            expect(int(stages[index]) == index + 1, "%s stages are not contiguous" % arc_id)

func _causal_debt_gate() -> void:
    var origin := _first_event_in_pool("debt")
    if origin.is_empty():
        expect(false, "10.5 causal debt probe has no origin event")
        return
    var debt_id := str(origin.get("debt_id", ""))
    var mark_id := str(origin.get("memory_mark_id", ""))
    var callback := _event_for_debt("callback", debt_id)
    var transit := _first_event_in_pool("transit_callback")
    var unrelated := _first_unrelated_callback(debt_id)
    var character := _character_for_world(str(origin.get("world_id", "")))
    if callback.is_empty() or transit.is_empty() or unrelated.is_empty() or character.is_empty():
        expect(false, "10.5 causal debt probe lacks linked records")
        return

    # Without debt: origin is eligible, callback and transit consequence are not.
    GameState.new_run(str(character.get("id", "")), 105501)
    GameState.run.location_id = str(origin.get("location_id", ""))
    expect(ConditionEngine.evaluate(origin.get("condition", {})), "Debt origin is unavailable before debt creation")
    expect(not ConditionEngine.evaluate(callback.get("condition", {})), "Exact callback is available before debt creation")
    expect(not ConditionEngine.evaluate(transit.get("condition", {})), "Transit callback is available with no debt")

    # Choice 1 deliberately avoids the memory Mark: it must still create the
    # exact debt, but the callback's memory-specific answer stays unavailable.
    expect(EventDirector.apply_choice(origin, 1), "Could not apply debt-origin choice")
    expect(NarrativeDebtEngine.is_active(debt_id), "Debt-origin choice did not create its exact debt")
    expect(ConditionEngine.evaluate(callback.get("condition", {})), "Exact callback is unavailable after debt creation")
    expect(ConditionEngine.evaluate(transit.get("condition", {})), "Transit callback is unavailable with active debt")
    expect(EventDirector.available_choices(callback).size() == 2, "Memory callback answer is available without its Mark")
    expect(NarrativeDebtEngine.event_multiplier(callback) > 1.0, "Exact callback receives no debt pressure")
    expect(absf(NarrativeDebtEngine.event_multiplier(unrelated) - 1.0) < 0.0001, "Unrelated callback receives pressure from another debt")

    # Callback choice 1 has no Mark prerequisite and must close the exact debt.
    expect(EventDirector.apply_choice(callback, 1), "Could not apply exact callback choice")
    expect(not NarrativeDebtEngine.is_active(debt_id), "Exact callback did not resolve its debt")

    # Taking the origin's memory choice must grant the unique Mark and expose all
    # three callback answers, including the memory-specific one.
    GameState.new_run(str(character.get("id", "")), 105502)
    GameState.run.location_id = str(origin.get("location_id", ""))
    expect(EventDirector.apply_choice(origin, 0), "Could not apply memory-bearing debt-origin choice")
    expect(int((GameState.run.get("marks", {}) as Dictionary).get(mark_id, 0)) > 0, "Debt origin did not grant its memory Mark")
    expect(EventDirector.available_choices(callback).size() == 3, "Memory Mark did not unlock callback memory answer")
    expect(EventDirector.apply_choice(callback, 0), "Could not apply memory callback answer")
    expect(not NarrativeDebtEngine.is_active(debt_id), "Memory callback did not resolve its debt")

func _causal_arc_gate() -> void:
    var stage_one := _first_arc_stage(1)
    if stage_one.is_empty():
        expect(false, "10.5 causal arc probe has no stage one")
        return
    var arc_id := str(stage_one.get("arc_id", ""))
    var stage_two := _arc_stage(arc_id, 2)
    var character := _character_for_world(str(stage_one.get("world_id", "")))
    if stage_two.is_empty() or character.is_empty():
        expect(false, "10.5 causal arc probe lacks stage two or character")
        return
    GameState.new_run(str(character.get("id", "")), 105503)
    GameState.run.location_id = str(stage_one.get("location_id", ""))
    expect(not ConditionEngine.evaluate(stage_two.get("condition", {})), "Arc stage two is available before stage one")
    expect(EventDirector.apply_choice(stage_one, 0), "Could not advance arc stage one")
    expect(ConditionEngine.evaluate(stage_two.get("condition", {})), "Arc stage one did not unlock stage two")

func _run_statistical_gate() -> Dictionary:
    var stats := {
        "runs":0,
        "selections":0,
        "empty":0,
        "choice_deadlocks":0,
        "cooldown_violations":0,
        "wrong_personal":0,
        "unique_events":{},
        "pool_counts":{},
        "debt_origin":0,
        "callback":0,
        "transit_callback":0,
        "active_debt_end":0,
        "overdue_end":0,
        "arc_selected":0,
        "arc_events":{},
        "arc_ids":{},
        "max_arc_stage":0,
    }
    var characters := ContentRegistry.all("characters")
    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        var world_id := str(character.get("world_id", ""))
        var world := ContentRegistry.get_record(world_id)
        var locations: Array = world.get("locations", []) as Array
        if locations.is_empty():
            continue
        for seed_index in range(SEEDS_PER_CHARACTER):
            GameState.new_run(character_id, 105000 + character_index * 100 + seed_index)
            stats.runs = int(stats.runs) + 1
            var local_last: Dictionary = {}
            for step in range(STEPS_PER_RUN):
                var location_id := str(locations[step % locations.size()])
                GameState.run.location_id = location_id
                var turn_before := int(GameState.run.get("turn", 0))
                var event := EventDirector.choose_event(world_id, location_id)
                if event.is_empty():
                    stats.empty = int(stats.empty) + 1
                    GameState.run.turn = turn_before + 1
                    NarrativeDebtEngine.age_all(1)
                    continue
                stats.selections = int(stats.selections) + 1
                var event_id := str(event.get("id", ""))
                (stats.unique_events as Dictionary)[event_id] = true
                var pool := str(event.get("pool", ""))
                var pool_counts: Dictionary = stats.pool_counts as Dictionary
                pool_counts[pool] = int(pool_counts.get(pool, 0)) + 1
                stats.pool_counts = pool_counts
                if pool == "debt": stats.debt_origin = int(stats.debt_origin) + 1
                if pool == "callback": stats.callback = int(stats.callback) + 1
                if pool == "transit_callback": stats.transit_callback = int(stats.transit_callback) + 1
                if pool == "arc":
                    stats.arc_selected = int(stats.arc_selected) + 1
                    (stats.arc_events as Dictionary)[event_id] = true
                    (stats.arc_ids as Dictionary)[str(event.get("arc_id", ""))] = true
                    stats.max_arc_stage = maxi(int(stats.max_arc_stage), int(event.get("stage", 0)))

                var event_character := str(event.get("character_id", ""))
                if event_character != "" and event_character != character_id:
                    stats.wrong_personal = int(stats.wrong_personal) + 1
                var cooldown := maxi(0, int(event.get("cooldown_turns", 0)))
                if local_last.has(event_id) and turn_before - int(local_last[event_id]) < cooldown:
                    stats.cooldown_violations = int(stats.cooldown_violations) + 1
                local_last[event_id] = turn_before

                var available := EventDirector.available_choices(event)
                if available.is_empty():
                    stats.choice_deadlocks = int(stats.choice_deadlocks) + 1
                    GameState.run.turn = turn_before + 1
                    NarrativeDebtEngine.age_all(1)
                    continue
                var pick := (step + seed_index + character_index) % available.size()
                var entry: Dictionary = available[pick] as Dictionary
                if not EventDirector.apply_choice(event, int(entry.get("index", 0))):
                    stats.choice_deadlocks = int(stats.choice_deadlocks) + 1
            stats.active_debt_end = int(stats.active_debt_end) + NarrativeDebtEngine.active_count()
            stats.overdue_end = int(stats.overdue_end) + NarrativeDebtEngine.overdue_count()
    return stats

func _assert_statistical_gate(stats: Dictionary) -> void:
    var selections := int(stats.selections)
    var unique_events := (stats.unique_events as Dictionary).size()
    var coverage := float(unique_events) / float(maxi(1, ContentRegistry.all("events").size()))
    var pool_counts: Dictionary = stats.pool_counts as Dictionary
    var debt_origin := int(stats.debt_origin)
    var callback := int(stats.callback)
    var active_end := int(stats.active_debt_end)
    var overdue_end := int(stats.overdue_end)
    var arc_selected := int(stats.arc_selected)
    var arc_share := float(arc_selected) / float(maxi(1, selections))

    expect(int(stats.runs) == 216, "10.5 statistical matrix does not contain 216 runs")
    expect(selections == EXPECTED_SELECTIONS, "10.5 statistical matrix did not produce %d selections" % EXPECTED_SELECTIONS)
    expect(int(stats.empty) == 0, "10.5 event director produced empty selections")
    expect(int(stats.choice_deadlocks) == 0, "10.5 produced choices with no executable answer")
    expect(int(stats.cooldown_violations) == 0, "10.5 violated event cooldowns")
    expect(int(stats.wrong_personal) == 0, "10.5 selected personal stories for the wrong character")
    expect(coverage >= 0.88, "10.5 aggregate event coverage is too low: %.3f" % coverage)

    for pool in EXPECTED_POOLS:
        expect(int(pool_counts.get(pool, 0)) > 0, "10.5 pool %s never appears" % pool)
    for pool_variant in pool_counts.keys():
        var pool := str(pool_variant)
        var share := float(pool_counts[pool]) / float(maxi(1, selections))
        expect(share <= 0.10, "10.5 pool %s dominates event selection: %.3f" % [pool, share])

    expect(debt_origin > 0 and callback > 0 and int(stats.transit_callback) > 0, "10.5 debt origin/callback paths are absent from simulation")
    expect(float(callback) / float(maxi(1, debt_origin)) >= 0.35, "10.5 exact callbacks are too rare relative to debt origins")
    expect(float(active_end) / float(maxi(1, debt_origin)) <= 0.30, "10.5 leaves too many debts unresolved at run end")
    expect(float(overdue_end) / float(maxi(1, debt_origin)) <= 0.10, "10.5 leaves too many debts overdue at run end")

    expect(arc_share >= 0.018 and arc_share <= 0.06, "10.5 arc frequency outside calibrated envelope: %.3f" % arc_share)
    expect((stats.arc_ids as Dictionary).size() == 36, "10.5 does not expose all 36 arcs in the aggregate matrix")
    expect((stats.arc_events as Dictionary).size() >= 70, "10.5 exposes too few distinct arc stages")
    expect(int(stats.max_arc_stage) >= 4, "10.5 arcs do not progress beyond early stages")

func _first_event_in_pool(pool: String) -> Dictionary:
    for event_variant in ContentRegistry.all("events"):
        var event: Dictionary = event_variant as Dictionary
        if str(event.get("pool", "")) == pool:
            return event
    return {}

func _event_for_debt(pool: String, debt_id: String) -> Dictionary:
    for event_variant in ContentRegistry.all("events"):
        var event: Dictionary = event_variant as Dictionary
        if str(event.get("pool", "")) == pool and str(event.get("debt_id", "")) == debt_id:
            return event
    return {}

func _first_unrelated_callback(debt_id: String) -> Dictionary:
    for event_variant in ContentRegistry.all("events"):
        var event: Dictionary = event_variant as Dictionary
        if str(event.get("pool", "")) == "callback" and str(event.get("debt_id", "")) != debt_id:
            return event
    return {}

func _first_arc_stage(stage: int) -> Dictionary:
    for event_variant in ContentRegistry.all("events"):
        var event: Dictionary = event_variant as Dictionary
        if str(event.get("pool", "")) == "arc" and int(event.get("stage", 0)) == stage:
            return event
    return {}

func _arc_stage(arc_id: String, stage: int) -> Dictionary:
    for event_variant in ContentRegistry.all("events"):
        var event: Dictionary = event_variant as Dictionary
        if str(event.get("arc_id", "")) == arc_id and int(event.get("stage", 0)) == stage:
            return event
    return {}

func _character_for_world(world_id: String) -> Dictionary:
    for character_variant in ContentRegistry.all("characters"):
        var character: Dictionary = character_variant as Dictionary
        if str(character.get("world_id", "")) == world_id:
            return character
    return {}

func _condition_has(value, op: String, ref_id: String) -> bool:
    if typeof(value) != TYPE_DICTIONARY:
        return false
    var condition: Dictionary = value as Dictionary
    if str(condition.get("op", "")) == op:
        if ref_id == "":
            return true
        if op == "mark_has":
            return str(condition.get("mark_id", "")) == ref_id
        if op in ["debt_active", "debt_overdue"]:
            return str(condition.get("debt_id", "")) == ref_id
        return true
    if condition.has("condition") and _condition_has(condition.get("condition"), op, ref_id):
        return true
    for child_variant in condition.get("conditions", []) as Array:
        if _condition_has(child_variant, op, ref_id):
            return true
    return false

func _effect_has(value, op: String, debt_id: String) -> bool:
    if typeof(value) == TYPE_ARRAY:
        for child_variant in value as Array:
            if _effect_has(child_variant, op, debt_id):
                return true
        return false
    if typeof(value) != TYPE_DICTIONARY:
        return false
    var effect: Dictionary = value as Dictionary
    return str(effect.get("op", "")) == op and str(effect.get("debt_id", "")) == debt_id

func _finish(stats: Dictionary) -> void:
    var selections := int(stats.get("selections", 0))
    var coverage := float((stats.get("unique_events", {}) as Dictionary).size()) / float(maxi(1, ContentRegistry.all("events").size()))
    var debt_origin := int(stats.get("debt_origin", 0))
    var arc_share := float(stats.get("arc_selected", 0)) / float(maxi(1, selections))
    print("10.5 certification matrix: runs=%d selections=%d coverage=%.3f debt_origins=%d exact_callbacks=%d transit_callbacks=%d active_end=%d overdue_end=%d arc_share=%.3f arc_unique=%d max_arc_stage=%d" % [
        int(stats.get("runs", 0)), selections, coverage, debt_origin,
        int(stats.get("callback", 0)), int(stats.get("transit_callback", 0)),
        int(stats.get("active_debt_end", 0)), int(stats.get("overdue_end", 0)), arc_share,
        (stats.get("arc_events", {}) as Dictionary).size(), int(stats.get("max_arc_stage", 0)),
    ])
    if failures.is_empty():
        print("NARRATIVE_BALANCE_CERTIFICATION PASS: 10.5")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("NARRATIVE_BALANCE_CERTIFICATION: %s" % failure)
        print("NARRATIVE_BALANCE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
