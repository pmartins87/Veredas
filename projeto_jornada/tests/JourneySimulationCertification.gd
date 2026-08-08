extends Node

var failures: Array[String] = []
var simulator := JourneySimulationEngine.new()
var policies := PlayerPolicyEngine.new()
var representative_characters: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _resolve_representatives()
    _catalog_gate()
    _isolation_gate()
    _determinism_gate()
    _representative_matrix_gate()
    _invalid_input_gate()
    _finish()

func _resolve_representatives() -> void:
    var by_world: Dictionary = {}
    for character_variant in ContentRegistry.all("characters"):
        var character: Dictionary = character_variant as Dictionary
        var character_id := str(character.get("id", ""))
        var world_id := str(character.get("world_id", ""))
        if character_id == "" or world_id == "" or by_world.has(world_id):
            continue
        by_world[world_id] = character_id
    var worlds: Array = by_world.keys()
    worlds.sort()
    if "world.mata_fio_verde" in worlds:
        representative_characters.append(str(by_world["world.mata_fio_verde"]))
        worlds.erase("world.mata_fio_verde")
    for world_variant in worlds:
        if representative_characters.size() >= 2:
            break
        representative_characters.append(str(by_world[world_variant]))
    expect(representative_characters.size() == 2, "10.1 needs representatives from two Domains")

func _catalog_gate() -> void:
    expect(policies.policy_ids().size() == 5, "10.1 must expose five player policies")
    for required_policy in ["balanced", "aggressive", "cautious", "explorer", "random"]:
        expect(policies.is_valid(required_policy), "10.1 missing policy %s" % required_policy)
    expect(simulator.build_ids() == ["baseline", "offense", "defense", "utility"], "10.1 build matrix mismatch")
    for character_id in representative_characters:
        var character := ContentRegistry.get_record(character_id)
        expect(not character.is_empty(), "10.1 representative character missing: %s" % character_id)
        expect(not ContentRegistry.get_record(str(character.get("world_id", ""))).is_empty(), "10.1 representative world missing: %s" % character_id)

func _isolation_gate() -> void:
    GameState.reset_profile()
    GameState.profile.settings = {"simulation_sentinel":"profile-stays"}
    GameState.run = {"simulation_sentinel":"run-stays", "active":false}
    RNGService.start(24681357)
    RNGService.range_int(1, 100)
    CombatEngine.combat = {"simulation_sentinel":"combat-stays"}

    var before_profile := GameState.profile.duplicate(true)
    var before_run := GameState.run.duplicate(true)
    var before_rng := RNGService.snapshot().duplicate(true)
    var before_combat := CombatEngine.combat.duplicate(true)
    var save_existed := FileAccess.file_exists(SaveService.SAVE_PATH)
    var save_before := _read_save_text() if save_existed else ""

    var result := simulator.simulate({
        "character_id":representative_characters[0],
        "policy_id":"balanced",
        "build_id":"baseline",
        "seed":101001,
        "max_steps":80,
    })
    expect(bool(result.get("ok", false)), "10.1 isolated simulation failed")
    expect(GameState.profile == before_profile, "10.1 simulation leaked into profile state")
    expect(GameState.run == before_run, "10.1 simulation leaked into run state")
    expect(RNGService.snapshot() == before_rng, "10.1 simulation leaked into global RNG")
    expect(CombatEngine.combat == before_combat, "10.1 simulation leaked into global combat state")
    expect(FileAccess.file_exists(SaveService.SAVE_PATH) == save_existed, "10.1 simulation changed save-file existence")
    if save_existed:
        expect(_read_save_text() == save_before, "10.1 simulation wrote into the player's save file")

func _determinism_gate() -> void:
    var config := {
        "character_id":representative_characters[0],
        "policy_id":"random",
        "build_id":"utility",
        "seed":202002,
        "max_steps":80,
    }
    var first := simulator.simulate(config)
    var second := simulator.simulate(config)
    expect(bool(first.get("ok", false)) and bool(second.get("ok", false)), "10.1 deterministic sample failed")
    expect(str(first.get("trajectory_hash", "")) != "", "10.1 deterministic sample has no trajectory hash")
    expect(first.get("trajectory_hash", "") == second.get("trajectory_hash", ""), "10.1 same seed/policy/build produced different trajectory hashes")
    for field in ["result", "ending_id", "turns", "events", "combats", "purchases", "locations_visited", "final_health", "final_vigor", "final_fragments"]:
        expect(first.get(field) == second.get(field), "10.1 deterministic field mismatch: %s" % field)

