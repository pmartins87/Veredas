extends Node

const SEEDS := 6
const BASE_SEED := 108000
const MAX_STEPS := 80
const POLICIES := ["balanced", "aggressive", "cautious", "explorer", "random"]
const CONTROLLED_POLICIES := ["balanced", "aggressive", "cautious", "explorer"]
const BUILDS := ["baseline", "offense", "defense", "utility"]
const EQUIPPED_BUILDS := ["offense", "defense", "utility"]

var failures: Array[String] = []
var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    _run_mass_matrix()
    _finish()

func _run_mass_matrix() -> void:
    var characters := ContentRegistry.all("characters")
    expect(characters.size() == 36, "10.8 probe requires all 36 characters")
    if characters.size() != 36:
        return

    var combo_stats: Dictionary = {}
    var policy_stats: Dictionary = {}
    var build_stats: Dictionary = {}
    var world_stats: Dictionary = {}
    var character_policy_baseline: Dictionary = {}
    var context_policy: Dictionary = {}
    var context_build: Dictionary = {}
    var total_runs := 0
    var invalid_runs := 0
    var deadlocks := 0
    var stalemates := 0
    var very_long := 0

    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        var world_id := str(character.get("world_id", ""))
        for difficulty_id in DifficultyEngine.ids():
            for policy_id in POLICIES:
                for build_id in BUILDS:
                    var combo_key := "%s|%s|%s|%s" % [character_id, difficulty_id, policy_id, build_id]
                    if not combo_stats.has(combo_key): combo_stats[combo_key] = _empty_stats()
                    var policy_key := "%s|%s" % [difficulty_id, policy_id]
                    if not policy_stats.has(policy_key): policy_stats[policy_key] = _empty_stats()
                    var build_key := "%s|%s" % [difficulty_id, build_id]
                    if not build_stats.has(build_key): build_stats[build_key] = _empty_stats()
                    var world_key := "%s|%s" % [difficulty_id, world_id]
                    if not world_stats.has(world_key): world_stats[world_key] = _empty_stats()
                    for sample_index in range(SEEDS):
                        var seed_value := BASE_SEED + character_index * 1009 + sample_index * 97
                        var result := simulator.simulate({
                            "character_id":character_id,
                            "policy_id":policy_id,
                            "build_id":build_id,
                            "seed":seed_value,
                            "max_steps":MAX_STEPS,
                        }, difficulty_id)
                        total_runs += 1
                        if not bool(result.get("ok", false)):
                            invalid_runs += 1
                            continue
                        deadlocks += int(result.get("deadlocks", 0))
                        stalemates += int(result.get("combat_timeouts", 0))
                        if int(result.get("steps", 0)) > 35: very_long += 1
                        _accumulate(combo_stats[combo_key] as Dictionary, result)
                        _accumulate(policy_stats[policy_key] as Dictionary, result)
                        _accumulate(build_stats[build_key] as Dictionary, result)
                        _accumulate(world_stats[world_key] as Dictionary, result)

                        if difficulty_id == "andarilho" and build_id == "baseline" and policy_id in CONTROLLED_POLICIES:
                            var cp_key := "%s|%s" % [character_id, policy_id]
                            if not character_policy_baseline.has(cp_key): character_policy_baseline[cp_key] = _empty_stats()
                            _accumulate(character_policy_baseline[cp_key] as Dictionary, result)

                        if policy_id in CONTROLLED_POLICIES:
                            var policy_context := "%s|%s|%s" % [character_id, difficulty_id, build_id]
                            if not context_policy.has(policy_context): context_policy[policy_context] = {}
                            var per_policy: Dictionary = context_policy[policy_context] as Dictionary
                            if not per_policy.has(policy_id): per_policy[policy_id] = _empty_stats()
                            _accumulate(per_policy[policy_id] as Dictionary, result)

                        if build_id in EQUIPPED_BUILDS:
                            var build_context := "%s|%s|%s" % [character_id, difficulty_id, policy_id]
                            if not context_build.has(build_context): context_build[build_context] = {}
                            var per_build: Dictionary = context_build[build_context] as Dictionary
                            if not per_build.has(build_id): per_build[build_id] = _empty_stats()
                            _accumulate(per_build[build_id] as Dictionary, result)

    expect(total_runs == 36 * 4 * 5 * 4 * SEEDS, "10.8 run count mismatch: %d" % total_runs)
    print("10.8 massive probe: runs=%d invalid=%d structural_deadlocks=%d combat_stalemates=%d very_long=%d (%.4f)" % [total_runs, invalid_runs, deadlocks, stalemates, very_long, float(very_long) / float(maxi(1,total_runs))])

    _print_policy_aggregates(policy_stats)
    _print_build_aggregates(build_stats)
    _print_character_regret(characters, character_policy_baseline)
    _print_policy_dominance(context_policy)
    _print_build_dominance(context_build)
    _print_world_outliers(world_stats)
    _print_extreme_combos(combo_stats)

