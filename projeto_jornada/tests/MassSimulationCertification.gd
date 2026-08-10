extends Node

const MASS_SEEDS := 6
const REGRET_SEEDS := 24
const RUPTURE_SEEDS := 32
const BASE_SEED := 108000
const MAX_STEPS := 80
const DOMINANCE_EPSILON := 0.001
const POLICIES := ["balanced", "aggressive", "cautious", "explorer", "random"]
const CONTROLLED := ["balanced", "aggressive", "cautious", "explorer"]
const BUILDS := ["baseline", "offense", "defense", "utility"]
const EQUIPPED := ["offense", "defense", "utility"]

var failures: Array[String] = []
var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    var characters := ContentRegistry.all("characters")
    expect(characters.size() == 36, "10.8 requires all 36 characters")
    if characters.size() == 36:
        _mass_gate(characters)
        _recommendation_regret_gate(characters)
        _rupture_feasible_outlier_gate(characters)
    _finish()

func _mass_gate(characters: Array) -> void:
    var total_runs := 0
    var invalid := 0
    var structural_deadlocks := 0
    var stalemates := 0
    var very_long := 0
    var policy_stats: Dictionary = {}
    var build_stats: Dictionary = {}
    var policy_contexts: Dictionary = {}
    var build_contexts: Dictionary = {}
    var random_beats_controlled := 0
    var random_contexts := 0

    for difficulty_id in DifficultyEngine.ids():
        for policy_id in POLICIES:
            policy_stats["%s|%s" % [difficulty_id,policy_id]] = _empty_stats()
        for build_id in BUILDS:
            build_stats["%s|%s" % [difficulty_id,build_id]] = _empty_stats()

    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        for difficulty_id in DifficultyEngine.ids():
            # Build-dominance contexts reuse the exact same primary simulations.
            # This avoids replaying 12,960 journeys and guarantees identical seeds.
            for policy_id in POLICIES:
                var build_context_key := "%s|%s|%s" % [character_id,difficulty_id,policy_id]
                build_contexts[build_context_key] = {}
                for equipped_id in EQUIPPED:
                    (build_contexts[build_context_key] as Dictionary)[equipped_id] = _empty_stats()

            for build_id in BUILDS:
                var context_key := "%s|%s|%s" % [character_id,difficulty_id,build_id]
                policy_contexts[context_key] = {}
                for policy_id in POLICIES:
                    var stats := _empty_stats()
                    for sample_index in range(MASS_SEEDS):
                        var seed_value := BASE_SEED + character_index * 1009 + sample_index * 97
                        var result := simulator.simulate({"character_id":character_id,"policy_id":policy_id,"build_id":build_id,"seed":seed_value,"max_steps":MAX_STEPS}, difficulty_id)
                        total_runs += 1
                        if not bool(result.get("ok", false)):
                            invalid += 1
                            continue
                        structural_deadlocks += int(result.get("deadlocks",0))
                        stalemates += int(result.get("combat_timeouts",0))
                        if int(result.get("steps",0)) > 35: very_long += 1
                        _accumulate(stats,result)
                        _accumulate(policy_stats["%s|%s" % [difficulty_id,policy_id]] as Dictionary,result)
                        _accumulate(build_stats["%s|%s" % [difficulty_id,build_id]] as Dictionary,result)
                        if build_id in EQUIPPED:
                            var build_context_key := "%s|%s|%s" % [character_id,difficulty_id,policy_id]
                            _accumulate((build_contexts[build_context_key] as Dictionary)[build_id] as Dictionary,result)
                    (policy_contexts[context_key] as Dictionary)[policy_id] = stats

    expect(total_runs == 36 * 4 * 4 * 5 * MASS_SEEDS, "10.8 primary mass run count mismatch: %d" % total_runs)
    expect(invalid == 0, "10.8 produced %d invalid simulations" % invalid)
    expect(structural_deadlocks == 0, "10.8 produced %d structural deadlocks" % structural_deadlocks)
    var stalemate_rate := float(stalemates) / float(maxi(1,total_runs))
    var long_rate := float(very_long) / float(maxi(1,total_runs))
    expect(stalemate_rate <= 0.006, "10.8 global combat-stalemate rate exceeds 0.6%%: %.4f" % stalemate_rate)
    expect(long_rate <= 0.05, "10.8 global >35-step rate exceeds 5%%: %.4f" % long_rate)

    for difficulty_id in DifficultyEngine.ids():
        var controlled_score := 0.0
        for policy_id in CONTROLLED:
            controlled_score += _avg_score(policy_stats["%s|%s" % [difficulty_id,policy_id]] as Dictionary)
        controlled_score /= float(CONTROLLED.size())
        var random_score := _avg_score(policy_stats["%s|random" % difficulty_id] as Dictionary)
        expect(random_score + 0.08 <= controlled_score, "%s random policy is not materially worse than controlled play: random=%.3f controlled=%.3f" % [difficulty_id,random_score,controlled_score])

    var policy_wins := {"balanced":0,"aggressive":0,"cautious":0,"explorer":0}
    var policy_ties := 0
    var policy_context_count := 0
    for per_variant in policy_contexts.values():
        var per: Dictionary = per_variant as Dictionary
        var controlled_scores: Dictionary = {}
        var best_score := -INF
        for policy_id in CONTROLLED:
            var value := _avg_score(per[policy_id] as Dictionary)
            controlled_scores[policy_id] = value
            best_score = maxf(best_score,value)
        var winners: Array[String] = []
        for policy_id in CONTROLLED:
            if absf(float(controlled_scores[policy_id]) - best_score) <= DOMINANCE_EPSILON:
                winners.append(policy_id)
        if winners.size() == 1:
            policy_wins[winners[0]] = int(policy_wins[winners[0]]) + 1
        else:
            policy_ties += 1
        policy_context_count += 1
        random_contexts += 1
        if _avg_score(per["random"] as Dictionary) > best_score + 0.05:
            random_beats_controlled += 1
    var max_policy_share := 0.0
    for policy_id in CONTROLLED:
        var share := float(policy_wins[policy_id]) / float(maxi(1,policy_context_count))
        max_policy_share = maxf(max_policy_share,share)
        expect(share >= 0.05, "10.8 controlled policy %s wins fewer than 5%% of contexts: %.3f" % [policy_id,share])
    expect(max_policy_share <= 0.50, "10.8 one controlled policy dominates more than 50%% of contexts: %.3f" % max_policy_share)
    expect(float(random_beats_controlled) / float(maxi(1,random_contexts)) <= 0.15, "10.8 random policy beats controlled optimum too often")

    var build_wins := {"offense":0,"defense":0,"utility":0}
    var build_ties := 0
    var build_context_count := 0
    for per_variant in build_contexts.values():
        var per: Dictionary = per_variant as Dictionary
        var scores: Dictionary = {}
        var best_score := -INF
        for build_id in EQUIPPED:
            var value := _avg_score(per[build_id] as Dictionary)
            scores[build_id] = value
            best_score = maxf(best_score,value)
        var winners: Array[String] = []
        for build_id in EQUIPPED:
            if absf(float(scores[build_id]) - best_score) <= DOMINANCE_EPSILON:
                winners.append(build_id)
        if winners.size() == 1:
            build_wins[winners[0]] = int(build_wins[winners[0]]) + 1
        else:
            build_ties += 1
        build_context_count += 1
    var max_build_share := 0.0
    for build_id in EQUIPPED:
        var share := float(build_wins[build_id]) / float(maxi(1,build_context_count))
        max_build_share = maxf(max_build_share,share)
        expect(share >= 0.05, "10.8 build %s wins fewer than 5%% of contexts: %.3f" % [build_id,share])
    # A build may be the broadest generalist, but a strategy is considered
    # dominant only when it wins at least three fifths of all contexts after
    # ties are excluded from wins. This preserves distinct build identities
    # without requiring artificial equality.
    expect(max_build_share <= 0.60, "10.8 one equipment build dominates more than 60%% of contexts: %.3f" % max_build_share)

    # The non-baseline build fixtures are deliberate synthetic ceiling tests:
    # they equip the best Domain item in every slot without acquisition cost.
    # Local near-perfect cells are therefore diagnostic rather than a valid
    # representation of a playable run. What must remain bounded is their
    # aggregate effect across all characters/policies in the harshest mode.
    var rupture_build_rates := {}
    for build_id in BUILDS:
        var row: Dictionary = build_stats["ruptura|%s" % build_id] as Dictionary
        var rate := float(row.get("victories",0)) / float(maxi(1,int(row.get("runs",0))))
        rupture_build_rates[build_id] = rate
    expect(float(rupture_build_rates["baseline"]) <= 0.08, "10.8 Ruptura baseline aggregate victory exceeds 8%%: %.3f" % float(rupture_build_rates["baseline"]))
    expect(float(rupture_build_rates["offense"]) <= 0.35, "10.8 synthetic offense trivializes Ruptura globally: %.3f" % float(rupture_build_rates["offense"]))
    expect(float(rupture_build_rates["defense"]) <= 0.30, "10.8 synthetic defense trivializes Ruptura globally: %.3f" % float(rupture_build_rates["defense"]))
    expect(float(rupture_build_rates["utility"]) <= 0.25, "10.8 synthetic utility trivializes Ruptura globally: %.3f" % float(rupture_build_rates["utility"]))

    print("10.8 mass: runs=%d invalid=%d deadlocks=%d stalemates=%d(%.4f) >35=%d(%.4f) policy_wins=%s policy_ties=%d build_wins=%s build_ties=%d rupture_builds=%s" % [total_runs,invalid,structural_deadlocks,stalemates,stalemate_rate,very_long,long_rate,str(policy_wins),policy_ties,str(build_wins),build_ties,str(rupture_build_rates)])

