extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    GameState.reset_profile()
    GameState.run = {}
    HubEngine.ensure_state()
    MetaUnlockEngine.ensure_state()

    var initial: Dictionary = MetaUnlockEngine.summary()
    expect(int(initial.get("characters",0)) == 1, "9.2 initial character count must be one")
    expect(int(initial.get("routes",0)) == 1, "9.2 initial route count must be one")
    expect(int(initial.get("modes",0)) == 1, "9.2 initial mode count must be one")
    expect(MetaUnlockEngine.is_mode_unlocked("journey"), "9.2 base journey mode missing")

    var mata_characters: Array = _characters_for_world("world.mata_fio_verde")
    expect(mata_characters.size() == 3, "9.2 expected three Mata characters")
    if mata_characters.size() >= 2:
        var second_id: String = str((mata_characters[1] as Dictionary).get("id",""))
        expect(not MetaUnlockEngine.is_character_unlocked(second_id), "9.2 second Mata character unlocked too early")
        expect(not RunFlowEngine.start_journey(second_id, 92001), "9.2 locked character was allowed to start a journey")

    expect(RunFlowEngine.start_journey("character.mata_fio_verde.01", 92002), "9.2 could not start base character")
    var base_health: int = int(GameState.run.get("max_health",0))
    var base_vigor: int = int(GameState.run.get("max_vigor",0))
    var endings: Array = RunFlowEngine.endings_for_current_world()
    expect(not endings.is_empty(), "9.2 Mata ending missing")
    if not endings.is_empty():
        var ending_id: String = str((endings[0] as Dictionary).get("id",""))
        expect(RunFlowEngine.finish(ending_id), "9.2 could not record first ending")
        expect(MetaUnlockEngine.is_discovered(ending_id), "9.2 ending not added to Codex")
        expect(MetaUnlockEngine.is_mode_unlocked("fixed_seed"), "9.2 first ending did not unlock fixed-seed mode")
        if mata_characters.size() >= 2:
            var second_id: String = str((mata_characters[1] as Dictionary).get("id",""))
            expect(MetaUnlockEngine.is_character_unlocked(second_id), "9.2 first ending did not unlock second Mata character")
            expect(RunFlowEngine.start_journey(second_id, 92003), "9.2 newly unlocked character could not start")
            expect(int(GameState.run.get("max_health",0)) == base_health, "9.2 horizontal unlock changed base max health")
            expect(int(GameState.run.get("max_vigor",0)) == base_vigor, "9.2 horizontal unlock changed base max vigor")

    var second_world_id: String = "world.varzea_espelhos"
    expect(MetaUnlockEngine.unlock_route(second_world_id), "9.2 could not unlock a second route")
    expect(MetaUnlockEngine.is_route_unlocked(second_world_id), "9.2 second route state missing")
    var second_world_characters: Array = _characters_for_world(second_world_id)
    expect(second_world_characters.size() == 3, "9.2 expected three characters in second route")
    if not second_world_characters.is_empty():
        var route_character: String = str((second_world_characters[0] as Dictionary).get("id",""))
        expect(MetaUnlockEngine.is_character_unlocked(route_character), "9.2 route did not unlock its first character")

    var sample_monster: Dictionary = ContentRegistry.get_record("monster.mata_fio_verde.01")
    expect(not sample_monster.is_empty(), "9.2 sample monster missing")
    if not sample_monster.is_empty():
        expect(MetaUnlockEngine.discover("monster.mata_fio_verde.01"), "9.2 Codex discovery rejected valid content")
        expect(MetaUnlockEngine.is_discovered("monster.mata_fio_verde.01"), "9.2 Codex discovery did not persist in profile")

    var before_save: Dictionary = MetaUnlockEngine.ensure_state().duplicate(true)
    expect(SaveService.save_game(), "9.2 profile save failed")
    GameState.profile.unlocks = {}
    GameState.profile.unlocked_characters = []
    GameState.profile.codex = []
    expect(SaveService.load_game(), "9.2 profile reload failed")
    MetaUnlockEngine.ensure_state()
    expect(MetaUnlockEngine.ensure_state() == before_save, "9.2 unlock state changed after save/load")

    if failures.is_empty():
        print("META_UNLOCK_CERTIFICATION PASS: 9.2")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("META_UNLOCK_CERTIFICATION: %s" % failure)
        print("META_UNLOCK_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _characters_for_world(world_id: String) -> Array:
    var result: Array = []
    for character_variant in ContentRegistry.all("characters"):
        var character: Dictionary = character_variant as Dictionary
        if str(character.get("world_id","")) == world_id:
            result.append(character)
    result.sort_custom(func(a,b): return str((a as Dictionary).get("id","")) < str((b as Dictionary).get("id","")))
    return result