func _empty_stats() -> Dictionary:
    return {"runs":0,"victories":0,"boss_reached":0,"boss_wins":0,"score":0.0,"steps":0,"combats":0,"combat_wins":0,"combat_timeouts":0,"deadlocks":0,"final_health":0,"min_health":0,"provisions_spent":0,"fragments_gained":0,"fragments_spent":0}

func _accumulate(row: Dictionary, result: Dictionary) -> void:
    row.runs = int(row.runs) + 1
    if str(result.get("result", "")) == "victory": row.victories = int(row.victories) + 1
    if bool(result.get("boss_reached", false)): row.boss_reached = int(row.boss_reached) + 1
    if bool(result.get("boss_win", false)): row.boss_wins = int(row.boss_wins) + 1
    row.score = float(row.score) + _score(result)
    row.steps = int(row.steps) + int(result.get("steps", 0))
    row.combats = int(row.combats) + int(result.get("combats", 0))
    row.combat_wins = int(row.combat_wins) + int(result.get("combat_wins", 0))
    row.combat_timeouts = int(row.combat_timeouts) + int(result.get("combat_timeouts", 0))
    row.deadlocks = int(row.deadlocks) + int(result.get("deadlocks", 0))
    row.final_health = int(row.final_health) + int(result.get("final_health", 0))
    row.min_health = int(row.min_health) + int(result.get("min_health", 0))
    row.provisions_spent = int(row.provisions_spent) + int(result.get("provisions_spent", 0))
    row.fragments_gained = int(row.fragments_gained) + int(result.get("fragments_gained", 0))
    row.fragments_spent = int(row.fragments_spent) + int(result.get("fragments_spent", 0))

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

func _avg_score(row: Dictionary) -> float:
    return float(row.get("score", 0.0)) / float(maxi(1, int(row.get("runs", 0))))

func _win_rate(row: Dictionary) -> float:
    return float(row.get("victories", 0)) / float(maxi(1, int(row.get("runs", 0))))

func _print_policy_aggregates(stats: Dictionary) -> void:
    for difficulty_id in DifficultyEngine.ids():
        for policy_id in POLICIES:
            var row: Dictionary = stats["%s|%s" % [difficulty_id, policy_id]] as Dictionary
            print("10.8 policy %s/%s: runs=%d victory=%.3f score=%.3f boss=%.3f steps=%.2f stalemate=%.4f" % [difficulty_id,policy_id,int(row.runs),_win_rate(row),_avg_score(row),float(row.boss_reached)/float(maxi(1,int(row.runs))),float(row.steps)/float(maxi(1,int(row.runs))),float(row.combat_timeouts)/float(maxi(1,int(row.runs)))])

func _print_build_aggregates(stats: Dictionary) -> void:
    for difficulty_id in DifficultyEngine.ids():
        for build_id in BUILDS:
            var row: Dictionary = stats["%s|%s" % [difficulty_id, build_id]] as Dictionary
            print("10.8 build %s/%s: runs=%d victory=%.3f score=%.3f boss=%.3f steps=%.2f" % [difficulty_id,build_id,int(row.runs),_win_rate(row),_avg_score(row),float(row.boss_reached)/float(maxi(1,int(row.runs))),float(row.steps)/float(maxi(1,int(row.runs)))])

func _print_character_regret(characters: Array, stats: Dictionary) -> void:
    var rows: Array = []
    for character_variant in characters:
        var character: Dictionary = character_variant as Dictionary
        var character_id := str(character.get("id", ""))
        var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
        var recommended := str(curve.get("recommended_policy", "balanced"))
        var best_policy := ""
        var best_score := -999.0
        var recommended_score := -999.0
        for policy_id in CONTROLLED_POLICIES:
            var row: Dictionary = stats["%s|%s" % [character_id, policy_id]] as Dictionary
            var score := _avg_score(row)
            if policy_id == recommended: recommended_score = score
            if score > best_score:
                best_score = score
                best_policy = policy_id
        rows.append({"name":str(character.get("name",character_id)),"id":character_id,"recommended":recommended,"best":best_policy,"recommended_score":recommended_score,"best_score":best_score,"regret":best_score-recommended_score})
    rows.sort_custom(func(a,b): return float((a as Dictionary).regret) > float((b as Dictionary).regret))
    print("10.8 character policy regret TOP 12 (Andarilho/baseline):")
    for i in range(mini(12, rows.size())):
        var row: Dictionary = rows[i] as Dictionary
        print("10.8 regret %s: recommended=%s %.3f best=%s %.3f delta=%.3f" % [str(row.name),str(row.recommended),float(row.recommended_score),str(row.best),float(row.best_score),float(row.regret)])