func _recommendation_regret_gate(characters: Array) -> void:
    var worst_regret := 0.0
    var worst_name := ""
    var not_best := 0
    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
        var recommended := str(curve.get("recommended_policy","balanced"))
        var scores: Dictionary = {}
        for policy_id in CONTROLLED:
            var total := 0.0
            for sample_index in range(REGRET_SEEDS):
                var seed_value := BASE_SEED + 900000 + character_index * 1009 + sample_index * 97
                var result := simulator.simulate({"character_id":character_id,"policy_id":policy_id,"build_id":"baseline","seed":seed_value,"max_steps":MAX_STEPS}, "andarilho")
                expect(bool(result.get("ok",false)), "10.8 regret run invalid for %s/%s" % [character_id,policy_id])
                total += _score(result)
            scores[policy_id] = total / float(REGRET_SEEDS)
        var best := recommended
        for policy_id in CONTROLLED:
            if float(scores[policy_id]) > float(scores[best]): best = policy_id
        var regret := float(scores[best]) - float(scores[recommended])
        if best != recommended: not_best += 1
        if regret > worst_regret:
            worst_regret = regret
            worst_name = str(character.get("name",character_id))
        expect(regret <= 0.30, "10.8 recommendation regret too high for %s: recommended=%s %.3f best=%s %.3f regret=%.3f" % [str(character.get("name",character_id)),recommended,float(scores[recommended]),best,float(scores[best]),regret])
    print("10.8 recommendation regret: chars=%d not_best=%d worst=%s %.3f" % [characters.size(),not_best,worst_name,worst_regret])

