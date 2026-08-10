extends Node

const HUB_SCENE := "res://scenes/Hub.tscn"
const SCENE_CYCLES := 20
const SOAK_CYCLES := 120
const SAVE_ROUNDS := 24
const WARMUP_CYCLES := 12
const BASE_SEED := 1133000

var failures: Array[String] = []
var simulator := DifficultySimulationEngine.new()
var scene_cold_ms := 0.0
var scene_p95_ms := 0.0
var simulation_p95_ms := 0.0
var save_p95_ms := 0.0
var load_p95_ms := 0.0
var memory_warm_mb := 0.0
var memory_final_mb := 0.0
var memory_peak_mb := 0.0
var node_drift := 0

func _ready() -> void:
    await get_tree().process_frame
    var targets := PerformanceBudgetService.targets()
    expect(not targets.is_empty(), "11.3-A performance targets are missing")
    await _scene_profile(targets)
    await _simulation_soak(targets)
    _save_load_profile()
    _finish()

func _scene_profile(targets: Dictionary) -> void:
    var before_nodes := _node_count()
    var before_memory := _memory_mb()
    var load_started := Time.get_ticks_usec()
    var resource = ResourceLoader.load(HUB_SCENE)
    scene_cold_ms = float(Time.get_ticks_usec() - load_started) / 1000.0
    expect(resource is PackedScene, "11.3-A Hub scene did not load as PackedScene")
    if not (resource is PackedScene):
        return

    var instantiate_times: Array = []
    var peak := before_memory
    for _i in range(SCENE_CYCLES):
        var started := Time.get_ticks_usec()
        var instance := (resource as PackedScene).instantiate()
        add_child(instance)
        await get_tree().process_frame
        instantiate_times.append(float(Time.get_ticks_usec() - started) / 1000.0)
        peak = maxf(peak, _memory_mb())
        instance.queue_free()
        await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame

    scene_p95_ms = _percentile(instantiate_times, 0.95)
    node_drift = _node_count() - before_nodes
    memory_peak_mb = maxf(memory_peak_mb, peak)
    var warm_limit_ms := float(targets.get("warm_start_seconds", 3.0)) * 1000.0
    expect(scene_cold_ms <= warm_limit_ms, "11.3-A Hub resource load too slow: %.2fms > %.2fms" % [scene_cold_ms,warm_limit_ms])
    expect(scene_p95_ms <= 750.0, "11.3-A Hub instantiate p95 too slow: %.2fms" % scene_p95_ms)
    expect(node_drift <= 64, "11.3-A Hub scene cycles leaked nodes: drift=%d" % node_drift)
    print("11.3-A scene profile: cold_ms=%.2f instantiate_p95_ms=%.2f nodes_before=%d nodes_after=%d node_drift=%d memory_before_mb=%.2f peak_mb=%.2f" % [scene_cold_ms,scene_p95_ms,before_nodes,_node_count(),node_drift,before_memory,peak])

func _simulation_soak(targets: Dictionary) -> void:
    var representatives := _representatives_by_world()
    expect(representatives.size() == 12, "11.3-A soak requires representatives from 12 Domains")
    if representatives.size() != 12:
        return
    var difficulties := DifficultyEngine.ids()
    var times: Array = []
    var peak := _memory_mb()
    var start_nodes := _node_count()
    var invalid := 0
    var deadlocks := 0
    for i in range(SOAK_CYCLES):
        var character: Dictionary = representatives[i % representatives.size()] as Dictionary
        var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
        var policy_id := str(curve.get("recommended_policy", "balanced"))
        var started := Time.get_ticks_usec()
        var result := simulator.simulate({
            "character_id":str(character.get("id", "")),
            "policy_id":policy_id,
            "build_id":"baseline",
            "seed":BASE_SEED + i * 977,
            "max_steps":80,
        }, str(difficulties[i % difficulties.size()]))
        times.append(float(Time.get_ticks_usec() - started) / 1000.0)
        if not bool(result.get("ok", false)):
            invalid += 1
        deadlocks += int(result.get("deadlocks", 0))
        peak = maxf(peak, _memory_mb())
        if i == WARMUP_CYCLES - 1:
            memory_warm_mb = _memory_mb()
        if i % 8 == 7:
            await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    memory_final_mb = _memory_mb()
    memory_peak_mb = maxf(memory_peak_mb, peak)
    simulation_p95_ms = _percentile(times, 0.95)

    var memory_hard := float(targets.get("static_memory_mb_hard", 420.0))
    var drift := memory_final_mb - memory_warm_mb
    expect(invalid == 0, "11.3-A soak produced %d invalid journeys" % invalid)
    expect(deadlocks == 0, "11.3-A soak produced %d structural deadlocks" % deadlocks)
    expect(memory_peak_mb <= memory_hard, "11.3-A static memory exceeded hard budget: %.2fMB > %.2fMB" % [memory_peak_mb,memory_hard])
    expect(drift <= 96.0, "11.3-A post-warmup memory drift too high: %.2fMB" % drift)
    expect(_node_count() - start_nodes <= 32, "11.3-A simulation soak leaked nodes: drift=%d" % (_node_count() - start_nodes))
    expect(simulation_p95_ms <= 500.0, "11.3-A journey simulation p95 too slow on CI runner: %.2fms" % simulation_p95_ms)
    print("11.3-A simulation soak: cycles=%d p95_ms=%.2f invalid=%d deadlocks=%d warm_memory_mb=%.2f final_memory_mb=%.2f drift_mb=%.2f peak_mb=%.2f" % [SOAK_CYCLES,simulation_p95_ms,invalid,deadlocks,memory_warm_mb,memory_final_mb,drift,memory_peak_mb])

