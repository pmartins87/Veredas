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
var accessibility_panel: AccessibilityPanel
var nav_story: Button
var nav_inventory: Button
var nav_travel: Button
var current_domain_id := "mata_fio_verde"

func _ready() -> void:
    _build_ui()
    AccessibilityService.changed.connect(_on_accessibility_changed)
    if GameState.run.is_empty():
        RunFlowEngine.start_journey("character.mata_fio_verde.01", int(Time.get_unix_time_from_system()) & 0x7fffffff)
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
    page.add_theme_constant_override("separation", 10)
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
    header.set_meta("base_font_size", 32)
    title_row.add_child(header)
    var trama_icon := TextureRect.new()
    trama_icon.texture = VectorAtlasRegistry.system_icon("trama")
    trama_icon.custom_minimum_size = Vector2(42, 42)
    trama_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    trama_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    title_row.add_child(trama_icon)
    page.add_child(title_row)

    location_label = Label.new()
    location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    location_label.set_meta("base_font_size", 16)
    page.add_child(location_label)

    stats = RichTextLabel.new()
    stats.fit_content = true
    stats.custom_minimum_size = Vector2(0, 34)
    stats.scroll_active = false
    stats.set_meta("base_font_size", 16)
    page.add_child(stats)
    page.add_child(HSeparator.new())

    story = RichTextLabel.new()
    story.bbcode_enabled = true
    story.size_flags_vertical = Control.SIZE_EXPAND_FILL
    story.scroll_active = true
    story.set_meta("base_font_size", 19)
    page.add_child(story)

    choices = VBoxContainer.new()
    choices.add_theme_constant_override("separation", 8)
    page.add_child(choices)

    var nav := HBoxContainer.new()
    nav.alignment = BoxContainer.ALIGNMENT_CENTER
    nav.add_theme_constant_override("separation", 7)
    nav_story = _nav_button("Jornada", func(): RunFlowEngine.resume_story(); current_event = {}; _refresh())
    nav_inventory = _nav_button("Inventário", func(): RunFlowEngine.open_inventory(); _refresh())
    nav_travel = _nav_button("Veredas", func(): RunFlowEngine.open_travel(); _refresh())
    var save := _nav_button("Salvar", func(): SaveService.save_game())
    var access := _nav_button("Ajustes", _open_accessibility)
    nav.add_child(nav_story)
    nav.add_child(nav_inventory)
    nav.add_child(nav_travel)
    nav.add_child(save)
    nav.add_child(access)
    page.add_child(nav)

    accessibility_panel = AccessibilityPanel.new()
    add_child(accessibility_panel)

func _nav_button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.set_meta("base_font_size", 14)
    button.pressed.connect(callback)
    return button

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
        material.set_shader_parameter("domain_strength", 0.025 if AccessibilityService.high_contrast() else 0.065)
    AccessibilityService.apply_font_scale(self)

func _render_stats() -> void:
    stats.clear()
    stats.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
    InlineIconRegistry.append_icon(stats, "health", 19)
    stats.add_text(" %s/%s   " % [GameState.run.get("health",0), GameState.run.get("max_health",0)])
    InlineIconRegistry.append_icon(stats, "vigor", 19)
    stats.add_text(" %s/%s   " % [GameState.run.get("vigor",0), GameState.run.get("max_vigor",0)])
    InlineIconRegistry.append_icon(stats, "coin", 19)
    stats.add_text(" %s   " % GameState.run.get("resources",{}).get("fragments",0))
    InlineIconRegistry.append_icon(stats, "mark", 19)
    stats.add_text(" %s" % GameState.run.get("marks",{}).size())
    stats.pop()

func _refresh() -> void:
    var world_id := str(GameState.run.get("world_id", "world.mata_fio_verde"))
    current_domain_id = _domain_id(world_id)
    var loc := str(GameState.run.get("location_id", ""))
    var world := ContentRegistry.get_record(world_id)
    var location := ContentRegistry.get_record(loc)
    header.text = str(world.get("name", "Veredas da Trama"))
    location_label.text = str(location.get("name", "Uma Vereda sem nome"))
    _apply_visuals(current_domain_id)
    _render_stats()
    _clear_choices()

    var mode := str(GameState.run.get("mode", "story"))
    var locked := mode in ["combat", "final_choice", "debrief"]
    nav_story.disabled = locked
    nav_inventory.disabled = locked
    nav_travel.disabled = locked
    match mode:
        "inventory": _render_inventory()
        "merchant": _render_merchant()
        "travel": _render_travel()
        "combat": _render_combat()
        "final_choice": _render_finals()
        "debrief": _render_debrief()
        _: _render_story()
    AccessibilityService.apply_font_scale(self)
    BookVFX.page_settle(page_panel, AccessibilityService.reduce_motion())

