extends Node

const PROFILE_FUZZ_CASES := 192
const RUN_FUZZ_CASES := 64
const SAVE_FILE_CASES := 8

var failures: Array[String] = []
var migration := ProfileMigrationEngine.new()
var baseline_profile: Dictionary = {}
var baseline_run: Dictionary = {}
var baseline_fingerprint: Dictionary = {}
var accepted_profiles := 0
var rejected_profiles := 0
var accepted_runs := 0
var rejected_runs := 0
var file_rejections := 0

func _ready() -> void:
    await get_tree().process_frame
    _prepare_baseline()
    _top_level_transaction_gate()
    _profile_fuzz_gate()
    _run_fuzz_gate()
    _save_file_corruption_gate()
    _canonical_roundtrip_gate()
    _restore_baseline()
    _finish()

func _prepare_baseline() -> void:
    GameState.reset_profile()
    var chars := ContentRegistry.all("characters")
    var character_id := ProfileMigrationEngine.DEFAULT_CHARACTER
    if not chars.is_empty():
        character_id = str((chars[0] as Dictionary).get("id", character_id))
    GameState.new_run(character_id, 1122001)
    DifficultyEngine.apply_to_run("andarilho")
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["save_fuzz.sentinel"] = "preserve"
    GameState.run.flags = flags
    var settings: Dictionary = GameState.profile.get("settings", {}) as Dictionary
    settings["font_scale"] = 1.1
    settings["reduced_motion"] = true
    GameState.profile.settings = settings
    var report := migration.normalize_live_profile()
    expect(bool(report.get("ok", false)), "11.2 baseline profile is not canonical")
    baseline_profile = GameState.profile.duplicate(true)
    baseline_run = GameState.run.duplicate(true)
    baseline_fingerprint = migration.progress_fingerprint().duplicate(true)

func _restore_baseline() -> void:
    GameState.profile = baseline_profile.duplicate(true)
    GameState.run = baseline_run.duplicate(true)
    if GameState.run.has("rng") and typeof(GameState.run.rng) == TYPE_DICTIONARY:
        RNGService.restore(GameState.run.rng)

func _top_level_transaction_gate() -> void:
    _restore_baseline()
    expect(not GameState.deserialize({}), "11.2 accepted save without profile")
    _expect_baseline_unchanged("missing profile")
    expect(not GameState.deserialize({"profile":42,"run":{}}), "11.2 accepted non-dictionary profile")
    _expect_baseline_unchanged("non-dictionary profile")
    expect(not GameState.deserialize({"profile":baseline_profile.duplicate(true),"run":"broken"}), "11.2 accepted non-dictionary run")
    _expect_baseline_unchanged("non-dictionary run")
    var future := baseline_profile.duplicate(true)
    future.profile_schema_version = ProfileMigrationEngine.CURRENT_SCHEMA_VERSION + 1
    expect(not GameState.deserialize({"profile":future,"run":baseline_run.duplicate(true)}), "11.2 accepted future profile schema")
    _expect_baseline_unchanged("future schema")
    print("11.2 transaction gate: malformed top-level/future schema rejected without state mutation")

func _profile_fuzz_gate() -> void:
    for case_index in range(PROFILE_FUZZ_CASES):
        _restore_baseline()
        var before_profile := GameState.profile.duplicate(true)
        var before_run := GameState.run.duplicate(true)
        var before_fingerprint := migration.progress_fingerprint().duplicate(true)
        var raw := _fuzz_profile(case_index)
        var accepted := GameState.deserialize({"profile":raw,"run":{}})
        if accepted:
            accepted_profiles += 1
            var report := migration.audit_live_profile()
            expect(bool(report.get("ok", false)), "11.2 accepted fuzz profile failed audit case=%d errors=%s" % [case_index,str(report.get("errors",[]))])
            expect(int(GameState.profile.get("profile_schema_version",0)) == ProfileMigrationEngine.CURRENT_SCHEMA_VERSION, "11.2 accepted fuzz profile not upgraded to schema 3 case=%d" % case_index)
            expect(ProfileMigrationEngine.DEFAULT_CHARACTER in (GameState.profile.unlocks.characters as Array), "11.2 accepted fuzz profile lost default character case=%d" % case_index)
            expect(ProfileMigrationEngine.DEFAULT_ROUTE in (GameState.profile.unlocks.routes as Array), "11.2 accepted fuzz profile lost default route case=%d" % case_index)
            expect("journey" in (GameState.profile.unlocks.modes as Array), "11.2 accepted fuzz profile lost default mode case=%d" % case_index)
            var entitlements: Dictionary = GameState.profile.get("entitlements", {}) as Dictionary
            for forbidden in ["damage_bonus","health_bonus","vigor_bonus","currency_grant","drop_rate_bonus"]:
                expect(not entitlements.has(forbidden), "11.2 accepted fuzz profile retained forbidden entitlement %s case=%d" % [forbidden,case_index])
            var again := migration.migrate_raw(GameState.profile)
            GameState.profile = again
            var second := migration.normalize_live_profile()
            expect(bool(second.get("ok",false)), "11.2 repeated normalization failed case=%d" % case_index)
            var first_fp := migration.progress_fingerprint().duplicate(true)
            migration.normalize_live_profile()
            expect(migration.progress_fingerprint() == first_fp, "11.2 accepted fuzz migration is not idempotent case=%d" % case_index)
        else:
            rejected_profiles += 1
            expect(GameState.profile == before_profile, "11.2 rejected fuzz profile mutated live profile case=%d" % case_index)
            expect(GameState.run == before_run, "11.2 rejected fuzz profile mutated live run case=%d" % case_index)
            expect(migration.progress_fingerprint() == before_fingerprint, "11.2 rejected fuzz profile changed fingerprint case=%d" % case_index)
    expect(accepted_profiles + rejected_profiles == PROFILE_FUZZ_CASES, "11.2 profile fuzz accounting mismatch")
    expect(accepted_profiles > 0, "11.2 profile fuzz accepted no migratable cases")
    print("11.2 profile fuzz: cases=%d accepted=%d rejected=%d" % [PROFILE_FUZZ_CASES,accepted_profiles,rejected_profiles])

