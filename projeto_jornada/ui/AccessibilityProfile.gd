extends Node
class_name AccessibilityProfile

signal changed

const MIN_FONT_SCALE := 0.85
const MAX_FONT_SCALE := 1.60

var font_scale: float = 1.0
var high_contrast: bool = false
var reduce_motion: bool = false
var disable_flashes: bool = false
var icon_labels: bool = true
var haptics_enabled: bool = true
var combat_text_detail: int = 1 # 0 compact, 1 normal, 2 verbose

func set_font_scale(value: float) -> void:
    font_scale = clampf(value, MIN_FONT_SCALE, MAX_FONT_SCALE)
    changed.emit()

func set_high_contrast(value: bool) -> void:
    high_contrast = value
    changed.emit()

func set_reduce_motion(value: bool) -> void:
    reduce_motion = value
    changed.emit()

func set_disable_flashes(value: bool) -> void:
    disable_flashes = value
    changed.emit()

func set_icon_labels(value: bool) -> void:
    icon_labels = value
    changed.emit()

func set_haptics_enabled(value: bool) -> void:
    haptics_enabled = value
    changed.emit()

func set_combat_text_detail(value: int) -> void:
    combat_text_detail = clampi(value, 0, 2)
    changed.emit()

func serialize() -> Dictionary:
    return {
        "font_scale": font_scale,
        "high_contrast": high_contrast,
        "reduce_motion": reduce_motion,
        "disable_flashes": disable_flashes,
        "icon_labels": icon_labels,
        "haptics_enabled": haptics_enabled,
        "combat_text_detail": combat_text_detail,
    }

func deserialize(data: Dictionary) -> void:
    font_scale = clampf(float(data.get("font_scale", 1.0)), MIN_FONT_SCALE, MAX_FONT_SCALE)
    high_contrast = bool(data.get("high_contrast", false))
    reduce_motion = bool(data.get("reduce_motion", false))
    disable_flashes = bool(data.get("disable_flashes", false))
    icon_labels = bool(data.get("icon_labels", true))
    haptics_enabled = bool(data.get("haptics_enabled", true))
    combat_text_detail = clampi(int(data.get("combat_text_detail", 1)), 0, 2)
    changed.emit()
