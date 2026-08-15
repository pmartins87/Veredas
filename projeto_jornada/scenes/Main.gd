extends Control

var localization := LocalizationService.new()

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
var _last_back_msec := -10000

func _ready() -> void:
    _build_ui()
    AccessibilityService.changed.connect(_on_accessibility_changed)
    MobilePlatformService.back_requested.connect(_on_mobile_back_requested)
    if GameState.run.is_empty():
        var restored := SaveService.load_game()
        if not restored or GameState.run.is_empty():
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

    var outer := SafeAreaMargin.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(outer)
    var reading_width := ReadingWidthMargin.new()
    outer.add_child(reading_width)

    page_panel = PanelContainer.new()
    reading_width.add_child(page_panel)
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
    header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
    location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

    var choices_scroll := ScrollContainer.new()
    choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    choices_scroll.follow_focus = true
    choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page.add_child(choices_scroll)

    choices = VBoxContainer.new()
    choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choices.add_theme_constant_override("separation", 8)
    choices_scroll.add_child(choices)

    var nav := HFlowContainer.new()
    nav.alignment = FlowContainer.ALIGNMENT_CENTER
    nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nav.add_theme_constant_override("h_separation", 7)
    nav.add_theme_constant_override("v_separation", 7)
    nav_story = _nav_button(localization.text("common.journey"), func(): RunFlowEngine.resume_story(); current_event = {}; _refresh())
    nav_inventory = _nav_button(localization.text("common.inventory"), func(): RunFlowEngine.open_inventory(); _refresh())
    nav_travel = _nav_button(localization.text("common.paths"), func(): RunFlowEngine.open_travel(); _refresh())
    var save := _nav_button(localization.text("common.save"), func(): SaveService.save_game())
    var access := _nav_button(localization.text("common.settings"), _open_accessibility)
    nav.add_child(nav_story)
    nav.add_child(nav_inventory)
    nav.add_child(nav_travel)
    nav.add_child(save)
    nav.add_child(access)
    page.add_child(nav)

    accessibility_panel = AccessibilityPanel.new()
    add_child(accessibility_panel)
    MobilePlatformService.apply_touch_targets(self)

func _nav_button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size.y = float(MobilePlatformService.MIN_TOUCH_TARGET)
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
    var world_view := localization.localize_record(world)
    var location_view := localization.localize_record(location)
    header.text = str(world_view.get("name", localization.text("main.game_title")))
    location_label.text = str(location_view.get("name", localization.text("main.unnamed_path")))
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
    MobilePlatformService.apply_touch_targets(self)
    BookVFX.page_settle(page_panel, AccessibilityService.reduce_motion())

func _render_story() -> void:
    if current_event.is_empty():
        current_event = RunFlowEngine.story_event()
    if current_event.is_empty():
        story.text = localization.text("main.story.none")
        return
    var title_size := AccessibilityService.font_size(25)
    var event_view := localization.localize_record(current_event)
    var kicker := str(event_view.get("kicker", ""))
    var kicker_block := ""
    if kicker != "":
        kicker_block = "[i]%s[/i]\n\n" % kicker
    story.text = "%s[font_size=%d][b]%s[/b][/font_size]\n\n%s" % [kicker_block, title_size, event_view.get("title",localization.text("main.story.default_title")), event_view.get("text","")]
    var localized_choices: Array = event_view.get("choices", []) as Array
    var available := EventDirector.available_choices(current_event)
    for entry in available:
        var idx := int(entry.get("index",0))
        var choice: Dictionary = entry.get("choice",{})
        var display_choice: Dictionary = (localized_choices[idx] as Dictionary) if idx >= 0 and idx < localized_choices.size() else choice
        _add_action_button(str(display_choice.get("text",localization.text("main.story.choose"))), _choose_story.bind(idx), idx == 0)
    if int(GameState.run.get("turn",0)) >= 6 and not RunFlowEngine.local_bosses().is_empty():
        _add_action_button(localization.text("main.story.face_boss"), _start_local_boss, false)

