extends Node

func start_journey(character_id: String, seed_value: int, difficulty_id: String = "") -> bool:
    if ContentRegistry.get_record(character_id).is_empty():
        return false
    MetaUnlockEngine.evaluate_progression()
    if not MetaUnlockEngine.is_character_unlocked(character_id):
        return false
    var character: Dictionary = ContentRegistry.get_record(character_id)
    var world_id := str(character.get("world_id", ""))
    if not EntitlementEngine.new().can_access_world(world_id):
        return false
    var ephemeral_simulation := bool(GameState.profile.get("_simulation_ephemeral", false))
    var resolved_difficulty := DifficultyEngine.requested_id(difficulty_id)
    GameState.new_run(character_id, seed_value)
    DifficultyEngine.apply_to_run(resolved_difficulty)
    GameState.run.mode = "story"
    GameState.run.visited_locations = [str(GameState.run.get("location_id", ""))]
    GameState.run.defeated_enemies = []
    GameState.run.purchases = []
    GameState.run.loot_found = []
    GameState.run.ending_id = ""
    if ephemeral_simulation:
        var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
        flags["simulation.no_persist"] = true
        GameState.run.flags = flags
    else:
        MetaUnlockEngine.discover(character_id)
        MetaUnlockEngine.discover(str(GameState.run.get("world_id", "")))
        MetaUnlockEngine.discover(str(GameState.run.get("location_id", "")))
        EchoConsequenceEngine.apply_to_run()
        AuthoredStoryDirector.activate_for_new_run()
    return true

func story_event() -> Dictionary:
    GameState.run.mode = "story"
    var event: Dictionary = AuthoredStoryDirector.current_event()
    if not event.is_empty():
        return event
    event = EventDirector.choose_event(str(GameState.run.get("world_id", "")), str(GameState.run.get("location_id", "")))
    if not event.is_empty() and not _simulation_no_persist():
        MetaUnlockEngine.discover(str(event.get("id", "")))
    return event

func choose(event: Dictionary, option: int) -> bool:
    var choices: Array = event.get("choices", [])
    if option < 0 or option >= choices.size():
        return false
    if AuthoredStoryDirector.is_authored_event(event):
        return AuthoredStoryDirector.apply_choice(event, option)
    if not _simulation_no_persist():
        MetaUnlockEngine.discover(str(event.get("id", "")))
    return EventDirector.apply_choice(event, option)

func travel(location_id: String) -> bool:
    var ok := LocationEngine.travel_to(location_id)
    if ok:
        GameState.run.mode = "story"
        if not _simulation_no_persist():
            MetaUnlockEngine.discover(location_id)
    return ok

func travel_world(world_id: String, location_id: String = "") -> bool:
    if not MetaUnlockEngine.is_route_unlocked(world_id):
        return false
    if not EntitlementEngine.new().can_access_world(world_id):
        return false
    var ok := LocationEngine.travel_world(world_id, location_id)
    if ok:
        GameState.run.mode = "story"
        if not _simulation_no_persist():
            MetaUnlockEngine.discover(world_id)
            MetaUnlockEngine.discover(str(GameState.run.get("location_id", "")))
    return ok

func open_inventory() -> void:
    GameState.run.mode = "inventory"

func open_travel() -> void:
    GameState.run.mode = "travel"

func open_merchant(size: int = 8) -> Array:
    GameState.run.mode = "merchant"
    return MerchantEngine.stock(str(GameState.run.get("world_id", "")), size)

func buy(item_id: String) -> bool:
    var ok := MerchantEngine.buy(item_id)
    if ok:
        var purchases: Array = GameState.run.get("purchases", [])
        purchases.append(item_id)
        GameState.run.purchases = purchases
        if not _simulation_no_persist():
            MetaUnlockEngine.discover(item_id)
    return ok

func local_monsters() -> Array:
    var result: Array = []
    var location_id := str(GameState.run.get("location_id", ""))
    for monster in ContentRegistry.all("monsters"):
        if str(monster.get("location_id", "")) == location_id:
            result.append(monster)
    return result

func local_bosses() -> Array:
    var result: Array = []
    var location_id := str(GameState.run.get("location_id", ""))
    for boss in ContentRegistry.all("bosses"):
        if str(boss.get("location_id", "")) == location_id:
            result.append(boss)
    return result