func _save_load_profile() -> void:
    GameState.reset_profile()
    GameState.new_run(ProfileMigrationEngine.DEFAULT_CHARACTER, BASE_SEED + 777001)
    DifficultyEngine.apply_to_run("andarilho")
    var save_times: Array = []
    var load_times: Array = []
    for _i in range(SAVE_ROUNDS):
        var save_started := Time.get_ticks_usec()
        var saved := SaveService.save_game()
        save_times.append(float(Time.get_ticks_usec() - save_started) / 1000.0)
        expect(saved, "11.3-A save failed during profiling")
        var load_started := Time.get_ticks_usec()
        var loaded := SaveService.load_game()
        load_times.append(float(Time.get_ticks_usec() - load_started) / 1000.0)
        expect(loaded, "11.3-A load failed during profiling")
    save_p95_ms = _percentile(save_times, 0.95)
    load_p95_ms = _percentile(load_times, 0.95)
    expect(save_p95_ms <= 250.0, "11.3-A save p95 too slow: %.2fms" % save_p95_ms)
    expect(load_p95_ms <= 250.0, "11.3-A load p95 too slow: %.2fms" % load_p95_ms)
    print("11.3-A persistence profile: rounds=%d save_p95_ms=%.2f load_p95_ms=%.2f" % [SAVE_ROUNDS,save_p95_ms,load_p95_ms])

func _representatives_by_world() -> Array:
    var by_world := {}
    for variant in ContentRegistry.all("characters"):
        var character: Dictionary = variant as Dictionary
        var world_id := str(character.get("world_id", ""))
        if not by_world.has(world_id):
            by_world[world_id] = character
    var keys: Array = by_world.keys()
    keys.sort()
    var result: Array = []
    for key_variant in keys:
        result.append((by_world[key_variant] as Dictionary).duplicate(true))
    return result

func _memory_mb() -> float:
    return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0

func _node_count() -> int:
    return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

func _percentile(values: Array, p: float) -> float:
    if values.is_empty():
        return 0.0
    var copy := values.duplicate()
    copy.sort()
    var index := clampi(roundi(float(copy.size() - 1) * clampf(p, 0.0, 1.0)), 0, copy.size() - 1)
    return float(copy[index])

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: PERFORMANCE_PROFILE_AUTOMATED: %s" % message)

func _finish() -> void:
    DifficultyEngine.clear_simulation_override()
    if failures.is_empty():
        print("PERFORMANCE_PROFILE_AUTOMATED PASS: 11.3-A cold_ms=%.2f scene_p95_ms=%.2f simulation_p95_ms=%.2f save_p95_ms=%.2f load_p95_ms=%.2f peak_memory_mb=%.2f memory_drift_mb=%.2f node_drift=%d" % [scene_cold_ms,scene_p95_ms,simulation_p95_ms,save_p95_ms,load_p95_ms,memory_peak_mb,memory_final_mb-memory_warm_mb,node_drift])
        get_tree().quit(0)
    else:
        print("PERFORMANCE_PROFILE_AUTOMATED FAIL: %d" % failures.size())
        get_tree().quit(1)