func _choose_story(index: int) -> void:
    var pool := str(current_event.get("pool", ""))
    var authored := AuthoredStoryDirector.is_authored_event(current_event)
    if not RunFlowEngine.choose(current_event, index):
        return
    current_event = {}
    if authored:
        var transition := AuthoredStoryDirector.consume_transition()
        if str(transition.get("type", "")) == "combat":
            var enemy_id := str(transition.get("enemy_id", ""))
            if enemy_id != "" and not ContentRegistry.get_record(enemy_id).is_empty():
                RunFlowEngine.start_combat(enemy_id)
            else:
                RunFlowEngine.resume_story()
        else:
            RunFlowEngine.resume_story()
        _refresh()
        return
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
    story.text = localization.text("main.inventory.body") % AccessibilityService.font_size(25)
    var inventory: Array = GameState.run.get("inventory", [])
    if inventory.is_empty():
        story.add_text(localization.text("main.inventory.empty"))
    var shown := {}
    for item_id in inventory:
        if shown.has(str(item_id)):
            continue
        shown[str(item_id)] = true
        var item := ContentRegistry.get_record(str(item_id))
        var item_view := localization.localize_record(item)
        var count := InventoryEngine.count_item(str(item_id))
        var label := "%s%s" % [AffixEngine.display_name(item_view), " ×%d" % count if count > 1 else ""]
        var slot := InventoryEngine.slot_for(item)
        if slot != "":
            _add_action_button(localization.text("main.inventory.equip") % label, func(): InventoryEngine.equip(str(item_id)); _refresh(), false)
        elif str(item.get("kind","")) in ["consumable","tool"]:
            _add_action_button(localization.text("main.inventory.use") % label, func(): InventoryEngine.use_item(str(item_id)); _refresh(), false)
    _add_action_button(localization.text("main.back_to_journey"), func(): RunFlowEngine.resume_story(); current_event = {}; _refresh(), true)

func _render_merchant() -> void:
    story.text = localization.text("main.merchant.body") % [AccessibilityService.font_size(25), GameState.run.get("resources",{}).get("fragments",0)]
    for item in MerchantEngine.stock(str(GameState.run.get("world_id","")), 8):
        var item_id := str(item.get("id",""))
        var cost := MerchantEngine.price(item_id)
        var item_view := localization.localize_record(item)
        var label := localization.text("main.merchant.price") % [AffixEngine.display_name(item_view), cost]
        var button := _add_action_button(label, func(): RunFlowEngine.buy(item_id); _refresh(), false)
        button.disabled = not MerchantEngine.can_buy(item_id)
    _add_action_button(localization.text("main.merchant.leave"), func(): RunFlowEngine.resume_story(); current_event = {}; _refresh(), true)

