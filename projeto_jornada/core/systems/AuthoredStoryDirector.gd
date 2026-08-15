extends Node

const ARC_PATH := "res://content_authored/mata_fio_verde_golden_slice.json"
const ARC_ID := "golden_slice.mata_fio_verde.01"
const WORLD_ID := "world.mata_fio_verde"
const CHARACTER_ID := "character.mata_fio_verde.01"

var _arc: Dictionary = {}
var _localization := LocalizationService.new()

func activate_for_new_run() -> bool:
    if str(GameState.run.get("world_id", "")) != WORLD_ID:
        return false
    if str(GameState.run.get("character_id", "")) != CHARACTER_ID:
        return false
    if bool((GameState.run.get("flags", {}) as Dictionary).get("simulation.no_persist", false)):
        return false
    if not _ensure_loaded():
        return false
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["authored.arc_id"] = ARC_ID
    flags["authored.scene"] = str(_arc.get("start_scene", "opening"))
    flags["authored.completed"] = false
    GameState.run.flags = flags
    return true

func is_active() -> bool:
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    return str(flags.get("authored.arc_id", "")) == ARC_ID and not bool(flags.get("authored.completed", false))

func is_authored_event(event: Dictionary) -> bool:
    return str(event.get("authored_arc_id", "")) == ARC_ID

func current_event() -> Dictionary:
    if not is_active() or not _ensure_loaded():
        return {}
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    var scene_key := str(flags.get("authored.scene", ""))
    var scenes: Dictionary = _arc.get("scenes", {}) as Dictionary
    if not scenes.has(scene_key):
        push_error("AuthoredStoryDirector missing scene: %s" % scene_key)
        return {}
    var scene: Dictionary = (scenes.get(scene_key, {}) as Dictionary).duplicate(true)
    _sync_location(str(scene.get("location_id", "")))
    var copy := _localized_copy(scene.get("copy", {}) as Dictionary)
    var choice_copy: Array = copy.get("choices", []) as Array
    var runtime_choices: Array = []
    var definitions: Array = scene.get("choices", []) as Array
    for index in range(definitions.size()):
        var definition: Dictionary = (definitions[index] as Dictionary).duplicate(true)
        definition["text"] = str(choice_copy[index]) if index < choice_copy.size() else "Continuar"
        runtime_choices.append(definition)
    return {
        "id": str(scene.get("id", "authored.%s" % scene_key)),
        "authored_arc_id": ARC_ID,
        "authored_scene_id": scene_key,
        "world_id": WORLD_ID,
        "location_id": str(scene.get("location_id", "")),
        "kicker": str(copy.get("kicker", "")),
        "title": str(copy.get("title", "")),
        "text": str(copy.get("text", "")),
        "choices": runtime_choices,
    }

func apply_choice(event: Dictionary, choice_index: int) -> bool:
    if not is_active() or not is_authored_event(event) or not _ensure_loaded():
        return false
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    var scene_key := str(flags.get("authored.scene", ""))
    if scene_key != str(event.get("authored_scene_id", "")):
        return false
    var scenes: Dictionary = _arc.get("scenes", {}) as Dictionary
    var scene: Dictionary = scenes.get(scene_key, {}) as Dictionary
    var choices: Array = scene.get("choices", []) as Array
    if choice_index < 0 or choice_index >= choices.size():
        return false
    var choice: Dictionary = choices[choice_index] as Dictionary
    _apply_effects(choice.get("effects", {}) as Dictionary)
    GameState.run.turn = int(GameState.run.get("turn", 0)) + 1
    NarrativeDebtEngine.age_all(1)
    PresentationBus.choice()

    if choice.has("end"):
        _complete(str(choice.get("end", "")))
        return true

    var next_scene := str(choice.get("next", ""))
    if next_scene == "" or not scenes.has(next_scene):
        push_error("AuthoredStoryDirector invalid next scene from %s: %s" % [scene_key, next_scene])
        return false
    flags = GameState.run.get("flags", {}) as Dictionary
    flags["authored.scene"] = next_scene
    GameState.run.flags = flags
    var transition: Dictionary = (choice.get("effects", {}) as Dictionary).get("transition", {}) as Dictionary
    if not transition.is_empty():
        GameState.run.authored_transition = transition.duplicate(true)
    return true

