extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _safe_area_gate()
    _lifecycle_gate()
    _touch_and_back_gate()
    _responsive_gate()
    if failures.is_empty():
        print("MOBILE_CERTIFICATION PASS: 8.1 8.2 8.3 8.4")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("MOBILE_CERTIFICATION: %s" % failure)
        print("MOBILE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _safe_area_gate() -> void:
    var margins := MobilePlatformService.calculate_safe_margins(
        Vector2i(1080, 2400), Rect2i(0, 100, 1080, 2200), Vector2i(540, 1200), 18
    )
    expect(int(margins.left) == 18, "8.1 unexpected left safe margin")
    expect(int(margins.right) == 18, "8.1 unexpected right safe margin")
    expect(int(margins.top) == 68, "8.1 top notch conversion failed")
    expect(int(margins.bottom) == 68, "8.1 bottom inset conversion failed")
    var fallback := MobilePlatformService.calculate_safe_margins(Vector2i.ZERO, Rect2i(), Vector2i(540,960), 18)
    expect(int(fallback.top) == 18 and int(fallback.bottom) == 18, "8.1 safe-area fallback failed")

func _lifecycle_gate() -> void:
    RunFlowEngine.start_journey("character.mata_fio_verde.01", 80802)
    var marker := "mobile_pause_roundtrip"
    GameState.run.flags[marker] = true
    var before_pause := MobilePlatformService.pause_count
    MobilePlatformService.notification(NOTIFICATION_APPLICATION_PAUSED)
    expect(MobilePlatformService.pause_count == before_pause + 1, "8.2 pause notification not handled")
    GameState.run.flags.erase(marker)
    expect(SaveService.load_game(), "8.2 autosave on pause not readable")
    expect(bool(GameState.run.get("flags",{}).get(marker,false)), "8.2 autosave on pause lost run state")
    var before_resume := MobilePlatformService.resume_count
    MobilePlatformService.notification(NOTIFICATION_APPLICATION_RESUMED)
    expect(MobilePlatformService.resume_count == before_resume + 1, "8.2 resume notification not handled")

func _touch_and_back_gate() -> void:
    expect(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)), "8.3 quit_on_go_back must be disabled")
    var root := Control.new()
    var button := Button.new()
    button.custom_minimum_size = Vector2(10,10)
    root.add_child(button)
    add_child(root)
    MobilePlatformService.apply_touch_targets(root)
    expect(button.custom_minimum_size.x >= MobilePlatformService.MIN_TOUCH_TARGET, "8.3 touch target width too small")
    expect(button.custom_minimum_size.y >= MobilePlatformService.MIN_TOUCH_TARGET, "8.3 touch target height too small")
    var back_seen := [false]
    MobilePlatformService.back_requested.connect(func(): back_seen[0] = true, CONNECT_ONE_SHOT)
    MobilePlatformService.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
    expect(bool(back_seen[0]), "8.3 Android Back signal not emitted")
    root.queue_free()

func _responsive_gate() -> void:
    expect(MobilePlatformService.layout_class(Vector2(540,1200)) == "tall", "8.4 tall layout classification failed")
    expect(MobilePlatformService.layout_class(Vector2(540,960)) == "standard", "8.4 standard layout classification failed")
    expect(MobilePlatformService.layout_class(Vector2(900,1200)) == "wide", "8.4 wide layout classification failed")
    var wide_width := MobilePlatformService.recommended_text_width(Vector2(900,1200))
    expect(wide_width <= 680.0, "8.4 wide reading measure exceeds cap")
    expect(str(ProjectSettings.get_setting("display/window/stretch/mode", "")) == "canvas_items", "8.4 mobile stretch mode mismatch")
    expect(str(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "expand", "8.4 mobile stretch aspect mismatch")
