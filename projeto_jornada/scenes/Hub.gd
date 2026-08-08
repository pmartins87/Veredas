extends Control

var page_panel: PanelContainer
var title: Label
var summary: RichTextLabel
var actions: VBoxContainer
var loaded_active_run := false

func _ready() -> void:
    loaded_active_run = SaveService.load_game() and not GameState.run.is_empty() and bool(GameState.run.get("active", false))
    HubEngine.ensure_state()
    if not loaded_active_run:
        HubEngine.enter()
    _build_ui()
    _render()

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
    page_panel = PanelContainer.new()
    reading.add_child(page_panel)
    BookCardStyle.apply_panel(page_panel, "mata_fio_verde", DomainThemeService, "normal")

    var margin := MarginContainer.new()
    for side in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_%s" % side, 20)
    page_panel.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    margin.add_child(column)

    var top := HBoxContainer.new()
    top.alignment = BoxContainer.ALIGNMENT_CENTER
    var ornament := TextureRect.new()
    ornament.texture = VectorAtlasRegistry.system_icon("trama")
    ornament.custom_minimum_size = Vector2(52,52)
    ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ornament.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    top.add_child(ornament)
    title = Label.new()
    title.text = "Nó de Vigília"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.set_meta("base_font_size", 34)
    BookCardStyle.apply_heading(title, "mata_fio_verde", DomainThemeService, 1)
    top.add_child(title)
    column.add_child(top)

    summary = RichTextLabel.new()
    summary.bbcode_enabled = true
    summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
    summary.set_meta("base_font_size", 18)
    BookCardStyle.apply_body(summary, "mata_fio_verde", DomainThemeService)
    column.add_child(summary)

    actions = VBoxContainer.new()
    actions.add_theme_constant_override("separation", 9)
    column.add_child(actions)
    MobilePlatformService.apply_touch_targets(self)
    AccessibilityService.apply_font_scale(self)

func _render() -> void:
    for child in actions.get_children():
        child.queue_free()
    var hub := HubEngine.summary()
    var lines: Array[String] = []
    lines.append("[font_size=%d][b]Um ponto estável entre Veredas instáveis.[/b][/font_size]" % AccessibilityService.font_size(23))
    lines.append("")
    lines.append("Estágio do Nó: [b]%s/5[/b]   •   Visitas: %s   •   Rotas: %s   •   Residentes: %s" % [hub.stage, hub.visits, hub.routes, hub.residents])
    lines.append("")
    lines.append("[b]Instalações[/b]")
    for facility in hub.facilities:
        var marker := "✓" if bool(facility.unlocked) else "·"
        lines.append("%s [b]%s[/b] — %s" % [marker, facility.name, facility.description])
    if not HubEngine.residents().is_empty():
        lines.append("")
        lines.append("[b]Pessoas que encontraram abrigo no Nó[/b]")
        for npc_id in HubEngine.residents().slice(0, 6):
            var npc := ContentRegistry.get_record(str(npc_id))
            lines.append("• %s" % npc.get("name", npc_id))
    summary.text = "\n".join(lines)

    if loaded_active_run:
        _button("Continuar jornada", _continue_run, true)
        _button("Abandonar jornada e retornar ao Nó", _abandon_run, false)
    else:
        _button("Partir pela Mata do Fio Verde", _start_default, true)
        for world_id in HubEngine.routes():
            var world := ContentRegistry.get_record(str(world_id))
            if str(world_id) != "world.mata_fio_verde":
                _button("Ver rota — %s" % world.get("name", world_id), func(): _show_route(str(world_id)), false)
    _button("Acessibilidade", _open_accessibility, false)

func _button(text_value: String, callback: Callable, primary: bool) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 56)
    button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button.set_meta("base_font_size", 17)
    BookCardStyle.apply_button(button, "mata_fio_verde", DomainThemeService, primary)
    button.pressed.connect(callback)
    actions.add_child(button)
    return button

func _continue_run() -> void:
    get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _start_default() -> void:
    RunFlowEngine.start_journey("character.mata_fio_verde.01", int(Time.get_unix_time_from_system()) & 0x7fffffff)
    SaveService.save_game()
    get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _abandon_run() -> void:
    GameState.run.active = false
    GameState.run.mode = "hub"
    loaded_active_run = false
    HubEngine.enter()
    _render()

func _show_route(world_id: String) -> void:
    var world := ContentRegistry.get_record(world_id)
    summary.append_text("\n\n[i]A Mesa das Veredas já conhece o caminho para %s. A preparação detalhada da próxima jornada será escolhida na etapa 9.4.[/i]" % world.get("name", world_id))

func _open_accessibility() -> void:
    var panel := AccessibilityPanel.new()
    add_child(panel)
    panel.open_for("mata_fio_verde")
