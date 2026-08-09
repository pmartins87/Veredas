extends Node

func create(debt_id: String) -> bool:
    if ContentRegistry.get_record(debt_id).is_empty():
        return false
    var debts: Array = GameState.run.get("debts", [])
    for debt in debts:
        if str(debt.get("id", "")) == debt_id:
            return true
    var spec := ContentRegistry.get_record(debt_id)
    debts.append({
        "id": debt_id,
        "age": 0,
        "pressure": 1.0,
        "soft_deadline": int(spec.get("soft_deadline", 4)),
        "hard_deadline": int(spec.get("hard_deadline", 10)),
    })
    GameState.run.debts = debts
    return true

func resolve(debt_id: String) -> bool:
    var debts: Array = GameState.run.get("debts", [])
    var before := debts.size()
    debts = debts.filter(func(debt): return str(debt.get("id", "")) != debt_id)
    GameState.run.debts = debts
    return debts.size() < before

func resolve_oldest() -> bool:
    var debts: Array = GameState.run.get("debts", [])
    if debts.is_empty():
        return false
    debts.sort_custom(func(a, b): return int(a.get("age", 0)) > int(b.get("age", 0)))
    debts.pop_front()
    GameState.run.debts = debts
    return true

func is_active(debt_id: String) -> bool:
    return not active_debt(debt_id).is_empty()

func has_active() -> bool:
    return not (GameState.run.get("debts", []) as Array).is_empty()

func active_count() -> int:
    return (GameState.run.get("debts", []) as Array).size()

func active_debt(debt_id: String) -> Dictionary:
    for debt_variant in GameState.run.get("debts", []) as Array:
        var debt: Dictionary = debt_variant as Dictionary
        if str(debt.get("id", "")) == debt_id:
            return debt
    return {}

func age_all(turns: int = 1) -> void:
    var debts: Array = GameState.run.get("debts", [])
    for debt in debts:
        debt.age = int(debt.get("age", 0)) + turns
        var spec := ContentRegistry.get_record(str(debt.get("id", "")))
        debt.pressure = float(debt.get("pressure", 1.0)) + float(spec.get("pressure_growth", 0.2)) * float(turns)
    GameState.run.debts = debts

func event_multiplier(event: Dictionary) -> float:
    var pool := str(event.get("pool", ""))
    if pool == "callback":
        # A callback is pressured only by the obligation it actually closes.
        # Unrelated debts must never make an arbitrary callback dominate the pool.
        var debt_id := str(event.get("debt_id", ""))
        var debt := active_debt(debt_id)
        if debt.is_empty():
            return 1.0
        var multiplier := 1.0 + float(debt.get("pressure", 1.0))
        if int(debt.get("age", 0)) >= int(debt.get("hard_deadline", 10)):
            multiplier += 50.0
        return multiplier
    if pool == "transit_callback":
        # Transit pressure reflects the most urgent unresolved obligation rather
        # than summing every debt and creating runaway multiplicative weight.
        var strongest := 0.0
        var overdue := false
        for debt_variant in GameState.run.get("debts", []) as Array:
            var debt: Dictionary = debt_variant as Dictionary
            strongest = maxf(strongest, float(debt.get("pressure", 1.0)))
            overdue = overdue or int(debt.get("age", 0)) >= int(debt.get("hard_deadline", 10))
        if strongest <= 0.0:
            return 1.0
        return 1.0 + strongest + (25.0 if overdue else 0.0)
    return 1.0

func overdue_count() -> int:
    var count := 0
    for debt in GameState.run.get("debts", []):
        if int(debt.get("age", 0)) >= int(debt.get("hard_deadline", 10)):
            count += 1
    return count
