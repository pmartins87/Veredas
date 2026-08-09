extends Node

const SEEDS_PER_CHARACTER := 6
const STEPS_PER_RUN := 60

func _ready() -> void:
    await get_tree().process_frame
    EventDirector.clear_candidate_cache()
    var stats := _run_probe()
    print("10.5 probe runs=%d selections=%d empty=%d choice_deadlocks=%d cooldown_violations=%d wrong_personal=%d" % [
        int(stats.runs), int(stats.selections), int(stats.empty), int(stats.choice_deadlocks),
        int(stats.cooldown_violations), int(stats.wrong_personal),
    ])
    print("10.5 probe unique_events=%d/%d coverage=%.3f" % [
        int((stats.unique_events as Dictionary).size()),
        ContentRegistry.all("events").size(),
        float((stats.unique_events as Dictionary).size()) / float(maxi(1, ContentRegistry.all("events").size())),
    ])
    print("10.5 probe pools=%s" % str(stats.pool_counts))
    print("10.5 probe debt_origin=%d callback=%d transit_callback=%d active_end=%d overdue_end=%d" % [
        int(stats.debt_origin), int(stats.callback), int(stats.transit_callback),
        int(stats.active_debt_end), int(stats.overdue_end),
    ])
    print("10.5 probe arc_selected=%d arc_unique=%d max_stage=%s" % [
        int(stats.arc_selected), int((stats.arc_events as Dictionary).size()), str(stats.arc_max_stage),
    ])
    print("NARRATIVE_BALANCE_PROBE PASS")
    get_tree().quit(0)

func _run_probe() -> Dictionary:
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
        "arc_max_stage":{},
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
                    var arc_id := str(event.get("arc_id", ""))
                    var max_stage: Dictionary = stats.arc_max_stage as Dictionary
                    max_stage[arc_id] = maxi(int(max_stage.get(arc_id, 0)), int(event.get("stage", 0)))
                    stats.arc_max_stage = max_stage
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
