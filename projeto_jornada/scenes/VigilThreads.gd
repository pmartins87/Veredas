extends Control

var localization := LocalizationService.new()

var economy := MetaEconomyEngine.new()
var body: RichTextLabel
var products: VBoxContainer
var feedback: Label

func _ready() -> void:
    _build_ui()
    _refresh(true)
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
    heading.text = localization.text("vigil.title")
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.set_meta("base_font_size", 32)
    BookCardStyle.apply_heading(heading, "mata_fio_verde", DomainThemeService, 1)
    column.add_child(heading)

    var intro := Label.new()
    intro.text = localization.text("vigil.intro")
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    intro.set_meta("base_font_size", 15)
    column.add_child(intro)

    body = RichTextLabel.new()
    body.bbcode_enabled = true
    body.fit_content = true
    body.scroll_active = false
    body.set_meta("base_font_size", 17)
    BookCardStyle.apply_body(body, "mata_fio_verde", DomainThemeService)
    column.add_child(body)

    feedback = Label.new()
    feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback.set_meta("base_font_size", 14)
    column.add_child(feedback)

    products = VBoxContainer.new()
    products.add_theme_constant_override("separation", 8)
    column.add_child(products)

    var back := Button.new()
    back.text = localization.text("common.back_to_hub")
    back.custom_minimum_size.y = 54
    back.set_meta("base_font_size", 16)
    BookCardStyle.apply_button(back, "mata_fio_verde", DomainThemeService, true)
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Hub.tscn"))
    column.add_child(back)

func _refresh(claim_rewards: bool = false) -> void:
    var reward := {"awarded":0,"new_rewards":[]}
    if claim_rewards:
        reward = economy.sync_rewards()
    var summary: Dictionary = economy.summary()
    var lines: Array[String] = []
    lines.append(localization.text("vigil.balance") % [int(summary.balance), localization.text("vigil.currency")])
    lines.append(localization.text("vigil.lifetime") % [int(summary.lifetime_earned), int(summary.lifetime_spent)])
    lines.append(localization.text("vigil.markers") % [int(summary.journey_presets), int(summary.seed_notebook), int(summary.codex_pins)])
    lines.append(localization.text("vigil.ornament_selected") % _ornament_name(str(summary.selected_ornament)))
    body.text = "\n".join(lines)

    var awarded := int(reward.get("awarded", 0))
    if awarded > 0:
        feedback.text = localization.text("vigil.reward") % awarded
    elif claim_rewards:
        feedback.text = localization.text("vigil.no_reward")

    for child in products.get_children():
        child.queue_free()
    for product_variant in economy.catalog():
        var product: Dictionary = product_variant as Dictionary
        var button := Button.new()
        var state := localization.text("vigil.owned") if bool(product.owned) else localization.text("vigil.price") % int(product.cost)
        button.text = "%s — %s\n%s" % [product.name, state, product.description]
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.custom_minimum_size.y = 68
        button.set_meta("base_font_size", 14)
        BookCardStyle.apply_button(button, "mata_fio_verde", DomainThemeService, false)
        button.disabled = bool(product.owned) or not bool(product.requirement_met) or not bool(product.affordable)
        button.pressed.connect(_purchase.bind(str(product.id)))
        products.add_child(button)

func _purchase(product_id: String) -> void:
    if economy.purchase(product_id):
        feedback.text = localization.text("vigil.purchase_success")
        var product: Dictionary = economy.product_state(product_id)
        if str(product.get("kind", "")) == "cosmetic":
            economy.select_ornament(str(product.get("value", "plain")))
        _refresh(false)
    else:
        feedback.text = localization.text("vigil.purchase_unavailable")

func _ornament_name(ornament_id: String) -> String:
    match ornament_id:
        "ink": return localization.text("vigil.ornament.ink")
        "echo": return localization.text("vigil.ornament.echo")
        _: return localization.text("vigil.ornament.plain")
