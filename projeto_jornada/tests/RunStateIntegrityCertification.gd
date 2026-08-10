extends Node

const RUN_CASES := 64
const ACCEPTED_PATTERNS := [0,1,4,12]

var failures: Array[String] = []
var migration := ProfileMigrationEngine.new()
var baseline_profile: Dictionary = {}
var baseline_run: Dictionary = {}
var baseline_rng: Dictionary = {}
var baseline_fingerprint: Dictionary = {}
var accepted := 0
var rejected := 0

func _ready() -> void:
    await get_tree().process_frame
    _prepare()
    _matrix()
    _restore()
    _finish()

func _prepare() -> void:
    GameState.reset_profile()
    GameState.new_run(ProfileMigrationEngine.DEFAULT_CHARACTER, 1122991)
    DifficultyEngine.apply_to_run("andarilho")
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["run_integrity.sentinel"] = "keep"
    GameState.run.flags = flags
    migration.normalize_live_profile()
    baseline_profile = GameState.profile.duplicate(true)
    baseline_run = GameState.run.duplicate(true)
    baseline_rng = RNGService.snapshot().duplicate(true)
    baseline_fingerprint = migration.progress_fingerprint().duplicate(true)

func _restore() -> void:
    GameState.profile = baseline_profile.duplicate(true)
    GameState.run = baseline_run.duplicate(true)
    RNGService.restore(baseline_rng)

func _matrix() -> void:
    for case_index in range(RUN_CASES):
        _restore()
        var pattern := case_index % 16
        var should_accept := pattern in ACCEPTED_PATTERNS
        var raw := _fuzz_run(pattern)
        var ok := GameState.deserialize({"profile":baseline_profile.duplicate(true),"run":raw})
        expect(ok == should_accept, "11.2 run pattern=%d expected_accept=%s got=%s" % [pattern,str(should_accept),str(ok)])
        if ok:
            accepted += 1
            expect(migration.progress_fingerprint() == baseline_fingerprint, "11.2 accepted run changed profile progression pattern=%d" % pattern)
            var audit := RunStateIntegrityEngine.new().normalize_and_audit(GameState.run)
            expect(bool(audit.get("ok", false)), "11.2 accepted run failed integrity re-audit pattern=%d errors=%s" % [pattern,str(audit.get("errors",[]))])
            if pattern == 1:
                expect(typeof(GameState.run.get("event_last_turn",{})) == TYPE_DICTIONARY, "11.2 legacy event_last_turn was not restored")
            if pattern == 12:
                expect(typeof(GameState.run.get("rng",{})) == TYPE_DICTIONARY, "11.2 missing legacy RNG was not reconstructed")
                expect(int((GameState.run.get("rng",{}) as Dictionary).get("seed",0)) == int(GameState.run.get("seed",0)), "11.2 reconstructed RNG seed mismatch")
        else:
            rejected += 1
            expect(GameState.profile == baseline_profile, "11.2 rejected run mutated profile pattern=%d" % pattern)
            expect(GameState.run == baseline_run, "11.2 rejected run mutated run pattern=%d" % pattern)
            expect(RNGService.snapshot() == baseline_rng, "11.2 rejected run mutated RNG pattern=%d" % pattern)
            expect(migration.progress_fingerprint() == baseline_fingerprint, "11.2 rejected run changed progression pattern=%d" % pattern)
    expect(accepted == 16, "11.2 strict run accepted count mismatch: %d" % accepted)
    expect(rejected == 48, "11.2 strict run rejected count mismatch: %d" % rejected)
    print("11.2 strict run integrity: cases=%d accepted=%d rejected=%d recoverable_patterns=%s" % [RUN_CASES,accepted,rejected,str(ACCEPTED_PATTERNS)])

func _fuzz_run(pattern: int) -> Dictionary:
    var r := baseline_run.duplicate(true)
    match pattern:
        0:
            return {}
        1:
            r.erase("event_last_turn")
            r.erase("setup")
        2:
            r.setup = {"world_id":str(r.get("world_id","")),"character_id":str(r.get("character_id","")),"journey_mode":"journey","difficulty_id":"severa","seed":int(r.get("seed",1)),"modifiers":[]}
            r.difficulty_id = "unknown-difficulty"
        3:
            r.setup = {"world_id":"x","character_id":"x","journey_mode":"x","difficulty_id":"x","seed":-5,"modifiers":["sem_trocas","sem_trocas"]}
            r.difficulty_id = "ruptura"
        4:
            r.recent_events = []
            r.event_counts = {}
            r.event_last_turn = {}
        5:
            r.health = -999
            r.vigor = -999
            r.resources = {"fragments":-999,"provisions":-999}
        6:
            r.inventory = ["item.nonexistent.99"]
            r.equipped = {"weapon":"item.nonexistent.99"}
        7:
            r.debts = [{"id":"debt.nonexistent","pressure":999999}]
            r.marks = {"mark.nonexistent.99":999}
        8:
            r.visited_locations = ["location.nonexistent.99"]
            r.location_id = "location.nonexistent.99"
        9:
            r.character_id = "character.nonexistent.99"
            r.world_id = "world.nonexistent"
        10:
            r.setup = "broken"
        11:
            r.rng = {}
        12:
            r.erase("rng")
        13:
            r.flags = {"modifier.no_trade":true,"unknown":true}
            r.modifiers = ["sem_trocas","sem_trocas","unknown"]
        14:
            r.turn = -100
            r.seed = -1
        15:
            r.active = false
            r.ending_id = "ending.nonexistent"
    return r

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: RUN_STATE_INTEGRITY_CERTIFICATION: %s" % message)

func _finish() -> void:
    if failures.is_empty():
        print("RUN_STATE_INTEGRITY_CERTIFICATION PASS: 11.2 cases=%d accepted=%d rejected=%d" % [RUN_CASES,accepted,rejected])
        get_tree().quit(0)
    else:
        print("RUN_STATE_INTEGRITY_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)
