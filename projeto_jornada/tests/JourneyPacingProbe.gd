extends Node

const SEEDS_PER_CHARACTER := 8
const BASE_SEED := 107000
const MAX_STEPS := 80

var failures: Array[String] = []
var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    _run_matrix()
    _finish()

func _run_matrix() -> void:
    var characters := ContentRegistry.all("characters")
    expect(characters.size() == 36, "10.7 probe requires all 36 characters")
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
                expect(bool(result.get("ok", false)), "%s seed %d %s returned invalid simulation" % [character_id, seed_value, difficulty_id])
                if not bool(result.get("ok", false)):
                    continue
                _validate_result(result)
                _accumulate(stats[difficulty_id] as Dictionary, result)
                var world_key := "%s|%s" % [difficulty_id, world_id]
                if not world_stats.has(world_key):
                    world_stats[world_key] = _empty_stats()
                _accumulate(world_stats[world_key] as Dictionary, result)
                total_runs += 1

    expect(total_runs == 36 * SEEDS_PER_CHARACTER * 4, "10.7 probe run count mismatch: %d" % total_runs)
    expect(world_stats.size() == 48, "10.7 probe did not cover 12 Domains across all four modes")
    print("10.7 pacing probe: characters=36 seeds_per_character=%d runs=%d" % [SEEDS_PER_CHARACTER, total_runs])

    for difficulty_id in DifficultyEngine.ids():
        _print_mode(difficulty_id, stats[difficulty_id] as Dictionary)
        _print_world_spread(difficulty_id, world_stats)

func _validate_result(result: Dictionary) -> void:
    var label := "%s/%s/%d" % [str(result.get("difficulty_id", "")), str(result.get("character_id", "")), int(result.get("seed", 0))]
    expect(int(result.get("steps", 0)) >= 1 and int(result.get("steps", 0)) <= MAX_STEPS, "%s steps outside horizon" % label)
    expect(int(result.get("combat_rounds", -1)) >= int(result.get("combats", 0)), "%s combat round telemetry is invalid" % label)
    expect(int(result.get("min_health", -1)) >= 0, "%s minimum health went negative" % label)
    expect(int(result.get("min_vigor", -1)) >= 0, "%s minimum vigor went negative" % label)
    expect(int(result.get("min_fragments", -1)) >= 0, "%s fragments went negative" % label)
    expect(int(result.get("min_provisions", -1)) >= 0, "%s provisions went negative" % label)
    expect(int(result.get("damage_taken", -1)) >= 0 and int(result.get("healing_received", -1)) >= 0, "%s health attrition telemetry is invalid" % label)
    expect(int(result.get("vigor_spent", -1)) >= 0 and int(result.get("vigor_recovered", -1)) >= 0, "%s vigor attrition telemetry is invalid" % label)
    expect(int(result.get("fragments_spent", -1)) >= 0 and int(result.get("fragments_gained", -1)) >= 0, "%s fragment telemetry is invalid" % label)
    expect(int(result.get("provisions_spent", -1)) >= 0 and int(result.get("provisions_gained", -1)) >= 0, "%s provision telemetry is invalid" % label)
    if bool(result.get("boss_reached", false)):
        expect(int(result.get("boss_step", 0)) > 0 and int(result.get("boss_step", 0)) <= int(result.get("steps", 0)), "%s boss step telemetry is invalid" % label)

func _empty_stats() -> Dictionary:
    return {
        "runs":0,
        "victories":0,
        "defeats":0,
        "journey_timeouts":0,
        "combat_timeouts":0,
        "deadlocks":0,
        "steps":0,
        "turns":0,
        "events":0,
        "combats":0,
        "combat_rounds":0,
        "locations":0,
        "travel":0,
        "purchases":0,
        "loot":0,
        "boss_reached":0,
        "boss_steps":0,
        "boss_step_min":999,
        "boss_step_max":0,
        "first_combat_steps":0,
        "first_combat_count":0,
        "first_purchase_steps":0,
        "first_purchase_count":0,
        "first_loot_steps":0,
        "first_loot_count":0,
        "min_health":0,
        "final_health":0,
        "damage":0,
        "healing":0,
        "min_vigor":0,
        "final_vigor":0,
        "vigor_spent":0,
        "vigor_recovered":0,
        "start_fragments":0,
        "final_fragments":0,
        "fragment_spent":0,
        "fragment_gained":0,
        "start_provisions":0,
        "final_provisions":0,
        "provision_spent":0,
        "provision_gained":0,
        "short_runs":0,
        "medium_runs":0,
        "long_runs":0,
        "very_long_runs":0,
    }