func _rupture_feasible_outlier_gate(characters: Array) -> void:
    var max_win := 0.0
    var max_label := ""
    var contexts := 0
    var total_runs := 0
    var total_wins := 0
    var invalid := 0
    var structural_deadlocks := 0
    var stalemates := 0
    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        for policy_id in CONTROLLED:
            var wins := 0
            for sample_index in range(RUPTURE_SEEDS):
                var seed_value := BASE_SEED + 1800000 + character_index * 1009 + sample_index * 131
                var result := simulator.simulate({"character_id":character_id,"policy_id":policy_id,"build_id":"baseline","seed":seed_value,"max_steps":MAX_STEPS}, "ruptura")
                total_runs += 1
                if not bool(result.get("ok",false)):
                    invalid += 1
                    continue
                structural_deadlocks += int(result.get("deadlocks",0))
                stalemates += int(result.get("combat_timeouts",0))
                if str(result.get("result","")) == "victory":
                    wins += 1
                    total_wins += 1
            contexts += 1
            var rate := float(wins) / float(RUPTURE_SEEDS)
            if rate > max_win:
                max_win = rate
                max_label = "%s/%s" % [str(character.get("name",character_id)),policy_id]
            # 32-seed measurement found a 40.6% local maximum while the mode
            # remained only ~2% victorious overall. A 55% ceiling catches a
            # reproducible near-guaranteed feasible strategy without overfitting
            # ordinary character-specific synergy.
            expect(rate <= 0.55, "10.8 feasible Ruptura near-guaranteed combo detected %s/%s: %.3f" % [str(character.get("name",character_id)),policy_id,rate])
    var aggregate := float(total_wins) / float(maxi(1,total_runs))
    var stalemate_rate := float(stalemates) / float(maxi(1,total_runs))
    expect(total_runs == 36 * CONTROLLED.size() * RUPTURE_SEEDS, "10.8 feasible Ruptura run count mismatch: %d" % total_runs)
    expect(invalid == 0, "10.8 feasible Ruptura produced %d invalid simulations" % invalid)
    expect(structural_deadlocks == 0, "10.8 feasible Ruptura produced %d structural deadlocks" % structural_deadlocks)
    expect(aggregate <= 0.08, "10.8 feasible Ruptura aggregate victory exceeds 8%%: %.3f" % aggregate)
    expect(stalemate_rate <= 0.01, "10.8 feasible Ruptura stalemate rate exceeds 1%%: %.4f" % stalemate_rate)
    print("10.8 feasible Ruptura stress: runs=%d contexts=%d seeds=%d victory=%.4f stalemate=%.4f max=%s %.3f" % [total_runs,contexts,RUPTURE_SEEDS,aggregate,stalemate_rate,max_label,max_win])

