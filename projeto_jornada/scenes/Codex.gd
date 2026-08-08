extends Control

const CATEGORY_NAMES := {
    "world":"Domínios",
    "location":"Localidades",
    "character":"Andarilhos",
    "monster":"Monstros",
    "boss":"Chefes",
    "item":"Itens",
    "npc":"Pessoas",
    "mark":"Marcas",
    "debt":"Dívidas Narrativas",
    "event":"Situações",
    "ending":"Finais",
    "ability":"Habilidades",
    "other":"Outros",
}

var codex := CodexProgressEngine.new()
var body: RichTextLabel

func _ready() -> void:
    codex.ensure_state()
    _build_ui()
    _render()
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

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)

    var heading := Label.new()
    heading.text = "Arquivo de Ecos"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.set_meta("base_font_size", 32)
    BookCardStyle.apply_heading(heading, "mata_fio_verde", DomainThemeService, 1)
    column.add_child(heading)

    var subtitle := Label.new()
    subtitle.text = "O Códice registra o que foi encontrado; não concede poder por completar listas."
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.set_meta("base_font_size", 15)
    column.add_child(subtitle)

    body = RichTextLabel.new()
    body.bbcode_enabled = true
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.scroll_active = true
    body.set_meta("base_font_size", 17)
    BookCardStyle.apply_body(body, "mata_fio_verde", DomainThemeService)
    column.add_child(body)

    var back := Button.new()
    back.text = "Voltar ao Nó"
    back.custom_minimum_size.y = 54
    back.set_meta("base_font_size", 16)
    BookCardStyle.apply_button(back, "mata_fio_verde", DomainThemeService, true)
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Hub.tscn"))
    column.add_child(back)

func _render() -> void:
    var collection: Dictionary = codex.collection_summary()
    var discovered: Dictionary = collection.get("discovered", {}) as Dictionary
    var total: Dictionary = collection.get("total", {}) as Dictionary
    var lines: Array[String] = []

    lines.append("[font_size=%d][b]Coleção[/b][/font_size]" % AccessibilityService.font_size(23))
    lines.append("Registros distintos: [b]%d[/b]" % int(collection.get("overall", 0)))
    var category_order := ["world","location","character","monster","boss","item","npc","mark","debt","event","ending","ability","other"]
    for category in category_order:
        var found := int(discovered.get(category, 0))
        var maximum := int(total.get(category, 0))
        if found == 0 and maximum == 0:
            continue
        var label := str(CATEGORY_NAMES.get(category, category))
        lines.append("• %s: [b]%d[/b]%s" % [label, found, " / %d" % maximum if maximum > 0 else ""])

    lines.append("")
    lines.append("[font_size=%d][b]Conquistas[/b][/font_size]" % AccessibilityService.font_size(23))
    lines.append("Desbloqueadas: [b]%d / %d[/b]" % [codex.unlocked_achievement_count(), CodexProgressEngine.ACHIEVEMENTS.size()])
    for achievement_variant in codex.achievements():
        var achievement: Dictionary = achievement_variant as Dictionary
        var unlocked := bool(achievement.get("unlocked", false))
        var marker := "✓" if unlocked else "·"
        var progress := mini(int(achievement.get("progress", 0)), int(achievement.get("target", 1)))
        lines.append("%s [b]%s[/b] — %s [%d/%d]" % [marker, achievement.get("name", ""), achievement.get("description", ""), progress, int(achievement.get("target", 1))])

    lines.append("")
    lines.append("[font_size=%d][b]Descobertas recentes[/b][/font_size]" % AccessibilityService.font_size(23))
    var recent: Array = codex.history(30)
    if recent.is_empty():
        lines.append("[i]As primeiras páginas ainda aguardam traços novos.[/i]")
    else:
        recent.reverse()
        for entry_variant in recent:
            var entry: Dictionary = entry_variant as Dictionary
            var content_id := str(entry.get("id", ""))
            var record: Dictionary = ContentRegistry.get_record(content_id)
            var name := str(record.get("name", content_id))
            var category := str(CATEGORY_NAMES.get(str(entry.get("category", "other")), entry.get("category", "other")))
            var source := _source_name(str(entry.get("source", "journey")))
            lines.append("• [b]%s[/b] — %s • %s%s" % [name, category, source, _date_suffix(int(entry.get("at", 0)))])

    body.text = "\n".join(lines)

func _source_name(source: String) -> String:
    match source:
        "route_unlock": return "rota aberta"
        "character_unlock": return "Andarilho liberado"
        "legacy": return "registro anterior"
        _: return "jornada"

func _date_suffix(unix_time: int) -> String:
    if unix_time <= 0:
        return ""
    var date: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
    return " • %02d/%02d/%04d" % [int(date.get("day", 0)), int(date.get("month", 0)), int(date.get("year", 0))]
