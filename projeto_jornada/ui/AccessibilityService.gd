extends Node
class_name AccessibilityService

signal changed

const SETTINGS_PATH := "user://accessibility.json"
var profile := AccessibilityProfile.new()

func _ready() -> void:
    profile.changed.connect(_on_profile_changed)
    load_settings()

func _on_profile_changed() -> void:
    save_settings()
    changed.emit()

func save_settings() -> bool:
    var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("AccessibilityService: could not save settings")
        return false
    file.store_string(JSON.stringify(profile.serialize()))
    file.close()
    return true

func load_settings() -> bool:
    if not FileAccess.file_exists(SETTINGS_PATH):
        return true
    var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
    if file == null:
        return false
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("AccessibilityService: invalid settings JSON")
        return false
    profile.deserialize(parsed)
    return true

func font_size(base_size: int) -> int:
    return maxi(10, roundi(float(base_size) * profile.font_scale))

func reduce_motion() -> bool:
    return profile.reduce_motion

func flashes_disabled() -> bool:
    return profile.disable_flashes

func high_contrast() -> bool:
    return profile.high_contrast

func icon_labels_enabled() -> bool:
    return profile.icon_labels

func combat_detail() -> int:
    return profile.combat_text_detail

func set_font_scale(value: float) -> void:
    profile.set_font_scale(value)

func set_high_contrast(value: bool) -> void:
    profile.set_high_contrast(value)

func set_reduce_motion(value: bool) -> void:
    profile.set_reduce_motion(value)

func set_disable_flashes(value: bool) -> void:
    profile.set_disable_flashes(value)

func set_icon_labels(value: bool) -> void:
    profile.set_icon_labels(value)

func set_haptics_enabled(value: bool) -> void:
    profile.set_haptics_enabled(value)

func set_combat_text_detail(value: int) -> void:
    profile.set_combat_text_detail(value)

func haptic(duration_ms: int = 18, amplitude: float = 0.35) -> void:
    if not profile.haptics_enabled:
        return
    Input.vibrate_handheld(duration_ms, clampf(amplitude, 0.0, 1.0))

func apply_font_scale(root: Node) -> void:
    if root == null:
        return
    _apply_font_recursive(root)

func _apply_font_recursive(node: Node) -> void:
    if node is Control and node.has_meta("base_font_size"):
        var control := node as Control
        var base := int(node.get_meta("base_font_size"))
        var scaled := font_size(base)
        if node is RichTextLabel:
            control.add_theme_font_size_override("normal_font_size", scaled)
        else:
            control.add_theme_font_size_override("font_size", scaled)
    for child in node.get_children():
        _apply_font_recursive(child)
