extends Node

func abilities_for(character_id: String) -> Array:
    var character := ContentRegistry.get_record(character_id)
    var out: Array = []
    for ability_id in character.get("abilities", []):
        var ability := ContentRegistry.get_record(str(ability_id))
        if not ability.is_empty(): out.append(ability)
    return out

func can_pay(ability: Dictionary, resource_pool: Dictionary) -> bool:
    var key := str(ability.get("resource", ""))
    return int(resource_pool.get(key, 0)) >= int(ability.get("cost", 0))

func execute(ability: Dictionary, actor: Dictionary, target: Dictionary, resource_pool: Dictionary) -> Dictionary:
    var resource := str(ability.get("resource", ""))
    var cost := int(ability.get("cost", 0))
    if int(resource_pool.get(resource, 0)) < cost:
        return {"ok":false,"reason":"resource"}
    resource_pool[resource] = int(resource_pool.get(resource, 0)) - cost
    match str(ability.get("mechanic", "")):
        "damage": target.hp = maxi(0, int(target.get("hp",0)) - 3)
        "posture": target.posture = maxi(0, int(target.get("posture",0)) - 4)
        "guard": actor.guard = int(actor.get("guard",0)) + 4
        "heal": actor.hp = mini(int(actor.get("max_hp",16)), int(actor.get("hp",0)) + 4)
        "move": actor.distance = clampi(int(actor.get("distance",1)) + 1, 0, 2)
        "status":
            var states: Array = target.get("states", []); states.append("marked"); target.states = states
        "counter": actor.counter = true
        "resource": resource_pool[resource] = int(resource_pool.get(resource,0)) + 3
        "echo": actor.echo_ready = true
        "mark": actor.mark_power = int(actor.get("mark_power",0)) + 1
        "debt": actor.debt_pressure_bonus = float(actor.get("debt_pressure_bonus",0.0)) + 1.0
        "range": actor.distance = int(target.get("distance",1))
        _: pass
    return {"ok":true,"actor":actor,"target":target,"resources":resource_pool}
