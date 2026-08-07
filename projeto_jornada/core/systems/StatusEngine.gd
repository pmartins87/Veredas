extends Node

const MAX_STACKS := 9

func apply_status(target: Dictionary, status_id: String, stacks: int = 1, duration: int = 2) -> Dictionary:
    var result := target.duplicate(true)
    var states: Array = result.get("states", [])
    var merged := false
    for state in states:
        if str(state.get("id", "")) == status_id:
            state.stacks = clampi(int(state.get("stacks", 1)) + stacks, 1, MAX_STACKS)
            state.duration = maxi(int(state.get("duration", 1)), duration)
            merged = true
            break
    if not merged:
        states.append({"id":status_id,"stacks":clampi(stacks,1,MAX_STACKS),"duration":maxi(1,duration)})
    result.states = states
    return _resolve_reactions(result)

func remove_status(target: Dictionary, status_id: String) -> Dictionary:
    var result := target.duplicate(true)
    result.states = result.get("states", []).filter(func(state): return str(state.get("id", "")) != status_id)
    return result

func has_status(target: Dictionary, status_id: String) -> bool:
    for state in target.get("states", []):
        if str(state.get("id", "")) == status_id:
            return true
    return false

func tick(target: Dictionary) -> Dictionary:
    var result := target.duplicate(true)
    var states: Array = result.get("states", [])
    var hp := int(result.get("hp", 0))
    for state in states:
        var status_id := str(state.get("id", ""))
        var stacks := int(state.get("stacks", 1))
        if status_id in ["bleeding", "burning", "poison"]:
            hp = maxi(0, hp - stacks)
        state.duration = int(state.get("duration", 1)) - 1
    result.hp = hp
    result.states = states.filter(func(state): return int(state.get("duration", 0)) > 0)
    return result

func damage_multiplier(target: Dictionary) -> float:
    var multiplier := 1.0
    if has_status(target, "exposed"):
        multiplier += 0.25
    if has_status(target, "fear"):
        multiplier += 0.08
    return multiplier

func movement_locked(target: Dictionary) -> bool:
    return has_status(target, "rooted") or has_status(target, "frozen")

func _resolve_reactions(target: Dictionary) -> Dictionary:
    var result := target
    if has_status(result, "wet") and has_status(result, "shock"):
        result = remove_status(result, "wet")
        result.hp = maxi(0, int(result.get("hp", 0)) - 2)
        result.posture = maxi(0, int(result.get("posture", 0)) - 3)
    if has_status(result, "burning") and has_status(result, "frozen"):
        result = remove_status(result, "burning")
        result = remove_status(result, "frozen")
        result.posture = maxi(0, int(result.get("posture", 0)) - 2)
    return result
