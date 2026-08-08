extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _budget_gate()
    _monitor_gate()
    if failures.is_empty():
        print("PERFORMANCE_BUDGET_CERTIFICATION PASS: 8.5")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("PERFORMANCE_BUDGET_CERTIFICATION: %s" % failure)
        print("PERFORMANCE_BUDGET_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _budget_gate() -> void:
    var targets := PerformanceBudgetService.targets()
    expect(targets.size() >= 10, "8.5 performance targets missing")
    expect(float(targets.get("fps_target", 0.0)) == 60.0, "8.5 target FPS mismatch")
    expect(float(targets.get("static_memory_mb_hard", 0.0)) > float(targets.get("static_memory_mb_soft", 9999.0)), "8.5 hard memory budget must exceed soft budget")
    expect(float(targets.get("frame_ms_target", 0.0)) <= 16.7, "8.5 frame time target too loose")

    var healthy := {
        "fps":60.0,"process_ms":4.0,"physics_ms":1.0,
        "static_memory_mb":120.0,"video_memory_mb":60.0,
        "draw_calls":80,"nodes":900
    }
    var healthy_report := PerformanceBudgetService.evaluate_sample(healthy, true)
    expect(bool(healthy_report.get("ok", false)), "8.5 healthy synthetic sample rejected")

    var unhealthy := healthy.duplicate(true)
    unhealthy.fps = 38.0
    unhealthy.process_ms = 18.0
    unhealthy.static_memory_mb = 600.0
    unhealthy.draw_calls = 400
    var bad_report := PerformanceBudgetService.evaluate_sample(unhealthy, true)
    expect(not bool(bad_report.get("ok", true)), "8.5 unhealthy synthetic sample accepted")
    var violations: Array = bad_report.get("violations", [])
    for expected in ["fps_floor","process_ms","static_memory_hard","draw_calls"]:
        expect(expected in violations, "8.5 missing synthetic violation %s" % expected)

func _monitor_gate() -> void:
    PerformanceBudgetService.reset_history()
    var sample := PerformanceBudgetService.sample()
    for key in ["fps","process_ms","physics_ms","static_memory_mb","video_memory_mb","draw_calls","nodes"]:
        expect(sample.has(key), "8.5 runtime sample missing %s" % key)
    expect(PerformanceBudgetService.history.size() == 1, "8.5 runtime sample not stored")
    var report := PerformanceBudgetService.session_report()
    expect(int(report.get("samples",0)) == 1, "8.5 session report sample count mismatch")
