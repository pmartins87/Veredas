extends RefCounted
class_name JourneySetupEngine

const DEFAULT_DIFFICULTY := "andarilho"

const DIFFICULTIES := {
    "contemplativa": {"name":"Contemplativa","description":"Maior margem para leitura, descoberta e aprendizado. Calibração numérica final em 10.6."},
    "andarilho": {"name":"Andarilho","description":"Experiência-base pretendida para a primeira jornada completa. Calibração numérica final em 10.6."},
    "severa": {"name":"Severa","description":"Menor margem para erro e recursos. Calibração numérica final em 10.6."},
    "ruptura": {"name":"Ruptura","description":"A configuração de maior exigência. Calibração numérica final em 10.6."},
}

const MODIFIERS := {
    "sem_trocas": {
        "name":"Vereda sem Trocas",
        "description":"Mercadores não negociam durante esta jornada.",
        "required_endings":1,
    },
    "mochila_leve": {
        "name":"Mochila Leve",
        "description":"A jornada começa com apenas uma Provisão.",
        "required_endings":2,
    },
}

func default_setup() -> Dictionary:
    MetaUnlockEngine.evaluate_progression()
    var routes := MetaUnlockEngine.unlocked_routes()
    var world_id := "world.mata_fio_verde"
    if not routes.is_empty():
        world_id = str((routes[0] as Dictionary).get("id", world_id))
    var characters := MetaUnlockEngine.unlocked_characters(world_id)
    var character_id := "character.mata_fio_verde.01"
    if not characters.is_empty():
        character_id = str((characters[0] as Dictionary).get("id", character_id))
    return {
        "world_id":world_id,
        "character_id":character_id,
        "journey_mode":"journey",
        "difficulty_id":DEFAULT_DIFFICULTY,
        "seed":0,
        "modifiers":[],
    }

func validate(setup: Dictionary) -> Dictionary:
    MetaUnlockEngine.evaluate_progression()
    var errors: Array[String] = []
    var world_id := str(setup.get("world_id", ""))
    var character_id := str(setup.get("character_id", ""))
    var journey_mode := str(setup.get("journey_mode", "journey"))
    var difficulty_id := str(setup.get("difficulty_id", DEFAULT_DIFFICULTY))
    var seed_value := int(setup.get("seed", 0))
    var modifiers: Array = setup.get("modifiers", []) as Array

    if not MetaUnlockEngine.is_route_unlocked(world_id):
        errors.append("route_locked")
    var character := ContentRegistry.get_record(character_id)
    if character.is_empty() or not MetaUnlockEngine.is_character_unlocked(character_id):
        errors.append("character_locked")
    elif str(character.get("world_id", "")) != world_id:
        errors.append("character_wrong_route")
    if not MetaUnlockEngine.is_mode_unlocked(journey_mode):
        errors.append("mode_locked")
    if not DIFFICULTIES.has(difficulty_id):
        errors.append("difficulty_unknown")
    if journey_mode == "fixed_seed" and seed_value <= 0:
        errors.append("fixed_seed_required")

    var seen := {}
    for modifier_variant in modifiers:
        var modifier_id := str(modifier_variant)
        if seen.has(modifier_id):
            errors.append("modifier_duplicate:%s" % modifier_id)
            continue
        seen[modifier_id] = true
        if not MODIFIERS.has(modifier_id):
            errors.append("modifier_unknown:%s" % modifier_id)
        elif not modifier_available(modifier_id):
            errors.append("modifier_locked:%s" % modifier_id)

    return {"ok":errors.is_empty(),"errors":errors}

func start(setup: Dictionary) -> bool:
    var check := validate(setup)
    if not bool(check.get("ok", false)):
        return false
    var seed_value := int(setup.get("seed", 0))
    if seed_value <= 0:
        seed_value = int(Time.get_unix_time_from_system()) & 0x7fffffff
        if seed_value <= 0:
            seed_value = 1
    var character_id := str(setup.get("character_id", ""))
    if not RunFlowEngine.start_journey(character_id, seed_value):
        return false

    var normalized := {
        "world_id":str(setup.get("world_id", "")),
        "character_id":character_id,
        "journey_mode":str(setup.get("journey_mode", "journey")),
        "difficulty_id":str(setup.get("difficulty_id", DEFAULT_DIFFICULTY)),
        "seed":seed_value,
        "modifiers":_normalized_modifiers(setup.get("modifiers", []) as Array),
    }
    GameState.run.journey_mode = normalized.journey_mode
    GameState.run.difficulty_id = normalized.difficulty_id
    GameState.run.modifiers = normalized.modifiers.duplicate()
    GameState.run.setup = normalized.duplicate(true)

    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    if "sem_trocas" in normalized.modifiers:
        flags["modifier.no_trade"] = true
    if "mochila_leve" in normalized.modifiers:
        var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
        resources.provisions = mini(1, int(resources.get("provisions", 0)))
        GameState.run.resources = resources
        flags["modifier.light_pack"] = true
    GameState.run.flags = flags
    SaveService.save_game()
    return true

func difficulty_options() -> Array:
    var result: Array = []
    for difficulty_id in DIFFICULTIES:
        var spec: Dictionary = (DIFFICULTIES[difficulty_id] as Dictionary).duplicate(true)
        spec.id = difficulty_id
        result.append(spec)
    var order := ["contemplativa","andarilho","severa","ruptura"]
    result.sort_custom(func(a,b): return order.find(str((a as Dictionary).id)) < order.find(str((b as Dictionary).id)))
    return result

func modifier_options() -> Array:
    var result: Array = []
    for modifier_id in MODIFIERS:
        var spec: Dictionary = (MODIFIERS[modifier_id] as Dictionary).duplicate(true)
        spec.id = modifier_id
        spec.available = modifier_available(modifier_id)
        result.append(spec)
    result.sort_custom(func(a,b): return str((a as Dictionary).id) < str((b as Dictionary).id))
    return result

func modifier_available(modifier_id: String) -> bool:
    if not MODIFIERS.has(modifier_id):
        return false
    var required := int((MODIFIERS[modifier_id] as Dictionary).get("required_endings", 0))
    return (GameState.profile.get("endings", []) as Array).size() >= required

func _normalized_modifiers(values: Array) -> Array:
    var result: Array = []
    for value_variant in values:
        var value := str(value_variant)
        if value != "" and value not in result:
            result.append(value)
    result.sort()
    return result
