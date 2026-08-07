extends Node

func start_journey(character_id: String, seed_value: int) -> bool:
    if ContentRegistry.get_record(character_id).is_empty():
        return false
    GameState.new_run(character_id, seed_value)
    GameState.run.mode = "story"
    GameState.run.visited_locations = [str(GameState.run.get("location_id", ""))]
    GameState.run.defeated_enemies = []
    GameState.run.purchases = []
    GameState.run.ending_id = ""
    return true

func story_event() -> Dictionary:
    GameState.run.mode = "story"
    return EventDirector.choose_event(str(GameState.run.get("world_id", "")), str(GameState.run.get("location_id", "")))

func choose(event: Dictionary, option: int) -> bool:
    var choices: Array = event.get("choices", [])
    if option < 0 or option >= choices.size():
        return false
    EventDirector.apply_choice(event, option)
    return true

func travel(location_id: String) -> bool:
    var ok := LocationEngine.travel_to(location_id)
    if ok:
        GameState.run.mode = "story"
    return ok

func travel_world(world_id: String, location_id: String = "") -> bool:
    var ok := LocationEngine.travel_world(world_id, location_id)
    if ok:
        GameState.run.mode = "story"
    return ok

func open_merchant(size: int = 8) -> Array:
    GameState.run.mode = "merchant"
    return MerchantEngine.stock(str(GameState.run.get("world_id", "")), size)

func buy(item_id: String) -> bool:
    var ok := MerchantEngine.buy(item_id)
    if ok:
        var purchases: Array = GameState.run.get("purchases", [])
        purchases.append(item_id)
        GameState.run.purchases = purchases
    return ok

func start_combat(enemy_id: String) -> Dictionary:
    GameState.run.mode = "combat"
    return CombatEngine.start(enemy_id, str(GameState.run.get("character_id", "")))

func combat_action(action: String) -> Dictionary:
    var state := CombatEngine.player_action(action)
    if not bool(state.get("active", false)):
        _close_combat(state)
    return state

func combat_ability(ability_id: String) -> Dictionary:
    var state := CombatEngine.use_character_ability(ability_id)
    if not bool(state.get("active", false)):
        _close_combat(state)
    return state

func finish(ending_id: String) -> bool:
    var ending := ContentRegistry.get_record(ending_id)
    if ending.is_empty() or not ending_id.begins_with("ending."):
        return false
    GameState.run.active = false
    GameState.run.mode = "debrief"
    GameState.run.ending_id = ending_id
    GameState.run.result = "victory"
    var endings: Array = GameState.profile.get("endings", [])
    if ending_id not in endings:
        endings.append(ending_id)
    GameState.profile.endings = endings
    return true

func fail(reason: String = "defeat") -> void:
    GameState.run.active = false
    GameState.run.mode = "debrief"
    GameState.run.result = reason

func debrief() -> Dictionary:
    return {
        "result": GameState.run.get("result", "in_progress"),
        "ending_id": GameState.run.get("ending_id", ""),
        "turns": int(GameState.run.get("turn", 0)),
        "visited_locations": GameState.run.get("visited_locations", []).duplicate(),
        "defeated_enemies": GameState.run.get("defeated_enemies", []).duplicate(),
        "purchases": GameState.run.get("purchases", []).duplicate(),
        "marks": GameState.run.get("marks", {}).duplicate(true),
    }

func _close_combat(state: Dictionary) -> void:
    var result := str(state.get("result", ""))
    if result == "victory":
        var defeated: Array = GameState.run.get("defeated_enemies", [])
        var enemy_id := str(state.get("enemy", {}).get("id", ""))
        if enemy_id != "":
            defeated.append(enemy_id)
        GameState.run.defeated_enemies = defeated
        GameState.run.mode = "story"
    elif result == "defeat":
        fail("defeat")
