extends Node

const SEEDS_PER_CHARACTER := 12
const BASE_SEED := 106000
const MAX_STEPS := 80

var failures: Array[String] = []
var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    _structural_gate()
    _explicit_setup_gate()
    _determinism_gate()
    _paired_matrix_gate()
    _finish()

func _structural_gate() -> void:
    var expected := ["contemplativa", "andarilho", "severa", "ruptura"]
    expect(DifficultyEngine.ids() == expected, "10.6 requires exactly four ordered difficulty modes")
    for difficulty_id in expected:
        expect(JourneySetupEngine.DIFFICULTIES.has(difficulty_id), "setup is missing difficulty %s" % difficulty_id)
        expect(DifficultyEngine.PROFILES.has(difficulty_id), "runtime is missing difficulty %s" % difficulty_id)

    var contemplativa := DifficultyEngine.profile("contemplativa")
    var andarilho := DifficultyEngine.profile("andarilho")
    var severa := DifficultyEngine.profile("severa")
    var ruptura := DifficultyEngine.profile("ruptura")

    expect(is_equal_approx(float(andarilho.enemy_health), 1.0), "Andarilho health multiplier must preserve the certified baseline")
    expect(is_equal_approx(float(andarilho.enemy_posture), 1.0), "Andarilho posture multiplier must preserve the certified baseline")
    expect(is_equal_approx(float(andarilho.enemy_damage), 1.0), "Andarilho damage multiplier must preserve the certified baseline")
    expect(int(andarilho.start_fragments) == 12 and int(andarilho.start_provisions) == 3, "Andarilho starting economy must preserve the certified baseline")

    expect(float(contemplativa.enemy_health) < 1.0 and float(contemplativa.enemy_posture) < 1.0 and float(contemplativa.enemy_damage) < 1.0, "Contemplativa is not mechanically easier than Andarilho")
    expect(float(severa.enemy_health) > 1.0 and float(severa.enemy_posture) > 1.0 and float(severa.enemy_damage) > 1.0, "Severa is not mechanically harder than Andarilho")
    expect(float(ruptura.enemy_health) > float(severa.enemy_health), "Ruptura health pressure must exceed Severa")
    expect(float(ruptura.enemy_posture) > float(severa.enemy_posture), "Ruptura posture pressure must exceed Severa")
    expect(float(ruptura.enemy_damage) > float(severa.enemy_damage), "Ruptura damage pressure must exceed Severa")
    expect(int(contemplativa.start_fragments) > int(andarilho.start_fragments) and int(andarilho.start_fragments) > int(severa.start_fragments) and int(severa.start_fragments) > int(ruptura.start_fragments), "starting fragments are not monotonic")
    expect(int(contemplativa.start_provisions) > int(andarilho.start_provisions) and int(andarilho.start_provisions) > int(severa.start_provisions) and int(severa.start_provisions) > int(ruptura.start_provisions), "starting provisions are not monotonic")

func _explicit_setup_gate() -> void:
    GameState.reset_profile()
    var setup_engine := JourneySetupEngine.new()
    var setup := setup_engine.default_setup()
    setup.difficulty_id = "ruptura"
    setup.seed = 106123
    var validation := setup_engine.validate(setup)
    expect(bool(validation.get("ok", false)), "10.6 explicit Ruptura setup is rejected: %s" % str(validation.get("errors", [])))
    if not bool(validation.get("ok", false)):
        return
    expect(setup_engine.start(setup), "10.6 explicit Ruptura setup could not start")
    if GameState.run.is_empty():
        expect(false, "10.6 setup start produced no run state")
        return
    expect(str(GameState.run.get("difficulty_id", "")) == "ruptura", "selected difficulty did not persist into the run")
    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    expect(int(resources.get("fragments", -1)) == 8, "Ruptura starting fragments were not applied through setup")
    expect(int(resources.get("provisions", -1)) == 1, "Ruptura starting provisions were not applied through setup")

    var monsters := RunFlowEngine.local_monsters()
    expect(not monsters.is_empty(), "10.6 explicit setup location has no combat probe")
    if monsters.is_empty():
        return
    var enemy_record: Dictionary = monsters[0] as Dictionary
    var combat := CombatEngine.start(str(enemy_record.get("id", "")), str(GameState.run.get("character_id", "")))
    var enemy: Dictionary = combat.get("enemy", {}) as Dictionary
    expect(str(combat.get("difficulty_id", "")) == "ruptura", "combat did not inherit the run difficulty")
    expect(int(enemy.get("max_hp", 0)) == DifficultyEngine.scale_enemy_health(int(enemy_record.get("hp", 12)), "ruptura"), "combat HP scaling is not wired to Ruptura")
    expect(int(enemy.get("max_posture", 0)) == DifficultyEngine.scale_enemy_posture(int(enemy_record.get("posture", 8)), "ruptura"), "combat posture scaling is not wired to Ruptura")

