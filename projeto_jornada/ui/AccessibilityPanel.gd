extends PanelContainer
class_name AccessibilityPanel

signal closed

var domain_id := "mata_fio_verde"

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
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    margin.add_child(column)

    var title := Label.new()
    title.text = "Acessibilidade"
    title.set_meta("base_font_size", 28)
    BookCardStyle.apply_heading(title, domain_id, DomainThemeService, 1)
    column.add_child(title)

    var description := Label.new()
    description.text = "Ajustes podem ser alterados a qualquer momento e não mudam as regras da jornada."
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.set_meta("base_font_size", 16)
    column.add_child(description)

    var font_label := Label.new()
    font_label.text = "Tamanho do texto: %d%%" % roundi(AccessibilityService.profile.font_scale * 100.0)
    font_label.set_meta("base_font_size", 17)
    column.add_child(font_label)
    var slider := HSlider.new()
    slider.min_value = AccessibilityProfile.MIN_FONT_SCALE
    slider.max_value = AccessibilityProfile.MAX_FONT_SCALE
    slider.step = 0.05
    slider.value = AccessibilityService.profile.font_scale
    slider.value_changed.connect(func(value: float):
        AccessibilityService.set_font_scale(value)
        font_label.text = "Tamanho do texto: %d%%" % roundi(value * 100.0)
        AccessibilityService.apply_font_scale(self)
    )
    column.add_child(slider)

    _add_toggle(column, "Alto contraste", AccessibilityService.profile.high_contrast, func(value: bool): AccessibilityService.set_high_contrast(value))
    _add_toggle(column, "Reduzir movimento", AccessibilityService.profile.reduce_motion, func(value: bool): AccessibilityService.set_reduce_motion(value))
    _add_toggle(column, "Desativar flashes", AccessibilityService.profile.disable_flashes, func(value: bool): AccessibilityService.set_disable_flashes(value))
    _add_toggle(column, "Exibir rótulos junto aos ícones", AccessibilityService.profile.icon_labels, func(value: bool): AccessibilityService.set_icon_labels(value))
    _add_toggle(column, "Resposta tátil", AccessibilityService.profile.haptics_enabled, func(value: bool): AccessibilityService.set_haptics_enabled(value))

    var detail_label := Label.new()
    detail_label.text = "Detalhe dos textos de combate"
    detail_label.set_meta("base_font_size", 17)
    column.add_child(detail_label)
    var detail := OptionButton.new()
    detail.add_item("Compacto", 0)
    detail.add_item("Normal", 1)
    detail.add_item("Detalhado", 2)
    detail.select(AccessibilityService.profile.combat_text_detail)
    detail.item_selected.connect(func(index: int): AccessibilityService.set_combat_text_detail(index))
    column.add_child(detail)

    var close := Button.new()
    close.text = "Concluir"
    close.custom_minimum_size = Vector2(0, 54)
    BookCardStyle.apply_button(close, domain_id, DomainThemeService, true)
    close.pressed.connect(close_panel)
    column.add_child(close)
    AccessibilityService.apply_font_scale(self)

func _add_toggle(parent: VBoxContainer, label_text: String, initial: bool, callback: Callable) -> void:
    var toggle := CheckButton.new()
    toggle.text = label_text
    toggle.button_pressed = initial
    toggle.set_meta("base_font_size", 17)
    toggle.toggled.connect(callback)
    parent.add_child(toggle)
