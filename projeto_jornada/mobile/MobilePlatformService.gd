extends Node

signal safe_area_changed(margins: Dictionary)
signal application_paused
signal application_resumed
signal back_requested

const DESIGN_SIZE := Vector2i(540, 960)
const DESIGN_WIDTH := 540
const DESIGN_HEIGHT := 960
const BASE_MARGIN := 18
const MIN_TOUCH_TARGET := 48

var _last_margins: Dictionary = {"left":18,"top":18,"right":18,"bottom":18}
var pause_count := 0
var resume_count := 0
var last_pause_unix := 0

func _ready() -> void:
    var root := get_tree().root
    if not root.size_changed.is_connected(_on_window_size_changed):
        root.size_changed.connect(_on_window_size_changed)
    call_deferred("refresh_safe_area")

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED:
            pause_count += 1
            last_pause_unix = int(Time.get_unix_time_from_system())
            _autosave_active_run()
            application_paused.emit()
        NOTIFICATION_APPLICATION_RESUMED:
            resume_count += 1
            refresh_safe_area()
            application_resumed.emit()
        NOTIFICATION_WM_GO_BACK_REQUEST:
            _autosave_active_run()
            back_requested.emit()
        NOTIFICATION_WM_CLOSE_REQUEST:
            _autosave_active_run()
        _:
            pass

func is_mobile() -> bool:
    return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func platform_name() -> String:
    if OS.has_feature("android"):
        return "android"
    if OS.has_feature("ios"):
        return "ios"
    return OS.get_name().to_lower()

func refresh_safe_area() -> Dictionary:
    var window_size := DisplayServer.window_get_size()
    var safe_rect := DisplayServer.get_display_safe_area()
    var viewport_size := Vector2i(get_tree().root.get_visible_rect().size)
    var margins := calculate_safe_margins(window_size, safe_rect, viewport_size, BASE_MARGIN)
    if margins != _last_margins:
        _last_margins = margins
        safe_area_changed.emit(margins.duplicate(true))
    return margins

func safe_margins() -> Dictionary:
    return _last_margins.duplicate(true)

func layout_class(viewport_size: Vector2) -> String:
    if viewport_size.y <= 0.0:
        return "standard"
    var ratio := viewport_size.x / viewport_size.y
    if ratio < 0.50:
        return "tall"
    if ratio > 0.72:
        return "wide"
    return "standard"

func recommended_text_width(viewport_size: Vector2) -> float:
    var klass := layout_class(viewport_size)
    if klass == "wide":
        return minf(680.0, viewport_size.x * 0.76)
    return maxf(320.0, viewport_size.x - float(_last_margins.left + _last_margins.right))

func apply_touch_targets(root: Node) -> void:
    if root == null:
        return
    _apply_touch_recursive(root)

func _apply_touch_recursive(node: Node) -> void:
    if node is BaseButton:
        var control := node as Control
        control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, float(MIN_TOUCH_TARGET))
        control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, float(MIN_TOUCH_TARGET))
    for child in node.get_children():
        _apply_touch_recursive(child)

func calculate_safe_margins(window_size: Vector2i, safe_rect: Rect2i, viewport_size: Vector2i, base_margin: int = BASE_MARGIN) -> Dictionary:
    if window_size.x <= 0 or window_size.y <= 0 or viewport_size.x <= 0 or viewport_size.y <= 0:
        return {"left":base_margin,"top":base_margin,"right":base_margin,"bottom":base_margin}
    if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
        return {"left":base_margin,"top":base_margin,"right":base_margin,"bottom":base_margin}
    var physical_left := maxi(0, safe_rect.position.x)
    var physical_top := maxi(0, safe_rect.position.y)
    var physical_right := maxi(0, window_size.x - (safe_rect.position.x + safe_rect.size.x))
    var physical_bottom := maxi(0, window_size.y - (safe_rect.position.y + safe_rect.size.y))
    var scale_x := float(viewport_size.x) / float(window_size.x)
    var scale_y := float(viewport_size.y) / float(window_size.y)
    return {
        "left": base_margin + ceili(float(physical_left) * scale_x),
        "top": base_margin + ceili(float(physical_top) * scale_y),
        "right": base_margin + ceili(float(physical_right) * scale_x),
        "bottom": base_margin + ceili(float(physical_bottom) * scale_y),
    }

func _autosave_active_run() -> void:
    if not GameState.run.is_empty() and bool(GameState.run.get("active", false)):
        SaveService.save_game()

func _on_window_size_changed() -> void:
    refresh_safe_area()
