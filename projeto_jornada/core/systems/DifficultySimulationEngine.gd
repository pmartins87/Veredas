extends RefCounted
class_name DifficultySimulationEngine

var simulator := JourneySimulationEngine.new()

func simulate(config: Dictionary, difficulty_id: String) -> Dictionary:
    var resolved := DifficultyEngine.normalize_id(difficulty_id)
    DifficultyEngine.set_simulation_override(resolved)
    var result := simulator.simulate(config)
    DifficultyEngine.clear_simulation_override()
    result["difficulty_id"] = resolved
    return result

func simulate_paired(config: Dictionary) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for difficulty_id in DifficultyEngine.ids():
        results.append(simulate(config, difficulty_id))
    return results
