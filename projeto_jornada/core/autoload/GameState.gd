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
    run = {
        "active":true,
        "mode":"story",
        "character_id":character_id,
        "world_id":world_id,
        "location_id":first_location,
        "health":16,"max_health":16,
        "vigor":8,"max_vigor":8,
        "resources":{"fragments":12,"essence":0,"provisions":3},
        "marks":{},"flags":{},"inventory":[],"equipped":{},"debts":[],
        "recent_events":[],"event_counts":{},"turn":0,
        "visited_locations":[first_location],"defeated_enemies":[],"purchases":[],"ending_id":"",
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

    var previous_profile := profile.duplicate(true)
    var previous_run := run.duplicate(true)
    profile = migration.migrate_raw(raw_profile)
    run = (run_raw as Dictionary).duplicate(true)

    var report := migration.normalize_live_profile()
    if not bool(report.get("ok", false)):
        push_error("Profile migration integrity failure: %s" % str(report.get("errors", [])))
        profile = previous_profile
        run = previous_run
        return false

    if not run.is_empty():
        var setup_engine := JourneySetupEngine.new()
        run = setup_engine.normalize_run_state(run)
    if not run.is_empty() and run.has("rng"):
        RNGService.restore(run.rng)
    return true
