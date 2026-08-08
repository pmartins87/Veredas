extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    GameState.reset_profile()
    GameState.run = {}
    MetaUnlockEngine.ensure_state()
    EchoConsequenceEngine.ensure_state()

    var mark_id := "mark.mata_fio_verde.01"
    expect(not ContentRegistry.get_record(mark_id).is_empty(), "9.3 canonical sample mark missing")
    expect(RunFlowEngine.start_journey("character.mata_fio_verde.01", 93001), "9.3 could not start baseline journey")
    var base_health := int(GameState.run.get("max_health", 0))
    var base_vigor := int(GameState.run.get("max_vigor", 0))

    GameState.add_mark(mark_id, 3)
    expect(int(GameState.run.get("marks", {}).get(mark_id, 0)) == 3, "9.3 run mark intensity mismatch")

    var endings := RunFlowEngine.endings_for_current_world()
    expect(not endings.is_empty(), "9.3 no ending available for canonical world")
    if endings.is_empty():
        _finish()
        return
    var ending_id := str((endings[0] as Dictionary).get("id", ""))
    expect(RunFlowEngine.finish(ending_id), "9.3 could not finish journey")

    expect(EchoConsequenceEngine.has_echo(mark_id, 3), "9.3 mark did not become persistent Echo")
    expect(EchoConsequenceEngine.echo_intensity(mark_id) == 3, "9.3 Echo intensity was not preserved")
    expect(EchoConsequenceEngine.ending_witnessed(ending_id), "9.3 ending consequence was not recorded")
    expect(ConditionEngine.evaluate({"op":"echo_mark_has","mark_id":mark_id}), "9.3 echo_mark_has condition failed")
    expect(ConditionEngine.evaluate({"op":"echo_mark_intensity_gte","mark_id":mark_id,"value":3}), "9.3 Echo intensity condition failed")
    expect(ConditionEngine.evaluate({"op":"ending_witnessed","ending_id":ending_id}), "9.3 ending_witnessed condition failed")
    expect(not ConditionEngine.evaluate({"op":"echo_mark_intensity_gte","mark_id":mark_id,"value":4}), "9.3 Echo intensity condition accepted excessive threshold")

    var consequence := EchoConsequenceEngine.consequence(ending_id)
    expect(bool(consequence.get("witnessed", false)), "9.3 consequence record missing witnessed flag")
    expect(int(consequence.get("count", 0)) == 1, "9.3 first consequence count mismatch")

    expect(RunFlowEngine.start_journey("character.mata_fio_verde.01", 93002), "9.3 could not start second journey")
    var echo_context: Dictionary = GameState.run.get("echo_context", {}) as Dictionary
    var context_echoes: Dictionary = echo_context.get("echo_marks", {}) as Dictionary
    var context_consequences: Dictionary = echo_context.get("consequences", {}) as Dictionary
    expect(context_echoes.has(mark_id), "9.3 second journey did not receive Echo context")
    expect(context_consequences.has(ending_id), "9.3 second journey did not receive ending consequence context")
    expect(int(GameState.run.get("max_health", 0)) == base_health, "9.3 persistent memory changed base health")
    expect(int(GameState.run.get("max_vigor", 0)) == base_vigor, "9.3 persistent memory changed base vigor")

    var before_save := EchoConsequenceEngine.snapshot()
    expect(SaveService.save_game(), "9.3 save failed")
    GameState.profile.echo_marks = {}
    GameState.profile.consequences = {}
    GameState.profile.endings = []
    expect(SaveService.load_game(), "9.3 reload failed")
    expect(EchoConsequenceEngine.snapshot() == before_save, "9.3 Echo/consequence state changed after save-load")

    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("ECHO_CONSEQUENCE_CERTIFICATION PASS: 9.3")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("ECHO_CONSEQUENCE_CERTIFICATION: %s" % failure)
        print("ECHO_CONSEQUENCE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
