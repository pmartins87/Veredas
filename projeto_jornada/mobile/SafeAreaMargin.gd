extends MarginContainer
class_name SafeAreaMargin

func _ready() -> void:
    if not MobilePlatformService.safe_area_changed.is_connected(_apply_margins):
        MobilePlatformService.safe_area_changed.connect(_apply_margins)
    _apply_margins(MobilePlatformService.refresh_safe_area())

func _apply_margins(margins: Dictionary) -> void:
    add_theme_constant_override("margin_left", int(margins.get("left", MobilePlatformService.BASE_MARGIN)))
    add_theme_constant_override("margin_top", int(margins.get("top", MobilePlatformService.BASE_MARGIN)))
    add_theme_constant_override("margin_right", int(margins.get("right", MobilePlatformService.BASE_MARGIN)))
    add_theme_constant_override("margin_bottom", int(margins.get("bottom", MobilePlatformService.BASE_MARGIN)))
