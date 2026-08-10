extends Node

const VIEWPORTS := [
    Vector2i(360, 640),
    Vector2i(360, 800),
    Vector2i(540, 960),
    Vector2i(720, 1280),
    Vector2i(900, 1200),
]
const FONT_SCALES := [0.85, 1.0, 1.30, 1.60]
const SCENES := [
    {"label":"Hub", "path":"res://scenes/Hub.tscn", "needs_run":false},
    {"label":"JourneySetup", "path":"res://scenes/JourneySetup.tscn", "needs_run":false},
    {"label":"Codex", "path":"res://scenes/Codex.tscn", "needs_run":false},
    {"label":"VigilThreads", "path":"res://scenes/VigilThreads.tscn", "needs_run":false},
    {"label":"Main", "path":"res://scenes/Main.tscn", "needs_run":true},
]
const GEOMETRY_EPS := 3.0

var failures: Array[String] = []
var scene_cases := 0
var mode_cases := 0
var button_checks := 0
var font_checks := 0
var contrast_checks := 0
var safe_area_cases := 0

func _ready() -> void:
    await get_tree().process_frame
    _profile_contract_gate()
    _safe_area_matrix()
    _contrast_matrix()
    await _real_scene_matrix()
    _reset_accessibility()
    _finish()

func _profile_contract_gate() -> void:
    AccessibilityService.set_font_scale(0.1)
    expect(is_equal_approx(AccessibilityService.profile.font_scale, AccessibilityProfile.MIN_FONT_SCALE), "11.4 font scale minimum clamp failed")
    AccessibilityService.set_font_scale(9.0)
    expect(is_equal_approx(AccessibilityService.profile.font_scale, AccessibilityProfile.MAX_FONT_SCALE), "11.4 font scale maximum clamp failed")
    AccessibilityService.set_high_contrast(true)
    AccessibilityService.set_reduce_motion(true)
    AccessibilityService.set_disable_flashes(true)
    AccessibilityService.set_icon_labels(false)
    AccessibilityService.set_haptics_enabled(false)
    AccessibilityService.set_combat_text_detail(2)
    var serialized := AccessibilityService.profile.serialize()
    var restored := AccessibilityProfile.new()
    restored.deserialize(serialized)
    expect(restored.serialize() == serialized, "11.4 accessibility profile round-trip changed settings")
    expect(AccessibilityService.reduce_motion(), "11.4 reduced motion preference not active")
    expect(AccessibilityService.flashes_disabled(), "11.4 disable flashes preference not active")
    expect(AccessibilityService.high_contrast(), "11.4 high contrast preference not active")
    expect(not AccessibilityService.icon_labels_enabled(), "11.4 icon labels preference not active")
    expect(AccessibilityService.combat_detail() == 2, "11.4 combat text detail preference not active")
    _reset_accessibility()
    print("11.4 accessibility profile: clamp/round-trip/preferences PASS")

func _safe_area_matrix() -> void:
    var cases := [
        {"window":Vector2i(1080,2400), "safe":Rect2i(0,100,1080,2200), "viewport":Vector2i(540,1200)},
        {"window":Vector2i(1440,3120), "safe":Rect2i(0,120,1440,2880), "viewport":Vector2i(540,1170)},
        {"window":Vector2i(1080,1920), "safe":Rect2i(0,0,1080,1920), "viewport":Vector2i(540,960)},
        {"window":Vector2i(2400,1080), "safe":Rect2i(100,0,2200,1080), "viewport":Vector2i(1200,540)},
        {"window":Vector2i.ZERO, "safe":Rect2i(), "viewport":Vector2i(360,640)},
    ]
    for case_variant in cases:
        var case: Dictionary = case_variant as Dictionary
        var viewport: Vector2i = case.viewport
        var margins := MobilePlatformService.calculate_safe_margins(case.window, case.safe, viewport, MobilePlatformService.BASE_MARGIN)
        safe_area_cases += 1
        for side in ["left","top","right","bottom"]:
            expect(int(margins.get(side, -1)) >= MobilePlatformService.BASE_MARGIN, "11.4 safe area %s below base margin case=%d" % [side,safe_area_cases])
        expect(int(margins.left) + int(margins.right) < viewport.x, "11.4 horizontal safe area consumes viewport case=%d" % safe_area_cases)
        expect(int(margins.top) + int(margins.bottom) < viewport.y, "11.4 vertical safe area consumes viewport case=%d" % safe_area_cases)
    for viewport in VIEWPORTS:
        var text_width := MobilePlatformService.recommended_text_width(viewport)
        expect(text_width >= 320.0, "11.4 reading width below minimum for %s" % str(viewport))
        expect(text_width <= maxf(680.0, float(viewport.x)), "11.4 reading width invalid for %s" % str(viewport))
    print("11.4 safe-area/responsive helper matrix: cases=%d" % safe_area_cases)

