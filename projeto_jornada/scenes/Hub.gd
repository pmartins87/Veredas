extends Control

const ANDROID_CI_MARKER := "user://android_ci_autostart"
const ANDROID_CI_SEED := 881001

var page_panel: PanelContainer
var title: Label
var summary: RichTextLabel
var actions: VBoxContainer
var loaded_active_run := false

func _ready() -> void:
    if _consume_android_ci_marker():
        return
    loaded_active_run = SaveService.load_game() and not GameState.run.is_empty() and bool(GameState.run.get("active", false))
    if loaded_active_run and _android_ci_run_active():
        call_deferred("_continue_run")
        return
    HubEngine.ensure_state()
    MetaUnlockEngine.evaluate_progression()
    CodexProgressEngine.new().ensure_state()
    MetaEconomyEngine.new().sync_rewards()
    if not loaded_active_run:
        HubEngine.enter()
    _build_ui()
    _render()

func _consume_android_ci_marker() -> bool:
    if not OS.is_debug_build() or not OS.has_feature("android"):
        return false
    if not FileAccess.file_exists(ANDROID_CI_MARKER):
        return false
    var absolute_marker := ProjectSettings.globalize_path(ANDROID_CI_MARKER)
    DirAccess.remove_absolute(absolute_marker)
    GameState.reset_profile()
    MetaUnlockEngine.ensure_state()
    if not RunFlowEngine.start_journey("character.mata_fio_verde.01", ANDROID_CI_SEED):
        push_error("Android CI autostart could not create a canonical journey")
        return false
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["ci.android_autostart"] = true
    GameState.run.flags = flags
    SaveService.save_game()
    call_deferred("_continue_run")
    return true

func _android_ci_run_active() -> bool:
    if not OS.is_debug_build() or not OS.has_feature("android"):
        return false
    return bool((GameState.run.get("flags", {}) as Dictionary).get("ci.android_autostart", false))

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
    var ornament_id := str(MetaEconomyEngine.new().summary().get("selected_ornament", "plain"))
    match ornament_id:
        "ink": ornament.texture = VectorAtlasRegistry.domain_ornament("mata_fio_verde")
        "echo": ornament.texture = VectorAtlasRegistry.system_icon("echo")
        _: ornament.texture = VectorAtlasRegistry.system_icon("trama")
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
    MetaUnlockEngine.evaluate_progression()
    var codex := CodexProgressEngine.new()
    codex.ensure_state()
    var economy := MetaEconomyEngine.new()
    var economy_summary: Dictionary = economy.summary()
    var hub: Dictionary = HubEngine.summary()
    var unlocks: Dictionary = MetaUnlockEngine.summary()
    var echoes: Dictionary = EchoConsequenceEngine.summary()
    var lines: Array[String] = []
    lines.append("[font_size=%d][b]Um ponto estável entre Veredas instáveis.[/b][/font_size]" % AccessibilityService.font_size(23))
    lines.append("")
    lines.append("Estágio do Nó: [b]%s/5[/b]   •   Visitas: %s   •   Residentes: %s" % [hub.stage, hub.visits, hub.residents])
    lines.append("Andarilhos: [b]%s/36[/b]   •   Rotas: [b]%s/12[/b]   •   Modos: [b]%s/4[/b]   •   Códice: [b]%s[/b]" % [unlocks.characters, unlocks.routes, unlocks.modes, unlocks.codex])
    lines.append("Conquistas: [b]%s/%s[/b]   •   Ecos persistentes: [b]%s[/b]   •   Consequências: [b]%s[/b]" % [codex.unlocked_achievement_count(), CodexProgressEngine.ACHIEVEMENTS.size(), echoes.echo_marks, echoes.consequences])
    lines.append("Fios de Vigília: [b]%s[/b]   •   Gastos: %s   •   Aquisições: %s" % [economy_summary.balance, economy_summary.lifetime_spent, economy_summary.purchases])
    lines.append("")
    lines.append("[b]Instalações[/b]")
    for facility_variant in hub.facilities:
        var facility: Dictionary = facility_variant as Dictionary
        var marker := "✓" if bool(facility.unlocked) else "·"
        lines.append("%s [b]%s[/b] — %s" % [marker, facility.name, facility.description])

    var modes: Array = MetaUnlockEngine.unlocked_modes()
    if not modes.is_empty():
        lines.append("")
        lines.append("[b]Formas de jornada conhecidas[/b]")
        for mode_variant in modes:
            var mode: Dictionary = mode_variant as Dictionary
            lines.append("• %s — %s" % [mode.name, mode.description])

    if not HubEngine.residents().is_empty():
        lines.append("")
        lines.append("[b]Pessoas que encontraram abrigo no Nó[/b]")
        for npc_id_variant in HubEngine.residents().slice(0, 6):
            var npc_id: String = str(npc_id_variant)
            var npc: Dictionary = ContentRegistry.get_record(npc_id)
            lines.append("• %s" % npc.get("name", npc_id))
    summary.text = "\n".join(lines)

    if loaded_active_run:
        _button("Continuar jornada", _continue_run, true)
        _button("Abandonar jornada e retornar ao Nó", _abandon_run, false)
    else:
        _button("Preparar jornada", _open_journey_setup, true)
        for world_id_variant in HubEngine.routes():
            var world_id: String = str(world_id_variant)
            var world: Dictionary = ContentRegistry.get_record(world_id)
            _button("Examinar rota — %s" % world.get("name", world_id), func(): _show_route(world_id), false)
    _button("Arquivo de Ecos", _open_codex, false)
    _button("Mesa dos Fios", _open_meta_economy, false)
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

func _open_journey_setup() -> void:
    get_tree().change_scene_to_file("res://scenes/JourneySetup.tscn")

func _open_codex() -> void:
    get_tree().change_scene_to_file("res://scenes/Codex.tscn")

func _open_meta_economy() -> void:
    get_tree().change_scene_to_file("res://scenes/VigilThreads.tscn")

func _abandon_run() -> void:
    GameState.run.active = false
    GameState.run.mode = "hub"
    loaded_active_run = false
    HubEngine.enter()
    MetaEconomyEngine.new().sync_rewards()
    _render()

func _show_route(world_id: String) -> void:
    var world: Dictionary = ContentRegistry.get_record(world_id)
    var characters: Array = MetaUnlockEngine.unlocked_characters(world_id)
    summary.append_text("\n\n[i]A Mesa das Veredas conhece o caminho para %s. Andarilhos disponíveis nesta rota: %d. Use Preparar jornada para selecionar rota, Andarilho, modo, dificuldade, seed e modificadores.[/i]" % [world.get("name", world_id), characters.size()])

func _open_accessibility() -> void:
    var panel := AccessibilityPanel.new()
    add_child(panel)
    panel.open_for("mata_fio_verde")
