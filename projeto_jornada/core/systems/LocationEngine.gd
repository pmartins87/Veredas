extends Node

func travel_to(location_id: String) -> bool:
    var location := ContentRegistry.get_record(location_id)
    if location.is_empty() or not str(location_id).begins_with("location."):
        return false
    var world_id := str(location.get("world_id", ""))
    if world_id != str(GameState.run.get("world_id", "")):
        return false
    if location_id != str(GameState.run.get("location_id", "")):
        _apply_travel_attrition()
    GameState.run.location_id = location_id
    _remember(location_id)
    PresentationBus.location(location_id)
    return true

func travel_world(world_id: String, entry_location_id: String = "") -> bool:
    var world := ContentRegistry.get_record(world_id)
    if world.is_empty() or not str(world_id).begins_with("world."):
        return false
    var locations: Array = world.get("locations", [])
    if locations.is_empty():
        return false
    var target := entry_location_id if entry_location_id != "" else str(locations[0])
    if target not in locations:
        return false
    if world_id != str(GameState.run.get("world_id", "")) or target != str(GameState.run.get("location_id", "")):
        _apply_travel_attrition()
    GameState.run.world_id = world_id
    GameState.run.location_id = target
    _remember(target)
    PresentationBus.location(target)
    return true

func available_locations() -> Array:
    var world := ContentRegistry.get_record(str(GameState.run.get("world_id", "")))
    return world.get("locations", []).duplicate()

func visited_locations() -> Array:
    return GameState.run.get("visited_locations", []).duplicate()

func _apply_travel_attrition() -> void:
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    if bool(flags.get("simulation.no_attrition", false)):
        return
    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    var provisions := maxi(0, int(resources.get("provisions", 0)))
    if provisions > 0:
        resources.provisions = provisions - 1
        GameState.run.resources = resources
        return
    # Travelling without supplies is possible, but it converts route choice into
    # real attrition instead of a free loop: first Vigor, then nonlethal Health.
    var vigor := maxi(0, int(GameState.run.get("vigor", 0)))
    if vigor > 0:
        GameState.run.vigor = vigor - 1
        return
    GameState.run.health = maxi(1, int(GameState.run.get("health", 1)) - 1)

func _remember(location_id: String) -> void:
    var visited: Array = GameState.run.get("visited_locations", [])
    if location_id not in visited:
        visited.append(location_id)
    GameState.run.visited_locations = visited