func _contrast_matrix() -> void:
    var domain_ids: Array[String] = []
    for world_variant in ContentRegistry.all("worlds"):
        var world: Dictionary = world_variant as Dictionary
        domain_ids.append(str(world.get("id", "")).trim_prefix("world."))
    expect(domain_ids.size() == 12, "11.4 contrast matrix requires 12 Domains")
    for domain_id in domain_ids:
        AccessibilityService.set_high_contrast(false)
        var paper := DomainThemeService.color("paper", domain_id)
        var ink := DomainThemeService.color("ink", domain_id)
        var soft := DomainThemeService.color("ink_soft", domain_id)
        var body_ratio := _contrast_ratio(ink, paper)
        var secondary_ratio := _contrast_ratio(soft, paper)
        contrast_checks += 2
        expect(body_ratio >= 7.0, "11.4 body contrast below 7:1 in %s: %.2f" % [domain_id,body_ratio])
        expect(secondary_ratio >= 4.5, "11.4 secondary contrast below 4.5:1 in %s: %.2f" % [domain_id,secondary_ratio])
        AccessibilityService.set_high_contrast(true)
        var high_paper := DomainThemeService.color("paper", domain_id)
        var high_ink := DomainThemeService.color("ink", domain_id)
        var high_soft := DomainThemeService.color("ink_soft", domain_id)
        var high_body := _contrast_ratio(high_ink, high_paper)
        var high_secondary := _contrast_ratio(high_soft, high_paper)
        contrast_checks += 2
        expect(high_body >= body_ratio, "11.4 high contrast reduced body contrast in %s" % domain_id)
        expect(high_secondary >= 7.0, "11.4 high-contrast secondary text below 7:1 in %s: %.2f" % [domain_id,high_secondary])
    _reset_accessibility()
    print("11.4 contrast matrix: checks=%d Domains=%d" % [contrast_checks,domain_ids.size()])

func _real_scene_matrix() -> void:
    var original_size := get_tree().root.size
    for viewport in VIEWPORTS:
        get_tree().root.size = viewport
        await get_tree().process_frame
        for scale_variant in FONT_SCALES:
            var scale := float(scale_variant)
            AccessibilityService.set_font_scale(scale)
            for scene_spec_variant in SCENES:
                var scene_spec: Dictionary = scene_spec_variant as Dictionary
                await _exercise_scene(scene_spec, viewport, scale)
    get_tree().root.size = original_size
    await get_tree().process_frame
    print("11.4 real scene matrix: scene_cases=%d mode_cases=%d buttons=%d font_checks=%d" % [scene_cases,mode_cases,button_checks,font_checks])

func _exercise_scene(spec: Dictionary, viewport: Vector2i, scale: float) -> void:
    _remove_runtime_save()
    GameState.reset_profile()
    if bool(spec.get("needs_run", false)):
        expect(RunFlowEngine.start_journey(ProfileMigrationEngine.DEFAULT_CHARACTER, 1144000 + scene_cases), "11.4 could not prepare Main journey")
    var packed := load(str(spec.path)) as PackedScene
    expect(packed != null, "11.4 scene missing: %s" % str(spec.path))
    if packed == null:
        return
    var instance := packed.instantiate()
    add_child(instance)
    await get_tree().process_frame
    await get_tree().process_frame
    AccessibilityService.apply_font_scale(instance)
    MobilePlatformService.apply_touch_targets(instance)
    await get_tree().process_frame
    scene_cases += 1
    _validate_scene_tree(instance, str(spec.label), viewport, scale, "default")

    if str(spec.label) == "Main":
        RunFlowEngine.open_inventory()
        instance.call("_refresh")
        await get_tree().process_frame
        mode_cases += 1
        _validate_scene_tree(instance, "Main", viewport, scale, "inventory")

        RunFlowEngine.open_travel()
        instance.call("_refresh")
        await get_tree().process_frame
        mode_cases += 1
        _validate_scene_tree(instance, "Main", viewport, scale, "travel")

        RunFlowEngine.open_merchant(8)
        instance.call("_refresh")
        await get_tree().process_frame
        mode_cases += 1
        _validate_scene_tree(instance, "Main", viewport, scale, "merchant")

        RunFlowEngine.resume_story()
        var monsters := RunFlowEngine.local_monsters()
        if not monsters.is_empty():
            RunFlowEngine.start_combat(str((monsters[0] as Dictionary).get("id", "")))
            instance.call("_refresh")
            await get_tree().process_frame
            mode_cases += 1
            _validate_scene_tree(instance, "Main", viewport, scale, "combat")

    instance.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame

func _validate_scene_tree(root: Node, scene_label: String, viewport: Vector2i, scale: float, mode: String) -> void:
    if root is Control:
        var root_control := root as Control
        var minimum := root_control.get_combined_minimum_size()
        expect(minimum.x <= float(viewport.x) + GEOMETRY_EPS, "11.4 %s/%s min width %.1f exceeds viewport %d at scale %.2f" % [scene_label,mode,minimum.x,viewport.x,scale])
        expect(minimum.y <= float(viewport.y) + GEOMETRY_EPS, "11.4 %s/%s min height %.1f exceeds viewport %d at scale %.2f" % [scene_label,mode,minimum.y,viewport.y,scale])
    _validate_node_recursive(root, root, scene_label, viewport, scale, mode)

