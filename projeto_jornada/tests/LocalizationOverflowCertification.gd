extends Node

const LOCALES := ["pt_BR", "en"]
const VIEWPORTS := [
    Vector2i(360, 640),
    Vector2i(393, 873),
    Vector2i(412, 915),
    Vector2i(768, 1024),
]
const PRIMARY_SCENES := [
    "res://scenes/Hub.tscn",
    "res://scenes/JourneySetup.tscn",
    "res://scenes/Main.tscn",
    "res://scenes/Codex.tscn",
    "res://scenes/VigilThreads.tscn",
]

var failures: Array[String] = []
var controls_checked := 0
var scene_cases := 0


func _ready() -> void:
    call_deferred("_run")


func _run() -> void:
    await get_tree().process_frame
    var localization := get_node_or_null("/root/LocalizationService")
    _expect(localization != null, "LocalizationService autoload missing")
    if localization == null:
        _finish()
        return

    for scene_path in PRIMARY_SCENES:
        _expect(ResourceLoader.exists(scene_path), "primary localized scene missing: %s" % scene_path)

    for locale_id in LOCALES:
        _expect(_select_locale(localization, locale_id), "cannot select locale: %s" % locale_id)
        await get_tree().process_frame
        await get_tree().process_frame
        for viewport_size in VIEWPORTS:
            for scene_path in PRIMARY_SCENES:
                if ResourceLoader.exists(scene_path):
                    await _check_scene(locale_id, viewport_size, scene_path)

    _finish()


func _select_locale(service: Node, locale_id: String) -> bool:
    for method_name in ["set_locale", "set_current_locale", "select_locale", "apply_locale"]:
        if service.has_method(method_name):
            var result = service.call(method_name, locale_id)
            if typeof(result) == TYPE_BOOL:
                return bool(result)
            return true
    for property_name in ["current_locale", "locale", "active_locale"]:
        if _has_property(service, property_name):
            service.set(property_name, locale_id)
            return true
    return false


func _has_property(object: Object, property_name: String) -> bool:
    for row in object.get_property_list():
        if str(row.get("name", "")) == property_name:
            return true
    return false


func _check_scene(locale_id: String, viewport_size: Vector2i, scene_path: String) -> void:
    var packed := load(scene_path) as PackedScene
    _expect(packed != null, "cannot load scene: %s" % scene_path)
    if packed == null:
        return

    var viewport := SubViewport.new()
    viewport.size = viewport_size
    viewport.disable_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    add_child(viewport)

    var instance := packed.instantiate()
    viewport.add_child(instance)
    await get_tree().process_frame
    await get_tree().process_frame
    scene_cases += 1
    _walk_controls(instance, locale_id, viewport_size, scene_path)

    viewport.remove_child(instance)
    instance.queue_free()
    remove_child(viewport)
    viewport.queue_free()
    await get_tree().process_frame


func _walk_controls(node: Node, locale_id: String, viewport_size: Vector2i, scene_path: String) -> void:
    if node is Control:
        _check_control(node as Control, locale_id, viewport_size, scene_path)
    for child in node.get_children():
        if child is Node:
            _walk_controls(child as Node, locale_id, viewport_size, scene_path)


func _check_control(control: Control, locale_id: String, viewport_size: Vector2i, scene_path: String) -> void:
    if not control.visible:
        return
    if control.size.x <= 0.0 or control.size.y <= 0.0:
        return

    var text := _control_text(control)
    if text.is_empty():
        return
    controls_checked += 1

    var context := "%s %dx%d %s %s" % [
        locale_id,
        viewport_size.x,
        viewport_size.y,
        scene_path.get_file(),
        str(control.get_path()),
    ]

    if control is RichTextLabel:
        var rich := control as RichTextLabel
        if rich.has_method("get_content_height"):
            var content_height := float(rich.call("get_content_height"))
            _expect(
                content_height <= rich.size.y + 2.0 or rich.scroll_active,
                "%s RichTextLabel vertical overflow content=%.1f box=%.1f" % [context, content_height, rich.size.y]
            )
        if rich.autowrap_mode == TextServer.AUTOWRAP_OFF and rich.has_method("get_content_width"):
            var content_width := float(rich.call("get_content_width"))
            _expect(
                content_width <= rich.size.x + 2.0 or rich.scroll_active,
                "%s RichTextLabel horizontal overflow content=%.1f box=%.1f" % [context, content_width, rich.size.x]
            )
        return

    if control is Label:
        var label := control as Label
        if label.has_method("get_line_count") and label.has_method("get_visible_line_count"):
            var line_count := int(label.call("get_line_count"))
            var visible_lines := int(label.call("get_visible_line_count"))
            if line_count > 0 and visible_lines > 0:
                _expect(
                    visible_lines >= line_count,
                    "%s Label clips lines visible=%d total=%d" % [context, visible_lines, line_count]
                )
        var minimum := label.get_combined_minimum_size()
        if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
            _expect(
                minimum.x <= label.size.x + 2.0,
                "%s Label horizontal overflow minimum=%.1f box=%.1f" % [context, minimum.x, label.size.x]
            )
        _expect(
            minimum.y <= label.size.y + 2.0,
            "%s Label vertical overflow minimum=%.1f box=%.1f" % [context, minimum.y, label.size.y]
        )
        return

    if control is Button:
        var button := control as Button
        var minimum := button.get_combined_minimum_size()
        _expect(
            minimum.x <= button.size.x + 2.0,
            "%s Button horizontal overflow minimum=%.1f box=%.1f" % [context, minimum.x, button.size.x]
        )
        _expect(
            minimum.y <= button.size.y + 2.0,
            "%s Button vertical overflow minimum=%.1f box=%.1f" % [context, minimum.y, button.size.y]
        )


func _control_text(control: Control) -> String:
    if control is RichTextLabel:
        return (control as RichTextLabel).text.strip_edges()
    if control is Label:
        return (control as Label).text.strip_edges()
    if control is Button:
        return (control as Button).text.strip_edges()
    return ""


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _finish() -> void:
    if failures.is_empty():
        print(
            "LOCALIZATION_OVERFLOW_CERTIFICATION PASS: 11.6 locales=%d viewports=%d scene_cases=%d text_controls=%d" % [
                LOCALES.size(), VIEWPORTS.size(), scene_cases, controls_checked
            ]
        )
        get_tree().quit(0)
        return

    print("LOCALIZATION_OVERFLOW_CERTIFICATION FAIL: %d issue(s)" % failures.size())
    for failure in failures.slice(0, 100):
        print("ERROR: ", failure)
    get_tree().quit(1)