func _render_story() -> void:
    if current_event.is_empty():
        current_event = RunFlowEngine.story_event()
    if current_event.is_empty():
        story.text = "[b]A Vereda silencia.[/b]\n\nNenhuma situação está disponível aqui agora. Viaje para outra localidade."
        return
    var title_size := AccessibilityService.font_size(25)
    story.text = "[font_size=%d][b]%s[/b][/font_size]\n\n%s" % [title_size, current_event.get("title","A Vereda aguarda"), current_event.get("text","")]
    var available := EventDirector.available_choices(current_event)
    for entry in available:
        var idx := int(entry.get("index",0))
        var choice: Dictionary = entry.get("choice",{})
        _add_action_button(str(choice.get("text","Escolher")), _choose_story.bind(idx), idx == 0)
    if int(GameState.run.get("turn",0)) >= 6 and not RunFlowEngine.local_bosses().is_empty():
        _add_action_button("Enfrentar a ameaça que domina este lugar", _start_local_boss, false)

func _choose_story(index: int) -> void:
    var pool := str(current_event.get("pool", ""))
    if not RunFlowEngine.choose(current_event, index):
        return
    current_event = {}
    match pool:
        "creature":
            var monsters := RunFlowEngine.local_monsters()
            if not monsters.is_empty():
                RunFlowEngine.start_combat(str(monsters[0].get("id","")))
        "trade":
            RunFlowEngine.open_merchant(8)
        "route":
            RunFlowEngine.open_travel()
        _:
            RunFlowEngine.resume_story()
    _refresh()

func _render_inventory() -> void:
    story.text = "[font_size=%d][b]Inventário[/b][/font_size]\n\nItens carregados e equipamento atual." % AccessibilityService.font_size(25)
    var inventory: Array = GameState.run.get("inventory", [])
    if inventory.is_empty():
        story.add_text("\n\nVocê ainda não carrega nenhum item.")
    var shown := {}
    for item_id in inventory:
        if shown.has(str(item_id)):
            continue
        shown[str(item_id)] = true
        var item := ContentRegistry.get_record(str(item_id))
        var count := InventoryEngine.count_item(str(item_id))
        var label := "%s%s" % [AffixEngine.display_name(item), " ×%d" % count if count > 1 else ""]
        var slot := InventoryEngine.slot_for(item)
        if slot != "":
            _add_action_button("Equipar — %s" % label, func(): InventoryEngine.equip(str(item_id)); _refresh(), false)
        elif str(item.get("kind","")) in ["consumable","tool"]:
            _add_action_button("Usar — %s" % label, func(): InventoryEngine.use_item(str(item_id)); _refresh(), false)
    _add_action_button("Voltar à jornada", func(): RunFlowEngine.resume_story(); current_event = {}; _refresh(), true)

func _render_merchant() -> void:
    story.text = "[font_size=%d][b]Mercador da Vereda[/b][/font_size]\n\nFragmentos disponíveis: %s. O estoque muda conforme a jornada avança." % [AccessibilityService.font_size(25), GameState.run.get("resources",{}).get("fragments",0)]
    for item in MerchantEngine.stock(str(GameState.run.get("world_id","")), 8):
        var item_id := str(item.get("id",""))
        var cost := MerchantEngine.price(item_id)
        var label := "%s — %d Fragmentos" % [AffixEngine.display_name(item), cost]
        var button := _add_action_button(label, func(): RunFlowEngine.buy(item_id); _refresh(), false)
        button.disabled = not MerchantEngine.can_buy(item_id)
    _add_action_button("Deixar o mercador", func(): RunFlowEngine.resume_story(); current_event = {}; _refresh(), true)

func _render_travel() -> void:
    story.text = "[font_size=%d][b]Veredas locais[/b][/font_size]\n\nEscolha a próxima localidade. Lugares já visitados permanecem registrados na jornada." % AccessibilityService.font_size(25)
    var current := str(GameState.run.get("location_id",""))
    for location_id in LocationEngine.available_locations():
        var loc := ContentRegistry.get_record(str(location_id))
        var suffix := " — atual" if str(location_id) == current else ""
        var button := _add_action_button("%s%s" % [loc.get("name",location_id), suffix], func(): RunFlowEngine.travel(str(location_id)); current_event = {}; _refresh(), false)
        button.disabled = str(location_id) == current

