extends Node

func choose_event(world_id: String, location_id: String = "") -> Dictionary:
    var candidates: Array = []
    var weights: Array = []
    var recent: Array = GameState.run.get("recent_events", [])
    for event in ContentRegistry.all("events"):
        if str(event.get("world_id", "")) != world_id:
            continue
        var ev_loc := str(event.get("location_id", ""))
        if location_id != "" and ev_loc != "" and ev_loc != location_id:
            continue
        if int(event.get("max_per_run", 99)) <= _times_seen(str(event.id)):
            continue
        var weight := float(event.get("weight", 1.0))
        if str(event.id) in recent:
            weight *= 0.12
        weight *= _debt_pressure(event)
        if weight > 0.0:
            candidates.append(event)
            weights.append(weight)
    var index := RNGService.weighted_index(weights)
    if index < 0:
        return {}
    var selected: Dictionary = candidates[index]
    _remember(str(selected.id))
    return selected

func apply_choice(event: Dictionary, choice_index: int) -> void:
    var choices: Array = event.get("choices", [])
    if choice_index < 0 or choice_index >= choices.size():
        return
    _apply_effect(choices[choice_index].get("effect", {}))
    GameState.run.turn = int(GameState.run.get("turn", 0)) + 1
    _age_debts()
    PresentationBus.choice()

func _apply_effect(effect: Dictionary) -> void:
    var op := str(effect.get("op", ""))
    match op:
        "mark_add":
            GameState.add_mark(str(effect.get("mark_id", "")), int(effect.get("intensity", 1)))
        "mark_intensify":
            GameState.add_mark(str(effect.get("mark_id", "")), int(effect.get("value", 1)))
        "resource_add":
            var key := str(effect.get("resource", ""))
            if key == "vigor":
                GameState.run.vigor = clampi(int(GameState.run.get("vigor", 0)) + int(effect.get("value", 0)), 0, int(GameState.run.get("max_vigor", 8)))
            else:
                var res: Dictionary = GameState.run.get("resources", {})
                res[key] = int(res.get(key, 0)) + int(effect.get("value", 0))
                GameState.run.resources = res
        "flag_set":
            var flags: Dictionary = GameState.run.get("flags", {})
            flags[str(effect.get("key", ""))] = effect.get("value", true)
            GameState.run.flags = flags
        "debt_resolve":
            _resolve_debt(str(effect.get("debt_id", "")))
        "debt_resolve_oldest":
            _resolve_oldest_debt()
        _:
            pass

func create_debt(debt_id: String) -> void:
    var debts: Array = GameState.run.get("debts", [])
    for d in debts:
        if str(d.get("id", "")) == debt_id:
            return
    var spec := ContentRegistry.get_record(debt_id)
    debts.append({"id":debt_id,"age":0,"pressure":1.0,"hard_deadline":int(spec.get("hard_deadline", 10))})
    GameState.run.debts = debts

func _age_debts() -> void:
    var debts: Array = GameState.run.get("debts", [])
    for d in debts:
        d.age = int(d.get("age", 0)) + 1
        var spec := ContentRegistry.get_record(str(d.id))
        d.pressure = float(d.get("pressure", 1.0)) + float(spec.get("pressure_growth", 0.2))
    GameState.run.debts = debts

func _debt_pressure(event: Dictionary) -> float:
    if str(event.get("pool", "")) not in ["callback", "transit_callback", "debt"]:
        return 1.0
    var factor := 1.0
    for d in GameState.run.get("debts", []):
        factor += float(d.get("pressure", 1.0))
        if int(d.get("age", 0)) >= int(d.get("hard_deadline", 10)):
            factor += 50.0
    return factor

func _resolve_debt(debt_id: String) -> void:
    GameState.run.debts = GameState.run.get("debts", []).filter(func(d): return str(d.get("id", "")) != debt_id)

func _resolve_oldest_debt() -> void:
    var debts: Array = GameState.run.get("debts", [])
    if debts.is_empty():
        return
    debts.sort_custom(func(a, b): return int(a.get("age", 0)) > int(b.get("age", 0)))
    debts.pop_front()
    GameState.run.debts = debts

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
