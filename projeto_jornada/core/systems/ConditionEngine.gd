extends Node

func evaluate(condition: Dictionary, context: Dictionary = {}) -> bool:
    if condition.is_empty():
        return true
    var op := str(condition.get("op", ""))
    match op:
        "and":
            for child in condition.get("conditions", []):
                if not evaluate(child, context):
                    return false
            return true
        "or":
            for child in condition.get("conditions", []):
                if evaluate(child, context):
                    return true
            return false
        "not":
            return not evaluate(condition.get("condition", {}), context)
        "resource_gte":
            return _resource(str(condition.get("resource", ""))) >= int(condition.get("value", 0))
        "resource_lte":
            return _resource(str(condition.get("resource", ""))) <= int(condition.get("value", 0))
        "mark_has":
            return int(GameState.run.get("marks", {}).get(str(condition.get("mark_id", "")), 0)) > 0
        "mark_intensity_gte":
            return int(GameState.run.get("marks", {}).get(str(condition.get("mark_id", "")), 0)) >= int(condition.get("value", 1))
        "debt_active":
            return NarrativeDebtEngine.is_active(str(condition.get("debt_id", "")))
        "debt_any":
            return NarrativeDebtEngine.has_active()
        "debt_overdue":
            var debt := NarrativeDebtEngine.active_debt(str(condition.get("debt_id", "")))
            return not debt.is_empty() and int(debt.get("age", 0)) >= int(debt.get("hard_deadline", 10))
        "echo_mark_has":
            if _ephemeral_simulation():
                return false
            return EchoConsequenceEngine.has_echo(str(condition.get("mark_id", "")), 1)
        "echo_mark_intensity_gte":
            if _ephemeral_simulation():
                return false
            return EchoConsequenceEngine.has_echo(str(condition.get("mark_id", "")), int(condition.get("value", 1)))
        "ending_witnessed":
            if _ephemeral_simulation():
                return false
            return EchoConsequenceEngine.ending_witnessed(str(condition.get("ending_id", "")))
        "flag_is":
            return GameState.run.get("flags", {}).get(str(condition.get("key", ""))) == condition.get("value", true)
        "item_has":
            return InventoryEngine.has_item(str(condition.get("item_id", "")), int(condition.get("count", 1)))
        "character_is":
            return str(GameState.run.get("character_id", "")) == str(condition.get("character_id", ""))
        "world_is":
            return str(GameState.run.get("world_id", "")) == str(condition.get("world_id", ""))
        "location_is":
            return str(GameState.run.get("location_id", "")) == str(condition.get("location_id", ""))
        "turn_gte":
            return int(GameState.run.get("turn", 0)) >= int(condition.get("value", 0))
        _:
            return false

func _resource(key: String) -> int:
    if key == "health":
        return int(GameState.run.get("health", 0))
    if key == "vigor":
        return int(GameState.run.get("vigor", 0))
    return int(GameState.run.get("resources", {}).get(key, 0))

func _ephemeral_simulation() -> bool:
    return bool(GameState.profile.get("_simulation_ephemeral", false))
