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
    var maximum := maxi(1, int(character.get("resource_max", 5)))
    var start := clampi(int(character.get("resource_start", 0)), 0, maximum)
    return {resource:start}

func gain_resource(character_id: String, resource_pool: Dictionary, amount: int = 1) -> Dictionary:
    var result := resource_pool.duplicate(true)
    var character := ContentRegistry.get_record(character_id)
    var key := str(character.get("resource", "Focus"))
    var maximum := maxi(1, int(character.get("resource_max", 5)))
    var gain_per_action := maxi(0, int(character.get("resource_gain_per_action", 1)))
    result[key] = clampi(int(result.get(key, 0)) + amount * gain_per_action, 0, maximum)
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

    var mechanic := str(ability.get("mechanic", ""))
    var power := maxi(1, int(ability.get("power", _default_power(mechanic))))
    var duration := maxi(1, int(ability.get("duration", 2)))
    match mechanic:
        "damage":
            target_result.hp = maxi(0, int(target_result.get("hp",0)) - power)
        "posture":
            target_result.posture = maxi(0, int(target_result.get("posture",0)) - power)
        "guard":
            actor_result.guard = int(actor_result.get("guard",0)) + power
        "heal":
            actor_result.hp = mini(int(actor_result.get("max_hp",16)), int(actor_result.get("hp",0)) + power)
        "move":
            # Signature mobility is a protected gap-close. It must advance the
            # fight rather than creating a retreat/advance loop in baseline play.
            actor_result.distance = maxi(0, int(actor_result.get("distance",1)) - 1)
            actor_result.guard = int(actor_result.get("guard",0)) + power
        "status":
            var status_id := str(ability.get("status_id", "marked"))
            target_result = StatusEngine.apply_status(target_result, status_id, power, duration)
        "counter":
            # A successful counter must progress the fight: protection plus a
            # small riposte and posture punishment, not an endless turtle state.
            actor_result.guard = int(actor_result.get("guard",0)) + power
            var riposte := maxi(1, int(power / 2))
            target_result.hp = maxi(0, int(target_result.get("hp",0)) - riposte)
            target_result.posture = maxi(0, int(target_result.get("posture",0)) - riposte)
        "resource":
            var character := ContentRegistry.get_record(str(ability.get("character_id", "")))
            var maximum := maxi(1, int(character.get("resource_max", 5)))
            resources[resource] = clampi(int(resources.get(resource,0)) + power, 0, maximum)
            actor_result.guard = int(actor_result.get("guard",0)) + 1
        "echo":
            # An Echo repeats part of the attack immediately; its strength is
            # explicit in data so it can be balanced statistically.
            target_result.hp = maxi(0, int(target_result.get("hp",0)) - power)
            actor_result.guard = int(actor_result.get("guard",0)) + maxi(1, int(power / 2))
        "mark":
            target_result = StatusEngine.apply_status(target_result, "marked", power, duration)
        "debt":
            # Debt buys immediate power at a visible personal cost.
            target_result.hp = maxi(0, int(target_result.get("hp",0)) - power)
            var self_cost := maxi(1, int((power + 3) / 4))
            actor_result.hp = maxi(1, int(actor_result.get("hp",1)) - self_cost)
        "range":
            # Ranged signature attacks deal damage and create space.
            target_result.hp = maxi(0, int(target_result.get("hp",0)) - power)
            actor_result.distance = mini(2, int(actor_result.get("distance",1)) + 1)
        _:
            return {"ok":false,"reason":"unknown_mechanic"}
    return {"ok":true,"actor":actor_result,"target":target_result,"resources":resources}

func _default_power(mechanic: String) -> int:
    return int({
        "damage":4,
        "posture":5,
        "guard":5,
        "heal":5,
        "move":2,
        "status":1,
        "counter":3,
        "resource":3,
        "echo":2,
        "mark":1,
        "debt":5,
        "range":4,
    }.get(mechanic, 1))
