extends Node

# Bridges gameplay presentation signals to the restrained book/ink VFX language.
# It deliberately targets the active scene as a whole so gameplay systems remain
# unaware of UI layout details and future screens inherit the same vocabulary.

func _ready() -> void:
    PresentationBus.damage_applied.connect(_on_damage_applied)
    PresentationBus.intent_revealed.connect(_on_intent_revealed)
    PresentationBus.boss_phase_changed.connect(_on_boss_phase_changed)
    PresentationBus.location_changed.connect(_on_location_changed)
    PresentationBus.mark_added.connect(_on_mark_added)

func _scene_canvas() -> CanvasItem:
    var scene := get_tree().current_scene
    return scene as CanvasItem if scene is CanvasItem else null

func _scene_control() -> Control:
    var scene := get_tree().current_scene
    return scene as Control if scene is Control else null

func _on_damage_applied(target: String, amount: int) -> void:
    if amount <= 0:
        return
    var canvas := _scene_canvas()
    if canvas == null:
        return
    var domain_id := _current_domain_id()
    var color_token := "danger" if target == "player" else "accent"
    var stain_color: Color = DomainThemeService.color(color_token, domain_id)
    BookVFX.ink_stain(canvas, stain_color, AccessibilityService.reduce_motion(), AccessibilityService.flashes_disabled())

func _on_intent_revealed(_intent: Dictionary) -> void:
    var canvas := _scene_canvas()
    if canvas != null:
        BookVFX.intent_reveal(canvas, AccessibilityService.reduce_motion())

func _on_boss_phase_changed(_phase_index: int) -> void:
    var control := _scene_control()
    if control != null:
        BookVFX.thread_rupture(control, AccessibilityService.reduce_motion(), AccessibilityService.flashes_disabled())

func _on_location_changed(_location_id: String) -> void:
    var canvas := _scene_canvas()
    if canvas != null:
        BookVFX.location_transition(canvas, 1.0, AccessibilityService.reduce_motion())

func _on_mark_added(mark_id: String) -> void:
    var root := _scene_control()
    if root == null:
        return
    var icon := TextureRect.new()
    var mark: Dictionary = ContentRegistry.get_record(mark_id)
    icon.texture = VectorAtlasRegistry.mark_texture(mark)
    icon.custom_minimum_size = Vector2(46, 46)
    icon.size = Vector2(46, 46)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.position = Vector2(maxf(18.0, root.size.x - 68.0), 72.0)
    icon.modulate = DomainThemeService.color("accent", _current_domain_id())
    root.add_child(icon)
    var tween := BookVFX.stitch_mark(icon, AccessibilityService.reduce_motion())
    if tween != null:
        await tween.finished
    await get_tree().create_timer(0.35 if AccessibilityService.reduce_motion() else 0.65).timeout
    if is_instance_valid(icon):
        icon.queue_free()

func _current_domain_id() -> String:
    if GameState.run.is_empty():
        return "mata_fio_verde"
    return str(GameState.run.get("world_id", "world.mata_fio_verde")).trim_prefix("world.")
