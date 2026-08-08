extends Node

var failures: Array[String] = []
var codex := CodexProgressEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    GameState.reset_profile()
    GameState.run = {}
    MetaUnlockEngine.ensure_state()
    codex.ensure_state()

    _migration_and_history_gate()
    _collection_gate()
    _achievement_gate()
    _save_load_gate()
    _no_power_gate()
    _scene_gate()
    _finish()

func _migration_and_history_gate() -> void:
    expect(codex.record("character.mata_fio_verde.01").size() > 0, "9.5 legacy character Codex entry did not migrate")
    expect(codex.record("world.mata_fio_verde").size() > 0, "9.5 legacy world Codex entry did not migrate")

    var monster_id := "monster.mata_fio_verde.01"
    expect(not ContentRegistry.get_record(monster_id).is_empty(), "9.5 canonical sample monster missing")
    var history_before := codex.history(0).size()
    expect(codex.discover(monster_id, "test_discovery"), "9.5 valid discovery rejected")
    var first_record := codex.record(monster_id)
    expect(str(first_record.get("category", "")) == "monster", "9.5 discovery category mismatch")
    expect(int(first_record.get("encounters", 0)) == 1, "9.5 first encounter count mismatch")
    expect(codex.history(0).size() == history_before + 1, "9.5 first discovery missing from history")

    expect(codex.discover(monster_id, "repeat"), "9.5 repeated discovery rejected")
    var repeated_record := codex.record(monster_id)
    expect(int(repeated_record.get("encounters", 0)) == 2, "9.5 repeated encounter did not increment count")
    expect(codex.history(0).size() == history_before + 1, "9.5 repeated encounter duplicated discovery history")

    var second_world := "world.varzea_espelhos"
    expect(MetaUnlockEngine.unlock_route(second_world), "9.5 route unlock failed")
    var route_record := codex.record(second_world)
    expect(str(route_record.get("source", "")) == "route_unlock", "9.5 route unlock source was not recorded")

func _collection_gate() -> void:
    var item_ids := _ids("items", 25)
    var monster_ids := _ids("monsters", 25)
    expect(item_ids.size() == 25, "9.5 insufficient canonical items for collection gate")
    expect(monster_ids.size() == 25, "9.5 insufficient canonical monsters for collection gate")
    for content_id in item_ids:
        codex.discover(content_id, "collection_test")
    for content_id in monster_ids:
        codex.discover(content_id, "collection_test")
    var collection := codex.collection_summary()
    var discovered: Dictionary = collection.get("discovered", {}) as Dictionary
    var total: Dictionary = collection.get("total", {}) as Dictionary
    expect(int(discovered.get("item", 0)) >= 25, "9.5 item collection count mismatch")
    expect(int(discovered.get("monster", 0)) >= 25, "9.5 monster collection count mismatch")
    expect(int(total.get("item", 0)) == 1116, "9.5 item collection total mismatch")
    expect(int(total.get("monster", 0)) == 300, "9.5 monster collection total mismatch")

func _achievement_gate() -> void:
    var endings := _ids("finals", 1)
    expect(not endings.is_empty(), "9.5 canonical ending missing")
    if not endings.is_empty():
        GameState.profile.endings = [endings[0]]
    GameState.profile.echo_marks = {"mark.mata_fio_verde.01":{"max_intensity":1}}
    codex.evaluate_achievements()
    expect(_achievement_unlocked("first_trace"), "9.5 first-trace achievement missing")
    expect(_achievement_unlocked("first_ending"), "9.5 first-ending achievement missing")
    expect(_achievement_unlocked("collector_25"), "9.5 25-item achievement missing")
    expect(_achievement_unlocked("bestiary_25"), "9.5 bestiary achievement missing")
    expect(_achievement_unlocked("echo_witness"), "9.5 Echo achievement missing")

    MetaUnlockEngine.unlock_route("world.costa_sinos_afogados")
    MetaUnlockEngine.unlock_route("world.varzea_espelhos")
    codex.evaluate_achievements()
    expect(_achievement_unlocked("three_routes"), "9.5 three-route achievement missing")

    for achievement_variant in codex.achievements():
        var achievement: Dictionary = achievement_variant as Dictionary
        expect(int(achievement.get("progress", 0)) >= 0, "9.5 negative achievement progress")
        expect(int(achievement.get("target", 0)) > 0, "9.5 invalid achievement target")

func _save_load_gate() -> void:
    var monster_id := "monster.mata_fio_verde.01"
    var encounters_before := int(codex.record(monster_id).get("encounters", 0))
    var history_before := codex.history(0).size()
    var achievements_before := codex.unlocked_achievement_count()
    var overall_before := int(codex.collection_summary().get("overall", 0))
    expect(SaveService.save_game(), "9.5 save failed")

    GameState.profile.codex_records = {}
    GameState.profile.discovery_history = []
    GameState.profile.achievements = {}
    GameState.profile.codex = []
    expect(SaveService.load_game(), "9.5 reload failed")

    expect(int(codex.record(monster_id).get("encounters", 0)) == encounters_before, "9.5 encounter count changed after save/load")
    expect(codex.history(0).size() == history_before, "9.5 discovery history changed after save/load")
    expect(codex.unlocked_achievement_count() == achievements_before, "9.5 achievement state changed after save/load")
    expect(int(codex.collection_summary().get("overall", 0)) == overall_before, "9.5 collection size changed after save/load")

func _no_power_gate() -> void:
    MetaUnlockEngine.evaluate_progression()
    expect(RunFlowEngine.start_journey("character.mata_fio_verde.01", 95001), "9.5 could not start power-neutrality journey")
    expect(int(GameState.run.get("max_health", 0)) == 16, "9.5 Codex/achievement progression altered max health")
    expect(int(GameState.run.get("max_vigor", 0)) == 8, "9.5 Codex/achievement progression altered max vigor")

func _scene_gate() -> void:
    expect(ResourceLoader.exists("res://scenes/Codex.tscn"), "9.5 Codex scene missing")
    var packed := ResourceLoader.load("res://scenes/Codex.tscn") as PackedScene
    expect(packed != null, "9.5 Codex scene could not load")
    if packed != null:
        var instance := packed.instantiate()
        expect(instance != null, "9.5 Codex scene could not instantiate")
        if instance != null:
            instance.queue_free()

func _achievement_unlocked(achievement_id: String) -> bool:
    for achievement_variant in codex.achievements():
        var achievement: Dictionary = achievement_variant as Dictionary
        if str(achievement.get("id", "")) == achievement_id:
            return bool(achievement.get("unlocked", false))
    return false

func _ids(group: String, limit: int) -> Array[String]:
    var result: Array[String] = []
    for record_variant in ContentRegistry.all(group):
        var record: Dictionary = record_variant as Dictionary
        var content_id := str(record.get("id", ""))
        if content_id != "":
            result.append(content_id)
        if result.size() >= limit:
            break
    return result

func _finish() -> void:
    if failures.is_empty():
        print("CODEX_PROGRESS_CERTIFICATION PASS: 9.5")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("CODEX_PROGRESS_CERTIFICATION: %s" % failure)
        print("CODEX_PROGRESS_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
