extends Control
class_name SupporterSeal

const SIZE := 42.0

func _init() -> void:
    custom_minimum_size = Vector2(SIZE, SIZE)
    mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
        queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.38
    var ink := get_theme_color("font_color", "Label")
    if ink.a <= 0.01:
        ink = Color(0.18, 0.15, 0.12, 1.0)
    var faded := ink
    faded.a *= 0.62

    draw_arc(center, radius, 0.0, TAU, 32, ink, 2.0, true)
    draw_arc(center, radius * 0.72, 0.0, TAU, 24, faded, 1.0, true)

    var points := PackedVector2Array([
        center + Vector2(0.0, -radius * 0.72),
        center + Vector2(radius * 0.52, 0.0),
        center + Vector2(0.0, radius * 0.72),
        center + Vector2(-radius * 0.52, 0.0),
        center + Vector2(0.0, -radius * 0.72),
    ])
    draw_polyline(points, ink, 1.8, true)

    draw_line(
        center + Vector2(-radius * 0.46, -radius * 0.18),
        center + Vector2(radius * 0.46, radius * 0.18),
        faded,
        1.5,
        true
    )
    draw_line(
        center + Vector2(-radius * 0.46, radius * 0.18),
        center + Vector2(radius * 0.46, -radius * 0.18),
        faded,
        1.5,
        true
    )
    draw_circle(center, maxf(1.8, radius * 0.10), ink)
