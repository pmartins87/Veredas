extends Node

const SEEDS_PER_CHARACTER := 12
const BASE_SEED := 107000
const MAX_STEPS := 80
const VERY_LONG_STEP := 35

var failures: Array[String] = []
var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    _travel_attrition_gate()
    _matrix_gate()
    _finish()

func _travel_attrition_gate() -> void:
    GameState.reset_profile()
    var character_id := "character.mata_fio_verde.01"
    expect(RunFlowEngine.start_journey(character_id, 107777, "andarilho"), "10.7 could not start attrition probe journey")
    if GameState.run.is_empty():
        return
    var locations: Array = []
    for row_variant in ContentRegistry.all("locations"):
        var row: Dictionary = row_variant as Dictionary
        if str(row.get("world_id", "")) == str(GameState.run.get("world_id", "")):
            locations.append(row)
    locations.sort_custom(func(a,b): return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", "")))
    expect(locations.size() >= 4, "10.7 attrition probe needs four locations in the starting Domain")
    if locations.size() < 4:
        return

    var current := str(GameState.run.get("location_id", ""))
    var targets: Array[String] = []
    for row_variant in locations:
        var location_id := str((row_variant as Dictionary).get("id", ""))
        if location_id != current:
            targets.append(location_id)
    expect(targets.size() >= 3, "10.7 attrition probe could not select three travel targets")
    if targets.size() < 3:
        return

    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    expect(int(resources.get("provisions", -1)) == 3, "Andarilho attrition probe did not start with three Provisões")
    expect(LocationEngine.travel_to(targets[0]), "10.7 first attrition travel failed")
    resources = GameState.run.get("resources", {}) as Dictionary
    expect(int(resources.get("provisions", -1)) == 2, "travel did not consume exactly one Provisão")

    resources.provisions = 0
    GameState.run.resources = resources
    GameState.run.vigor = 2
    expect(LocationEngine.travel_to(targets[1]), "10.7 no-Provisão vigor fallback travel failed")
    expect(int(GameState.run.get("vigor", -1)) == 1, "travel without Provisão did not consume one Vigor")

    GameState.run.vigor = 0
    GameState.run.health = 8
    expect(LocationEngine.travel_to(targets[2]), "10.7 exhausted health fallback travel failed")
    expect(int(GameState.run.get("health", -1)) == 7, "travel without Provisão/Vigor did not consume one nonlethal Vida")

    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["simulation.no_attrition"] = true
    GameState.run.flags = flags
    resources = GameState.run.get("resources", {}) as Dictionary
    resources.provisions = 2
    GameState.run.resources = resources
    var before_provisions := int(resources.provisions)
    expect(LocationEngine.travel_to(current), "10.7 neutral attrition travel failed")
    resources = GameState.run.get("resources", {}) as Dictionary
    expect(int(resources.get("provisions", -1)) == before_provisions, "simulation.no_attrition did not isolate travel attrition")

func _matrix_gate() -> void:
    var characters := ContentRegistry.all("characters")
    expect(characters.size() == 36, "10.7 requires all 36 characters")
    if characters.size() != 36:
        return

    var stats: Dictionary = {}
    var world_stats: Dictionary = {}
    for difficulty_id in DifficultyEngine.ids():
        stats[difficulty_id] = _empty_stats()

    var total_runs := 0
    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        var world_id := str(character.get("world_id", ""))
        var policy := _recommended_policy(character)
        for sample_index in range(SEEDS_PER_CHARACTER):
            var seed_value := BASE_SEED + character_index * 1009 + sample_index * 97
            for difficulty_id in DifficultyEngine.ids():
                var result := simulator.simulate({
                    "character_id":character_id,
                    "policy_id":policy,
                    "build_id":"baseline",
                    "seed":seed_value,
                    "max_steps":MAX_STEPS,
                }, difficulty_id)
                expect(bool(result.get("ok", false)), "%s/%s/%d returned invalid simulation" % [character_id, difficulty_id, seed_value])
                if not bool(result.get("ok", false)):
                    continue
                _validate_result(result)
                _accumulate(stats[difficulty_id] as Dictionary, result)
                var world_key := "%s|%s" % [difficulty_id, world_id]
                if not world_stats.has(world_key):
                    world_stats[world_key] = _empty_stats()
                _accumulate(world_stats[world_key] as Dictionary, result)
                total_runs += 1

    expect(total_runs == 36 * SEEDS_PER_CHARACTER * 4, "10.7 run count mismatch: %d" % total_runs)
    expect(world_stats.size() == 48, "10.7 did not cover 12 Domains across all four modes")
    print("10.7 pacing certification: characters=36 seeds_per_character=%d runs=%d" % [SEEDS_PER_CHARACTER, total_runs])

    for difficulty_id in DifficultyEngine.ids():
        _gate_mode(difficulty_id, stats[difficulty_id] as Dictionary)
        _gate_world_spread(difficulty_id, world_stats)
    _gate_cross_mode_resource_flow(stats)

func _validate_result(result: Dictionary) -> void:
    var label := "%s/%s/%d" % [str(result.get("difficulty_id", "")), str(result.get("character_id", "")), int(result.get("seed", 0))]
    expect(int(result.get("steps", 0)) >= 1 and int(result.get("steps", 0)) <= MAX_STEPS, "%s steps outside horizon" % label)
    expect(int(result.get("combat_rounds", -1)) >= int(result.get("combats", 0)), "%s combat-round telemetry invalid" % label)
    expect(int(result.get("min_health", -1)) >= 0 and int(result.get("min_vigor", -1)) >= 0, "%s health/vigor became negative" % label)
    expect(int(result.get("min_fragments", -1)) >= 0 and int(result.get("min_provisions", -1)) >= 0, "%s economy became negative" % label)
    if bool(result.get("boss_reached", false)):
        expect(int(result.get("boss_step", 0)) > 0 and int(result.get("boss_step", 0)) <= int(result.get("steps", 0)), "%s boss-step telemetry invalid" % label)

func _empty_stats() -> Dictionary:
    return {
        "runs":0,"victories":0,"journey_timeouts":0,"combat_timeouts":0,"deadlocks":0,
        "steps":0,"events":0,"combats":0,"combat_rounds":0,"travel":0,"locations":0,
        "boss_reached":0,"boss_steps":0,"first_combat_count":0,"first_combat_steps":0,
        "very_long":0,"damage":0,"healing":0,"min_health":0,"final_health":0,
        "vigor_spent":0,"vigor_recovered":0,"min_vigor":0,"final_vigor":0,
        "start_fragments":0,"final_fragments":0,"fragment_gained":0,"fragment_spent":0,
        "start_provisions":0,"final_provisions":0,"provision_gained":0,"provision_spent":0,
    }

func _accumulate(row: Dictionary, result: Dictionary) -> void:
    row.runs = int(row.runs) + 1
    if str(result.get("result", "")) == "victory": row.victories = int(row.victories) + 1
    if str(result.get("result", "")) == "timeout": row.journey_timeouts = int(row.journey_timeouts) + 1
    row.combat_timeouts = int(row.combat_timeouts) + int(result.get("combat_timeouts", 0))
    row.deadlocks = int(row.deadlocks) + int(result.get("deadlocks", 0))
    row.steps = int(row.steps) + int(result.get("steps", 0))
    row.events = int(row.events) + int(result.get("events", 0))
    row.combats = int(row.combats) + int(result.get("combats", 0))
    row.combat_rounds = int(row.combat_rounds) + int(result.get("combat_rounds", 0))
    row.travel = int(row.travel) + int(result.get("travel_actions", 0))
    row.locations = int(row.locations) + int(result.get("locations_visited", 0))
    if int(result.get("steps", 0)) > VERY_LONG_STEP: row.very_long = int(row.very_long) + 1
    if bool(result.get("boss_reached", false)):
        row.boss_reached = int(row.boss_reached) + 1
        row.boss_steps = int(row.boss_steps) + int(result.get("boss_step", 0))
    var first_combat := int(result.get("first_combat_step", 0))
    if first_combat > 0:
        row.first_combat_count = int(row.first_combat_count) + 1
        row.first_combat_steps = int(row.first_combat_steps) + first_combat
    row.damage = int(row.damage) + int(result.get("damage_taken", 0))
    row.healing = int(row.healing) + int(result.get("healing_received", 0))
    row.min_health = int(row.min_health) + int(result.get("min_health", 0))
    row.final_health = int(row.final_health) + int(result.get("final_health", 0))
    row.vigor_spent = int(row.vigor_spent) + int(result.get("vigor_spent", 0))
    row.vigor_recovered = int(row.vigor_recovered) + int(result.get("vigor_recovered", 0))
    row.min_vigor = int(row.min_vigor) + int(result.get("min_vigor", 0))
    row.final_vigor = int(row.final_vigor) + int(result.get("final_vigor", 0))
    row.start_fragments = int(row.start_fragments) + int(result.get("start_fragments", 0))
    row.final_fragments = int(row.final_fragments) + int(result.get("final_fragments", 0))
    row.fragment_gained = int(row.fragment_gained) + int(result.get("fragments_gained", 0))
    row.fragment_spent = int(row.fragment_spent) + int(result.get("fragments_spent", 0))
    row.start_provisions = int(row.start_provisions) + int(result.get("start_provisions", 0))
    row.final_provisions = int(row.final_provisions) + int(result.get("final_provisions", 0))
    row.provision_gained = int(row.provision_gained) + int(result.get("provisions_gained", 0))
    row.provision_spent = int(row.provision_spent) + int(result.get("provisions_spent", 0))

func _gate_mode(difficulty_id: String, row: Dictionary) -> void:
    var runs := maxi(1, int(row.runs))
    var combats := maxi(1, int(row.combats))
    var boss_runs := maxi(1, int(row.boss_reached))
    var first_combat_runs := maxi(1, int(row.first_combat_count))
    var avg_steps := float(row.steps) / float(runs)
    var avg_events := float(row.events) / float(runs)
    var avg_combats := float(row.combats) / float(runs)
    var rounds_per_combat := float(row.combat_rounds) / float(combats)
    var avg_boss_step := float(row.boss_steps) / float(boss_runs)
    var avg_first_combat := float(row.first_combat_steps) / float(first_combat_runs)
    var very_long_rate := float(row.very_long) / float(runs)
    var stalemate_rate := float(row.combat_timeouts) / float(runs)
    var provision_spend := float(row.provision_spent) / float(runs)
    var fragment_gain := float(row.fragment_gained) / float(runs)
    var fragment_spend := float(row.fragment_spent) / float(runs)

    expect(int(row.deadlocks) == 0, "%s has structural deadlocks" % difficulty_id)
    expect(float(row.journey_timeouts) / float(runs) <= 0.05, "%s journey timeout rate exceeds 5%%" % difficulty_id)
    expect(stalemate_rate <= 0.01, "%s combat stalemate rate exceeds 1%%" % difficulty_id)
    expect(avg_steps >= 8.0 and avg_steps <= 20.0, "%s average journey length out of 8-20 step band: %.2f" % [difficulty_id, avg_steps])
    expect(avg_events >= 6.0 and avg_events <= 16.0, "%s event cadence out of 6-16 band: %.2f" % [difficulty_id, avg_events])
    var minimum_combats := 1.10 if difficulty_id == "ruptura" else 1.20
    expect(avg_combats >= minimum_combats and avg_combats <= 2.5, "%s combat cadence out of %.2f-2.5 band: %.2f" % [difficulty_id, minimum_combats, avg_combats])
    expect(rounds_per_combat >= 8.0 and rounds_per_combat <= 25.0, "%s rounds/combat out of 8-25 band: %.2f" % [difficulty_id, rounds_per_combat])
    expect(avg_first_combat >= 5.0 and avg_first_combat <= 10.0, "%s first combat cadence out of 5-10 band: %.2f" % [difficulty_id, avg_first_combat])
    expect(avg_boss_step >= 7.0 and avg_boss_step <= 18.0, "%s average boss step out of 7-18 band: %.2f" % [difficulty_id, avg_boss_step])
    expect(very_long_rate <= 0.10, "%s has more than 10%% very-long journeys: %.3f" % [difficulty_id, very_long_rate])
    expect(provision_spend >= 0.20, "%s Provisões remain functionally inert: %.2f spent/run" % [difficulty_id, provision_spend])
    expect(float(row.final_provisions) / float(runs) < float(row.start_provisions) / float(runs), "%s does not consume its starting Provisão buffer" % difficulty_id)
    # High difficulties win fewer fights by design, so absolute income must not
    # be forced to match easier modes. Require a live economy here; the cross-
    # mode gate below verifies the intended monotonic resource-pressure curve.
    expect(fragment_gain >= 0.50 and fragment_spend >= 2.00, "%s Fragment flow is inactive gain=%.2f spend=%.2f" % [difficulty_id, fragment_gain, fragment_spend])
    expect(float(row.damage) / float(runs) >= 8.0, "%s journey attrition is too low to be meaningful" % difficulty_id)

    print("10.7 %s: runs=%d victory=%.3f steps=%.2f events=%.2f combats=%.2f rounds_per_combat=%.2f first_combat=%.2f boss_step=%.2f very_long=%.3f stalemate=%.4f provisions=%.2f->%.2f spent=%.2f fragments_gain/spend=%.2f/%.2f min_hp=%.2f final_hp=%.2f" % [
        difficulty_id,int(row.runs),float(row.victories)/float(runs),avg_steps,avg_events,avg_combats,rounds_per_combat,avg_first_combat,avg_boss_step,very_long_rate,stalemate_rate,
        float(row.start_provisions)/float(runs),float(row.final_provisions)/float(runs),provision_spend,fragment_gain,fragment_spend,float(row.min_health)/float(runs),float(row.final_health)/float(runs)
    ])

func _gate_cross_mode_resource_flow(stats: Dictionary) -> void:
    var gains: Dictionary = {}
    var spends: Dictionary = {}
    for difficulty_id in DifficultyEngine.ids():
        var row: Dictionary = stats[difficulty_id] as Dictionary
        var runs := maxi(1, int(row.runs))
        gains[difficulty_id] = float(row.fragment_gained) / float(runs)
        spends[difficulty_id] = float(row.fragment_spent) / float(runs)

    expect(float(gains.contemplativa) > float(gains.andarilho) and float(gains.andarilho) > float(gains.severa) and float(gains.severa) > float(gains.ruptura), "Fragment income is not strictly monotonic with difficulty: C=%.2f A=%.2f S=%.2f R=%.2f" % [float(gains.contemplativa), float(gains.andarilho), float(gains.severa), float(gains.ruptura)])
    expect(float(spends.contemplativa) > float(spends.andarilho) and float(spends.andarilho) > float(spends.severa) and float(spends.severa) > float(spends.ruptura), "Fragment spending is not strictly monotonic with difficulty: C=%.2f A=%.2f S=%.2f R=%.2f" % [float(spends.contemplativa), float(spends.andarilho), float(spends.severa), float(spends.ruptura)])
    print("10.7 fragment pressure: gain C/A/S/R=%.2f/%.2f/%.2f/%.2f spend=%.2f/%.2f/%.2f/%.2f" % [float(gains.contemplativa),float(gains.andarilho),float(gains.severa),float(gains.ruptura),float(spends.contemplativa),float(spends.andarilho),float(spends.severa),float(spends.ruptura)])

func _gate_world_spread(difficulty_id: String, world_stats: Dictionary) -> void:
    var min_steps := INF
    var max_steps := -INF
    var max_world := ""
    for key_variant in world_stats.keys():
        var key := str(key_variant)
        if not key.begins_with("%s|" % difficulty_id): continue
        var row: Dictionary = world_stats[key] as Dictionary
        var avg_steps := float(row.steps) / float(maxi(1, int(row.runs)))
        min_steps = minf(min_steps, avg_steps)
        if avg_steps > max_steps:
            max_steps = avg_steps
            max_world = key.split("|", false, 1)[1]
    expect(min_steps >= 6.0, "%s has a Domain with implausibly short average journey %.2f" % [difficulty_id, min_steps])
    expect(max_steps <= 26.0, "%s has a Domain with excessive average journey %.2f (%s)" % [difficulty_id, max_steps, max_world])
    print("10.7 %s world pacing spread: %.2f..%.2f max=%s" % [difficulty_id,min_steps,max_steps,max_world])

func _recommended_policy(character: Dictionary) -> String:
    var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
    var policy := str(curve.get("recommended_policy", "balanced"))
    return policy if PlayerPolicyEngine.new().is_valid(policy) else "balanced"

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: JOURNEY_PACING_CERTIFICATION: %s" % message)

func _finish() -> void:
    DifficultyEngine.clear_simulation_override()
    if failures.is_empty():
        print("JOURNEY_PACING_CERTIFICATION PASS: 10.7")
        get_tree().quit(0)
    else:
        print("JOURNEY_PACING_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)
