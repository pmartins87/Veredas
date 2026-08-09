extends Node

const SEEDS := 32
const BASE_SEED := 109700
const POLICIES := ["balanced", "aggressive", "cautious", "explorer"]
const BUILDS := ["offense", "defense", "utility"]

var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    var forja: Array = []
    for row_variant in ContentRegistry.all("characters"):
        var row: Dictionary = row_variant as Dictionary
        if str(row.get("world_id", "")) == "world.forja_rubra":
            forja.append(row)
    var build_totals: Dictionary = {"offense":{"runs":0,"wins":0,"score":0.0},"defense":{"runs":0,"wins":0,"score":0.0},"utility":{"runs":0,"wins":0,"score":0.0}}
    for character_variant in forja:
        var character: Dictionary = character_variant as Dictionary
        for policy_id in POLICIES:
            for build_id in BUILDS:
                var wins := 0
                var score_total := 0.0
                for sample_index in range(SEEDS):
                    var seed_value := BASE_SEED + absi(str(character.get("id", "")).hash() % 100000) + sample_index * 131
                    var result := simulator.simulate({"character_id":str(character.get("id", "")),"policy_id":policy_id,"build_id":build_id,"seed":seed_value,"max_steps":80}, "ruptura")
                    if str(result.get("result", "")) == "victory": wins += 1
                    score_total += _score(result)
                var total: Dictionary = build_totals[build_id] as Dictionary
                total.runs = int(total.runs) + SEEDS
                total.wins = int(total.wins) + wins
                total.score = float(total.score) + score_total
                print("10.8 guardcap %s/%s/%s victory=%.3f score=%.3f" % [str(character.get("name", "")),policy_id,build_id,float(wins)/float(SEEDS),score_total/float(SEEDS)])
    for build_id in BUILDS:
        var total: Dictionary = build_totals[build_id] as Dictionary
        print("10.8 guardcap AGG %s runs=%d victory=%.3f score=%.3f" % [build_id,int(total.runs),float(total.wins)/float(maxi(1,int(total.runs))),float(total.score)/float(maxi(1,int(total.runs)))])
    get_tree().quit(0)

func _score(result: Dictionary) -> float:
    var score := 0.0
    if str(result.get("result", "")) == "victory": score += 1.0
    if bool(result.get("boss_reached", false)): score += 0.35
    if bool(result.get("boss_win", false)): score += 0.25
    var combats := maxi(1, int(result.get("combats", 0)))
    score += 0.15 * float(result.get("combat_wins", 0)) / float(combats)
    score += 0.10 * clampf(float(result.get("final_health", 0)) / 16.0, 0.0, 1.0)
    return score
