extends Node

const LOCALES := ["pt_BR", "en"]
const PRIMARY_SCENES := [
    "res://scenes/Hub.tscn",
    "res://scenes/JourneySetup.tscn",
    "res://scenes/Main.tscn",
    "res://scenes/Codex.tscn",
    "res://scenes/VigilThreads.tscn",
]
const MIN_TOUCH := 48.0

var failures: Array[String] = []
var scene_cases := 0
var buttons_checked := 0
var icon_controls := 0
var symbol_only_controls := 0


func _ready() -> void:
    call_deferred("_run")


func _run() -> void:
    OS.set_environment("VEREDAS_BILLING_UI_TEST", "1")
    await get_tree().process_frame
    var localization := get_node_or_null("/root/LocalizationService")
    _expect(localization != null, "LocalizationService autoload missing")
    if localization == null:
        _finish()
        return

    for scene_path in PRIMARY_SCENES:
        _expect(ResourceLoader.exists(scene_path), "primary scene missing: %s" % scene_path)

    for locale_id in LOCALES:
        _expect(_select_locale(localization, locale_id), "cannot select locale: %s" % locale_id)
        await get_tree().process_frame
        await get_tree().process_frame
        for scene_path in PRIMARY_SCENES:
            if ResourceLoader.exists(scene_path):
                await _check_scene(locale_id, scene_path)

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


func _check_scene(locale_id: String, scene_path: String) -> void:
    var packed := load(scene_path) as PackedScene
    _expect(packed != null, "cannot load scene: %s" % scene_path)
    if packed == null:
        return
    var instance := packed.instantiate()
    add_child(instance)
    await get_tree().process_frame
    await get_tree().process_frame
    scene_cases += 1
    _walk(instance, locale_id, scene_path)
    remove_child(instance)
    instance.queue_free()
    await get_tree().process_frame


func _walk(node: Node, locale_id: String, scene_path: String) -> void:
    if node is BaseButton:
        _check_button(node as BaseButton, locale_id, scene_path)
    for child in node.get_children():
        if child is Node:
            _walk(child as Node, locale_id, scene_path)


func _check_button(button: BaseButton, locale_id: String, scene_path: String) -> void:
    if not button.visible:
        return
    buttons_checked += 1
    var context := "%s %s %s" % [locale_id, scene_path.get_file(), str(button.get_path())]
    _expect(
        button.size.x + 0.01 >= MIN_TOUCH and button.size.y + 0.01 >= MIN_TOUCH,
        "%s interactive target below %.0f px: %.1fx%.1f" % [
            context, MIN_TOUCH, button.size.x, button.size.y
        ]
    )

    var text := ""
    if button is Button:
        text = (button as Button).text.strip_edges()
    var tooltip := button.tooltip_text.strip_edges()
    var has_visual_icon := _has_visual_icon(button)
    var symbol_only := _is_symbol_only(text)

    if has_visual_icon:
        icon_controls += 1
    if symbol_only:
        symbol_only_controls += 1

    if has_visual_icon and text.is_empty():
        _expect(
            not tooltip.is_empty(),
            "%s icon-only control has no accessible tooltip/label" % context
        )
    if symbol_only:
        _expect(
            not tooltip.is_empty(),
            "%s symbol-only control '%s' has no accessible tooltip/label" % [context, text]
        )

    if not text.is_empty():
        _expect(
            not _looks_like_raw_localization_key(text),
            "%s exposes raw localization key as button text: %s" % [context, text]
        )
    if not tooltip.is_empty():
        _expect(
            not _looks_like_raw_localization_key(tooltip),
            "%s exposes raw localization key as tooltip: %s" % [context, tooltip]
        )


func _has_visual_icon(button: BaseButton) -> bool:
    if button is Button:
        return (button as Button).icon != null
    if button is TextureButton:
        var texture_button := button as TextureButton
        return (
            texture_button.texture_normal != null
            or texture_button.texture_pressed != null
            or texture_button.texture_hover != null
        )
    return false


func _is_symbol_only(text: String) -> bool:
    if text.is_empty():
        return false
    for index in range(text.length()):
        var code := text.unicode_at(index)
        if (
            (code >= 48 and code <= 57)
            or (code >= 65 and code <= 90)
            or (code >= 97 and code <= 122)
            or (code >= 0x00C0 and code <= 0x02AF)
        ):
            return false
    return true


func _looks_like_raw_localization_key(text: String) -> bool:
    if " " in text or "\n" in text:
        return false
    if not "." in text:
        return false
    var prefix := text.get_slice(".", 0)
    return prefix in [
        "common", "settings", "journey_setup", "codex", "hub", "main", "vigil", "content", "label"
    ]


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _finish() -> void:
    if failures.is_empty():
        print(
            "LOCALIZATION_ICONOGRAPHY_CERTIFICATION PASS: 11.6 locales=%d scene_cases=%d buttons=%d icon_controls=%d symbol_only=%d billing_surface=1 disabled_visible_controls_included=1" % [
                LOCALES.size(), scene_cases, buttons_checked, icon_controls, symbol_only_controls
            ]
        )
        get_tree().quit(0)
        return
    print("LOCALIZATION_ICONOGRAPHY_CERTIFICATION FAIL: %d issue(s)" % failures.size())
    for failure in failures.slice(0, 100):
        print("ERROR: ", failure)
    get_tree().quit(1)
