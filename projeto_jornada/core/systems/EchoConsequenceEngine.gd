extends Node

func ensure_state() -> void:
    var raw_echoes = GameState.profile.get("echo_marks", {})
    var raw_consequences = GameState.profile.get("consequences", {})
    var raw_endings = GameState.profile.get("endings", [])

    var normalized_echoes: Dictionary = {}
    if typeof(raw_echoes) == TYPE_DICTIONARY:
        for mark_id_variant in (raw_echoes as Dictionary).keys():
            var mark_id := str(mark_id_variant)
            var raw_record = (raw_echoes as Dictionary).get(mark_id_variant, {})
            if typeof(raw_record) != TYPE_DICTIONARY:
                continue
            var record: Dictionary = raw_record as Dictionary
            normalized_echoes[mark_id] = {
                "mark_id":str(record.get("mark_id", mark_id)),
                "max_intensity":int(record.get("max_intensity", 0)),
                "encounters":int(record.get("encounters", 0)),
                "world_id":str(record.get("world_id", "")),
                "last_result":str(record.get("last_result", "")),
                "last_ending":str(record.get("last_ending", "")),
                "last_seen":int(record.get("last_seen", 0)),
            }

    var normalized_consequences: Dictionary = {}
    if typeof(raw_consequences) == TYPE_DICTIONARY:
        for ending_id_variant in (raw_consequences as Dictionary).keys():
            var ending_id := str(ending_id_variant)
            var raw_record = (raw_consequences as Dictionary).get(ending_id_variant, {})
            if typeof(raw_record) != TYPE_DICTIONARY:
                continue
            var record: Dictionary = raw_record as Dictionary
            normalized_consequences[ending_id] = {
                "ending_id":str(record.get("ending_id", ending_id)),
                "world_id":str(record.get("world_id", "")),
                "witnessed":bool(record.get("witnessed", false)),
                "count":int(record.get("count", 0)),
                "first_seen":int(record.get("first_seen", 0)),
                "last_seen":int(record.get("last_seen", 0)),
            }

    var normalized_endings: Array = []
    if typeof(raw_endings) == TYPE_ARRAY:
        for ending_variant in raw_endings as Array:
            var ending_id := str(ending_variant)
            if ending_id != "" and ending_id not in normalized_endings:
                normalized_endings.append(ending_id)

    GameState.profile.echo_marks = normalized_echoes
    GameState.profile.consequences = normalized_consequences
    GameState.profile.endings = normalized_endings

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
