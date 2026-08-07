extends RefCounted
class_name BookVFX

# Final motion language: restrained, readable, paper/ink oriented.
# All effects have a reduced-motion path and avoid rapid full-screen flashes.

static func page_settle(node: CanvasItem, reduce_motion: bool = false) -> Tween:
    if node == null:
        return null
    node.modulate.a = 1.0 if reduce_motion else 0.0
    node.position.y = 0.0 if reduce_motion else 8.0
    var tween := node.create_tween()
    if reduce_motion:
        tween.tween_interval(0.01)
        return tween
    tween.set_parallel(true)
    tween.tween_property(node, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(node, "position:y", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    return tween

static func choice_press(button: Control, reduce_motion: bool = false) -> Tween:
    if button == null:
        return null
    var tween := button.create_tween()
    if reduce_motion:
        tween.tween_property(button, "modulate", Color(0.94,0.94,0.94,1), 0.04)
        tween.tween_property(button, "modulate", Color.WHITE, 0.05)
        return tween
    button.pivot_offset = button.size * 0.5
    tween.tween_property(button, "scale", Vector2(0.985,0.985), 0.055).set_trans(Tween.TRANS_QUAD)
    tween.tween_property(button, "scale", Vector2.ONE, 0.095).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    return tween

static func ink_stain(node: CanvasItem, stain_color: Color, reduce_motion: bool = false, flashes_disabled: bool = false) -> Tween:
    if node == null:
        return null
    var base := node.modulate
    var target := base.lerp(stain_color, 0.18 if flashes_disabled else 0.28)
    var tween := node.create_tween()
    if reduce_motion or flashes_disabled:
        tween.tween_property(node, "modulate", target, 0.12)
        tween.tween_property(node, "modulate", base, 0.28)
    else:
        tween.tween_property(node, "modulate", target, 0.07)
        tween.tween_property(node, "modulate", base, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    return tween

static func stitch_mark(icon: CanvasItem, reduce_motion: bool = false) -> Tween:
    if icon == null:
        return null
    icon.modulate.a = 1.0 if reduce_motion else 0.0
    icon.scale = Vector2.ONE if reduce_motion else Vector2(0.72,0.72)
    var tween := icon.create_tween()
    if reduce_motion:
        tween.tween_interval(0.01)
        return tween
    tween.set_parallel(true)
    tween.tween_property(icon, "modulate:a", 1.0, 0.20)
    tween.tween_property(icon, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    return tween

static func intent_reveal(node: CanvasItem, reduce_motion: bool = false) -> Tween:
    if node == null:
        return null
    var tween := node.create_tween()
    if reduce_motion:
        node.modulate.a = 1.0
        tween.tween_interval(0.01)
        return tween
    node.modulate.a = 0.25
    tween.tween_property(node, "modulate:a", 1.0, 0.17).set_trans(Tween.TRANS_SINE)
    tween.tween_property(node, "modulate:a", 0.90, 0.08)
    tween.tween_property(node, "modulate:a", 1.0, 0.10)
    return tween

static func thread_rupture(node: Control, reduce_motion: bool = false, flashes_disabled: bool = false) -> Tween:
    if node == null:
        return null
    var tween := node.create_tween()
    if reduce_motion:
        tween.tween_property(node, "modulate", Color(0.88,0.84,0.78,1), 0.10)
        tween.tween_property(node, "modulate", Color.WHITE, 0.20)
        return tween
    node.pivot_offset = node.size * 0.5
    tween.set_parallel(true)
    tween.tween_property(node, "rotation", deg_to_rad(-0.35), 0.07)
    if not flashes_disabled:
        tween.tween_property(node, "modulate", Color(0.88,0.76,0.70,1), 0.07)
    tween.chain().set_parallel(true)
    tween.tween_property(node, "rotation", deg_to_rad(0.28), 0.08)
    tween.tween_property(node, "modulate", Color.WHITE, 0.18)
    tween.chain().tween_property(node, "rotation", 0.0, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    return tween

static func location_transition(node: CanvasItem, direction: float = 1.0, reduce_motion: bool = false) -> Tween:
    if node == null:
        return null
    var tween := node.create_tween()
    if reduce_motion:
        tween.tween_property(node, "modulate:a", 0.72, 0.08)
        tween.tween_property(node, "modulate:a", 1.0, 0.12)
        return tween
    tween.set_parallel(true)
    tween.tween_property(node, "modulate:a", 0.0, 0.14)
    tween.tween_property(node, "position:x", node.position.x + 9.0 * direction, 0.14)
    tween.chain().set_parallel(true)
    tween.tween_property(node, "modulate:a", 1.0, 0.20)
    tween.tween_property(node, "position:x", node.position.x, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    return tween