func _validate_node_recursive(node: Node, scene_root: Node, scene_label: String, viewport: Vector2i, scale: float, mode: String) -> void:
    if node is Control and (node as Control).is_visible_in_tree():
        var control := node as Control
        var size := control.size
        var pos := control.global_position
        expect(is_finite(size.x) and is_finite(size.y) and is_finite(pos.x) and is_finite(pos.y), "11.4 non-finite geometry %s/%s node=%s" % [scene_label,mode,node.name])
        expect(size.x >= -GEOMETRY_EPS and size.y >= -GEOMETRY_EPS, "11.4 negative control size %s/%s node=%s size=%s" % [scene_label,mode,node.name,str(size)])
        if node != scene_root:
            expect(pos.x + size.x >= -GEOMETRY_EPS and pos.x <= float(viewport.x) + GEOMETRY_EPS, "11.4 control horizontally unreachable %s/%s node=%s rect=%s,%s" % [scene_label,mode,node.name,str(pos),str(size)])
            if not _has_scroll_ancestor(node, scene_root):
                expect(pos.y + size.y >= -GEOMETRY_EPS and pos.y <= float(viewport.y) + GEOMETRY_EPS, "11.4 control vertically unreachable %s/%s node=%s rect=%s,%s" % [scene_label,mode,node.name,str(pos),str(size)])
        if node is BaseButton:
            var button := node as BaseButton
            button_checks += 1
            expect(button.custom_minimum_size.x == 0.0 or button.custom_minimum_size.x >= MobilePlatformService.MIN_TOUCH_TARGET, "11.4 button explicit width below touch target %s/%s text=%s" % [scene_label,mode,button.text])
            expect(button.custom_minimum_size.y >= MobilePlatformService.MIN_TOUCH_TARGET, "11.4 button minimum height below 48 %s/%s text=%s min=%.1f" % [scene_label,mode,button.text,button.custom_minimum_size.y])
            expect(button.size.y + GEOMETRY_EPS >= MobilePlatformService.MIN_TOUCH_TARGET, "11.4 rendered button height below 48 %s/%s text=%s size=%.1f" % [scene_label,mode,button.text,button.size.y])
            if button.text.length() > 28 and button is Button:
                expect((button as Button).autowrap_mode != TextServer.AUTOWRAP_OFF, "11.4 long button lacks autowrap %s/%s text=%s" % [scene_label,mode,button.text])
        if node.has_meta("base_font_size"):
            var expected_size := AccessibilityService.font_size(int(node.get_meta("base_font_size")))
            var actual_size := control.get_theme_font_size("normal_font_size" if node is RichTextLabel else "font_size")
            font_checks += 1
            expect(actual_size == expected_size, "11.4 font scale not applied %s/%s node=%s expected=%d actual=%d scale=%.2f" % [scene_label,mode,node.name,expected_size,actual_size,scale])
    for child in node.get_children():
        _validate_node_recursive(child, scene_root, scene_label, viewport, scale, mode)

func _has_scroll_ancestor(node: Node, stop: Node) -> bool:
    var current := node.get_parent()
    while current != null and current != stop:
        if current is ScrollContainer:
            return true
        current = current.get_parent()
    return false

func _contrast_ratio(a: Color, b: Color) -> float:
    var la := _relative_luminance(a)
    var lb := _relative_luminance(b)
    return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _relative_luminance(color: Color) -> float:
    return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)

func _linear(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)

func _remove_runtime_save() -> void:
    if FileAccess.file_exists(SaveService.SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.SAVE_PATH))

func _reset_accessibility() -> void:
    AccessibilityService.set_font_scale(1.0)
    AccessibilityService.set_high_contrast(false)
    AccessibilityService.set_reduce_motion(false)
    AccessibilityService.set_disable_flashes(false)
    AccessibilityService.set_icon_labels(true)
    AccessibilityService.set_haptics_enabled(true)
    AccessibilityService.set_combat_text_detail(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: RESPONSIVE_ACCESSIBILITY_CERTIFICATION: %s" % message)

func _finish() -> void:
    _remove_runtime_save()
    if failures.is_empty():
        print("RESPONSIVE_ACCESSIBILITY_CERTIFICATION PASS: 11.4-A scene_cases=%d mode_cases=%d button_checks=%d font_checks=%d contrast_checks=%d safe_area_cases=%d" % [scene_cases,mode_cases,button_checks,font_checks,contrast_checks,safe_area_cases])
        get_tree().quit(0)
    else:
        print("RESPONSIVE_ACCESSIBILITY_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)
