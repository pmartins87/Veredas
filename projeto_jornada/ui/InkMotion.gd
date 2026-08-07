extends RefCounted
class_name InkMotion

# Small, book-like transitions. No camera shakes or flashy 3D effects.

static func reveal(canvas_item: CanvasItem, duration: float = 0.22, reduced_motion: bool = false) -> Tween:
    var tree := canvas_item.get_tree()
    var tween := tree.create_tween()
    if reduced_motion:
        canvas_item.modulate.a = 1.0
        return tween
    canvas_item.modulate.a = 0.0
    canvas_item.scale = Vector2(0.985, 0.985)
    tween.set_parallel(true)
    tween.tween_property(canvas_item, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(canvas_item, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    return tween

static func ink_pulse(canvas_item: CanvasItem, ink_color: Color, reduced_motion: bool = false) -> Tween:
    var tree := canvas_item.get_tree()
    var tween := tree.create_tween()
    if reduced_motion:
        return tween
    var original := canvas_item.modulate
    var tinted := original.lerp(ink_color, 0.32)
    tween.tween_property(canvas_item, "modulate", tinted, 0.08)
    tween.tween_property(canvas_item, "modulate", original, 0.18)
    return tween

static func consequence_mark(canvas_item: CanvasItem, reduced_motion: bool = false) -> Tween:
    var tree := canvas_item.get_tree()
    var tween := tree.create_tween()
    if reduced_motion:
        return tween
    var original := canvas_item.rotation
    tween.tween_property(canvas_item, "rotation", original - 0.012, 0.05)
    tween.tween_property(canvas_item, "rotation", original + 0.009, 0.05)
    tween.tween_property(canvas_item, "rotation", original, 0.09)
    return tween

static func page_turn(control: Control, direction: int = 1, reduced_motion: bool = false) -> Tween:
    var tween := control.get_tree().create_tween()
    if reduced_motion:
        control.modulate.a = 1.0
        return tween
    var start_x := float(direction) * 12.0
    control.position.x += start_x
    control.modulate.a = 0.35
    tween.set_parallel(true)
    tween.tween_property(control, "position:x", control.position.x - start_x, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(control, "modulate:a", 1.0, 0.16)
    return tween
