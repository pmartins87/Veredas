extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _check_content()
    _check_rng()
    _check_run_and_event()
    _check_combat()
    _check_visual_assets()
    _check_theme()
    _check_accessibility_and_vfx()
    _check_save_roundtrip()
    if failures.is_empty():
        print("RUNTIME_SMOKE PASS")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("RUNTIME_SMOKE: %s" % failure)
        print("RUNTIME_SMOKE FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _check_content() -> void:
    expect(ContentRegistry.all("worlds").size() == 12, "expected 12 worlds")
    expect(ContentRegistry.all("locations").size() == 120, "expected 120 locations")
    expect(ContentRegistry.all("characters").size() == 36, "expected 36 characters")
    expect(ContentRegistry.all("monsters").size() == 300, "expected 300 monsters")
    expect(ContentRegistry.all("bosses").size() == 60, "expected 60 bosses")
    expect(ContentRegistry.all("items").size() == 1116, "expected 1116 items")
    expect(ContentRegistry.all("events").size() == 2544, "expected 2544 events")

func _check_rng() -> void:
    RNGService.start(987654)
    var seq_a := [RNGService.range_int(0, 1000000), RNGService.range_int(0, 1000000), RNGService.range_int(0, 1000000)]
    RNGService.start(987654)
    var seq_b := [RNGService.range_int(0, 1000000), RNGService.range_int(0, 1000000), RNGService.range_int(0, 1000000)]
    expect(seq_a == seq_b, "RNG is not deterministic")

func _check_run_and_event() -> void:
    GameState.new_run("character.mata_fio_verde.01", 12345)
    expect(str(GameState.run.get("world_id", "")) == "world.mata_fio_verde", "new run world mismatch")
    var event := EventDirector.choose_event(str(GameState.run.world_id), str(GameState.run.location_id))
    expect(not event.is_empty(), "EventDirector returned no event")
    if not event.is_empty():
        expect(event.get("choices", []).size() >= 2, "event has insufficient choices")
        var before := int(GameState.run.get("turn", 0))
        EventDirector.apply_choice(event, 0)
        expect(int(GameState.run.get("turn", 0)) == before + 1, "event choice did not advance turn")

func _check_combat() -> void:
    var state := CombatEngine.start("monster.mata_fio_verde.01", "character.mata_fio_verde.01")
    expect(state.get("active", false), "combat did not start")
    expect(not state.get("intent", {}).is_empty(), "enemy intent missing")
    var enemy_hp := int(state.enemy.hp)
    state = CombatEngine.player_action("strike")
    expect(int(state.enemy.hp) <= enemy_hp, "player strike increased enemy HP")
    expect(int(state.get("turn", 0)) >= 1, "combat turn invalid")

func _check_visual_assets() -> void:
    var asset_errors := VectorAtlasRegistry.validate_sources()
    expect(asset_errors.is_empty(), "vector atlases missing: %s" % [asset_errors])
    expect(VectorAtlasRegistry.system_icon("health") != null, "health icon unavailable")
    expect(VectorAtlasRegistry.domain_ornament("mata_fio_verde") != null, "domain ornament unavailable")
    expect(VectorAtlasRegistry.mark_glyph("action", 0) != null, "mark glyph unavailable")
    expect(ResourceLoader.exists("res://ui/shaders/parchment_paper.gdshader"), "parchment shader missing")

func _check_theme() -> void:
    expect(DomainThemeService.has_domain("mata_fio_verde"), "Mata palette missing")
    expect(DomainThemeService.has_domain("tear_desfeito"), "Tear palette missing")
    var paper := DomainThemeService.color("paper", "mata_fio_verde")
    var accent := DomainThemeService.color("accent", "mata_fio_verde")
    expect(paper != accent, "theme paper/accent collision")

func _check_accessibility_and_vfx() -> void:
    var original := AccessibilityService.profile.serialize()
    AccessibilityService.set_font_scale(1.25)
    expect(AccessibilityService.font_size(20) == 25, "font scaling failed")
    AccessibilityService.set_high_contrast(true)
    expect(DomainThemeService.color("ink_soft", "mata_fio_verde") == DomainThemeService.color("ink", "mata_fio_verde"), "high contrast ink mapping failed")
    AccessibilityService.set_reduce_motion(true)
    var probe := Control.new()
    add_child(probe)
    var tween := BookVFX.page_settle(probe, AccessibilityService.reduce_motion())
    expect(tween != null, "reduced-motion VFX did not return tween")
    var intent_seen := [false]
    PresentationBus.intent_revealed.connect(func(_intent: Dictionary): intent_seen[0] = true, CONNECT_ONE_SHOT)
    CombatEngine.start("monster.mata_fio_verde.02", "character.mata_fio_verde.01")
    expect(bool(intent_seen[0]), "combat intent was not emitted through PresentationBus")
    probe.queue_free()
    AccessibilityService.profile.deserialize(original)

func _check_save_roundtrip() -> void:
    var marker := "smoke_%d" % Time.get_ticks_msec()
    var flags: Dictionary = GameState.run.get("flags", {})
    flags[marker] = true
    GameState.run.flags = flags
    expect(SaveService.save_game(), "save_game failed")
    GameState.run.flags = {}
    expect(SaveService.load_game(), "load_game failed")
    expect(bool(GameState.run.get("flags", {}).get(marker, false)), "save roundtrip lost run flag")
