extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _check_arc_file()
    _check_pt_br_paths()
    _check_english_surface()
    if failures.is_empty():
        print("GOLDEN_SLICE_SMOKE PASS")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("GOLDEN_SLICE_SMOKE: %s" % failure)
        print("GOLDEN_SLICE_SMOKE FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _fresh_run(locale_id: String = "pt_BR") -> void:
    GameState.reset_profile()
    var settings: Dictionary = GameState.profile.get("settings", {}) as Dictionary
    settings["locale"] = locale_id
    GameState.profile.settings = settings
    GameState.new_run("character.mata_fio_verde.01", 991337)
    expect(AuthoredStoryDirector.activate_for_new_run(), "authored arc did not activate")
    expect(AuthoredStoryDirector.is_active(), "authored arc not active after activation")

func _event() -> Dictionary:
    var event := RunFlowEngine.story_event()
    expect(not event.is_empty(), "story_event returned empty authored scene")
    expect(AuthoredStoryDirector.is_authored_event(event), "story_event fell back to procedural content")
    expect(str(event.get("title", "")).strip_edges() != "", "authored scene title missing")
    expect(str(event.get("text", "")).length() >= 120, "authored scene text is too short to carry a scene")
    var choices: Array = event.get("choices", []) as Array
    expect(choices.size() == 3, "authored scene must expose exactly three deliberate choices")
    var seen := {}
    for choice_variant in choices:
        var choice: Dictionary = choice_variant as Dictionary
        var text := str(choice.get("text", "")).strip_edges()
        expect(text.length() >= 24, "authored choice lacks readable intention: %s" % text)
        expect(not seen.has(text), "authored choices are duplicated")
        seen[text] = true
    return event

func _choose(index: int) -> void:
    var event := _event()
    expect(RunFlowEngine.choose(event, index), "authored choice %d failed in %s" % [index, event.get("authored_scene_id", "?")])

func _check_arc_file() -> void:
    expect(FileAccess.file_exists("res://content_authored/mata_fio_verde_golden_slice.json"), "golden slice JSON missing from project")
    var file := FileAccess.open("res://content_authored/mata_fio_verde_golden_slice.json", FileAccess.READ)
    expect(file != null, "golden slice JSON cannot be opened")
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    expect(typeof(parsed) == TYPE_DICTIONARY, "golden slice JSON parse failed")
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var arc: Dictionary = parsed as Dictionary
    expect(str(arc.get("arc_id", "")) == "golden_slice.mata_fio_verde.01", "arc identity mismatch")
    expect((arc.get("scenes", {}) as Dictionary).size() >= 7, "golden slice needs at least seven authored scenes")
    expect((arc.get("endings", {}) as Dictionary).size() == 3, "golden slice needs three authored endings")

func _check_pt_br_surface(event: Dictionary) -> void:
    var surface := "%s\n%s\n%s" % [event.get("kicker", ""), event.get("title", ""), event.get("text", "")]
    for choice_variant in event.get("choices", []):
        surface += "\n" + str((choice_variant as Dictionary).get("text", ""))
    expect("Hazard" not in surface, "PT-BR authored surface leaked Hazard")
    expect("defeat" not in surface.to_lower(), "PT-BR authored surface leaked defeat")

func _check_pt_br_paths() -> void:
    # Ending 1: rescue Tori, trust her, call the hound by name, save Cathedral by erasing self.
    _fresh_run("pt_BR")
    var event := _event()
    _check_pt_br_surface(event)
    expect("Tori" in str(event.get("text", "")), "opening does not introduce named character Tori")
    expect(RunFlowEngine.choose(event, 0), "opening rescue choice failed")
    event = _event()
    _check_pt_br_surface(event)
    expect("mapa" in str(event.get("text", "")).to_lower(), "Tori scene lacks concrete map clue")
    expect(RunFlowEngine.choose(event, 0), "Tori trust choice failed")
    event = _event()
    _check_pt_br_surface(event)
    expect(str(event.get("authored_scene_id", "")) == "root_bridge", "path did not reach root bridge")
    expect(RunFlowEngine.choose(event, 0), "hound recognition choice failed")
    event = _event()
    _check_pt_br_surface(event)
    expect("Cartógrafo" in str(event.get("text", "")), "antagonist reveal missing")
    expect(RunFlowEngine.choose(event, 1), "save Cathedral clue choice failed")
    event = _event()
    _check_pt_br_surface(event)
    expect(RunFlowEngine.choose(event, 0), "nameless guardian ending choice failed")
    var debrief := RunFlowEngine.debrief().get("authored_debrief", {}) as Dictionary
    expect(str(debrief.get("ending_key", "")) == "nameless_guardian", "wrong first ending")
    expect(str(debrief.get("text", "")).length() >= 240, "first ending lacks narrative payoff")
    expect("Tori" in str(debrief.get("text", "")), "first ending does not pay back Tori")

    # Ending 2: investigate signature, conceal it, evade guardian, open box, follow future self.
    _fresh_run("pt_BR")
    _choose(1)
    _choose(1)
    _choose(1)
    _choose(0)
    _choose(1)
    debrief = RunFlowEngine.debrief().get("authored_debrief", {}) as Dictionary
    expect(str(debrief.get("ending_key", "")) == "future_trail", "wrong second ending")
    expect("Catedral" in str(debrief.get("text", "")), "second ending does not pay its central loss")

    # Ending 3: cut the message, demand truth, choose combat, inspect transition, preserve contradiction.
    _fresh_run("pt_BR")
    _choose(2)
    _choose(1)
    var bridge := _event()
    expect(RunFlowEngine.choose(bridge, 2), "combat-intent choice failed")
    var transition := AuthoredStoryDirector.consume_transition()
    expect(str(transition.get("type", "")) == "combat", "combat transition missing")
    expect(str(transition.get("enemy_id", "")) == "monster.mata_fio_verde.01", "combat transition enemy mismatch")
    var enemy := ContentRegistry.get_record(str(transition.get("enemy_id", "")))
    expect(not enemy.is_empty(), "authored combat references missing enemy")
    _choose(2)
    _choose(2)
    debrief = RunFlowEngine.debrief().get("authored_debrief", {}) as Dictionary
    expect(str(debrief.get("ending_key", "")) == "living_contradiction", "wrong third ending")
    expect("duas" in str(debrief.get("text", "")).to_lower(), "third ending does not express contradiction payoff")

func _check_english_surface() -> void:
    _fresh_run("en")
    var event := _event()
    expect(str(event.get("title", "")) == "The tree that knows your name", "English authored title not selected")
    expect("Tori" in str(event.get("text", "")), "English opening lost named character")
    expect("Hazard" not in str(event.get("title", "")), "English surface exposed internal taxonomy")