func endings_for_current_world() -> Array:
    var result: Array = []
    var world_id := str(GameState.run.get("world_id", ""))
    for ending in ContentRegistry.all("finals"):
        if str(ending.get("world_id", "")) == world_id:
            result.append(ending)
    return result

func start_combat(enemy_id: String) -> Dictionary:
    GameState.run.mode = "combat"
    if not _simulation_no_persist():
        MetaUnlockEngine.discover(enemy_id)
    return CombatEngine.start(enemy_id, str(GameState.run.get("character_id", "")))

func combat_action(action: String) -> Dictionary:
    var state := CombatEngine.player_action(action)
    if not bool(state.get("active", false)):
        _close_combat(state)
    return state

func combat_ability(ability_id: String) -> Dictionary:
    if not _simulation_no_persist():
        MetaUnlockEngine.discover(ability_id)
    var state := CombatEngine.use_character_ability(ability_id)
    if not bool(state.get("active", false)):
        _close_combat(state)
    return state

func finish(ending_id: String) -> bool:
    var ending := ContentRegistry.get_record(ending_id)
    if ending.is_empty() or not ending_id.begins_with("ending."):
        return false
    if str(ending.get("world_id", "")) != str(GameState.run.get("world_id", "")):
        return false
    GameState.run.active = false
    GameState.run.mode = "debrief"
    GameState.run.ending_id = ending_id
    GameState.run.result = "victory"
    if _simulation_no_persist():
        return true
    var endings: Array = GameState.profile.get("endings", [])
    if ending_id not in endings:
        endings.append(ending_id)
    GameState.profile.endings = endings
    MetaUnlockEngine.discover(ending_id)
    MetaUnlockEngine.evaluate_progression()
    EchoConsequenceEngine.record_outcome(ending_id, "victory")
    SaveService.save_game()
    return true

func fail(reason: String = "defeat") -> void:
    GameState.run.active = false
    GameState.run.mode = "debrief"
    GameState.run.result = reason
    if _simulation_no_persist():
        return
    EchoConsequenceEngine.record_outcome("", reason)
    SaveService.save_game()

func resume_story() -> void:
    if bool(GameState.run.get("active", false)):
        GameState.run.mode = "story"

func debrief() -> Dictionary:
    return {
        "result": GameState.run.get("result", "in_progress"),
        "ending_id": GameState.run.get("ending_id", ""),
        "turns": int(GameState.run.get("turn", 0)),
        "visited_locations": GameState.run.get("visited_locations", []).duplicate(),
        "defeated_enemies": GameState.run.get("defeated_enemies", []).duplicate(),
        "purchases": GameState.run.get("purchases", []).duplicate(),
        "loot_found": GameState.run.get("loot_found", []).duplicate(),
        "marks": GameState.run.get("marks", {}).duplicate(true),
        "echoes": EchoConsequenceEngine.summary(),
    }

func _close_combat(state: Dictionary) -> void:
    var result := str(state.get("result", ""))
    if result == "victory":
        var defeated: Array = GameState.run.get("defeated_enemies", [])
        var enemy_id := str(state.get("enemy", {}).get("id", ""))
        if enemy_id != "":
            defeated.append(enemy_id)
            if not _simulation_no_persist():
                MetaUnlockEngine.discover(enemy_id)
        GameState.run.defeated_enemies = defeated

        var enemy_record: Dictionary = state.get("enemy_record", {}) as Dictionary
        var resources: Dictionary = GameState.run.get("resources", {})
        resources.fragments = int(resources.get("fragments", 0)) + ItemEconomyEngine.fragment_reward(enemy_record)
        GameState.run.resources = resources

        var loot_found: Array = GameState.run.get("loot_found", [])
        for item_id in ItemEconomyEngine.loot_for_victory(enemy_record, defeated.size()):
            if InventoryEngine.add_item(str(item_id)):
                loot_found.append(str(item_id))
                if not _simulation_no_persist():
                    MetaUnlockEngine.discover(str(item_id))
        GameState.run.loot_found = loot_found
        GameState.run.mode = "final_choice" if enemy_id.begins_with("boss.") else "story"
    elif result == "defeat":
        fail("defeat")

func _simulation_no_persist() -> bool:
    return bool((GameState.run.get("flags", {}) as Dictionary).get("simulation.no_persist", false))
