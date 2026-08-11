extends Control

var localization := LocalizationService.new()

const CATEGORY_NAMES := {
    "world":"codex.category.world",
    "location":"codex.category.location",
    "character":"codex.category.character",
    "monster":"codex.category.monster",
    "boss":"codex.category.boss",
    "item":"codex.category.item",
    "npc":"codex.category.npc",
    "mark":"codex.category.mark",
    "debt":"codex.category.debt",
    "event":"codex.category.event",
    "ending":"codex.category.ending",
    "ability":"codex.category.ability",
    "other":"codex.category.other",
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
    heading.text = localization.text("codex.title")
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.set_meta("base_font_size", 32)
    BookCardStyle.apply_heading(heading, "mata_fio_verde", DomainThemeService, 1)
    column.add_child(heading)

    var subtitle := Label.new()
    subtitle.text = localization.text("codex.subtitle")
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
    back.text = localization.text("common.back_to_hub")
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

    lines.append(localization.text("codex.collection") % AccessibilityService.font_size(23))
    lines.append(localization.text("codex.distinct_records") % int(collection.get("overall", 0)))
    var category_order := ["world","location","character","monster","boss","item","npc","mark","debt","event","ending","ability","other"]
    for category in category_order:
        var found := int(discovered.get(category, 0))
        var maximum := int(total.get(category, 0))
        if found == 0 and maximum == 0:
            continue
        var label := _category_name(str(category))
        lines.append("• %s: [b]%d[/b]%s" % [label, found, " / %d" % maximum if maximum > 0 else ""])

    lines.append("")
    lines.append(localization.text("codex.achievements") % AccessibilityService.font_size(23))
    lines.append(localization.text("codex.unlocked") % [codex.unlocked_achievement_count(), CodexProgressEngine.ACHIEVEMENTS.size()])
    for achievement_variant in codex.achievements():
        var achievement: Dictionary = achievement_variant as Dictionary
        var unlocked := bool(achievement.get("unlocked", false))
        var marker := "✓" if unlocked else "·"
        var progress := mini(int(achievement.get("progress", 0)), int(achievement.get("target", 1)))
        lines.append("%s [b]%s[/b] — %s [%d/%d]" % [marker, achievement.get("name", ""), achievement.get("description", ""), progress, int(achievement.get("target", 1))])

    lines.append("")
    lines.append(localization.text("codex.recent") % AccessibilityService.font_size(23))
    var recent: Array = codex.history(30)
    if recent.is_empty():
        lines.append(localization.text("codex.empty"))
    else:
        recent.reverse()
        for entry_variant in recent:
            var entry: Dictionary = entry_variant as Dictionary
            var content_id := str(entry.get("id", ""))
            var record: Dictionary = ContentRegistry.get_record(content_id)
            var record_view := localization.localize_record(record)
            var name := str(record_view.get("name", content_id))
            var category := _category_name(str(entry.get("category", "other")))
            var source := _source_name(str(entry.get("source", "journey")))
            lines.append("• [b]%s[/b] — %s • %s%s" % [name, category, source, _date_suffix(int(entry.get("at", 0)))])

    body.text = "\n".join(lines)

func _source_name(source: String) -> String:
    match source:
        "route_unlock": return localization.text("codex.source.route")
        "character_unlock": return localization.text("codex.source.character")
        "legacy": return localization.text("codex.source.legacy")
        _: return localization.text("codex.source.journey")

func _category_name(category: String) -> String:
    var key := str(CATEGORY_NAMES.get(category, "codex.category.other"))
    return localization.text(key)

func _date_suffix(unix_time: int) -> String:
    if unix_time <= 0:
        return ""
    var date: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
    return " • %02d/%02d/%04d" % [int(date.get("day", 0)), int(date.get("month", 0)), int(date.get("year", 0))]