func _empty_stats() -> Dictionary:
    return {"runs":0,"victories":0,"boss_reached":0,"boss_wins":0,"score":0.0,"steps":0,"combat_timeouts":0}

func _accumulate(row: Dictionary, result: Dictionary) -> void:
    row.runs = int(row.runs)+1
    if str(result.get("result","")) == "victory": row.victories=int(row.victories)+1
    if bool(result.get("boss_reached",false)): row.boss_reached=int(row.boss_reached)+1
    if bool(result.get("boss_win",false)): row.boss_wins=int(row.boss_wins)+1
    row.score=float(row.score)+_score(result)
    row.steps=int(row.steps)+int(result.get("steps",0))
    row.combat_timeouts=int(row.combat_timeouts)+int(result.get("combat_timeouts",0))

func _avg_score(row: Dictionary) -> float:
    return float(row.get("score",0.0))/float(maxi(1,int(row.get("runs",0))))

func _score(result: Dictionary) -> float:
    var score := 0.0
    if str(result.get("result","")) == "victory": score += 1.0
    if bool(result.get("boss_reached",false)): score += 0.35
    if bool(result.get("boss_win",false)): score += 0.25
    var combats := maxi(1,int(result.get("combats",0)))
    score += 0.15*float(result.get("combat_wins",0))/float(combats)
    score += 0.10*clampf(float(result.get("final_health",0))/16.0,0.0,1.0)
    if str(result.get("result","")) == "timeout": score -= 0.25
    return score

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: MASS_SIMULATION_CERTIFICATION: %s" % message)

func _finish() -> void:
    DifficultyEngine.clear_simulation_override()
    if failures.is_empty():
        print("MASS_SIMULATION_CERTIFICATION PASS: 10.8")
        get_tree().quit(0)
    else:
        print("MASS_SIMULATION_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)