func _determinism_gate() -> void:
    var characters := ContentRegistry.all("characters")
    expect(not characters.is_empty(), "difficulty determinism probe has no characters")
    if characters.is_empty():
        return
    var character: Dictionary = characters[0] as Dictionary
    var policy := _recommended_policy(character)
    var config := {
        "character_id":str(character.get("id", "")),
        "policy_id":policy,
        "build_id":"baseline",
        "seed":106777,
        "max_steps":MAX_STEPS,
    }
    for difficulty_id in DifficultyEngine.ids():
        var a := simulator.simulate(config, difficulty_id)
        var b := simulator.simulate(config, difficulty_id)
        expect(bool(a.get("ok", false)) and bool(b.get("ok", false)), "%s deterministic probe returned invalid run" % difficulty_id)
        expect(str(a.get("trajectory_hash", "")) == str(b.get("trajectory_hash", "")), "%s is not deterministic for identical seed/config" % difficulty_id)

func _paired_matrix_gate() -> void:
    var characters := ContentRegistry.all("characters")
    expect(characters.size() == 36, "10.6 requires all 36 characters")
    if characters.size() != 36:
        return

    var stats: Dictionary = {}
    for difficulty_id in DifficultyEngine.ids():
        stats[difficulty_id] = _empty_stats()
    var adjacent := {
        "contemplativa>andarilho":{"not_worse":0,"strict":0,"pairs":0},
        "andarilho>severa":{"not_worse":0,"strict":0,"pairs":0},
        "severa>ruptura":{"not_worse":0,"strict":0,"pairs":0},
    }
    var worlds: Dictionary = {}
    var total_runs := 0

    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        var policy := _recommended_policy(character)
        worlds[str(character.get("world_id", ""))] = true
        for sample_index in range(SEEDS_PER_CHARACTER):
            var seed_value := BASE_SEED + character_index * 1009 + sample_index * 97
            var paired := simulator.simulate_paired({
                "character_id":character_id,
                "policy_id":policy,
                "build_id":"baseline",
                "seed":seed_value,
                "max_steps":MAX_STEPS,
            })
            expect(paired.size() == 4, "%s seed %d did not return four paired modes" % [character_id, seed_value])
            if paired.size() != 4:
                continue
            var scores: Dictionary = {}
            for result_variant in paired:
                var result: Dictionary = result_variant as Dictionary
                var difficulty_id := str(result.get("difficulty_id", ""))
                expect(bool(result.get("ok", false)), "%s seed %d %s returned invalid simulation" % [character_id, seed_value, difficulty_id])
                if not bool(result.get("ok", false)):
                    continue
                _accumulate(stats[difficulty_id] as Dictionary, result)
                scores[difficulty_id] = _journey_score(result)
                total_runs += 1
            _pair(adjacent["contemplativa>andarilho"] as Dictionary, float(scores.get("contemplativa", -99.0)), float(scores.get("andarilho", 99.0)))
            _pair(adjacent["andarilho>severa"] as Dictionary, float(scores.get("andarilho", -99.0)), float(scores.get("severa", 99.0)))
            _pair(adjacent["severa>ruptura"] as Dictionary, float(scores.get("severa", -99.0)), float(scores.get("ruptura", 99.0)))

    expect(worlds.size() == 12, "10.6 matrix did not cover all 12 Domains")
    expect(total_runs == 36 * SEEDS_PER_CHARACTER * 4, "10.6 matrix run count mismatch: %d" % total_runs)

    var metrics: Dictionary = {}
    print("10.6 difficulty certification: characters=36 seeds_per_character=%d runs=%d" % [SEEDS_PER_CHARACTER, total_runs])
    for difficulty_id in DifficultyEngine.ids():
        var row: Dictionary = stats[difficulty_id] as Dictionary
        var runs := maxi(1, int(row.runs))
        metrics[difficulty_id] = {
            "victory":float(row.victories) / float(runs),
            "boss_reach":float(row.boss_reached) / float(runs),
            "boss_win":float(row.boss_wins) / float(runs),
            "timeout":float(row.timeouts) / float(runs),
            "score":float(row.score_total) / float(runs),
            "combat_win":float(row.combat_wins) / float(maxi(1, int(row.combats))),
            "final_hp":float(row.final_health) / float(runs),
            "purchases":float(row.purchases) / float(runs),
        }
        var m: Dictionary = metrics[difficulty_id] as Dictionary
        expect(int(row.deadlocks) == 0, "%s produced %d simulation deadlocks" % [difficulty_id, int(row.deadlocks)])
        expect(float(m.timeout) <= 0.05, "%s timeout rate exceeds 5%%: %.3f" % [difficulty_id, float(m.timeout)])
        print("10.6 %s: runs=%d victory=%.3f boss_reach=%.3f boss_win=%.3f timeout=%.3f score=%.3f combat_win=%.3f final_hp=%.2f purchases=%.2f" % [
            difficulty_id, int(row.runs), float(m.victory), float(m.boss_reach), float(m.boss_win), float(m.timeout), float(m.score), float(m.combat_win), float(m.final_hp), float(m.purchases)
        ])

    var c: Dictionary = metrics["contemplativa"] as Dictionary
    var a: Dictionary = metrics["andarilho"] as Dictionary
    var s: Dictionary = metrics["severa"] as Dictionary
    var r: Dictionary = metrics["ruptura"] as Dictionary

    # Broad absolute envelopes prevent a nominally ordered curve that is either
    # trivial everywhere or effectively impossible everywhere. Relative gates
    # below do the real separation work and are intentionally more important.
    expect(float(c.victory) >= 0.35 and float(c.victory) <= 0.65, "Contemplativa victory rate is outside the accessible-but-nontrivial envelope")
    expect(float(a.victory) >= 0.12 and float(a.victory) <= 0.30, "Andarilho no longer resembles the certified baseline envelope")
    expect(float(s.victory) >= 0.06 and float(s.victory) <= 0.20, "Severa victory rate is outside its calibrated envelope")
    expect(float(r.victory) >= 0.01 and float(r.victory) <= 0.10, "Ruptura must remain possible but distinctly unforgiving")

    expect(float(c.victory) >= float(a.victory) + 0.15, "Contemplativa is not sufficiently separated from Andarilho")
    expect(float(a.victory) >= float(s.victory) + 0.04, "Andarilho is not sufficiently separated from Severa")
    expect(float(s.victory) >= float(r.victory) + 0.04, "Severa is not sufficiently separated from Ruptura")

    expect(float(c.score) >= float(a.score) + 0.08, "Contemplativa score is not separated from Andarilho")
    expect(float(a.score) >= float(s.score) + 0.08, "Andarilho score is not separated from Severa")
    expect(float(s.score) >= float(r.score) + 0.08, "Severa score is not separated from Ruptura")

    expect(float(c.combat_win) > float(a.combat_win) and float(a.combat_win) > float(s.combat_win) and float(s.combat_win) > float(r.combat_win), "combat success is not strictly monotonic across difficulty")
    expect(float(c.boss_reach) >= float(a.boss_reach) and float(a.boss_reach) >= float(s.boss_reach) and float(s.boss_reach) >= float(r.boss_reach), "boss reach is not monotonic across difficulty")

    for label in adjacent:
        var row: Dictionary = adjacent[label] as Dictionary
        var pairs := maxi(1, int(row.pairs))
        var not_worse := float(row.not_worse) / float(pairs)
        var strict := float(row.strict) / float(pairs)
        expect(not_worse >= 0.90, "%s paired not-worse rate below 90%%: %.3f" % [label, not_worse])
        expect(strict >= 0.10, "%s has too few materially separated paired outcomes: %.3f" % [label, strict])
        print("10.6 paired %s: not_worse=%.3f strict=%.3f pairs=%d" % [label, not_worse, strict, int(row.pairs)])

