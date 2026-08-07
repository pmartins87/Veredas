extends Control

var current_event: Dictionary = {}
var story: RichTextLabel
var choices: VBoxContainer
var header: Label
var location_label: Label
var stats: RichTextLabel
var page_panel: PanelContainer
var ornament: TextureRect
var background: ColorRect

func _ready() -> void:
    _build_ui()
    if GameState.run.is_empty():
        GameState.new_run("character.mata_fio_verde.01", int(Time.get_unix_time_from_system()) & 0x7fffffff)
    _refresh()

func _build_ui() -> void:
    background = ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var shader := load("res://ui/shaders/parchment_paper.gdshader") as Shader
    if shader != null:
        var material := ShaderMaterial.new()
        material.shader = shader
        background.material = material
    add_child(background)

    var outer := MarginContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("margin_left", 18)
    outer.add_theme_constant_override("margin_right", 18)
    outer.add_theme_constant_override("margin_top", 18)
    outer.add_theme_constant_override("margin_bottom", 18)
    add_child(outer)

    page_panel = PanelContainer.new()
    outer.add_child(page_panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    page_panel.add_child(margin)

    var page := VBoxContainer.new()
    page.add_theme_constant_override("separation", 11)
    margin.add_child(page)

    var title_row := HBoxContainer.new()
    title_row.alignment = BoxContainer.ALIGNMENT_CENTER
    ornament = TextureRect.new()
    ornament.custom_minimum_size = Vector2(42, 42)
    ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ornament.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    title_row.add_child(ornament)
    header = Label.new()
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(header)
    var mark_icon := TextureRect.new()
    mark_icon.texture = VectorAtlasRegistry.system_icon("trama")
    mark_icon.custom_minimum_size = Vector2(42, 42)
    mark_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mark_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    title_row.add_child(mark_icon)
    page.add_child(title_row)

    location_label = Label.new()
    location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    location_label.add_theme_font_size_override("font_size", 17)
    page.add_child(location_label)

    stats = RichTextLabel.new()
    stats.fit_content = true
    stats.custom_minimum_size = Vector2(0, 34)
    stats.scroll_active = false
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.add_theme_font_size_override("normal_font_size", 17)
    page.add_child(stats)
    page.add_child(HSeparator.new())

    story = RichTextLabel.new()
    story.bbcode_enabled = true
    story.size_flags_vertical = Control.SIZE_EXPAND_FILL
    story.scroll_active = true
    page.add_child(story)

    choices = VBoxContainer.new()
    choices.add_theme_constant_override("separation", 9)
    page.add_child(choices)

    var nav := HBoxContainer.new()
    nav.alignment = BoxContainer.ALIGNMENT_CENTER
    nav.add_theme_constant_override("separation", 10)
    var save := Button.new()
    save.text = "Salvar"
    save.tooltip_text = "Salva a jornada atual"
    save.pressed.connect(func(): SaveService.save_game())
    nav.add_child(save)
    var next := Button.new()
    next.text = "Nova situação"
    next.tooltip_text = "Avança sem escolher somente em builds de teste"
    next.pressed.connect(_refresh)
    nav.add_child(next)
    page.add_child(nav)

func _domain_id(world_id: String) -> String:
    return world_id.trim_prefix("world.")

func _apply_visuals(domain_id: String) -> void:
    BookCardStyle.apply_panel(page_panel, domain_id, DomainThemeService, "normal")
    BookCardStyle.apply_heading(header, domain_id, DomainThemeService, 1)
    location_label.add_theme_color_override("font_color", DomainThemeService.color("primary", domain_id))
    stats.add_theme_color_override("default_color", DomainThemeService.color("ink_soft", domain_id))
    BookCardStyle.apply_body(story, domain_id, DomainThemeService)
    ornament.texture = VectorAtlasRegistry.domain_ornament(domain_id)
    ornament.modulate = DomainThemeService.color("primary", domain_id)
    if background.material is ShaderMaterial:
        var material := background.material as ShaderMaterial
        material.set_shader_parameter("paper_light", DomainThemeService.color("paper_light", domain_id))
        material.set_shader_parameter("paper_dark", DomainThemeService.color("paper_dark", domain_id))
        material.set_shader_parameter("domain_wash", DomainThemeService.color("wash", domain_id))
        material.set_shader_parameter("domain_strength", 0.065)

func _render_stats() -> void:
    stats.clear()
    InlineIconRegistry.append_icon(stats, "health", 20)
    stats.add_text(" %s/%s    " % [GameState.run.get("health", 0), GameState.run.get("max_health", 0)])
    InlineIconRegistry.append_icon(stats, "vigor", 20)
    stats.add_text(" %s/%s    " % [GameState.run.get("vigor", 0), GameState.run.get("max_vigor", 0)])
    InlineIconRegistry.append_icon(stats, "coin", 20)
    stats.add_text(" %s    " % GameState.run.get("resources", {}).get("fragments", 0))
    InlineIconRegistry.append_icon(stats, "mark", 20)
    stats.add_text(" %s" % GameState.run.get("marks", {}).size())

func _refresh() -> void:
    var world_id := str(GameState.run.get("world_id", "world.mata_fio_verde"))
    var domain_id := _domain_id(world_id)
    var loc := str(GameState.run.get("location_id", ""))
    current_event = EventDirector.choose_event(world_id, loc)
    var world := ContentRegistry.get_record(world_id)
    var location := ContentRegistry.get_record(loc)
    header.text = str(world.get("name", "Veredas da Trama"))
    location_label.text = str(location.get("name", "Uma Vereda sem nome"))
    _apply_visuals(domain_id)
    _render_stats()

    var narrative := "[font_size=25][b]%s[/b][/font_size]\n\n%s" % [current_event.get("title", "A Vereda aguarda"), current_event.get("text", "Nenhum evento elegível.")]
    story.text = InlineIconRegistry.render_bbcode_fallback(narrative) if InlineIconRegistry.has_method("render_bbcode_fallback") else narrative

    for child in choices.get_children():
        child.queue_free()
    var options: Array = current_event.get("choices", [])
    for i in range(options.size()):
        var button := Button.new()
        button.text = str(options[i].get("text", "Escolher"))
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.custom_minimum_size = Vector2(0, 60)
        BookCardStyle.apply_button(button, domain_id, DomainThemeService, i == 0)
        var idx := i
        button.pressed.connect(func(): EventDirector.apply_choice(current_event, idx); _refresh())
        choices.add_child(button)
