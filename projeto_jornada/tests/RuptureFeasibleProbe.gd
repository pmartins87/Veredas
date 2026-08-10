extends Node

const SEEDS := 32
const POLICIES := ["balanced", "aggressive", "cautious", "explorer"]
const BASE_SEED := 4100000
var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    var rows: Array[Dictionary] = []
    var total_runs := 0
    var total_wins := 0
    var invalid := 0
    var deadlocks := 0
    for character_variant in ContentRegistry.all("characters"):
        var character: Dictionary = character_variant as Dictionary
        var cid := str(character.get("id", ""))
        for policy_id in POLICIES:
            var wins := 0
            var score := 0.0
            var stalemates := 0
            for i in range(SEEDS):
                var seed_value := BASE_SEED + absi(cid.hash()) % 100000 + i * 173
                var result := simulator.simulate({"character_id":cid,"policy_id":policy_id,"build_id":"baseline","seed":seed_value,"max_steps":80}, "ruptura")
                total_runs += 1
                if not bool(result.get("ok",false)):
                    invalid += 1
                    continue
                deadlocks += int(result.get("deadlocks",0))
                stalemates += int(result.get("combat_timeouts",0))
                if str(result.get("result","")) == "victory":
                    wins += 1
                    total_wins += 1
                score += _score(result)
            rows.append({"name":str(character.get("name",cid)),"id":cid,"policy":policy_id,"wins":wins,"rate":float(wins)/float(SEEDS),"score":score/float(SEEDS),"stalemates":stalemates})
    rows.sort_custom(func(a,b):
        if not is_equal_approx(float(a.rate),float(b.rate)): return float(a.rate)>float(b.rate)
        return float(a.score)>float(b.score)
    )
    print("10.8 feasible Ruptura: runs=%d wins=%d rate=%.4f invalid=%d deadlocks=%d" % [total_runs,total_wins,float(total_wins)/float(maxi(1,total_runs)),invalid,deadlocks])
    for i in range(mini(16,rows.size())):
        var row: Dictionary = rows[i]
        print("10.8 feasible TOP %02d: %s/%s wins=%d/%d rate=%.3f score=%.3f stalemates=%d" % [i+1,str(row.name),str(row.policy),int(row.wins),SEEDS,float(row.rate),float(row.score),int(row.stalemates)])
    if invalid > 0 or deadlocks > 0:
        print("RUPTURE_FEASIBLE_PROBE FAIL")
        get_tree().quit(1)
        return
    print("RUPTURE_FEASIBLE_PROBE PASS")
    get_tree().quit(0)

func _score(result: Dictionary) -> float:
    var value := 0.0
    if str(result.get("result","")) == "victory": value += 1.0
    if bool(result.get("boss_reached",false)): value += 0.35
    if bool(result.get("boss_win",false)): value += 0.25
    var combats := maxi(1,int(result.get("combats",0)))
    value += 0.15*float(result.get("combat_wins",0))/float(combats)
    value += 0.10*clampf(float(result.get("final_health",0))/16.0,0.0,1.0)
    if str(result.get("result","")) == "timeout": value -= 0.25
    return value
