extends Node

var profile: Dictionary = {}
var run: Dictionary = {}

func _ready() -> void:
    reset_profile()

func reset_profile() -> void:
    profile = ProfileMigrationEngine.new().fresh_profile()
    run = {}

func new_run(character_id: String, seed_value: int) -> void:
    RNGService.start(seed_value)
    var character: Dictionary = ContentRegistry.get_record(character_id)
    var world_id := str(character.get("world_id", "world.mata_fio_verde"))
    var world: Dictionary = ContentRegistry.get_record(world_id)
    var locs: Array = world.get("locations", ["location.mata_fio_verde.01"])
    var first_location := str(locs[0])
    var base_health := maxi(1, int(character.get("base_health", 16)))
    var base_vigor := maxi(1, int(character.get("base_vigor", 8)))
    var base_posture := maxi(1, int(character.get("base_posture", 10)))
    var base_guard := maxi(0, int(character.get("base_guard", 0)))
    run = {
        "active":true,
        "mode":"story",
        "character_id":character_id,
        "world_id":world_id,
        "location_id":first_location,
        "health":base_health,"max_health":base_health,
        "vigor":base_vigor,"max_vigor":base_vigor,
        "base_posture":base_posture,"base_guard":base_guard,
        "learning_curve":(character.get("learning_curve", {}) as Dictionary).duplicate(true),
        "resources":{"fragments":12,"essence":0,"provisions":3},
        "marks":{},"flags":{},"inventory":[],"equipped":{},"debts":[],
        "recent_events":[],"event_counts":{},"event_last_turn":{},"turn":0,
        "visited_locations":[first_location],"defeated_enemies":[],"purchases":[],"loot_found":[],"ending_id":"",
        "echo_context":{},
        "seed":seed_value,"rng":RNGService.snapshot()
    }
    PresentationBus.location(first_location)

func add_mark(mark_id: String, amount: int = 1) -> void:
    var marks: Dictionary = run.get("marks", {})
    var before := int(marks.get(mark_id, 0))
    marks[mark_id] = clampi(before + amount, 0, 5)
    run.marks = marks
    if int(marks[mark_id]) > before:
        PresentationBus.mark(mark_id)

func serialize() -> Dictionary:
    var migration := ProfileMigrationEngine.new()
    var report := migration.normalize_live_profile()
    if not bool(report.get("ok", false)):
        push_error("Profile integrity failed before save: %s" % str(report.get("errors", [])))
    if not run.is_empty():
        run.rng = RNGService.snapshot()
    return {"profile":profile.duplicate(true),"run":run.duplicate(true)}

func deserialize(data: Dictionary) -> bool:
    if not data.has("profile") or typeof(data.get("profile")) != TYPE_DICTIONARY:
        push_error("Save profile is missing or invalid")
        return false
    var run_raw = data.get("run", {})
    if typeof(run_raw) != TYPE_DICTIONARY:
        push_error("Save run state is invalid")
        return false

    var raw_profile: Dictionary = data.get("profile", {}) as Dictionary
    var migration := ProfileMigrationEngine.new()
    if not migration.can_migrate(raw_profile):
        push_error("Profile schema is newer than this build")
        return false

    var run_check := RunStateIntegrityEngine.new().normalize_and_audit(run_raw as Dictionary)
    if not bool(run_check.get("ok", false)):
        push_error("Run state integrity failure: %s" % str(run_check.get("errors", [])))
        return false

    var previous_profile := profile.duplicate(true)
    var previous_run := run.duplicate(true)
    var previous_rng := RNGService.snapshot().duplicate(true)
    profile = migration.migrate_raw(raw_profile)
    run = (run_check.get("run", {}) as Dictionary).duplicate(true)

    var report := migration.normalize_live_profile()
    if not bool(report.get("ok", false)):
        push_error("Profile migration integrity failure: %s" % str(report.get("errors", [])))
        profile = previous_profile
        run = previous_run
        RNGService.restore(previous_rng)
        return false

    if not run.is_empty() and run.has("rng"):
        RNGService.restore(run.rng)
    return true
