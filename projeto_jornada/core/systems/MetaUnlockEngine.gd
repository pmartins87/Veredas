extends Node

const DEFAULT_CHARACTER := "character.mata_fio_verde.01"
const DEFAULT_ROUTE := "world.mata_fio_verde"
const DEFAULT_MODE := "journey"

const MODE_SPECS := {
    "journey": {"name":"Jornada","description":"A forma principal de atravessar as Veredas."},
    "fixed_seed": {"name":"Trama Compartilhada","description":"Jornadas com seed explícita para repetir ou compartilhar uma configuração."},
    "echo_run": {"name":"Caminho de Eco","description":"Uma jornada que parte de consequências já testemunhadas, sem bônus permanentes de poder."},
    "convergence": {"name":"Convergência","description":"Modo avançado que cruza Domínios e consequências já descobertas."},
}

func ensure_state() -> Dictionary:
    var unlocks: Dictionary = GameState.profile.get("unlocks", {}) as Dictionary
    var legacy_characters: Array = GameState.profile.get("unlocked_characters", []) as Array
    var legacy_codex: Array = GameState.profile.get("codex", []) as Array
    var hub: Dictionary = GameState.profile.get("hub", {}) as Dictionary

    var characters: Array = unlocks.get("characters", []) as Array
    if characters.is_empty():
        characters = legacy_characters.duplicate()
    if DEFAULT_CHARACTER not in characters:
        characters.append(DEFAULT_CHARACTER)

    var routes_list: Array = unlocks.get("routes", []) as Array
    if routes_list.is_empty() and not hub.is_empty():
        routes_list = (hub.get("routes", []) as Array).duplicate()
    if DEFAULT_ROUTE not in routes_list:
        routes_list.append(DEFAULT_ROUTE)

    var modes: Array = unlocks.get("modes", []) as Array
    if DEFAULT_MODE not in modes:
        modes.append(DEFAULT_MODE)

    var codex_entries: Array = unlocks.get("codex", []) as Array
    if codex_entries.is_empty():
        codex_entries = legacy_codex.duplicate()
    for initial_id in [DEFAULT_CHARACTER, DEFAULT_ROUTE]:
        if initial_id not in codex_entries:
            codex_entries.append(initial_id)

    unlocks = {
        "characters": _unique_sorted(characters),
        "routes": _unique_sorted(routes_list),
        "modes": _unique_sorted(modes),
        "codex": _unique_sorted(codex_entries),
    }
    GameState.profile.unlocks = unlocks
    _sync_legacy_fields()
    return unlocks

func evaluate_progression() -> Dictionary:
    var unlocks: Dictionary = ensure_state()
    var endings: Array = GameState.profile.get("endings", []) as Array
    var endings_by_world: Dictionary = {}
    for ending_id_variant in endings:
        var ending_id: String = str(ending_id_variant)
        var ending: Dictionary = ContentRegistry.get_record(ending_id)
        var world_id: String = str(ending.get("world_id", ""))
        if world_id == "":
            continue
        endings_by_world[world_id] = int(endings_by_world.get(world_id, 0)) + 1
        _append_unique(unlocks.codex, ending_id)

    for world_id_variant in (unlocks.get("routes", []) as Array):
        var world_id: String = str(world_id_variant)
        var characters: Array = _characters_for_world(world_id)
        if not characters.is_empty():
            _append_unique(unlocks.characters, str((characters[0] as Dictionary).get("id", "")))
        var ending_count: int = int(endings_by_world.get(world_id, 0))
        if ending_count >= 1 and characters.size() >= 2:
            _append_unique(unlocks.characters, str((characters[1] as Dictionary).get("id", "")))
        if ending_count >= 2 and characters.size() >= 3:
            _append_unique(unlocks.characters, str((characters[2] as Dictionary).get("id", "")))

    if endings.size() >= 1:
        _append_unique(unlocks.modes, "fixed_seed")
    if endings.size() >= 3:
        _append_unique(unlocks.modes, "echo_run")
    if endings.size() >= 6 and (unlocks.get("routes", []) as Array).size() >= 6:
        _append_unique(unlocks.modes, "convergence")

    unlocks.characters = _unique_sorted(unlocks.characters as Array)
    unlocks.routes = _unique_sorted(unlocks.routes as Array)
    unlocks.modes = _unique_sorted(unlocks.modes as Array)
    unlocks.codex = _unique_sorted(unlocks.codex as Array)
    GameState.profile.unlocks = unlocks
    _sync_legacy_fields()
    return unlocks

