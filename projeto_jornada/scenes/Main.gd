extends Control

var current_event: Dictionary = {}
var story: RichTextLabel
var choices: VBoxContainer
var header: Label
var status: Label

func _ready() -> void:
    _build_ui()
    if GameState.run.is_empty():
        GameState.new_run("character.mata_fio_verde.01", int(Time.get_unix_time_from_system()) & 0x7fffffff)
    _refresh()

func _build_ui() -> void:
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_top", 26)
    margin.add_theme_constant_override("margin_bottom", 26)
    add_child(margin)
    var page := VBoxContainer.new(); page.add_theme_constant_override("separation", 14); margin.add_child(page)
    header = Label.new(); header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; header.add_theme_font_size_override("font_size", 30); page.add_child(header)
    status = Label.new(); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; page.add_child(status)
    page.add_child(HSeparator.new())
    story = RichTextLabel.new(); story.bbcode_enabled = true; story.size_flags_vertical = Control.SIZE_EXPAND_FILL; story.add_theme_font_size_override("normal_font_size", 20); story.add_theme_constant_override("line_separation", 6); page.add_child(story)
    choices = VBoxContainer.new(); choices.add_theme_constant_override("separation", 10); page.add_child(choices)
    var nav := HBoxContainer.new(); nav.alignment = BoxContainer.ALIGNMENT_CENTER
    var save := Button.new(); save.text = "Salvar"; save.pressed.connect(func(): SaveService.save_game()); nav.add_child(save)
    var next := Button.new(); next.text = "Nova situação"; next.pressed.connect(_refresh); nav.add_child(next); page.add_child(nav)

func _refresh() -> void:
    var world_id := str(GameState.run.get("world_id", "world.mata_fio_verde"))
    var loc := str(GameState.run.get("location_id", ""))
    current_event = EventDirector.choose_event(world_id, loc)
    var world := ContentRegistry.get_record(world_id); var location := ContentRegistry.get_record(loc)
    header.text = str(world.get("name", "Veredas da Trama"))
    status.text = "%s  •  Vida %s/%s  •  Vigor %s/%s" % [location.get("name", ""), GameState.run.get("health", 0), GameState.run.get("max_health", 0), GameState.run.get("vigor", 0), GameState.run.get("max_vigor", 0)]
    story.text = "[font_size=26][b]%s[/b][/font_size]\n\n%s" % [current_event.get("title", "A Vereda aguarda"), current_event.get("text", "Nenhum evento elegível.")]
    for child in choices.get_children(): child.queue_free()
    var options: Array = current_event.get("choices", [])
    for i in range(options.size()):
        var b := Button.new(); b.text = str(options[i].get("text", "Escolher")); b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.custom_minimum_size = Vector2(0, 64)
        var idx := i; b.pressed.connect(func(): EventDirector.apply_choice(current_event, idx); _refresh()); choices.add_child(b)
