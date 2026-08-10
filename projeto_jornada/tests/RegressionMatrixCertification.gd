extends Node

const SEEDS_PER_CHARACTER := 2
const DETERMINISM_SEEDS := 1
const MAX_STEPS := 80
const BASE_SEED := 111000
const TERMINAL_RESULTS := ["victory", "defeat", "timeout", "combat_timeout"]

var failures: Array[String] = []
var simulator := DifficultySimulationEngine.new()
var policy_engine := PlayerPolicyEngine.new()
var full_runs := 0
var determinism_pairs := 0
var live_scenarios := 0
var live_events := 0
var live_travels := 0
var live_merchants := 0
var live_combats := 0

func _ready() -> void:
    await get_tree().process_frame
    var characters := _sorted_characters()
    expect(characters.size() == 36, "11.1 requires all 36 characters")
    expect(DifficultyEngine.ids().size() == 4, "11.1 requires all four difficulty modes")
    if characters.size() == 36 and DifficultyEngine.ids().size() == 4:
        _complete_journey_matrix(characters)
        _determinism_matrix(_representatives_by_world(characters))
        _state_restoration_gate(characters[0] as Dictionary)
        _live_cross_system_matrix(_representatives_by_world(characters))
    _finish()

func _sorted_characters() -> Array:
    var rows := ContentRegistry.all("characters").duplicate()
    rows.sort_custom(func(a, b): return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", "")))
    return rows

func _representatives_by_world(characters: Array) -> Array[Dictionary]:
    var by_world := {}
    for character_variant in characters:
        var character: Dictionary = character_variant as Dictionary
        var world_id := str(character.get("world_id", ""))
        if not by_world.has(world_id):
            by_world[world_id] = character
    var world_ids: Array = by_world.keys()
    world_ids.sort()
    var result: Array[Dictionary] = []
    for world_id_variant in world_ids:
        result.append((by_world[world_id_variant] as Dictionary).duplicate(true))
    expect(result.size() == 12, "11.1 representative set does not cover all 12 Domains")
    return result

func _recommended_policy(character: Dictionary) -> String:
    var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
    var policy_id := str(curve.get("recommended_policy", "balanced"))
    return policy_id if policy_engine.is_valid(policy_id) else "balanced"

func _complete_journey_matrix(characters: Array) -> void:
    var worlds := {}
    var outcomes := {}
    var max_steps_seen := 0
    var total_deadlocks := 0
    var total_stalemates := 0
    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        var world_id := str(character.get("world_id", ""))
        var policy_id := _recommended_policy(character)
        worlds[world_id] = true
        for difficulty_id in DifficultyEngine.ids():
            for sample_index in range(SEEDS_PER_CHARACTER):
                var seed_value := BASE_SEED + character_index * 1009 + sample_index * 97
                var result := simulator.simulate({
                    "character_id":character_id,
                    "policy_id":policy_id,
                    "build_id":"baseline",
                    "seed":seed_value,
                    "max_steps":MAX_STEPS,
                }, difficulty_id)
                full_runs += 1
                _validate_complete_result(result, character, policy_id, difficulty_id, seed_value)
                if not bool(result.get("ok", false)):
                    continue
                var outcome := str(result.get("result", ""))
                outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
                max_steps_seen = maxi(max_steps_seen, int(result.get("steps", 0)))
                total_deadlocks += int(result.get("deadlocks", 0))
                total_stalemates += int(result.get("combat_timeouts", 0))
    expect(full_runs == 36 * 4 * SEEDS_PER_CHARACTER, "11.1 complete journey run count mismatch: %d" % full_runs)
    expect(worlds.size() == 12, "11.1 complete journey matrix missed Domains: %d" % worlds.size())
    expect(total_deadlocks == 0, "11.1 complete journey matrix produced %d structural deadlocks" % total_deadlocks)
    expect(outcomes.size() >= 2, "11.1 complete journey matrix collapsed to one terminal outcome: %s" % str(outcomes))
    print("11.1 complete matrix: runs=%d worlds=%d outcomes=%s max_steps=%d deadlocks=%d combat_timeouts=%d" % [full_runs,worlds.size(),str(outcomes),max_steps_seen,total_deadlocks,total_stalemates])

func _validate_complete_result(result: Dictionary, character: Dictionary, policy_id: String, difficulty_id: String, seed_value: int) -> void:
    var character_id := str(character.get("id", ""))
    var world_id := str(character.get("world_id", ""))
    expect(bool(result.get("ok", false)), "11.1 invalid journey %s/%s/%d" % [character_id,difficulty_id,seed_value])
    if not bool(result.get("ok", false)):
        return
    expect(str(result.get("character_id", "")) == character_id, "11.1 character identity drifted in simulation")
    expect(str(result.get("world_id", "")) == world_id, "11.1 world identity drifted for %s" % character_id)
    expect(str(result.get("policy_id", "")) == policy_id, "11.1 policy identity drifted for %s" % character_id)
    expect(str(result.get("build_id", "")) == "baseline", "11.1 baseline journey leaked a synthetic build")
    expect(str(result.get("difficulty_id", "")) == difficulty_id, "11.1 difficulty identity drifted for %s" % character_id)
    expect(int(result.get("seed", 0)) == seed_value, "11.1 seed identity drifted for %s" % character_id)
    var outcome := str(result.get("result", ""))
    expect(outcome in TERMINAL_RESULTS, "11.1 unexpected terminal result %s for %s" % [outcome,character_id])
    expect(int(result.get("deadlocks", 0)) == 0, "11.1 structural deadlock for %s/%s/%d" % [character_id,difficulty_id,seed_value])
    expect(int(result.get("steps", 0)) >= 1 and int(result.get("steps", 0)) <= MAX_STEPS, "11.1 steps out of bounds for %s: %d" % [character_id,int(result.get("steps",0))])
    expect(int(result.get("locations_visited", 0)) >= 1, "11.1 journey visited no location for %s" % character_id)
    expect(int(result.get("final_health", 0)) >= 0, "11.1 negative final health for %s" % character_id)
    expect(int(result.get("final_vigor", 0)) >= 0, "11.1 negative final vigor for %s" % character_id)
    expect(int(result.get("final_fragments", 0)) >= 0, "11.1 negative fragments for %s" % character_id)
    expect(int(result.get("final_provisions", 0)) >= 0, "11.1 negative provisions for %s" % character_id)
    expect(str(result.get("trajectory_hash", "")).length() == 64, "11.1 trajectory hash is missing/malformed for %s" % character_id)

func _determinism_matrix(representatives: Array[Dictionary]) -> void:
    for world_index in range(representatives.size()):
        var character: Dictionary = representatives[world_index]
        var character_id := str(character.get("id", ""))
        var policy_id := _recommended_policy(character)
        for difficulty_id in DifficultyEngine.ids():
            var seed_value := BASE_SEED + 500000 + world_index * 1009
            var config := {
                "character_id":character_id,
                "policy_id":policy_id,
                "build_id":"baseline",
                "seed":seed_value,
                "max_steps":MAX_STEPS,
            }
            var a := simulator.simulate(config, difficulty_id)
            var b := simulator.simulate(config, difficulty_id)
            determinism_pairs += DETERMINISM_SEEDS
            expect(bool(a.get("ok", false)) and bool(b.get("ok", false)), "11.1 determinism pair invalid for %s/%s" % [character_id,difficulty_id])
            expect(str(a.get("trajectory_hash", "")) == str(b.get("trajectory_hash", "")), "11.1 deterministic trajectory diverged for %s/%s" % [character_id,difficulty_id])
            expect(_result_signature(a) == _result_signature(b), "11.1 deterministic result signature diverged for %s/%s" % [character_id,difficulty_id])
    expect(determinism_pairs == 12 * 4 * DETERMINISM_SEEDS, "11.1 determinism pair count mismatch: %d" % determinism_pairs)
    print("11.1 determinism matrix: pairs=%d worlds=12 difficulties=4" % determinism_pairs)

func _result_signature(result: Dictionary) -> String:
    return "%s|%s|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%s" % [
        str(result.get("result", "")),
        str(result.get("ending_id", "")),
        str(result.get("world_id", "")),
        str(result.get("character_id", "")),
        int(result.get("steps", 0)),
        int(result.get("turns", 0)),
        int(result.get("events", 0)),
        int(result.get("combats", 0)),
        int(result.get("purchases", 0)),
        int(result.get("final_health", 0)),
        int(result.get("final_vigor", 0)),
        int(result.get("final_fragments", 0)),
        str(result.get("trajectory_hash", "")),
    ]

func _state_restoration_gate(character: Dictionary) -> void:
    GameState.reset_profile()
    GameState.new_run(str(character.get("id", "")), BASE_SEED + 700001)
    DifficultyEngine.apply_to_run("severa")
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["regression.sentinel"] = "keep"
    GameState.run.flags = flags
    var profile_before := GameState.profile.duplicate(true)
    var run_before := GameState.run.duplicate(true)
    var rng_before := RNGService.snapshot().duplicate(true)
    var combat_before := CombatEngine.combat.duplicate(true)
    var result := simulator.simulate({
        "character_id":str(character.get("id", "")),
        "policy_id":_recommended_policy(character),
        "build_id":"baseline",
        "seed":BASE_SEED + 700777,
        "max_steps":MAX_STEPS,
    }, "ruptura")
    expect(bool(result.get("ok", false)), "11.1 restoration probe simulation failed")
    expect(GameState.profile == profile_before, "11.1 simulator leaked profile mutations into caller state")
    expect(GameState.run == run_before, "11.1 simulator leaked run mutations into caller state")
    expect(RNGService.snapshot() == rng_before, "11.1 simulator leaked RNG state")
    expect(CombatEngine.combat == combat_before, "11.1 simulator leaked combat state")
    expect(str((GameState.run.get("flags", {}) as Dictionary).get("regression.sentinel", "")) == "keep", "11.1 sentinel state was not restored")
    print("11.1 state restoration: profile/run/RNG/combat preserved")

func _live_cross_system_matrix(representatives: Array[Dictionary]) -> void:
    var worlds := {}
    for world_index in range(representatives.size()):
        var character: Dictionary = representatives[world_index]
        for difficulty_id in DifficultyEngine.ids():
            _live_scenario(character, difficulty_id, world_index)
            worlds[str(character.get("world_id", ""))] = true
    expect(live_scenarios == 12 * 4, "11.1 live scenario count mismatch: %d" % live_scenarios)
    expect(worlds.size() == 12, "11.1 live matrix missed Domains")
    expect(live_events == live_scenarios, "11.1 live event coverage mismatch: %d/%d" % [live_events,live_scenarios])
    expect(live_travels == live_scenarios, "11.1 live travel coverage mismatch: %d/%d" % [live_travels,live_scenarios])
    expect(live_merchants == live_scenarios, "11.1 live merchant coverage mismatch: %d/%d" % [live_merchants,live_scenarios])
    expect(live_combats == live_scenarios, "11.1 live combat coverage mismatch: %d/%d" % [live_combats,live_scenarios])
    print("11.1 live integration: scenarios=%d events=%d travels=%d merchants=%d combats=%d worlds=%d" % [live_scenarios,live_events,live_travels,live_merchants,live_combats,worlds.size()])

func _live_scenario(character: Dictionary, difficulty_id: String, world_index: int) -> void:
    live_scenarios += 1
    GameState.reset_profile()
    EventDirector.clear_candidate_cache()
    var character_id := str(character.get("id", ""))
    var expected_world := str(character.get("world_id", ""))
    var seed_value := BASE_SEED + 900000 + world_index * 1009 + DifficultyEngine.ids().find(difficulty_id) * 131
    GameState.new_run(character_id, seed_value)
    DifficultyEngine.apply_to_run(difficulty_id)
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["simulation.no_persist"] = true
    GameState.run.flags = flags

    expect(str(GameState.run.get("character_id", "")) == character_id, "11.1 live character mismatch %s/%s" % [character_id,difficulty_id])
    expect(str(GameState.run.get("world_id", "")) == expected_world, "11.1 live world mismatch %s/%s" % [character_id,difficulty_id])
    expect(str(GameState.run.get("difficulty_id", "")) == difficulty_id, "11.1 live difficulty not applied %s/%s" % [character_id,difficulty_id])
    expect((GameState.run.get("inventory", []) as Array).is_empty(), "11.1 live scenario inherited inventory")
    expect((GameState.run.get("marks", {}) as Dictionary).is_empty(), "11.1 live scenario inherited marks")
    expect((GameState.run.get("debts", []) as Array).is_empty(), "11.1 live scenario inherited debts")
    expect((GameState.run.get("event_counts", {}) as Dictionary).is_empty(), "11.1 live scenario inherited event history")

    var event := RunFlowEngine.story_event()
    expect(not event.is_empty(), "11.1 live event unavailable %s/%s" % [character_id,difficulty_id])
    if not event.is_empty():
        var available := EventDirector.available_choices(event)
        expect(not available.is_empty(), "11.1 live event has no legal choice %s" % str(event.get("id", "")))
        if not available.is_empty():
            var choice_index := int((available[0] as Dictionary).get("index", -1))
            var before_turn := int(GameState.run.get("turn", 0))
            if RunFlowEngine.choose(event, choice_index):
                live_events += 1
                expect(int(GameState.run.get("turn", 0)) == before_turn + 1, "11.1 live event choice did not advance exactly one turn")
            else:
                expect(false, "11.1 legal live event choice was rejected")
    RunFlowEngine.resume_story()

    var current := str(GameState.run.get("location_id", ""))
    var destination := _alternate_location(current)
    expect(destination != "", "11.1 live travel has no alternate destination in %s" % expected_world)
    if destination != "":
        var before_provisions := int((GameState.run.get("resources", {}) as Dictionary).get("provisions", 0))
        if RunFlowEngine.travel(destination):
            live_travels += 1
            expect(str(GameState.run.get("location_id", "")) == destination, "11.1 live travel did not update location")
            expect(int((GameState.run.get("resources", {}) as Dictionary).get("provisions", 0)) >= 0, "11.1 live travel produced negative provisions")
            expect(int(GameState.run.get("vigor", 0)) >= 0, "11.1 live travel produced negative vigor")
            expect(int(GameState.run.get("health", 0)) >= 1, "11.1 live travel violated nonlethal travel floor")
            expect(int((GameState.run.get("resources", {}) as Dictionary).get("provisions", 0)) <= before_provisions, "11.1 ordinary live travel unexpectedly created provisions")
        else:
            expect(false, "11.1 live travel rejected a listed destination %s" % destination)

    var stock := RunFlowEngine.open_merchant(4)
    expect(stock.size() <= 4, "11.1 merchant exceeded requested stock size")
    var unique := {}
    for item_variant in stock:
        var item_id := str(item_variant)
        expect(item_id != "" and not ContentRegistry.get_record(item_id).is_empty(), "11.1 merchant returned invalid item %s" % item_id)
        expect(not unique.has(item_id), "11.1 merchant returned duplicate item %s" % item_id)
        unique[item_id] = true
        var item := ContentRegistry.get_record(item_id)
        expect(str(item.get("world_id", "")) == expected_world, "11.1 merchant leaked cross-Domain item %s into %s" % [item_id,expected_world])
    live_merchants += 1
    RunFlowEngine.resume_story()

    if _move_to_monster_location(expected_world):
        var monsters := RunFlowEngine.local_monsters()
        expect(not monsters.is_empty(), "11.1 live combat location still has no monster")
        if not monsters.is_empty():
            var monster: Dictionary = monsters[0] as Dictionary
            var combat := RunFlowEngine.start_combat(str(monster.get("id", "")))
            expect(not combat.is_empty(), "11.1 live combat failed to start")
            expect(str(combat.get("difficulty_id", "")) == difficulty_id, "11.1 live combat lost difficulty context")
            if not combat.is_empty():
                var before_turn := int(combat.get("turn", 0))
                var decision := policy_engine.choose_combat_decision(_recommended_policy(character), combat)
                var after := _apply_decision(decision)
                expect(str(after.get("last_error", "")) == "", "11.1 live policy chose rejected action %s" % str(decision))
                expect(int(after.get("turn", before_turn)) > before_turn or not bool(after.get("active", true)), "11.1 live combat decision failed to progress")
                live_combats += 1
    else:
        expect(false, "11.1 could not reach any monster location in %s" % expected_world)

func _alternate_location(current: String) -> String:
    for location_variant in LocationEngine.available_locations():
        var location_id := str(location_variant)
        if location_id != current:
            return location_id
    return ""

func _move_to_monster_location(world_id: String) -> bool:
    var current := str(GameState.run.get("location_id", ""))
    if not RunFlowEngine.local_monsters().is_empty():
        return true
    var allowed := {}
    for location_variant in LocationEngine.available_locations():
        allowed[str(location_variant)] = true
    for monster_variant in ContentRegistry.all("monsters"):
        var monster: Dictionary = monster_variant as Dictionary
        if str(monster.get("world_id", "")) != world_id:
            continue
        var location_id := str(monster.get("location_id", ""))
        if location_id == current:
            return true
        if allowed.has(location_id) and RunFlowEngine.travel(location_id):
            return not RunFlowEngine.local_monsters().is_empty()
    return false

func _apply_decision(decision: Dictionary) -> Dictionary:
    var kind := str(decision.get("kind", "action"))
    var decision_id := str(decision.get("id", "strike"))
    if kind == "ability":
        return RunFlowEngine.combat_ability(decision_id)
    return RunFlowEngine.combat_action(decision_id)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: REGRESSION_MATRIX_CERTIFICATION: %s" % message)

func _finish() -> void:
    DifficultyEngine.clear_simulation_override()
    if failures.is_empty():
        print("REGRESSION_MATRIX_CERTIFICATION PASS: 11.1 full_runs=%d determinism_pairs=%d live_scenarios=%d" % [full_runs,determinism_pairs,live_scenarios])
        get_tree().quit(0)
    else:
        print("REGRESSION_MATRIX_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)