func consume_transition() -> Dictionary:
    var transition: Dictionary = GameState.run.get("authored_transition", {}) as Dictionary
    GameState.run.erase("authored_transition")
    return transition.duplicate(true)

func debrief() -> Dictionary:
    if not _ensure_loaded():
        return {}
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    if str(flags.get("authored.arc_id", "")) != ARC_ID:
        return {}
    var ending_key := str(flags.get("authored.ending", ""))
    if ending_key == "":
        return {}
    var endings: Dictionary = _arc.get("endings", {}) as Dictionary
    var ending: Dictionary = endings.get(ending_key, {}) as Dictionary
    if ending.is_empty():
        return {}
    var copy := _localized_copy(ending)
    return {
        "authored": true,
        "ending_key": ending_key,
        "title": str(copy.get("title", "Fim da jornada")),
        "text": str(copy.get("text", "")),
    }

func _complete(ending_key: String) -> void:
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["authored.completed"] = true
    flags["authored.ending"] = ending_key
    GameState.run.flags = flags
    GameState.run.active = false
    GameState.run.mode = "debrief"
    GameState.run.result = "authored_resolution"
    GameState.run.ending_id = ""
    SaveService.save_game()

func _apply_effects(effects: Dictionary) -> void:
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    var flag_updates: Dictionary = effects.get("flags", {}) as Dictionary
    for key_variant in flag_updates.keys():
        flags[str(key_variant)] = flag_updates[key_variant]
    GameState.run.flags = flags

    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    if effects.has("fragments_delta"):
        resources.fragments = maxi(0, int(resources.get("fragments", 0)) + int(effects.get("fragments_delta", 0)))
        GameState.run.resources = resources
    if effects.has("health_delta"):
        GameState.run.health = clampi(
            int(GameState.run.get("health", 0)) + int(effects.get("health_delta", 0)),
            1,
            maxi(1, int(GameState.run.get("max_health", 1)))
        )
    if effects.has("vigor_delta"):
        GameState.run.vigor = clampi(
            int(GameState.run.get("vigor", 0)) + int(effects.get("vigor_delta", 0)),
            0,
            maxi(0, int(GameState.run.get("max_vigor", 0)))
        )
    var mark_id := str(effects.get("mark", ""))
    if mark_id != "":
        var marks: Dictionary = GameState.run.get("marks", {}) as Dictionary
        marks[mark_id] = {"source": ARC_ID, "turn": int(GameState.run.get("turn", 0))}
        GameState.run.marks = marks

func _sync_location(location_id: String) -> void:
    if location_id == "" or location_id == str(GameState.run.get("location_id", "")):
        return
    GameState.run.location_id = location_id
    var visited: Array = GameState.run.get("visited_locations", []) as Array
    if location_id not in visited:
        visited.append(location_id)
        GameState.run.visited_locations = visited

func _localized_copy(copies: Dictionary) -> Dictionary:
    var locale := _localization.current_locale()
    if copies.has(locale):
        return (copies.get(locale, {}) as Dictionary).duplicate(true)
    if copies.has("pt_BR"):
        return (copies.get("pt_BR", {}) as Dictionary).duplicate(true)
    return {}

func _ensure_loaded() -> bool:
    if not _arc.is_empty():
        return true
    if not FileAccess.file_exists(ARC_PATH):
        push_error("AuthoredStoryDirector missing arc data: %s" % ARC_PATH)
        return false
    var file := FileAccess.open(ARC_PATH, FileAccess.READ)
    if file == null:
        return false
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("AuthoredStoryDirector arc JSON is invalid")
        return false
    _arc = parsed as Dictionary
    if int(_arc.get("schema_version", 0)) != 1 or str(_arc.get("arc_id", "")) != ARC_ID:
        push_error("AuthoredStoryDirector arc identity mismatch")
        _arc = {}
        return false
    return true