func _accumulate(row: Dictionary, result: Dictionary) -> void:
    row.runs = int(row.runs) + 1
    var outcome := str(result.get("result", ""))
    if outcome == "victory":
        row.victories = int(row.victories) + 1
    elif outcome == "timeout":
        row.journey_timeouts = int(row.journey_timeouts) + 1
    else:
        row.defeats = int(row.defeats) + 1
    row.combat_timeouts = int(row.combat_timeouts) + int(result.get("combat_timeouts", 0))
    row.deadlocks = int(row.deadlocks) + int(result.get("deadlocks", 0))
    row.steps = int(row.steps) + int(result.get("steps", 0))
    row.turns = int(row.turns) + int(result.get("turns", 0))
    row.events = int(row.events) + int(result.get("events", 0))
    row.combats = int(row.combats) + int(result.get("combats", 0))
    row.combat_rounds = int(row.combat_rounds) + int(result.get("combat_rounds", 0))
    row.locations = int(row.locations) + int(result.get("locations_visited", 0))
    row.travel = int(row.travel) + int(result.get("travel_actions", 0))
    row.purchases = int(row.purchases) + int(result.get("purchases", 0))
    row.loot = int(row.loot) + int(result.get("loot_drops", 0))

    if bool(result.get("boss_reached", false)):
        var boss_step := int(result.get("boss_step", 0))
        row.boss_reached = int(row.boss_reached) + 1
        row.boss_steps = int(row.boss_steps) + boss_step
        row.boss_step_min = mini(int(row.boss_step_min), boss_step)
        row.boss_step_max = maxi(int(row.boss_step_max), boss_step)

    var first_combat := int(result.get("first_combat_step", 0))
    if first_combat > 0:
        row.first_combat_count = int(row.first_combat_count) + 1
        row.first_combat_steps = int(row.first_combat_steps) + first_combat
    var first_purchase := int(result.get("first_purchase_step", 0))
    if first_purchase > 0:
        row.first_purchase_count = int(row.first_purchase_count) + 1
        row.first_purchase_steps = int(row.first_purchase_steps) + first_purchase
    var first_loot := int(result.get("first_loot_step", 0))
    if first_loot > 0:
        row.first_loot_count = int(row.first_loot_count) + 1
        row.first_loot_steps = int(row.first_loot_steps) + first_loot

    row.min_health = int(row.min_health) + int(result.get("min_health", 0))
    row.final_health = int(row.final_health) + int(result.get("final_health", 0))
    row.damage = int(row.damage) + int(result.get("damage_taken", 0))
    row.healing = int(row.healing) + int(result.get("healing_received", 0))
    row.min_vigor = int(row.min_vigor) + int(result.get("min_vigor", 0))
    row.final_vigor = int(row.final_vigor) + int(result.get("final_vigor", 0))
    row.vigor_spent = int(row.vigor_spent) + int(result.get("vigor_spent", 0))
    row.vigor_recovered = int(row.vigor_recovered) + int(result.get("vigor_recovered", 0))
    row.start_fragments = int(row.start_fragments) + int(result.get("start_fragments", 0))
    row.final_fragments = int(row.final_fragments) + int(result.get("final_fragments", 0))
    row.fragment_spent = int(row.fragment_spent) + int(result.get("fragments_spent", 0))
    row.fragment_gained = int(row.fragment_gained) + int(result.get("fragments_gained", 0))
    row.start_provisions = int(row.start_provisions) + int(result.get("start_provisions", 0))
    row.final_provisions = int(row.final_provisions) + int(result.get("final_provisions", 0))
    row.provision_spent = int(row.provision_spent) + int(result.get("provisions_spent", 0))
    row.provision_gained = int(row.provision_gained) + int(result.get("provisions_gained", 0))

    var steps := int(result.get("steps", 0))
    if steps <= 10:
        row.short_runs = int(row.short_runs) + 1
    elif steps <= 20:
        row.medium_runs = int(row.medium_runs) + 1
    elif steps <= 35:
        row.long_runs = int(row.long_runs) + 1
    else:
        row.very_long_runs = int(row.very_long_runs) + 1