func unlock_route(world_id: String) -> bool:
    if not world_id.begins_with("world.") or ContentRegistry.get_record(world_id).is_empty():
        return false
    var unlocks: Dictionary = ensure_state()
    _append_unique(unlocks.routes, world_id)
    _append_unique(unlocks.codex, world_id)
    GameState.profile.unlocks = unlocks
    var hub: Dictionary = GameState.profile.get("hub", {}) as Dictionary
    if not hub.is_empty():
        var hub_routes: Array = hub.get("routes", []) as Array
        _append_unique(hub_routes, world_id)
        hub.routes = hub_routes
        GameState.profile.hub = hub
    _sync_legacy_fields()
    CodexProgressEngine.new().discover(world_id, "route_unlock")
    evaluate_progression()
    return true

func unlock_character(character_id: String) -> bool:
    if not character_id.begins_with("character.") or ContentRegistry.get_record(character_id).is_empty():
        return false
    var unlocks: Dictionary = ensure_state()
    _append_unique(unlocks.characters, character_id)
    _append_unique(unlocks.codex, character_id)
    GameState.profile.unlocks = unlocks
    _sync_legacy_fields()
    CodexProgressEngine.new().discover(character_id, "character_unlock")
    return true

func unlock_mode(mode_id: String) -> bool:
    if not MODE_SPECS.has(mode_id):
        return false
    var unlocks: Dictionary = ensure_state()
    _append_unique(unlocks.modes, mode_id)
    GameState.profile.unlocks = unlocks
    return true

func discover(content_id: String) -> bool:
    if content_id == "" or ContentRegistry.get_record(content_id).is_empty():
        return false
    var unlocks: Dictionary = ensure_state()
    _append_unique(unlocks.codex, content_id)
    GameState.profile.unlocks = unlocks
    _sync_legacy_fields()
    return CodexProgressEngine.new().discover(content_id, "journey")

func is_character_unlocked(character_id: String) -> bool:
    return character_id in (ensure_state().get("characters", []) as Array)

func is_route_unlocked(world_id: String) -> bool:
    return world_id in (ensure_state().get("routes", []) as Array)

func is_mode_unlocked(mode_id: String) -> bool:
    return mode_id in (ensure_state().get("modes", []) as Array)

func is_discovered(content_id: String) -> bool:
    return content_id in (ensure_state().get("codex", []) as Array)

func unlocked_characters(world_id: String = "") -> Array:
    var allowed: Array = ensure_state().get("characters", []) as Array
    var result: Array = []
    for character in ContentRegistry.all("characters"):
        var character_dict: Dictionary = character as Dictionary
        var character_id: String = str(character_dict.get("id", ""))
        if character_id not in allowed:
            continue
        if world_id != "" and str(character_dict.get("world_id", "")) != world_id:
            continue
        result.append(character_dict)
    result.sort_custom(func(a, b): return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", "")))
    return result

func unlocked_routes() -> Array:
    var result: Array = []
    for world_id_variant in (ensure_state().get("routes", []) as Array):
        var world: Dictionary = ContentRegistry.get_record(str(world_id_variant))
        if not world.is_empty():
            result.append(world)
    return result

func unlocked_modes() -> Array:
    var result: Array = []
    for mode_id_variant in (ensure_state().get("modes", []) as Array):
        var mode_id: String = str(mode_id_variant)
        if MODE_SPECS.has(mode_id):
            var spec: Dictionary = (MODE_SPECS[mode_id] as Dictionary).duplicate(true)
            spec.id = mode_id
            result.append(spec)
    return result

func codex_ids() -> Array:
    return (ensure_state().get("codex", []) as Array).duplicate()

func summary() -> Dictionary:
    var unlocks: Dictionary = ensure_state()
    return {
        "characters": (unlocks.get("characters", []) as Array).size(),
        "routes": (unlocks.get("routes", []) as Array).size(),
        "modes": (unlocks.get("modes", []) as Array).size(),
        "codex": (unlocks.get("codex", []) as Array).size(),
    }

func _characters_for_world(world_id: String) -> Array:
    var result: Array = []
    for character in ContentRegistry.all("characters"):
        var character_dict: Dictionary = character as Dictionary
        if str(character_dict.get("world_id", "")) == world_id:
            result.append(character_dict)
    result.sort_custom(func(a, b): return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", "")))
    return result

func _sync_legacy_fields() -> void:
    var unlocks: Dictionary = GameState.profile.get("unlocks", {}) as Dictionary
    GameState.profile.unlocked_characters = (unlocks.get("characters", []) as Array).duplicate()
    GameState.profile.codex = (unlocks.get("codex", []) as Array).duplicate()

func _append_unique(target: Array, value: String) -> void:
    if value != "" and value not in target:
        target.append(value)

func _unique_sorted(values: Array) -> Array:
    var seen: Dictionary = {}
    var result: Array = []
    for value_variant in values:
        var value: String = str(value_variant)
        if value == "" or seen.has(value):
            continue
        seen[value] = true
        result.append(value)
    result.sort()
    return result
