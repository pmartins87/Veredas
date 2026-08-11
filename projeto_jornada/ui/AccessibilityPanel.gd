extends PanelContainer
class_name AccessibilityPanel

signal closed

var domain_id := "mata_fio_verde"
var localization := LocalizationService.new()
var _language_ids: Array[String] = []

func _ready() -> void:
    visible = false
    set_anchors_preset(Control.PRESET_CENTER)
    custom_minimum_size = Vector2(460, 650)

func open_for(domain: String) -> void:
    domain_id = domain
    _rebuild()
    visible = true
    move_to_front()

func close_panel() -> void:
    visible = false
    closed.emit()

func _rebuild() -> void:
    for child in get_children():
        child.queue_free()
    BookCardStyle.apply_panel(self, domain_id, DomainThemeService, "selected")
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    add_child(margin)

    var scroll := ScrollContainer.new()
    scroll.name = "AccessibilityScroll"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_child(scroll)
    var column := VBoxContainer.new()
    column.name = "AccessibilityColumn"
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 12)
    scroll.add_child(column)

    var title := Label.new()
    title.name = "AccessibilityTitle"
    title.text = localization.text("settings.accessibility.title")
    title.set_meta("base_font_size", 28)
    BookCardStyle.apply_heading(title, domain_id, DomainThemeService, 1)
    column.add_child(title)

    var description := Label.new()
    description.name = "AccessibilityDescription"
    description.text = localization.text("settings.accessibility.description")
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.set_meta("base_font_size", 16)
    column.add_child(description)

    var language_label := Label.new()
    language_label.name = "LanguageLabel"
    language_label.text = localization.text("settings.language.label")
    language_label.set_meta("base_font_size", 17)
    column.add_child(language_label)
    var language := OptionButton.new()
    language.name = "LanguageOption"
    language.set_meta("base_font_size", 16)
    language.custom_minimum_size.y = 50
    _language_ids = localization.launch_locales()
    var selected_index := 0
    for i in range(_language_ids.size()):
        var locale_id := _language_ids[i]
        language.add_item(localization.locale_label(locale_id), i)
        if locale_id == localization.current_locale():
            selected_index = i
    language.select(selected_index)
    language.item_selected.connect(_on_language_selected)
    column.add_child(language)

    var font_label := Label.new()
    font_label.name = "FontSizeLabel"
    font_label.text = localization.text("settings.font_size", {"percent":roundi(AccessibilityService.profile.font_scale * 100.0)})
    font_label.set_meta("base_font_size", 17)
    column.add_child(font_label)
    var slider := HSlider.new()
    slider.name = "FontSizeSlider"
    slider.min_value = AccessibilityProfile.MIN_FONT_SCALE
    slider.max_value = AccessibilityProfile.MAX_FONT_SCALE
    slider.step = 0.05
    slider.value = AccessibilityService.profile.font_scale
    slider.value_changed.connect(func(value: float):
        AccessibilityService.set_font_scale(value)
        font_label.text = localization.text("settings.font_size", {"percent":roundi(value * 100.0)})
        AccessibilityService.apply_font_scale(self)
    )
    column.add_child(slider)

    _add_toggle(column, "HighContrastToggle", localization.text("settings.high_contrast"), AccessibilityService.profile.high_contrast, func(value: bool): AccessibilityService.set_high_contrast(value))
    _add_toggle(column, "ReduceMotionToggle", localization.text("settings.reduce_motion"), AccessibilityService.profile.reduce_motion, func(value: bool): AccessibilityService.set_reduce_motion(value))
    _add_toggle(column, "DisableFlashesToggle", localization.text("settings.disable_flashes"), AccessibilityService.profile.disable_flashes, func(value: bool): AccessibilityService.set_disable_flashes(value))
    _add_toggle(column, "IconLabelsToggle", localization.text("settings.icon_labels"), AccessibilityService.profile.icon_labels, func(value: bool): AccessibilityService.set_icon_labels(value))
    _add_toggle(column, "HapticsToggle", localization.text("settings.haptics"), AccessibilityService.profile.haptics_enabled, func(value: bool): AccessibilityService.set_haptics_enabled(value))

    var detail_label := Label.new()
    detail_label.name = "CombatTextDetailLabel"
    detail_label.text = localization.text("settings.combat_text_detail")
    detail_label.set_meta("base_font_size", 17)
    column.add_child(detail_label)
    var detail := OptionButton.new()
    detail.name = "CombatTextDetailOption"
    detail.add_item(localization.text("settings.combat_text.compact"), 0)
    detail.add_item(localization.text("settings.combat_text.normal"), 1)
    detail.add_item(localization.text("settings.combat_text.detailed"), 2)
    detail.select(AccessibilityService.profile.combat_text_detail)
    detail.item_selected.connect(func(index: int): AccessibilityService.set_combat_text_detail(index))
    column.add_child(detail)

    var close := Button.new()
    close.name = "AccessibilityDone"
    close.text = localization.text("common.done")
    close.custom_minimum_size = Vector2(0, 54)
    BookCardStyle.apply_button(close, domain_id, DomainThemeService, true)
    close.pressed.connect(close_panel)
    column.add_child(close)
    AccessibilityService.apply_font_scale(self)
    MobilePlatformService.apply_touch_targets(self)

func _on_language_selected(index: int) -> void:
    if index < 0 or index >= _language_ids.size():
        return
    if localization.set_locale(_language_ids[index], true):
        call_deferred("_rebuild")

func _add_toggle(parent: VBoxContainer, node_name: String, label_text: String, initial: bool, callback: Callable) -> void:
    var toggle := CheckButton.new()
    toggle.name = node_name
    toggle.text = label_text
    toggle.button_pressed = initial
    toggle.set_meta("base_font_size", 17)
    toggle.toggled.connect(callback)
    parent.add_child(toggle)