func _fuzz_profile(i: int) -> Dictionary:
    var p := baseline_profile.duplicate(true)
    p.profile_schema_version = i % (ProfileMigrationEngine.CURRENT_SCHEMA_VERSION + 1)
    match i % 16:
        0:
            p.erase("profile_schema_version")
            p.erase("unlocks")
            p.erase("codex_records")
        1:
            p.unlocks = {"characters":[ProfileMigrationEngine.DEFAULT_CHARACTER,ProfileMigrationEngine.DEFAULT_CHARACTER,"character.nonexistent.99"],"routes":[ProfileMigrationEngine.DEFAULT_ROUTE,"world.nonexistent"],"modes":["journey","journey","paid_power_mode"],"codex":[ProfileMigrationEngine.DEFAULT_CHARACTER,"item.nonexistent.99"]}
        2:
            p.unlocked_characters = [ProfileMigrationEngine.DEFAULT_CHARACTER, 42, null, "character.nonexistent.99"]
            p.codex = [ProfileMigrationEngine.DEFAULT_ROUTE, {}, "content.nonexistent"]
        3:
            p.hub = {"stage":999,"visit_count":-100,"routes":["world.nonexistent"],"residents":["npc.nonexistent.99"],"facilities":"bad","history":[]}
        4:
            var history: Array = []
            for n in range(80): history.append({"n":n})
            p.hub = {"stage":-5,"visit_count":-1,"routes":[],"residents":[],"facilities":{},"history":history}
        5:
            p.saved_seeds = [{"seed":0,"label":"zero"},{"seed":17,"label":"a"},{"seed":17,"label":"b"},"broken",{"seed":-9}]
            p.codex_pins = ["item.nonexistent.99",ProfileMigrationEngine.DEFAULT_CHARACTER,ProfileMigrationEngine.DEFAULT_CHARACTER]
        6:
            p.saved_journey_presets = {"0":{"world_id":"garbage","character_id":"garbage","journey_mode":"garbage","difficulty_id":"garbage","seed":-7,"modifiers":["x","x"]},"bad":"not-a-dict","-1":{}}
        7:
            p.echo_marks = {"mark.nonexistent.99":{"max_intensity":999}}
            p.codex_records = {"item.nonexistent.99":{"encounters":999}}
            p.consequences = {"ending.nonexistent":{"witnessed":true}}
        8:
            p.entitlements = {"damage_bonus":999,"health_bonus":999,"currency_grant":999999,"grants":{}}
        9:
            p.meta_economy = {"balance":-50,"lifetime_earned":-10,"lifetime_spent":-5}
        10:
            p.unlocks = "broken"
            p.hub = []
            p.settings = "broken"
        11:
            p.codex_records = []
            p.achievements = "broken"
            p.echo_marks = []
        12:
            p.unlocked_characters = "broken"
            p.codex = 99
            p.endings = {"bad":true}
        13:
            p.saved_seeds = "broken"
            p.codex_pins = "broken"
            p.saved_journey_presets = []
        14:
            p.entitlements = []
            p.meta_economy = "broken"
            p.consequences = 7
        15:
            p.settings = {"font_scale":10.0,"reduced_motion":true,"unknown_setting":{"nested":[1,2,3]}}
    return p