func _empty_stats() -> Dictionary:
    return {
        "runs":0,
        "victories":0,
        "boss_reached":0,
        "boss_wins":0,
        "timeouts":0,
        "score_total":0.0,
        "combats":0,
        "combat_wins":0,
        "final_health":0,
        "purchases":0,
        "deadlocks":0,
    }

func _accumulate(row: Dictionary, result: Dictionary) -> void:
    row.runs = int(row.runs) + 1
    if str(result.get("result", "")) == "victory":
        row.victories = int(row.victories) + 1
    if bool(result.get("boss_reached", false)):
        row.boss_reached = int(row.boss_reached) + 1
    if bool(result.get("boss_win", false)):
        row.boss_wins = int(row.boss_wins) + 1
    if str(result.get("result", "")) == "timeout":
        row.timeouts = int(row.timeouts) + 1
    row.score_total = float(row.score_total) + _journey_score(result)
    row.combats = int(row.combats) + int(result.get("combats", 0))
    row.combat_wins = int(row.combat_wins) + int(result.get("combat_wins", 0))
    row.final_health = int(row.final_health) + int(result.get("final_health", 0))
    row.purchases = int(row.purchases) + int(result.get("purchases", 0))
    row.deadlocks = int(row.deadlocks) + int(result.get("deadlocks", 0))

