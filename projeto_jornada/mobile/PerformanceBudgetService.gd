extends Node

signal budget_warning(report: Dictionary)

const BUDGET_PATH := "res://mobile/performance_budgets.json"
var budgets: Dictionary = {}
var history: Array = []

func _ready() -> void:
    _load_budgets()

func _load_budgets() -> void:
    var file := FileAccess.open(BUDGET_PATH, FileAccess.READ)
    if file == null:
        push_error("PerformanceBudgetService: missing performance budgets")
        budgets = {}
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("PerformanceBudgetService: invalid performance budget JSON")
        budgets = {}
        return
    budgets = parsed

func targets() -> Dictionary:
    return (budgets.get("targets", {}) as Dictionary).duplicate(true)

func sample() -> Dictionary:
    var current := {
        "fps": float(Performance.get_monitor(Performance.TIME_FPS)),
        "process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
        "physics_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
        "static_memory_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
        "video_memory_mb": float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0,
        "draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
        "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
        "unix": int(Time.get_unix_time_from_system()),
    }
    history.append(current)
    var maximum := int((budgets.get("policy", {}) as Dictionary).get("sample_window", 600))
    if history.size() > maximum:
        history.pop_front()
    var report := evaluate_sample(current, false)
    if not bool(report.get("ok", true)):
        budget_warning.emit(report)
    return current

func evaluate_sample(current: Dictionary, include_fps: bool = true) -> Dictionary:
    var t := targets()
    var violations: Array[String] = []
    if include_fps and float(current.get("fps", 0.0)) < float(t.get("fps_floor_sustained", 50.0)):
        violations.append("fps_floor")
    if float(current.get("process_ms", 0.0)) > float(t.get("process_ms_p95", 10.0)):
        violations.append("process_ms")
    if float(current.get("physics_ms", 0.0)) > float(t.get("physics_ms_p95", 4.0)):
        violations.append("physics_ms")
    if float(current.get("static_memory_mb", 0.0)) > float(t.get("static_memory_mb_hard", 420.0)):
        violations.append("static_memory_hard")
    if float(current.get("draw_calls", 0.0)) > float(t.get("draw_calls_soft", 180.0)):
        violations.append("draw_calls")
    if float(current.get("nodes", 0.0)) > float(t.get("nodes_soft", 3000.0)):
        violations.append("nodes")
    return {"ok":violations.is_empty(),"violations":violations,"sample":current.duplicate(true)}

func percentile(metric: String, p: float) -> float:
    if history.is_empty():
        return 0.0
    var values: Array[float] = []
    for row in history:
        values.append(float((row as Dictionary).get(metric, 0.0)))
    values.sort()
    var index := clampi(roundi((values.size() - 1) * clampf(p, 0.0, 1.0)), 0, values.size() - 1)
    return values[index]

func session_report() -> Dictionary:
    return {
        "samples": history.size(),
        "fps_p05": percentile("fps", 0.05),
        "process_ms_p95": percentile("process_ms", 0.95),
        "physics_ms_p95": percentile("physics_ms", 0.95),
        "memory_mb_p95": percentile("static_memory_mb", 0.95),
        "draw_calls_p95": percentile("draw_calls", 0.95),
        "nodes_p95": percentile("nodes", 0.95),
    }

func reset_history() -> void:
    history.clear()