func _print_policy_dominance(contexts: Dictionary) -> void:
    var wins := {"balanced":0,"aggressive":0,"cautious":0,"explorer":0}
    var ties := 0
    var contexts_count := 0
    for per_variant in contexts.values():
        var per: Dictionary = per_variant as Dictionary
        var best := -999.0
        var best_ids: Array[String] = []
        for policy_id in CONTROLLED_POLICIES:
            var score := _avg_score(per[policy_id] as Dictionary)
            if score > best + 0.0001:
                best = score
                best_ids = [policy_id]
            elif absf(score-best) <= 0.0001:
                best_ids.append(policy_id)
        contexts_count += 1
        if best_ids.size() == 1: wins[best_ids[0]] = int(wins[best_ids[0]]) + 1
        else: ties += 1
    print("10.8 policy dominance: contexts=%d balanced=%d aggressive=%d cautious=%d explorer=%d ties=%d" % [contexts_count,int(wins.balanced),int(wins.aggressive),int(wins.cautious),int(wins.explorer),ties])

func _print_build_dominance(contexts: Dictionary) -> void:
    var wins := {"offense":0,"defense":0,"utility":0}
    var ties := 0
    var contexts_count := 0
    for per_variant in contexts.values():
        var per: Dictionary = per_variant as Dictionary
        var best := -999.0
        var best_ids: Array[String] = []
        for build_id in EQUIPPED_BUILDS:
            var score := _avg_score(per[build_id] as Dictionary)
            if score > best + 0.0001:
                best = score
                best_ids = [build_id]
            elif absf(score-best) <= 0.0001:
                best_ids.append(build_id)
        contexts_count += 1
        if best_ids.size() == 1: wins[best_ids[0]] = int(wins[best_ids[0]]) + 1
        else: ties += 1
    print("10.8 build dominance: contexts=%d offense=%d defense=%d utility=%d ties=%d" % [contexts_count,int(wins.offense),int(wins.defense),int(wins.utility),ties])

func _print_world_outliers(stats: Dictionary) -> void:
    var rows: Array = []
    for key_variant in stats.keys():
        var key := str(key_variant)
        var parts := key.split("|", false)
        var row: Dictionary = stats[key] as Dictionary
        rows.append({"difficulty":parts[0],"world":parts[1],"steps":float(row.steps)/float(maxi(1,int(row.runs))),"score":_avg_score(row),"victory":_win_rate(row)})
    rows.sort_custom(func(a,b): return float((a as Dictionary).steps) > float((b as Dictionary).steps))
    print("10.8 world longest TOP 8:")
    for i in range(mini(8, rows.size())):
        var row: Dictionary = rows[i] as Dictionary
        print("10.8 world %s/%s: steps=%.2f score=%.3f victory=%.3f" % [str(row.difficulty),str(row.world),float(row.steps),float(row.score),float(row.victory)])

func _print_extreme_combos(stats: Dictionary) -> void:
    var rows: Array = []
    for key_variant in stats.keys():
        var key := str(key_variant)
        var row: Dictionary = stats[key] as Dictionary
        rows.append({"key":key,"score":_avg_score(row),"victory":_win_rate(row),"steps":float(row.steps)/float(maxi(1,int(row.runs))),"stalemate":float(row.combat_timeouts)/float(maxi(1,int(row.runs)))})
    rows.sort_custom(func(a,b): return float((a as Dictionary).score) > float((b as Dictionary).score))
    print("10.8 combo score TOP 10:")
    for i in range(mini(10, rows.size())):
        var row: Dictionary = rows[i] as Dictionary
        print("10.8 combo TOP %s score=%.3f victory=%.3f steps=%.2f stalemate=%.3f" % [str(row.key),float(row.score),float(row.victory),float(row.steps),float(row.stalemate)])
    print("10.8 combo score BOTTOM 10:")
    for i in range(maxi(0, rows.size()-10), rows.size()):
        var row: Dictionary = rows[i] as Dictionary
        print("10.8 combo BOTTOM %s score=%.3f victory=%.3f steps=%.2f stalemate=%.3f" % [str(row.key),float(row.score),float(row.victory),float(row.steps),float(row.stalemate)])

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: MASS_SIMULATION_PROBE: %s" % message)

func _finish() -> void:
    DifficultyEngine.clear_simulation_override()
    if failures.is_empty():
        print("MASS_SIMULATION_PROBE PASS: 10.8 diagnostics")
        get_tree().quit(0)
    else:
        print("MASS_SIMULATION_PROBE FAIL: %d" % failures.size())
        get_tree().quit(1)
