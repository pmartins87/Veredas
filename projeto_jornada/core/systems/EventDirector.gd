extends Node

var _candidate_cache: Dictionary = {}

func choose_event(world_id: String, location_id: String = "") -> Dictionary:
    var candidates: Array = []
    var weights: Array = []
    var recent: Array = GameState.run.get("recent_events", [])
    for event_variant in _static_candidates(world_id, location_id):
        var event: Dictionary = event_variant as Dictionary
        if int(event.get("max_per_run", 99)) <= _times_seen(str(event.get("id", ""))):
            continue
        if event.has("condition") and not ConditionEngine.evaluate(event.get("condition", {})):
            continue
        var weight := float(event.get("weight", 1.0))
        if str(event.get("id", "")) in recent:
            weight *= 0.12
        weight *= NarrativeDebtEngine.event_multiplier(event)
        if weight > 0.0:
            candidates.append(event)
            weights.append(weight)
    var index := RNGService.weighted_index(weights)
    if index < 0:
        return {}
    var selected: Dictionary = candidates[index]
    _remember(str(selected.get("id", "")))
    return selected

func available_choices(event: Dictionary) -> Array:
    var result: Array = []
    for i in range(event.get("choices", []).size()):
        var choice: Dictionary = event.get("choices", [])[i]
        if not choice.has("condition") or ConditionEngine.evaluate(choice.get("condition", {})):
            result.append({"index":i,"choice":choice})
    return result

func apply_choice(event: Dictionary, choice_index: int) -> bool:
    var choices: Array = event.get("choices", [])
    if choice_index < 0 or choice_index >= choices.size():
        return false
    var choice: Dictionary = choices[choice_index]
    if choice.has("condition") and not ConditionEngine.evaluate(choice.get("condition", {})):
        return false
    var effect = choice.get("effect", {})
    if typeof(effect) == TYPE_ARRAY:
        EffectEngine.apply_all(effect)
    else:
        EffectEngine.apply(effect)
    GameState.run.turn = int(GameState.run.get("turn", 0)) + 1
    NarrativeDebtEngine.age_all(1)
    PresentationBus.choice()
    return true

func create_debt(debt_id: String) -> bool:
    return NarrativeDebtEngine.create(debt_id)

func clear_candidate_cache() -> void:
    _candidate_cache.clear()

func cached_candidate_sets() -> int:
    return _candidate_cache.size()

func _static_candidates(world_id: String, location_id: String) -> Array:
    var key := "%s|%s" % [world_id, location_id]
    if _candidate_cache.has(key):
        return _candidate_cache[key] as Array
    var result: Array = []
    for event_variant in ContentRegistry.all("events"):
        var event: Dictionary = event_variant as Dictionary
        if str(event.get("world_id", "")) != world_id:
            continue
        var ev_loc := str(event.get("location_id", ""))
        if location_id != "" and ev_loc != "" and ev_loc != location_id:
            continue
        result.append(event)
    _candidate_cache[key] = result
    return result

func _times_seen(event_id: String) -> int:
    return int(GameState.run.get("event_counts", {}).get(event_id, 0))

func _remember(event_id: String) -> void:
    var recent: Array = GameState.run.get("recent_events", [])
    recent.push_front(event_id)
    if recent.size() > 12:
        recent.resize(12)
    GameState.run.recent_events = recent
    var counts: Dictionary = GameState.run.get("event_counts", {})
    counts[event_id] = int(counts.get(event_id, 0)) + 1
    GameState.run.event_counts = counts
