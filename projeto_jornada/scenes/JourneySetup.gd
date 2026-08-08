extends Control

var setup_engine := JourneySetupEngine.new()
var route_option: OptionButton
var character_option: OptionButton
var mode_option: OptionButton
var difficulty_option: OptionButton
var seed_edit: LineEdit
var modifier_box: VBoxContainer
var status_label: Label
var _route_ids: Array[String] = []
var _character_ids: Array[String] = []
var _mode_ids: Array[String] = []
var _difficulty_ids: Array[String] = []

func _ready() -> void:
    MetaUnlockEngine.evaluate_progression()
    _build_ui()
    _populate_routes()
    _populate_modes()
    _populate_difficulties()
    _populate_modifiers()
    _on_route_selected(0)
    MobilePlatformService.apply_touch_targets(self)
    AccessibilityService.apply_font_scale(self)

func _build_ui() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shader := load("res://ui/shaders/parchment_paper.gdshader") as Shader
    if shader != null:
        var material := ShaderMaterial.new()
        material.shader = shader
        background.material = material
    add_child(background)

    var outer := SafeAreaMargin.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(outer)
    var reading := ReadingWidthMargin.new()
    outer.add_child(reading)
    var panel := PanelContainer.new()
    reading.add_child(panel)
    BookCardStyle.apply_panel(panel, "mata_fio_verde", DomainThemeService, "normal")

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    panel.add_child(margin)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 10)
    scroll.add_child(column)

    var heading := Label.new()
    heading.text = "Preparar a Jornada"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.set_meta("base_font_size", 32)
    BookCardStyle.apply_heading(heading, "mata_fio_verde", DomainThemeService, 1)
    column.add_child(heading)

    var intro := Label.new()
    intro.text = "Escolha a Vereda, o Andarilho e as regras desta travessia. Dificuldade é registrada agora; a calibração numérica final pertence à fase 10.6."
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro.set_meta("base_font_size", 16)
    column.add_child(intro)

    route_option = _field(column, "Rota")
    route_option.item_selected.connect(_on_route_selected)
    character_option = _field(column, "Andarilho")
    mode_option = _field(column, "Modo")
    mode_option.item_selected.connect(_on_mode_selected)
    difficulty_option = _field(column, "Dificuldade")

    var seed_label := Label.new()
    seed_label.text = "Seed — deixe 0 para gerar automaticamente; Trama Compartilhada exige valor positivo"
    seed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    seed_label.set_meta("base_font_size", 14)
    column.add_child(seed_label)
    seed_edit = LineEdit.new()
    seed_edit.text = "0"
    seed_edit.placeholder_text = "0"
    seed_edit.custom_minimum_size.y = 48
    seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
    column.add_child(seed_edit)

    var modifier_title := Label.new()
    modifier_title.text = "Modificadores"
    modifier_title.set_meta("base_font_size", 19)
    column.add_child(modifier_title)
    modifier_box = VBoxContainer.new()
    modifier_box.add_theme_constant_override("separation", 6)
    column.add_child(modifier_box)

    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.set_meta("base_font_size", 14)
    column.add_child(status_label)

    var start_button := Button.new()
    start_button.text = "Partir"
    start_button.custom_minimum_size.y = 56
    start_button.set_meta("base_font_size", 17)
    BookCardStyle.apply_button(start_button, "mata_fio_verde", DomainThemeService, true)
    start_button.pressed.connect(_start)
    column.add_child(start_button)

    var back_button := Button.new()
    back_button.text = "Voltar ao Nó"
    back_button.custom_minimum_size.y = 52
    back_button.set_meta("base_font_size", 16)
    BookCardStyle.apply_button(back_button, "mata_fio_verde", DomainThemeService, false)
    back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Hub.tscn"))
    column.add_child(back_button)

func _field(column: VBoxContainer, label_text: String) -> OptionButton:
    var label := Label.new()
    label.text = label_text
    label.set_meta("base_font_size", 16)
    column.add_child(label)
    var option := OptionButton.new()
    option.custom_minimum_size.y = 50
    option.set_meta("base_font_size", 16)
    BookCardStyle.apply_button(option, "mata_fio_verde", DomainThemeService, false)
    column.add_child(option)
    return option