func _render_combat() -> void:
    var combat: Dictionary = CombatEngine.combat
    if combat.is_empty():
        RunFlowEngine.resume_story()
        _refresh()
        return
    var enemy: Dictionary = combat.get("enemy",{})
    var player: Dictionary = combat.get("player",{})
    var intent: Dictionary = combat.get("intent",{})
    var resource: Dictionary = combat.get("signature_resource",{})
    story.text = "[font_size=%d][b]%s[/b][/font_size]\n\nVida %s/%s • Postura %s/%s • Distância %s\n\n[b]Intenção:[/b] %s\n\nVocê: Vida %s/%s • Vigor %s/%s • Recurso %s" % [AccessibilityService.font_size(25), enemy.get("name","Ameaça"), enemy.get("hp",0), enemy.get("max_hp",0), enemy.get("posture",0), enemy.get("max_posture",0), player.get("distance",1), intent.get("telegraph","observa"), player.get("hp",0), player.get("max_hp",0), player.get("vigor",0), player.get("max_vigor",0), str(resource)]
    for action in ["strike","precise","guard","advance","retreat"]:
        var names := {"strike":"Golpear","precise":"Ataque preciso","guard":"Firmar guarda","advance":"Avançar","retreat":"Recuar"}
        _add_action_button(str(names[action]), _combat_action.bind(action), action == "strike")
    for ability in CharacterKitEngine.abilities_for(str(GameState.run.get("character_id",""))):
        var cost := int(ability.get("cost",0))
        var label := "★ %s — %d %s" % [ability.get("name","Habilidade"), cost, ability.get("resource","")]
        var button := _add_action_button(label, _combat_ability.bind(str(ability.get("id",""))), false)
        button.disabled = not CharacterKitEngine.can_pay(ability, combat.get("signature_resource",{}))

func _combat_action(action: String) -> void:
    RunFlowEngine.combat_action(action)
    _refresh()

func _combat_ability(ability_id: String) -> void:
    RunFlowEngine.combat_ability(ability_id)
    _refresh()

func _start_local_boss() -> void:
    var bosses := RunFlowEngine.local_bosses()
    if bosses.is_empty():
        return
    current_event = {}
    RunFlowEngine.start_combat(str(bosses[0].get("id","")))
    _refresh()

func _render_finals() -> void:
    story.text = "[font_size=%d][b]Convergência local[/b][/font_size]\n\nA ameaça caiu, mas vencer não responde o que deve acontecer com este lugar. Escolha a consequência que sua jornada deixará." % AccessibilityService.font_size(25)
    for ending in RunFlowEngine.endings_for_current_world():
        var ending_id := str(ending.get("id",""))
        _add_action_button(str(ending.get("name","Desfecho")), func(): RunFlowEngine.finish(ending_id); _refresh(), false)

func _render_debrief() -> void:
    var report := RunFlowEngine.debrief()
    var ending := ContentRegistry.get_record(str(report.get("ending_id","")))
    story.text = "[font_size=%d][b]Fim da jornada[/b][/font_size]\n\nResultado: %s\nDesfecho: %s\nBatidas: %s\nLocalidades visitadas: %s\nInimigos derrotados: %s\nCompras: %s\nMarcas: %s" % [AccessibilityService.font_size(25), report.get("result",""), ending.get("name","—"), report.get("turns",0), report.get("visited_locations",[]).size(), report.get("defeated_enemies",[]).size(), report.get("purchases",[]).size(), report.get("marks",{}).size()]
    _add_action_button("Iniciar outra jornada", func(): RunFlowEngine.start_journey("character.mata_fio_verde.01", int(Time.get_unix_time_from_system()) & 0x7fffffff); current_event = {}; _refresh(), true)

func _clear_choices() -> void:
    for child in choices.get_children():
        child.queue_free()

func _add_action_button(text_value: String, callback: Callable, primary: bool) -> Button:
    var button := Button.new()
    button.text = text_value
    button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button.custom_minimum_size = Vector2(0, 54)
    button.set_meta("base_font_size", 16)
    BookCardStyle.apply_button(button, current_domain_id, DomainThemeService, primary)
    button.pressed.connect(_press_action.bind(button, callback))
    choices.add_child(button)
    return button

func _press_action(button: Button, callback: Callable) -> void:
    var tween := BookVFX.choice_press(button, AccessibilityService.reduce_motion())
    AccessibilityService.haptic(18, 0.28)
    if tween != null:
        await tween.finished
    if callback.is_valid():
        callback.call()

func _open_accessibility() -> void:
    accessibility_panel.open_for(current_domain_id)

func _on_accessibility_changed() -> void:
    if not is_node_ready():
        return
    _apply_visuals(current_domain_id)
    _render_stats()
