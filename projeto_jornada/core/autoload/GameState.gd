extends Node

var profile: Dictionary = {}
var run: Dictionary = {}

func _ready() -> void:
    reset_profile()

func reset_profile() -> void:
    profile = {
        "unlocked_characters":["character.mata_fio_verde.01"],
        "codex":[],
        "codex_records":{},
        "discovery_history":[],
        "achievements":{},
        "echo_marks":{},
        "consequences":{},
        "endings":[],
        "settings":{},
        "meta_economy":{},
        "saved_journey_presets":{},
        "saved_seeds":[],
        "codex_pins":[],
        "unlocks":{
            "characters":["character.mata_fio_verde.01"],
            "routes":["world.mata_fio_verde"],
            "modes":["journey"],
            "codex":["character.mata_fio_verde.01","world.mata_fio_verde"]
        }
    }

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
    if not run.is_empty():
        run.rng = RNGService.snapshot()
    return {"profile":profile,"run":run}

func deserialize(data: Dictionary) -> void:
    profile = data.get("profile", {})
    run = data.get("run", {})
    CodexProgressEngine.new().ensure_state()
    MetaEconomyEngine.new().ensure_state()
    if not run.is_empty():
        var setup_engine := JourneySetupEngine.new()
        run = setup_engine.normalize_run_state(run)
    if not run.is_empty() and run.has("rng"):
        RNGService.restore(run.rng)
