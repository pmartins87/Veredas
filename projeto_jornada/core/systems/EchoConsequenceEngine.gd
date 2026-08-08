extends Node

func ensure_state() -> void:
    if typeof(GameState.profile.get("echo_marks", {})) != TYPE_DICTIONARY:
        GameState.profile.echo_marks = {}
    if typeof(GameState.profile.get("consequences", {})) != TYPE_DICTIONARY:
        GameState.profile.consequences = {}

func record_outcome(ending_id: String = "", result: String = "victory") -> Dictionary:
    ensure_state()
    var echo_marks: Dictionary = GameState.profile.get("echo_marks", {}) as Dictionary
    var run_marks: Dictionary = GameState.run.get("marks", {}) as Dictionary
    var world_id: String = str(GameState.run.get("world_id", ""))
    var now: int = int(Time.get_unix_time_from_system())

    for mark_id_variant in run_marks.keys():
        var mark_id: String = str(mark_id_variant)
        var intensity: int = int(run_marks.get(mark_id, 0))
        if intensity <= 0 or ContentRegistry.get_record(mark_id).is_empty():
            continue
        var prior: Dictionary = echo_marks.get(mark_id, {}) as Dictionary
        echo_marks[mark_id] = {
            "mark_id":mark_id,
            "max_intensity":maxi(int(prior.get("max_intensity",0)), intensity),
            "encounters":int(prior.get("encounters",0)) + 1,
            "world_id":world_id,
            "last_result":result,
            "last_ending":ending_id,
            "last_seen":now,
        }
    GameState.profile.echo_marks = echo_marks

    if ending_id != "":
        var consequences: Dictionary = GameState.profile.get("consequences", {}) as Dictionary
        var prior_consequence: Dictionary = consequences.get(ending_id, {}) as Dictionary
        consequences[ending_id] = {
            "ending_id":ending_id,
            "world_id":world_id,
            "witnessed":true,
            "count":int(prior_consequence.get("count",0)) + 1,
            "first_seen":int(prior_consequence.get("first_seen",now)),
            "last_seen":now,
        }
        GameState.profile.consequences = consequences

    return snapshot()

func apply_to_run() -> Dictionary:
    ensure_state()
    var context := snapshot()
    GameState.run.echo_context = context
    return context

func has_echo(mark_id: String, minimum_intensity: int = 1) -> bool:
    ensure_state()
    var record: Dictionary = (GameState.profile.get("echo_marks", {}) as Dictionary).get(mark_id, {}) as Dictionary
    return int(record.get("max_intensity",0)) >= minimum_intensity

func echo_intensity(mark_id: String) -> int:
    ensure_state()
    var record: Dictionary = (GameState.profile.get("echo_marks", {}) as Dictionary).get(mark_id, {}) as Dictionary
    return int(record.get("max_intensity",0))

func ending_witnessed(ending_id: String) -> bool:
    ensure_state()
    var consequences: Dictionary = GameState.profile.get("consequences", {}) as Dictionary
    if consequences.has(ending_id):
        return bool((consequences[ending_id] as Dictionary).get("witnessed",false))
    return ending_id in (GameState.profile.get("endings", []) as Array)

func consequence(ending_id: String) -> Dictionary:
    ensure_state()
    return ((GameState.profile.get("consequences", {}) as Dictionary).get(ending_id, {}) as Dictionary).duplicate(true)

func snapshot() -> Dictionary:
    ensure_state()
    return {
        "echo_marks":(GameState.profile.get("echo_marks", {}) as Dictionary).duplicate(true),
        "consequences":(GameState.profile.get("consequences", {}) as Dictionary).duplicate(true),
        "endings":(GameState.profile.get("endings", []) as Array).duplicate(),
    }

func summary() -> Dictionary:
    ensure_state()
    return {
        "echo_marks":(GameState.profile.get("echo_marks", {}) as Dictionary).size(),
        "consequences":(GameState.profile.get("consequences", {}) as Dictionary).size(),
        "endings":(GameState.profile.get("endings", []) as Array).size(),
    }
