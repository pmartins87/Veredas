extends Node

const SEEDS := 48
const BASE_SEED := 2088000
const POLICIES := ["balanced", "aggressive", "cautious", "explorer"]
var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    var scores := {}
    var wins := {}
    for policy_id in POLICIES:
        var total := 0.0
        var victories := 0
        for sample_index in range(SEEDS):
            var seed_value := BASE_SEED + sample_index * 131
            var result := simulator.simulate({"character_id":"character.forja_rubra.01","policy_id":policy_id,"build_id":"baseline","seed":seed_value,"max_steps":80}, "andarilho")
            if not bool(result.get("ok", false)):
                print("FERREIRO_RECOMMENDATION_PROBE FAIL: invalid %s/%d" % [policy_id, sample_index])
                get_tree().quit(1)
                return
            total += _score(result)
            if str(result.get("result", "")) == "victory": victories += 1
        scores[policy_id] = total / float(SEEDS)
        wins[policy_id] = victories
    var best := "balanced"
    for policy_id in POLICIES:
        if float(scores[policy_id]) > float(scores[best]): best = policy_id
    print("10.8 Ferreiro 48-seed policy probe scores=%s wins=%s best=%s balanced_minus_aggressive=%.3f" % [str(scores), str(wins), best, float(scores["balanced"]) - float(scores["aggressive"])])
    if best != "balanced" or float(scores["balanced"]) < float(scores["aggressive"]) + 0.20:
        print("FERREIRO_RECOMMENDATION_PROBE FAIL: balanced is not robustly superior")
        get_tree().quit(1)
        return
    print("FERREIRO_RECOMMENDATION_PROBE PASS")
    get_tree().quit(0)

func _score(result: Dictionary) -> float:
    var score := 0.0
    if str(result.get("result", "")) == "victory": score += 1.0
    if bool(result.get("boss_reached", false)): score += 0.35
    if bool(result.get("boss_win", false)): score += 0.25
    var combats := maxi(1, int(result.get("combats", 0)))
    score += 0.15 * float(result.get("combat_wins", 0)) / float(combats)
    score += 0.10 * clampf(float(result.get("final_health", 0)) / 16.0, 0.0, 1.0)
    if str(result.get("result", "")) == "timeout": score -= 0.25
    return score