func _populate_routes() -> void:
    route_option.clear()
    _route_ids.clear()
    for world_variant in MetaUnlockEngine.unlocked_routes():
        var world: Dictionary = world_variant as Dictionary
        var world_id := str(world.get("id", ""))
        _route_ids.append(world_id)
        route_option.add_item(str(world.get("name", world_id)))

func _populate_modes() -> void:
    mode_option.clear()
    _mode_ids.clear()
    for mode_variant in MetaUnlockEngine.unlocked_modes():
        var mode: Dictionary = mode_variant as Dictionary
        _mode_ids.append(str(mode.get("id", "journey")))
        mode_option.add_item(str(mode.get("name", mode.get("id", "journey"))))

func _populate_difficulties() -> void:
    difficulty_option.clear()
    _difficulty_ids.clear()
    for difficulty_variant in setup_engine.difficulty_options():
        var difficulty: Dictionary = difficulty_variant as Dictionary
        _difficulty_ids.append(str(difficulty.get("id", JourneySetupEngine.DEFAULT_DIFFICULTY)))
        difficulty_option.add_item(str(difficulty.get("name", difficulty.get("id", ""))))
    var default_index := _difficulty_ids.find(JourneySetupEngine.DEFAULT_DIFFICULTY)
    if default_index >= 0:
        difficulty_option.select(default_index)

func _populate_modifiers() -> void:
    for child in modifier_box.get_children():
        child.queue_free()
    for modifier_variant in setup_engine.modifier_options():
        var modifier: Dictionary = modifier_variant as Dictionary
        var check := CheckButton.new()
        check.text = "%s — %s" % [modifier.get("name", ""), modifier.get("description", "")]
        check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        check.disabled = not bool(modifier.get("available", false))
        check.set_meta("modifier_id", str(modifier.get("id", "")))
        check.set_meta("base_font_size", 14)
        check.custom_minimum_size.y = 48
        modifier_box.add_child(check)

func _on_route_selected(index: int) -> void:
    character_option.clear()
    _character_ids.clear()
    if index < 0 or index >= _route_ids.size():
        return
    var world_id := _route_ids[index]
    for character_variant in MetaUnlockEngine.unlocked_characters(world_id):
        var character: Dictionary = character_variant as Dictionary
        var character_id := str(character.get("id", ""))
        _character_ids.append(character_id)
        character_option.add_item(str(character.get("name", character_id)))

func _on_mode_selected(_index: int) -> void:
    if _selected_id(_mode_ids, mode_option) == "fixed_seed" and seed_edit.text.strip_edges() == "0":
        status_label.text = "Trama Compartilhada exige uma seed positiva para que a jornada possa ser repetida."
    else:
        status_label.text = ""

func _start() -> void:
    var modifiers: Array = []
    for child in modifier_box.get_children():
        if child is CheckButton and (child as CheckButton).button_pressed:
            modifiers.append(str(child.get_meta("modifier_id", "")))
    var setup := {
        "world_id":_selected_id(_route_ids, route_option),
        "character_id":_selected_id(_character_ids, character_option),
        "journey_mode":_selected_id(_mode_ids, mode_option),
        "difficulty_id":_selected_id(_difficulty_ids, difficulty_option),
        "seed":int(seed_edit.text) if seed_edit.text.is_valid_int() else 0,
        "modifiers":modifiers,
    }
    var check := setup_engine.validate(setup)
    if not bool(check.get("ok", false)):
        status_label.text = "Configuração inválida: %s" % ", ".join(check.get("errors", []))
        return
    if not setup_engine.start(setup):
        status_label.text = "Não foi possível iniciar esta jornada."
        return
    get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _selected_id(ids: Array[String], option: OptionButton) -> String:
    var index := option.selected
    if index < 0 or index >= ids.size():
        return ""
    return ids[index]
