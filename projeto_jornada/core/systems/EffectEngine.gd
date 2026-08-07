extends Node

func apply(effect: Dictionary) -> bool:
    if effect.is_empty():
        return true
    var op := str(effect.get("op", ""))
    match op:
        "mark_add":
            GameState.add_mark(str(effect.get("mark_id", "")), int(effect.get("intensity", 1)))
            return true
        "mark_intensify":
            GameState.add_mark(str(effect.get("mark_id", "")), int(effect.get("value", 1)))
            return true
        "resource_add":
            return _resource_add(str(effect.get("resource", "")), int(effect.get("value", 0)))
        "flag_set":
            var flags: Dictionary = GameState.run.get("flags", {})
            flags[str(effect.get("key", ""))] = effect.get("value", true)
            GameState.run.flags = flags
            return true
        "item_add":
            return InventoryEngine.add_item(str(effect.get("item_id", "")), int(effect.get("count", 1)))
        "item_remove":
            return InventoryEngine.remove_item(str(effect.get("item_id", "")), int(effect.get("count", 1)))
        "debt_create":
            return NarrativeDebtEngine.create(str(effect.get("debt_id", "")))
        "debt_resolve":
            return NarrativeDebtEngine.resolve(str(effect.get("debt_id", "")))
        "debt_resolve_oldest":
            return NarrativeDebtEngine.resolve_oldest()
        "travel_location":
            return LocationEngine.travel_to(str(effect.get("location_id", "")))
        "travel_world":
            return LocationEngine.travel_world(str(effect.get("world_id", "")))
        "heal":
            return _resource_add("health", int(effect.get("value", 0)))
        "vigor":
            return _resource_add("vigor", int(effect.get("value", 0)))
        _:
            return false

func apply_all(effects: Array) -> bool:
    var ok := true
    for effect in effects:
        ok = apply(effect) and ok
    return ok

func _resource_add(key: String, value: int) -> bool:
    if key == "health":
        GameState.run.health = clampi(int(GameState.run.get("health", 0)) + value, 0, int(GameState.run.get("max_health", 16)))
        return true
    if key == "vigor":
        GameState.run.vigor = clampi(int(GameState.run.get("vigor", 0)) + value, 0, int(GameState.run.get("max_vigor", 8)))
        return true
    var resources: Dictionary = GameState.run.get("resources", {})
    resources[key] = int(resources.get(key, 0)) + value
    GameState.run.resources = resources
    return true
