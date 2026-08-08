extends MarginContainer
class_name ReadingWidthMargin

func _ready() -> void:
    var root := get_tree().root
    if not root.size_changed.is_connected(_refresh_width):
        root.size_changed.connect(_refresh_width)
    call_deferred("_refresh_width")

func _refresh_width() -> void:
    var viewport_size := get_tree().root.get_visible_rect().size
    var target := MobilePlatformService.recommended_text_width(viewport_size)
    var extra := maxi(0, roundi((viewport_size.x - target) * 0.5))
    add_theme_constant_override("margin_left", extra)
    add_theme_constant_override("margin_right", extra)
    add_theme_constant_override("margin_top", 0)
    add_theme_constant_override("margin_bottom", 0)