func _journey_score(result: Dictionary) -> float:
    var score := 0.0
    if str(result.get("result", "")) == "victory":
        score += 1.0
    if bool(result.get("boss_reached", false)):
        score += 0.35
    if bool(result.get("boss_win", false)):
        score += 0.25
    var combats := maxi(1, int(result.get("combats", 0)))
    score += 0.15 * float(result.get("combat_wins", 0)) / float(combats)
    score += 0.10 * clampf(float(result.get("final_health", 0)) / 16.0, 0.0, 1.0)
    if str(result.get("result", "")) == "timeout":
        score -= 0.25
    return score

func _pair(row: Dictionary, easier: float, harder: float) -> void:
    if easier < -10.0 or harder > 10.0:
        return
    row.pairs = int(row.pairs) + 1
    if easier + 0.01 >= harder:
        row.not_worse = int(row.not_worse) + 1
    if easier > harder + 0.05:
        row.strict = int(row.strict) + 1

func _recommended_policy(character: Dictionary) -> String:
    var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
    var policy := str(curve.get("recommended_policy", "balanced"))
    return policy if PlayerPolicyEngine.new().is_valid(policy) else "balanced"

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: DIFFICULTY_BALANCE_CERTIFICATION: %s" % message)

func _finish() -> void:
    DifficultyEngine.clear_simulation_override()
    if failures.is_empty():
        print("DIFFICULTY_BALANCE_CERTIFICATION PASS: 10.6")
        get_tree().quit(0)
    else:
        print("DIFFICULTY_BALANCE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)
