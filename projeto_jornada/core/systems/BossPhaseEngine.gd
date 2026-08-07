extends Node

func phase_index(boss: Dictionary, hp: int, max_hp: int) -> int:
    if max_hp <= 0:
        return 0
    var ratio := float(hp) / float(max_hp)
    var phases: Array = boss.get("phases", [])
    if phases.is_empty():
        return 0
    var current := 0
    for i in range(phases.size()):
        if ratio <= float(phases[i].get("threshold", 1.0)):
            current = i
    return current

func phase(boss: Dictionary, hp: int, max_hp: int) -> Dictionary:
    var phases: Array = boss.get("phases", [])
    if phases.is_empty():
        return {}
    return phases[phase_index(boss, hp, max_hp)]

func transition_if_needed(boss: Dictionary, previous_index: int, hp: int, max_hp: int) -> Dictionary:
    var current := phase_index(boss, hp, max_hp)
    if current <= previous_index:
        return {"changed":false,"index":previous_index,"phase":phase(boss,hp,max_hp)}
    PresentationBus.boss_phase(current)
    return {"changed":true,"index":current,"phase":phase(boss,hp,max_hp)}
