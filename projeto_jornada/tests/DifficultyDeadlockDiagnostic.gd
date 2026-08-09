extends Node

const SEEDS_PER_CHARACTER := 12
const BASE_SEED := 106000
const MAX_STEPS := 80

var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    var characters := ContentRegistry.all("characters")
    var found := 0
    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        var policy := _recommended_policy(character)
        for sample_index in range(SEEDS_PER_CHARACTER):
            var seed_value := BASE_SEED + character_index * 1009 + sample_index * 97
            for difficulty_id in ["severa", "ruptura"]:
                var result := simulator.simulate({
                    "character_id":character_id,
                    "policy_id":policy,
                    "build_id":"baseline",
                    "seed":seed_value,
                    "max_steps":MAX_STEPS,
                }, difficulty_id)
                if int(result.get("deadlocks", 0)) <= 0:
                    continue
                found += 1
                print("10.6 DEADLOCK character=%s name=%s policy=%s seed=%d difficulty=%s result=%s steps=%d turns=%d combats=%d combat_wins=%d boss_reached=%s boss_win=%s final_hp=%d final_vigor=%d locations=%d events=%d choices=%d" % [
                    character_id,
                    str(character.get("name", "")),
                    policy,
                    seed_value,
                    difficulty_id,
                    str(result.get("result", "")),
                    int(result.get("steps", 0)),
                    int(result.get("turns", 0)),
                    int(result.get("combats", 0)),
                    int(result.get("combat_wins", 0)),
                    str(result.get("boss_reached", false)),
                    str(result.get("boss_win", false)),
                    int(result.get("final_health", 0)),
                    int(result.get("final_vigor", 0)),
                    int(result.get("locations_visited", 0)),
                    int(result.get("events", 0)),
                    int(result.get("choices", 0)),
                ])
    print("10.6 DEADLOCK_DIAGNOSTIC found=%d" % found)
    DifficultyEngine.clear_simulation_override()
    get_tree().quit(0)

func _recommended_policy(character: Dictionary) -> String:
    var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
    var policy := str(curve.get("recommended_policy", "balanced"))
    return policy if PlayerPolicyEngine.new().is_valid(policy) else "balanced"
