extends Node

func abilities_for(character_id: String) -> Array:
    var character := ContentRegistry.get_record(character_id)
    var result: Array = []
    for ability_id in character.get("abilities", []):
        var ability := ContentRegistry.get_record(str(ability_id))
        if not ability.is_empty():
            result.append(ability)
    return result

func initial_resource_pool(character_id: String) -> Dictionary:
    var character := ContentRegistry.get_record(character_id)
    var resource := str(character.get("resource", "Focus"))
    return {resource:0}

func gain_resource(character_id: String, resource_pool: Dictionary, amount: int = 1) -> Dictionary:
    var result := resource_pool.duplicate(true)
    var character := ContentRegistry.get_record(character_id)
    var key := str(character.get("resource", "Focus"))
    var maximum := int(character.get("resource_max", 5))
    result[key] = clampi(int(result.get(key, 0)) + amount, 0, maximum)
    return result

func can_pay(ability: Dictionary, resource_pool: Dictionary) -> bool:
    var key := str(ability.get("resource", ""))
    return int(resource_pool.get(key, 0)) >= int(ability.get("cost", 0))

func execute(ability: Dictionary, actor: Dictionary, target: Dictionary, resource_pool: Dictionary) -> Dictionary:
    var resources := resource_pool.duplicate(true)
    var actor_result := actor.duplicate(true)
    var target_result := target.duplicate(true)
    var resource := str(ability.get("resource", ""))
    var cost := int(ability.get("cost", 0))
    if int(resources.get(resource, 0)) < cost:
        return {"ok":false,"reason":"resource"}
    resources[resource] = int(resources.get(resource, 0)) - cost
    match str(ability.get("mechanic", "")):
        "damage":
            target_result.hp = maxi(0, int(target_result.get("hp",0)) - 4)
        "posture":
            target_result.posture = maxi(0, int(target_result.get("posture",0)) - 5)
        "guard":
            actor_result.guard = int(actor_result.get("guard",0)) + 5
        "heal":
            actor_result.hp = mini(int(actor_result.get("max_hp",16)), int(actor_result.get("hp",0)) + 5)
        "move":
            actor_result.distance = clampi(int(actor_result.get("distance",1)) + 1, 0, 2)
        "status":
            target_result = StatusEngine.apply_status(target_result, "marked", 1, 3)
        "counter":
            actor_result.counter = true
        "resource":
            resources[resource] = int(resources.get(resource,0)) + 3
        "echo":
            actor_result.echo_ready = true
        "mark":
            actor_result.mark_power = int(actor_result.get("mark_power",0)) + 1
        "debt":
            actor_result.debt_pressure_bonus = float(actor_result.get("debt_pressure_bonus",0.0)) + 1.0
        "range":
            actor_result.distance = int(target_result.get("distance",1))
        _:
            pass
    return {"ok":true,"actor":actor_result,"target":target_result,"resources":resources}