func _representative_matrix_gate() -> void:
    var started_at := Time.get_ticks_msec()
    var matrix := simulator.simulate_matrix({
        "character_ids":representative_characters,
        "policy_ids":["balanced", "random"],
        "build_ids":["baseline", "offense"],
        "seeds_per_combination":1,
        "base_seed":303003,
        "max_steps":80,
    })
    var results: Array = matrix.get("results", []) as Array
    var summary: Dictionary = matrix.get("summary", {}) as Dictionary
    expect(results.size() == 8, "10.1 compact cartesian matrix must execute eight full journeys")
    expect(int(summary.get("runs", 0)) == results.size(), "10.1 summary run count mismatch")
    expect((summary.get("groups", []) as Array).size() == 8, "10.1 summary grouping lost a cartesian cell")
    expect(str(matrix.get("signature", "")).length() == 64, "10.1 matrix signature is not SHA-256")

    var probes: Array = results.duplicate()
    probes.append(simulator.simulate({"character_id":representative_characters[0], "policy_id":"aggressive", "build_id":"utility", "seed":404001, "max_steps":80}))
    probes.append(simulator.simulate({"character_id":representative_characters[0], "policy_id":"cautious", "build_id":"baseline", "seed":404002, "max_steps":80}))
    probes.append(simulator.simulate({"character_id":representative_characters[0], "policy_id":"explorer", "build_id":"defense", "seed":404003, "max_steps":80}))

    var seen_worlds: Dictionary = {}
    var seen_policies: Dictionary = {}
    var seen_builds: Dictionary = {}
    var total_events := 0
    var total_combats := 0
    var total_travel := 0
    var total_purchases := 0
    var total_boss_reached := 0
    var total_nonbaseline_items := 0
    var total_invalid := 0
    var total_deadlocks := 0
    var valid_outcomes := ["victory", "defeat", "combat_timeout", "ending_unavailable", "timeout"]

    for result_variant in probes:
        var result: Dictionary = result_variant as Dictionary
        if not bool(result.get("ok", false)):
            total_invalid += 1
            continue
        var character := ContentRegistry.get_record(str(result.get("character_id", "")))
        var expected_world := str(character.get("world_id", ""))
        expect(str(result.get("world_id", "")) == expected_world, "10.1 result escaped its character Domain")
        expect(str(result.get("result", "")) in valid_outcomes, "10.1 invalid journey outcome: %s" % str(result.get("result", "")))
        expect(str(result.get("trajectory_hash", "")).length() == 64, "10.1 result missing trajectory hash")
        expect(int(result.get("steps", 0)) > 0, "10.1 result executed zero journey steps")
        expect(int(result.get("events", 0)) > 0, "10.1 result executed zero narrative events")
        expect(int(result.get("locations_visited", 0)) >= 1, "10.1 result has no visited location")
        seen_worlds[str(result.get("world_id", ""))] = true
        seen_policies[str(result.get("policy_id", ""))] = true
        seen_builds[str(result.get("build_id", ""))] = true
        total_events += int(result.get("events", 0))
        total_combats += int(result.get("combats", 0))
        total_travel += int(result.get("travel_actions", 0))
        total_purchases += int(result.get("purchases", 0))
        total_deadlocks += int(result.get("deadlocks", 0))
        if bool(result.get("boss_reached", false)):
            total_boss_reached += 1
        if str(result.get("build_id", "")) != "baseline":
            var build_items: Array = result.get("build_items", []) as Array
            total_nonbaseline_items += build_items.size()
            for item_id_variant in build_items:
                var item := ContentRegistry.get_record(str(item_id_variant))
                expect(str(item.get("kind", "")) == "equipment", "10.1 build contains a non-equipment item")

    expect(total_invalid == 0, "10.1 representative probes produced invalid simulations")
    expect(seen_worlds.size() == 2, "10.1 probes did not cover two Domains")
    expect(seen_policies.size() == 5, "10.1 probes did not cover all five policies")
    expect(seen_builds.size() == 4, "10.1 probes did not cover all four builds")
    expect(total_events >= probes.size(), "10.1 probes did not exercise narrative runtime")
    expect(total_combats > 0, "10.1 probes did not exercise combat runtime")
    expect(total_travel > 0, "10.1 probes did not exercise travel runtime")
    expect(total_boss_reached > 0, "10.1 probes never reached a boss")
    expect(total_nonbaseline_items > 0, "10.1 non-baseline builds contain no equipment")
    expect(total_deadlocks < probes.size(), "10.1 simulator is dominated by deadlocks")
    var elapsed_ms := Time.get_ticks_msec() - started_at
    print("10.1 representative probes: runs=%d matrix_victories=%d matrix_defeats=%d matrix_timeouts=%d events=%d combats=%d travel=%d purchases=%d bosses=%d elapsed_ms=%d" % [
        probes.size(), int(summary.get("victories", 0)), int(summary.get("defeats", 0)), int(summary.get("timeouts", 0)),
        total_events, total_combats, total_travel, total_purchases, total_boss_reached, elapsed_ms,
    ])

func _invalid_input_gate() -> void:
    var invalid_character := simulator.simulate({"character_id":"character.invalid", "policy_id":"balanced", "build_id":"baseline", "seed":1})
    expect(not bool(invalid_character.get("ok", true)) and str(invalid_character.get("error", "")) == "invalid_character", "10.1 invalid character was accepted")
    var invalid_policy := simulator.simulate({"character_id":representative_characters[0], "policy_id":"omniscient", "build_id":"baseline", "seed":1})
    expect(not bool(invalid_policy.get("ok", true)) and str(invalid_policy.get("error", "")) == "invalid_policy", "10.1 invalid policy was accepted")
    var invalid_build := simulator.simulate({"character_id":representative_characters[0], "policy_id":"balanced", "build_id":"pay_to_win", "seed":1})
    expect(not bool(invalid_build.get("ok", true)) and str(invalid_build.get("error", "")) == "invalid_build", "10.1 invalid build was accepted")

func _read_save_text() -> String:
    var file := FileAccess.open(SaveService.SAVE_PATH, FileAccess.READ)
    if file == null:
        return ""
    var text := file.get_as_text()
    file.close()
    return text

func _finish() -> void:
    if failures.is_empty():
        print("JOURNEY_SIMULATION_CERTIFICATION PASS: 10.1")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("JOURNEY_SIMULATION_CERTIFICATION: %s" % failure)
        print("JOURNEY_SIMULATION_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