func _render_travel() -> void:
    story.text = localization.text("main.travel.body") % AccessibilityService.font_size(25)
    var current := str(GameState.run.get("location_id",""))
    for location_id in LocationEngine.available_locations():
        var loc := ContentRegistry.get_record(str(location_id))
        var loc_view := localization.localize_record(loc)
        var suffix := localization.text("main.travel.current") if str(location_id) == current else ""
        var button := _add_action_button("%s%s" % [loc_view.get("name",location_id), suffix], func(): RunFlowEngine.travel(str(location_id)); current_event = {}; _refresh(), false)
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
    story.text = localization.text("main.combat.summary") % [AccessibilityService.font_size(25), enemy.get("name",localization.text("main.combat.threat")), enemy.get("hp",0), enemy.get("max_hp",0), enemy.get("posture",0), enemy.get("max_posture",0), player.get("distance",1), intent.get("telegraph","observa"), player.get("hp",0), player.get("max_hp",0), player.get("vigor",0), player.get("max_vigor",0), str(resource)]
    for action in ["strike","precise","guard","advance","retreat"]:
        var names := {"strike":localization.text("main.combat.strike"),"precise":localization.text("main.combat.precise"),"guard":localization.text("main.combat.guard"),"advance":localization.text("main.combat.advance"),"retreat":localization.text("main.combat.retreat")}
        _add_action_button(str(names[action]), _combat_action.bind(action), action == "strike")
    for ability in CharacterKitEngine.abilities_for(str(GameState.run.get("character_id",""))):
        var cost := int(ability.get("cost",0))
        var ability_view := localization.localize_record(ability)
        var resource_label := localization.label("resource", str(ability.get("resource", "")))
        var label := "★ %s — %d %s" % [ability_view.get("name",localization.text("main.combat.ability")), cost, resource_label]
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
    story.text = localization.text("main.finals.body") % AccessibilityService.font_size(25)
    for ending in RunFlowEngine.endings_for_current_world():
        var ending_id := str(ending.get("id",""))
        var ending_view := localization.localize_record(ending)
        _add_action_button(str(ending_view.get("name",localization.text("main.finals.default"))), func(): RunFlowEngine.finish(ending_id); _refresh(), false)

func _render_debrief() -> void:
    var report := RunFlowEngine.debrief()
    var authored: Dictionary = report.get("authored_debrief", {}) as Dictionary
    if not authored.is_empty():
        story.text = "[font_size=%d][b]%s[/b][/font_size]\n\n%s\n\n[i]%s[/i]" % [AccessibilityService.font_size(25), str(authored.get("title", "Fim da jornada")), str(authored.get("text", "")), localization.text("main.debrief.authored_epilogue")]
        _add_action_button(localization.text("main.debrief.restart"), func(): RunFlowEngine.start_journey("character.mata_fio_verde.01", int(Time.get_unix_time_from_system()) & 0x7fffffff); current_event = {}; _refresh(), true)
        return
    var ending := ContentRegistry.get_record(str(report.get("ending_id","")))
    var ending_view := localization.localize_record(ending)
    var result_key := "main.debrief.result.%s" % str(report.get("result", "in_progress"))
    var result_label := localization.text(result_key)
    if result_label == result_key:
        result_label = localization.text("main.debrief.result.unknown")
    story.text = localization.text("main.debrief.body") % [AccessibilityService.font_size(25), result_label, ending_view.get("name","—"), report.get("turns",0), report.get("visited_locations",[]).size(), report.get("defeated_enemies",[]).size(), report.get("purchases",[]).size(), report.get("marks",{}).size()]
    _add_action_button(localization.text("main.debrief.restart"), func(): RunFlowEngine.start_journey("character.mata_fio_verde.01", int(Time.get_unix_time_from_system()) & 0x7fffffff); current_event = {}; _refresh(), true)

func _clear_choices() -> void:
    for child in choices.get_children():
        child.queue_free()

func _add_action_button(text_value: String, callback: Callable, primary: bool) -> Button:
    var button := Button.new()
    button.text = text_value
    button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button.custom_minimum_size = Vector2(0, maxf(54.0, float(MobilePlatformService.MIN_TOUCH_TARGET)))
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

func _on_mobile_back_requested() -> void:
    if accessibility_panel != null and accessibility_panel.visible:
        accessibility_panel.close_panel()
        return
    var mode := str(GameState.run.get("mode", "story"))
    if mode in ["inventory", "merchant", "travel"]:
        RunFlowEngine.resume_story()
        current_event = {}
        _refresh()
        return
    if mode in ["combat", "final_choice"]:
        var now := Time.get_ticks_msec()
        SaveService.save_game()
        if now - _last_back_msec <= 1500 and MobilePlatformService.is_mobile():
            get_tree().quit()
            return
        _last_back_msec = now
        story.append_text(localization.text("main.save_exit"))
        AccessibilityService.haptic(22, 0.22)
        return
    SaveService.save_game()
    if MobilePlatformService.is_mobile():
        get_tree().quit()
