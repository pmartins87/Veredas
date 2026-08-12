extends Node

const LIFECYCLE_CYCLES := 128
const RESTART_ROUNDS := 24
const BASE_SEED := 1190000

var failures: Array[String] = []
var migration := ProfileMigrationEngine.new()
var pause_start := 0
var resume_start := 0
var reloads := 0
var integrity_audits := 0


func _ready() -> void:
    await get_tree().process_frame
    _prepare()
    await _lifecycle_soak()
    await _restart_soak()
    _final_integrity_gate()
    _finish()


func _prepare() -> void:
    GameState.reset_profile()
    var normalized := migration.normalize_live_profile()
    expect(bool(normalized.get("ok", false)), "11.9 fresh profile normalization failed")
    expect(
        RunFlowEngine.start_journey(ProfileMigrationEngine.DEFAULT_CHARACTER, BASE_SEED, "andarilho"),
        "11.9 baseline journey did not start"
    )
    expect(bool(GameState.run.get("active", false)), "11.9 baseline journey is not active")
    pause_start = MobilePlatformService.pause_count
    resume_start = MobilePlatformService.resume_count
    _audit_live_state("baseline")


func _lifecycle_soak() -> void:
    var profile_fingerprint := migration.progress_fingerprint().duplicate(true)
    for cycle in range(LIFECYCLE_CYCLES):
        var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
        flags["reliability.pause_cycle"] = cycle
        GameState.run.flags = flags
        GameState.run.turn = cycle
        var expected_seed := int(GameState.run.get("seed", 0))

        MobilePlatformService.notification(NOTIFICATION_APPLICATION_PAUSED)
        expect(
            MobilePlatformService.pause_count == pause_start + cycle + 1,
            "11.9 pause counter drift at cycle %d" % cycle
        )

        # Destroy the in-memory sentinels after the pause autosave. A successful
        # reload must restore the persisted values rather than accepting RAM state.
        var damaged_flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
        damaged_flags.erase("reliability.pause_cycle")
        GameState.run.flags = damaged_flags
        GameState.run.turn = -999

        expect(SaveService.load_game(), "11.9 pause autosave reload failed at cycle %d" % cycle)
        reloads += 1
        expect(
            int((GameState.run.get("flags", {}) as Dictionary).get("reliability.pause_cycle", -1)) == cycle,
            "11.9 autosave lost pause sentinel at cycle %d" % cycle
        )
        expect(int(GameState.run.get("turn", -1)) == cycle, "11.9 autosave lost turn at cycle %d" % cycle)
        expect(int(GameState.run.get("seed", 0)) == expected_seed, "11.9 seed drift after reload at cycle %d" % cycle)
        expect(bool(GameState.run.get("active", false)), "11.9 active run lost after reload at cycle %d" % cycle)
        expect(
            migration.progress_fingerprint() == profile_fingerprint,
            "11.9 profile progression drift after pause reload at cycle %d" % cycle
        )
        _audit_live_state("pause cycle %d" % cycle)

        MobilePlatformService.notification(NOTIFICATION_APPLICATION_RESUMED)
        expect(
            MobilePlatformService.resume_count == resume_start + cycle + 1,
            "11.9 resume counter drift at cycle %d" % cycle
        )

        if (cycle + 1) % 16 == 0:
            await get_tree().process_frame

    expect(
        MobilePlatformService.pause_count - pause_start == LIFECYCLE_CYCLES,
        "11.9 final pause count mismatch"
    )
    expect(
        MobilePlatformService.resume_count - resume_start == LIFECYCLE_CYCLES,
        "11.9 final resume count mismatch"
    )


func _restart_soak() -> void:
    for round_index in range(RESTART_ROUNDS):
        var seed_value := BASE_SEED + 1000 + round_index
        expect(
            RunFlowEngine.start_journey(ProfileMigrationEngine.DEFAULT_CHARACTER, seed_value, "andarilho"),
            "11.9 restart journey did not start round=%d" % round_index
        )
        if not bool(GameState.run.get("active", false)):
            continue

        var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
        flags["reliability.restart_round"] = round_index
        GameState.run.flags = flags
        GameState.run.turn = round_index * 3
        var fingerprint := migration.progress_fingerprint().duplicate(true)

        expect(SaveService.save_game(), "11.9 explicit save failed round=%d" % round_index)
        GameState.profile = {}
        GameState.run = {}
        expect(SaveService.load_game(), "11.9 simulated process restore failed round=%d" % round_index)
        reloads += 1

        expect(int(GameState.run.get("seed", 0)) == seed_value, "11.9 restart seed mismatch round=%d" % round_index)
        expect(
            int((GameState.run.get("flags", {}) as Dictionary).get("reliability.restart_round", -1)) == round_index,
            "11.9 restart sentinel mismatch round=%d" % round_index
        )
        expect(
            int(GameState.run.get("turn", -1)) == round_index * 3,
            "11.9 restart turn mismatch round=%d" % round_index
        )
        expect(
            migration.progress_fingerprint() == fingerprint,
            "11.9 profile fingerprint changed across process restore round=%d" % round_index
        )
        _audit_live_state("restart round %d" % round_index)

        if (round_index + 1) % 4 == 0:
            await get_tree().process_frame


func _audit_live_state(label: String) -> void:
    var profile_audit := migration.audit_live_profile()
    expect(
        bool(profile_audit.get("ok", false)),
        "11.9 profile integrity failed at %s: %s" % [label, str(profile_audit.get("errors", []))]
    )
    if not GameState.run.is_empty():
        var run_audit := RunStateIntegrityEngine.new().normalize_and_audit(GameState.run.duplicate(true))
        expect(
            bool(run_audit.get("ok", false)),
            "11.9 run integrity failed at %s: %s" % [label, str(run_audit.get("errors", []))]
        )
    integrity_audits += 1


func _final_integrity_gate() -> void:
    _audit_live_state("final")
    expect(
        reloads == LIFECYCLE_CYCLES + RESTART_ROUNDS,
        "11.9 reload count mismatch expected=%d got=%d" % [LIFECYCLE_CYCLES + RESTART_ROUNDS, reloads]
    )
    expect(SaveService.save_game(), "11.9 final save failed")
    var final_seed := int(GameState.run.get("seed", 0))
    GameState.profile = {}
    GameState.run = {}
    expect(SaveService.load_game(), "11.9 final reload failed")
    reloads += 1
    expect(int(GameState.run.get("seed", 0)) == final_seed, "11.9 final seed changed after final reload")
    _audit_live_state("final reload")


func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: RELIABILITY_SOAK_CERTIFICATION: %s" % message)


func _finish() -> void:
    if failures.is_empty():
        print(
            "RELIABILITY_SOAK_CERTIFICATION PASS: 11.9 lifecycle_cycles=%d restart_rounds=%d reloads=%d integrity_audits=%d" % [
                LIFECYCLE_CYCLES,
                RESTART_ROUNDS,
                reloads,
                integrity_audits,
            ]
        )
        get_tree().quit(0)
        return
    print("RELIABILITY_SOAK_CERTIFICATION FAIL: %d" % failures.size())
    get_tree().quit(1)