func _print_mode(difficulty_id: String, row: Dictionary) -> void:
    var runs := maxi(1, int(row.runs))
    var boss_count := maxi(1, int(row.boss_reached))
    var combat_count := maxi(1, int(row.combats))
    print("10.7 %s pacing: runs=%d victory=%.3f timeout=%.3f steps=%.2f turns=%.2f events=%.2f combats=%.2f combat_rounds=%.2f rounds_per_combat=%.2f locations=%.2f travel=%.2f boss_reach=%.3f boss_step=%.2f boss_step_range=%d-%d" % [
        difficulty_id,
        int(row.runs),
        float(row.victories) / float(runs),
        float(row.journey_timeouts) / float(runs),
        float(row.steps) / float(runs),
        float(row.turns) / float(runs),
        float(row.events) / float(runs),
        float(row.combats) / float(runs),
        float(row.combat_rounds) / float(runs),
        float(row.combat_rounds) / float(combat_count),
        float(row.locations) / float(runs),
        float(row.travel) / float(runs),
        float(row.boss_reached) / float(runs),
        float(row.boss_steps) / float(boss_count),
        0 if int(row.boss_reached) == 0 else int(row.boss_step_min),
        int(row.boss_step_max),
    ])
    print("10.7 %s cadence: first_combat=%.2f(%d) first_purchase=%.2f(%d) first_loot=%.2f(%d) purchases=%.2f loot=%.2f buckets<=10/<=20/<=35/>35=%d/%d/%d/%d" % [
        difficulty_id,
        float(row.first_combat_steps) / float(maxi(1, int(row.first_combat_count))), int(row.first_combat_count),
        float(row.first_purchase_steps) / float(maxi(1, int(row.first_purchase_count))), int(row.first_purchase_count),
        float(row.first_loot_steps) / float(maxi(1, int(row.first_loot_count))), int(row.first_loot_count),
        float(row.purchases) / float(runs), float(row.loot) / float(runs),
        int(row.short_runs), int(row.medium_runs), int(row.long_runs), int(row.very_long_runs),
    ])
    print("10.7 %s attrition: min_hp=%.2f final_hp=%.2f damage=%.2f healing=%.2f min_vigor=%.2f final_vigor=%.2f vigor_spent=%.2f vigor_recovered=%.2f combat_stalemate=%.4f deadlocks=%d" % [
        difficulty_id,
        float(row.min_health) / float(runs), float(row.final_health) / float(runs),
        float(row.damage) / float(runs), float(row.healing) / float(runs),
        float(row.min_vigor) / float(runs), float(row.final_vigor) / float(runs),
        float(row.vigor_spent) / float(runs), float(row.vigor_recovered) / float(runs),
        float(row.combat_timeouts) / float(runs), int(row.deadlocks),
    ])
    print("10.7 %s economy: fragments start/final/gained/spent=%.2f/%.2f/%.2f/%.2f provisions start/final/gained/spent=%.2f/%.2f/%.2f/%.2f" % [
        difficulty_id,
        float(row.start_fragments) / float(runs), float(row.final_fragments) / float(runs), float(row.fragment_gained) / float(runs), float(row.fragment_spent) / float(runs),
        float(row.start_provisions) / float(runs), float(row.final_provisions) / float(runs), float(row.provision_gained) / float(runs), float(row.provision_spent) / float(runs),
    ])

func _print_world_spread(difficulty_id: String, world_stats: Dictionary) -> void:
    var min_steps := INF
    var max_steps := -INF
    var min_boss := INF
    var max_boss := -INF
    var min_steps_world := ""
    var max_steps_world := ""
    var min_boss_world := ""
    var max_boss_world := ""
    for key_variant in world_stats.keys():
        var key := str(key_variant)
        if not key.begins_with("%s|" % difficulty_id):
            continue
        var world_id := key.split("|", false, 1)[1]
        var row: Dictionary = world_stats[key] as Dictionary
        var runs := maxi(1, int(row.runs))
        var avg_steps := float(row.steps) / float(runs)
        var avg_boss := float(row.boss_steps) / float(maxi(1, int(row.boss_reached)))
        if avg_steps < min_steps:
            min_steps = avg_steps
            min_steps_world = world_id
        if avg_steps > max_steps:
            max_steps = avg_steps
            max_steps_world = world_id
        if int(row.boss_reached) > 0 and avg_boss < min_boss:
            min_boss = avg_boss
            min_boss_world = world_id
        if int(row.boss_reached) > 0 and avg_boss > max_boss:
            max_boss = avg_boss
            max_boss_world = world_id
    print("10.7 %s world_spread: avg_steps=%.2f(%s)..%.2f(%s) avg_boss_step=%.2f(%s)..%.2f(%s)" % [difficulty_id, min_steps, min_steps_world, max_steps, max_steps_world, min_boss, min_boss_world, max_boss, max_boss_world])

func _recommended_policy(character: Dictionary) -> String:
    var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
    var policy := str(curve.get("recommended_policy", "balanced"))
    return policy if PlayerPolicyEngine.new().is_valid(policy) else "balanced"

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: JOURNEY_PACING_PROBE: %s" % message)

func _finish() -> void:
    DifficultyEngine.clear_simulation_override()
    if failures.is_empty():
        print("JOURNEY_PACING_PROBE PASS: 10.7 instrumentation")
        get_tree().quit(0)
    else:
        print("JOURNEY_PACING_PROBE FAIL: %d" % failures.size())
        get_tree().quit(1)
