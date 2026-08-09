extends Node

const DEFAULT_ID := "andarilho"
const ORDER := ["contemplativa", "andarilho", "severa", "ruptura"]

# Andarilho is deliberately the exact legacy baseline. The other profiles are
# initial 10.6 calibration candidates; statistical probes may tune them before
# the phase is frozen, but their semantics stay monotonic and centralized here.
const PROFILES := {
    "contemplativa": {
        "name":"Contemplativa",
        "enemy_health":0.88,
        "enemy_posture":0.90,
        "enemy_damage":0.85,
        "start_fragments":16,
        "start_provisions":4,
    },
    "andarilho": {
        "name":"Andarilho",
        "enemy_health":1.00,
        "enemy_posture":1.00,
        "enemy_damage":1.00,
        "start_fragments":12,
        "start_provisions":3,
    },
    "severa": {
        "name":"Severa",
        "enemy_health":1.08,
        "enemy_posture":1.08,
        "enemy_damage":1.12,
        "start_fragments":10,
        "start_provisions":2,
    },
    "ruptura": {
        "name":"Ruptura",
        "enemy_health":1.18,
        "enemy_posture":1.15,
        "enemy_damage":1.22,
        "start_fragments":8,
        "start_provisions":1,
    },
}

var simulation_override := ""

func normalize_id(difficulty_id: String) -> String:
    return difficulty_id if PROFILES.has(difficulty_id) else DEFAULT_ID

func profile(difficulty_id: String = "") -> Dictionary:
    var resolved := current_id() if difficulty_id == "" else normalize_id(difficulty_id)
    return (PROFILES[resolved] as Dictionary).duplicate(true)

func current_id() -> String:
    if simulation_override != "":
        return normalize_id(simulation_override)
    if GameState.run.is_empty():
        return DEFAULT_ID
    return normalize_id(str(GameState.run.get("difficulty_id", DEFAULT_ID)))

func set_simulation_override(difficulty_id: String) -> void:
    simulation_override = normalize_id(difficulty_id)

func clear_simulation_override() -> void:
    simulation_override = ""

func scale_enemy_health(base_value: int, difficulty_id: String = "") -> int:
    return maxi(1, roundi(float(base_value) * float(profile(difficulty_id).enemy_health)))

func scale_enemy_posture(base_value: int, difficulty_id: String = "") -> int:
    return maxi(1, roundi(float(base_value) * float(profile(difficulty_id).enemy_posture)))

func scale_enemy_damage(base_value: int, difficulty_id: String = "") -> int:
    if base_value <= 0:
        return 0
    return maxi(1, roundi(float(base_value) * float(profile(difficulty_id).enemy_damage)))

func starting_resources(base_resources: Dictionary, difficulty_id: String) -> Dictionary:
    var result := base_resources.duplicate(true)
    var spec := profile(difficulty_id)
    result.fragments = int(spec.start_fragments)
    result.provisions = int(spec.start_provisions)
    return result

func apply_to_run(difficulty_id: String) -> String:
    var resolved := normalize_id(difficulty_id)
    GameState.run.difficulty_id = resolved
    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    GameState.run.resources = starting_resources(resources, resolved)
    return resolved

func ids() -> Array[String]:
    var result: Array[String] = []
    for difficulty_id in ORDER:
        result.append(str(difficulty_id))
    return result