func _run_fuzz_gate() -> void:
    for case_index in range(RUN_FUZZ_CASES):
        _restore_baseline()
        var before_fingerprint := migration.progress_fingerprint().duplicate(true)
        var raw_run := _fuzz_run(case_index)
        var accepted := GameState.deserialize({"profile":baseline_profile.duplicate(true),"run":raw_run})
        if accepted:
            accepted_runs += 1
            expect(migration.progress_fingerprint() == before_fingerprint, "11.2 run-only fuzz changed profile progression case=%d" % case_index)
            expect(typeof(GameState.run) == TYPE_DICTIONARY, "11.2 accepted run is not dictionary case=%d" % case_index)
            if not GameState.run.is_empty() and GameState.run.has("setup") and typeof(GameState.run.get("setup")) == TYPE_DICTIONARY:
                var setup: Dictionary = GameState.run.get("setup", {}) as Dictionary
                expect(typeof(setup.get("modifiers",[])) == TYPE_ARRAY, "11.2 normalized setup modifiers not array case=%d" % case_index)
                expect(str(GameState.run.get("difficulty_id","")) in DifficultyEngine.ids(), "11.2 accepted run has unknown difficulty case=%d" % case_index)
        else:
            rejected_runs += 1
            _expect_baseline_unchanged("rejected run fuzz case=%d" % case_index)
    expect(accepted_runs + rejected_runs == RUN_FUZZ_CASES, "11.2 run fuzz accounting mismatch")
    expect(accepted_runs > 0, "11.2 run fuzz accepted no compatible cases")
    print("11.2 run fuzz: cases=%d accepted=%d rejected=%d" % [RUN_FUZZ_CASES,accepted_runs,rejected_runs])

func _fuzz_run(i: int) -> Dictionary:
    var r := baseline_run.duplicate(true)
    match i % 16:
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

func _save_file_corruption_gate() -> void:
    var payloads := [
        "",
        "{",
        "[]",
        "null",
        "\"text\"",
        "{\"profile\":42,\"run\":{}}",
        "{\"profile\":{},\"run\":[]}",
        "{\"profile\":{\"profile_schema_version\":999},\"run\":{}}",
    ]
    expect(payloads.size() == SAVE_FILE_CASES, "11.2 file fuzz fixture count mismatch")
    for case_index in range(payloads.size()):
        _restore_baseline()
        var file := FileAccess.open(SaveService.SAVE_PATH, FileAccess.WRITE)
        expect(file != null, "11.2 could not open save path for corruption case=%d" % case_index)
        if file == null:
            continue
        file.store_string(str(payloads[case_index]))
        file.close()
        var loaded := SaveService.load_game()
        expect(not loaded, "11.2 corrupted save file was accepted case=%d payload=%s" % [case_index,str(payloads[case_index])])
        _expect_baseline_unchanged("corrupted save file case=%d" % case_index)
        if not loaded: file_rejections += 1
    expect(file_rejections == SAVE_FILE_CASES, "11.2 corrupted file rejection count mismatch: %d" % file_rejections)
    print("11.2 file corruption: rejected=%d/%d" % [file_rejections,SAVE_FILE_CASES])

func _canonical_roundtrip_gate() -> void:
    _restore_baseline()
    var before_fp := migration.progress_fingerprint().duplicate(true)
    var before_run := GameState.run.duplicate(true)
    expect(SaveService.save_game(), "11.2 canonical save failed")
    GameState.reset_profile()
    GameState.run = {}
    expect(SaveService.load_game(), "11.2 canonical reload failed")
    var report := migration.audit_live_profile()
    expect(bool(report.get("ok",false)), "11.2 canonical reload audit failed: %s" % str(report.get("errors",[])))
    expect(migration.progress_fingerprint() == before_fp, "11.2 canonical roundtrip changed progression fingerprint")
    expect(str((GameState.run.get("flags",{}) as Dictionary).get("save_fuzz.sentinel","")) == "preserve", "11.2 canonical roundtrip lost run sentinel")
    expect(str(GameState.run.get("character_id","")) == str(before_run.get("character_id","")), "11.2 canonical roundtrip changed character")
    expect(int(GameState.run.get("seed",0)) == int(before_run.get("seed",0)), "11.2 canonical roundtrip changed seed")
    print("11.2 canonical roundtrip: schema=%d fingerprint preserved" % int(GameState.profile.get("profile_schema_version",0)))

func _expect_baseline_unchanged(label: String) -> void:
    expect(GameState.profile == baseline_profile, "11.2 %s mutated profile" % label)
    expect(GameState.run == baseline_run, "11.2 %s mutated run" % label)
    expect(migration.progress_fingerprint() == baseline_fingerprint, "11.2 %s changed progression fingerprint" % label)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: SAVE_FUZZ_CERTIFICATION: %s" % message)

func _finish() -> void:
    if failures.is_empty():
        print("SAVE_FUZZ_CERTIFICATION PASS: 11.2 profile_cases=%d run_cases=%d file_cases=%d accepted_profiles=%d rejected_profiles=%d accepted_runs=%d rejected_runs=%d" % [PROFILE_FUZZ_CASES,RUN_FUZZ_CASES,SAVE_FILE_CASES,accepted_profiles,rejected_profiles,accepted_runs,rejected_runs])
        get_tree().quit(0)
    else:
        print("SAVE_FUZZ_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)
