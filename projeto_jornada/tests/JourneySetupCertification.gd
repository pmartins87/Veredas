extends Node

var failures: Array[String] = []
var setup_engine := JourneySetupEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    GameState.reset_profile()
    GameState.run = {}
    HubEngine.ensure_state()
    MetaUnlockEngine.ensure_state()

    _default_setup_gate()
    _validation_gate()
    _fixed_seed_and_no_trade_gate()
    _light_pack_and_persistence_gate()
    _scene_gate()
    _finish()

func _default_setup_gate() -> void:
    var setup: Dictionary = setup_engine.default_setup()
    expect(str(setup.get("world_id", "")) == "world.mata_fio_verde", "9.4 default route mismatch")
    expect(str(setup.get("character_id", "")) == "character.mata_fio_verde.01", "9.4 default character mismatch")
    expect(str(setup.get("journey_mode", "")) == "journey", "9.4 default mode mismatch")
    expect(str(setup.get("difficulty_id", "")) == "andarilho", "9.4 default difficulty mismatch")
    expect(bool(setup_engine.validate(setup).get("ok", false)), "9.4 default setup is invalid")
    expect(setup_engine.difficulty_options().size() == 4, "9.4 expected four difficulty profiles")

func _validation_gate() -> void:
    var invalid_route := setup_engine.default_setup()
    invalid_route.world_id = "world.varzea_espelhos"
    var route_check: Dictionary = setup_engine.validate(invalid_route)
    expect(not bool(route_check.get("ok", true)), "9.4 locked route accepted")
    expect("route_locked" in (route_check.get("errors", []) as Array), "9.4 locked route error missing")

    var invalid_difficulty := setup_engine.default_setup()
    invalid_difficulty.difficulty_id = "impossivel"
    var difficulty_check: Dictionary = setup_engine.validate(invalid_difficulty)
    expect("difficulty_unknown" in (difficulty_check.get("errors", []) as Array), "9.4 unknown difficulty accepted")

    var locked_mode := setup_engine.default_setup()
    locked_mode.journey_mode = "fixed_seed"
    locked_mode.seed = 424242
    var mode_check: Dictionary = setup_engine.validate(locked_mode)
    expect("mode_locked" in (mode_check.get("errors", []) as Array), "9.4 locked mode accepted")

func _fixed_seed_and_no_trade_gate() -> void:
    var canonical_endings := _canonical_endings()
    expect(canonical_endings.size() >= 2, "9.4 needs at least two canonical endings")
    if canonical_endings.is_empty():
        return
    GameState.profile.endings = [canonical_endings[0]]
    MetaUnlockEngine.evaluate_progression()
    expect(MetaUnlockEngine.is_mode_unlocked("fixed_seed"), "9.4 first ending did not unlock fixed seed mode")
    expect(setup_engine.modifier_available("sem_trocas"), "9.4 first ending did not unlock no-trade modifier")

    var setup := setup_engine.default_setup()
    setup.journey_mode = "fixed_seed"
    setup.difficulty_id = "severa"
    setup.seed = 424242
    setup.modifiers = ["sem_trocas"]
    var check: Dictionary = setup_engine.validate(setup)
    expect(bool(check.get("ok", false)), "9.4 valid fixed-seed setup rejected: %s" % str(check.get("errors", [])))
    expect(setup_engine.start(setup), "9.4 fixed-seed setup did not start")
    expect(int(GameState.run.get("seed", 0)) == 424242, "9.4 explicit seed not preserved")
    expect(str(GameState.run.get("journey_mode", "")) == "fixed_seed", "9.4 journey mode not persisted")
    expect(str(GameState.run.get("difficulty_id", "")) == "severa", "9.4 difficulty not persisted")
    expect("sem_trocas" in (GameState.run.get("modifiers", []) as Array), "9.4 modifier list not persisted")
    expect(bool((GameState.run.get("flags", {}) as Dictionary).get("modifier.no_trade", false)), "9.4 no-trade flag missing")
    expect(MerchantEngine.stock("world.mata_fio_verde", 8).is_empty(), "9.4 no-trade modifier still returned merchant stock")
    var any_item := _first_world_item("world.mata_fio_verde")
    if any_item != "":
        expect(not MerchantEngine.can_buy(any_item), "9.4 no-trade modifier still allowed purchase")
    expect(int(GameState.run.get("max_health", 0)) == 16, "9.4 difficulty prematurely changed max health")
    expect(int(GameState.run.get("max_vigor", 0)) == 8, "9.4 difficulty prematurely changed max vigor")

func _light_pack_and_persistence_gate() -> void:
    var canonical_endings := _canonical_endings()
    if canonical_endings.size() < 2:
        return
    GameState.profile.endings = [canonical_endings[0], canonical_endings[1]]
    MetaUnlockEngine.evaluate_progression()
    expect(setup_engine.modifier_available("mochila_leve"), "9.4 second ending did not unlock light-pack modifier")

    var setup := setup_engine.default_setup()
    setup.difficulty_id = "andarilho"
    setup.seed = 430001
    setup.modifiers = ["mochila_leve"]
    expect(setup_engine.start(setup), "9.4 light-pack setup did not start")
    expect(int((GameState.run.get("resources", {}) as Dictionary).get("provisions", 99)) <= 1, "9.4 light-pack modifier did not cap provisions")
    expect(bool((GameState.run.get("flags", {}) as Dictionary).get("modifier.light_pack", false)), "9.4 light-pack flag missing")
    var saved_setup: Dictionary = (GameState.run.get("setup", {}) as Dictionary).duplicate(true)
    expect(SaveService.save_game(), "9.4 setup save failed")
    GameState.run.setup = {}
    expect(SaveService.load_game(), "9.4 setup reload failed")
    expect((GameState.run.get("setup", {}) as Dictionary) == saved_setup, "9.4 setup changed after save/load")

func _scene_gate() -> void:
    expect(ResourceLoader.exists("res://scenes/JourneySetup.tscn"), "9.4 setup scene missing")
    var packed := ResourceLoader.load("res://scenes/JourneySetup.tscn") as PackedScene
    expect(packed != null, "9.4 setup scene could not be loaded")
    if packed != null:
        var instance := packed.instantiate()
        expect(instance != null, "9.4 setup scene could not instantiate")
        if instance != null:
            instance.queue_free()

func _canonical_endings() -> Array[String]:
    var result: Array[String] = []
    for ending_variant in ContentRegistry.all("finals"):
        var ending: Dictionary = ending_variant as Dictionary
        var ending_id := str(ending.get("id", ""))
        if ending_id != "":
            result.append(ending_id)
    result.sort()
    return result

func _first_world_item(world_id: String) -> String:
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("world_id", "")) == world_id:
            return str(item.get("id", ""))
    return ""

func _finish() -> void:
    if failures.is_empty():
        print("JOURNEY_SETUP_CERTIFICATION PASS: 9.4")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("JOURNEY_SETUP_CERTIFICATION: %s" % failure)
        print("JOURNEY_SETUP_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
