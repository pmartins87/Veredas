extends RefCounted
class_name PlayerPolicyEngine

const POLICIES := ["balanced", "aggressive", "cautious", "explorer", "random"]

func policy_ids() -> Array[String]:
    var result: Array[String] = []
    for policy_id_variant in POLICIES:
        result.append(str(policy_id_variant))
    return result

func is_valid(policy_id: String) -> bool:
    return policy_id in POLICIES

func choose_event_choice(policy_id: String, _event: Dictionary, available: Array) -> int:
    if available.is_empty():
        return -1
    if policy_id == "random":
        var random_position: int = RNGService.range_int(0, available.size() - 1)
        return int((available[random_position] as Dictionary).get("index", -1))
    var best_index: int = int((available[0] as Dictionary).get("index", -1))
    var best_score: float = -1000000.0
    for entry_variant in available:
        var entry: Dictionary = entry_variant as Dictionary
        var choice: Dictionary = entry.get("choice", {}) as Dictionary
        var score: float = _choice_score(policy_id, choice)
        var index: int = int(entry.get("index", -1))
        if score > best_score or (is_equal_approx(score, best_score) and index < best_index):
            best_score = score
            best_index = index
    return best_index

func choose_combat_decision(policy_id: String, combat: Dictionary) -> Dictionary:
    var player: Dictionary = combat.get("player", {}) as Dictionary
    var enemy: Dictionary = combat.get("enemy", {}) as Dictionary
    var intent: Dictionary = combat.get("intent", {}) as Dictionary
    var character_id: String = str(combat.get("character_id", ""))
    var resource_pool: Dictionary = combat.get("signature_resource", {}) as Dictionary
    var hp: int = int(player.get("hp", 0))
    var max_hp: int = maxi(1, int(player.get("max_hp", 16)))
    var hp_ratio: float = float(hp) / float(max_hp)
    var distance: int = int(player.get("distance", 1))
    var weapon_range: Vector2i = InventoryEngine.weapon_range()
    if InventoryEngine.equipped_item("weapon").is_empty():
        weapon_range = Vector2i(0, 0)

    if distance < weapon_range.x:
        return {"kind":"action", "id":"retreat"}
    if distance > weapon_range.y:
        return {"kind":"action", "id":"advance"}

    var payable: Array = []
    for ability_variant in CharacterKitEngine.abilities_for(character_id):
        var ability: Dictionary = ability_variant as Dictionary
        if CharacterKitEngine.can_pay(ability, resource_pool):
            payable.append(ability)

    if policy_id == "random":
        var options: Array[Dictionary] = [
            {"kind":"action", "id":"strike"},
            {"kind":"action", "id":"precise"},
            {"kind":"action", "id":"guard"},
        ]
        for ability_variant in payable:
            var ability: Dictionary = ability_variant as Dictionary
            options.append({"kind":"ability", "id":str(ability.get("id", ""))})
        return options[RNGService.range_int(0, options.size() - 1)]

    var healing_ability := _best_ability(payable, ["heal", "guard"])
    var damage_ability := _best_ability(payable, ["damage", "posture", "status", "mark", "counter"])
    var utility_ability := _best_ability(payable, ["resource", "echo", "range", "debt"])

    if policy_id == "cautious":
        if hp_ratio <= 0.70 and not healing_ability.is_empty():
            return {"kind":"ability", "id":str(healing_ability.get("id", ""))}
        if str(intent.get("id", "")) == "heavy" and int(player.get("guard", 0)) < 4:
            return {"kind":"action", "id":"guard"}
        if hp_ratio <= 0.45:
            return {"kind":"action", "id":"guard"}
        if not damage_ability.is_empty() and int(enemy.get("hp", 0)) <= 8:
            return {"kind":"ability", "id":str(damage_ability.get("id", ""))}
        if int(player.get("vigor", 0)) >= 4:
            return {"kind":"action", "id":"precise"}
        return {"kind":"action", "id":"strike"}

    if policy_id == "aggressive":
        if not damage_ability.is_empty():
            return {"kind":"ability", "id":str(damage_ability.get("id", ""))}
        if int(player.get("vigor", 0)) >= 2:
            return {"kind":"action", "id":"precise"}
        return {"kind":"action", "id":"strike"}

    if policy_id == "explorer":
        if hp_ratio <= 0.50 and not healing_ability.is_empty():
            return {"kind":"ability", "id":str(healing_ability.get("id", ""))}
        if not utility_ability.is_empty():
            return {"kind":"ability", "id":str(utility_ability.get("id", ""))}
        if not damage_ability.is_empty():
            return {"kind":"ability", "id":str(damage_ability.get("id", ""))}
        if int(player.get("vigor", 0)) >= 3:
            return {"kind":"action", "id":"precise"}
        return {"kind":"action", "id":"strike"}

    if hp_ratio <= 0.55 and not healing_ability.is_empty():
        return {"kind":"ability", "id":str(healing_ability.get("id", ""))}
    if str(intent.get("id", "")) == "heavy" and hp_ratio < 0.75:
        return {"kind":"action", "id":"guard"}
    if not damage_ability.is_empty():
        return {"kind":"ability", "id":str(damage_ability.get("id", ""))}
    if int(player.get("vigor", 0)) >= 3:
        return {"kind":"action", "id":"precise"}
    return {"kind":"action", "id":"strike"}

func should_fight_boss(policy_id: String, turn: int, health: int, max_health: int) -> bool:
    if turn < 6:
        return false
    var ratio: float = float(health) / float(maxi(1, max_health))
    match policy_id:
        "aggressive":
            return true
        "cautious":
            return turn >= 10 or (turn >= 8 and ratio >= 0.70)
        "explorer":
            return turn >= 9
        "random":
            return turn >= 6 and RNGService.next_float() >= 0.45
        _:
            return turn >= 7 and ratio >= 0.40

func choose_travel(policy_id: String, locations: Array, current_location: String, visited: Array) -> String:
    var candidates: Array[String] = []
    var unvisited: Array[String] = []
    for location_variant in locations:
        var location_id: String = str(location_variant)
        if location_id == "" or location_id == current_location:
            continue
        candidates.append(location_id)
        if location_id not in visited:
            unvisited.append(location_id)
    candidates.sort()
    unvisited.sort()
    if candidates.is_empty():
        return ""
    if policy_id == "random":
        return candidates[RNGService.range_int(0, candidates.size() - 1)]
    if policy_id in ["explorer", "balanced"] and not unvisited.is_empty():
        return unvisited[0]
    if policy_id == "cautious" and current_location != "" and current_location in visited and not unvisited.is_empty():
        return unvisited[0]
    return candidates[0]

func choose_purchase(policy_id: String, stock: Array) -> String:
    var affordable: Array[Dictionary] = []
    for item_variant in stock:
        var item: Dictionary = item_variant as Dictionary
        var item_id: String = str(item.get("id", ""))
        if item_id != "" and MerchantEngine.can_buy(item_id):
            affordable.append(item)
    if affordable.is_empty():
        return ""
    if policy_id == "random":
        return str(affordable[RNGService.range_int(0, affordable.size() - 1)].get("id", ""))
    var best_id: String = ""
    var best_score: float = -1000000.0
    for item in affordable:
        var item_id: String = str(item.get("id", ""))
        var score: float = _item_score(policy_id, item)
        if score > best_score or (is_equal_approx(score, best_score) and (best_id == "" or item_id < best_id)):
            best_score = score
            best_id = item_id
    return best_id

func choose_ending(policy_id: String, endings: Array) -> String:
    if endings.is_empty():
        return ""
    var ordered: Array[String] = []
    for ending_variant in endings:
        var ending: Dictionary = ending_variant as Dictionary
        var ending_id: String = str(ending.get("id", ""))
        if ending_id != "":
            ordered.append(ending_id)
    ordered.sort()
    if ordered.is_empty():
        return ""
    if policy_id == "random":
        return ordered[RNGService.range_int(0, ordered.size() - 1)]
    match policy_id:
        "aggressive":
            return ordered[ordered.size() - 1]
        "explorer":
            var known: Array = GameState.profile.get("endings", []) as Array
            for ending_id in ordered:
                if ending_id not in known:
                    return ending_id
        "cautious":
            return ordered[0]
        _:
            return ordered[0]
    return ordered[0]

func _choice_score(policy_id: String, choice: Dictionary) -> float:
    var effect_raw = choice.get("effect", {})
    var score: float = 0.0
    if typeof(effect_raw) == TYPE_ARRAY:
        for effect_variant in effect_raw as Array:
            if typeof(effect_variant) == TYPE_DICTIONARY:
                score += _effect_score(policy_id, effect_variant as Dictionary)
    elif typeof(effect_raw) == TYPE_DICTIONARY:
        score += _effect_score(policy_id, effect_raw as Dictionary)
    var text: String = str(choice.get("text", "")).to_lower()
    if policy_id == "aggressive" and ("enfrent" in text or "atac" in text or "arris" in text):
        score += 2.0
    if policy_id == "cautious" and ("recu" in text or "segur" in text or "cuidad" in text):
        score += 2.0
    if policy_id == "explorer" and ("explor" in text or "investig" in text or "seguir" in text):
        score += 2.0
    return score

func _effect_score(policy_id: String, effect: Dictionary) -> float:
    var op: String = str(effect.get("op", ""))
    var value: float = float(effect.get("value", effect.get("intensity", effect.get("count", 1))))
    match policy_id:
        "aggressive":
            match op:
                "mark_add", "mark_intensify": return 4.0 + value
                "debt_create": return 3.0
                "item_add": return 3.0
                "resource_add": return 1.5 + maxf(0.0, value)
                "heal", "vigor": return 0.5 + maxf(0.0, value) * 0.2
                "travel_location", "travel_world": return 1.0
                _: return 0.0
        "cautious":
            match op:
                "heal": return 5.0 + maxf(0.0, value)
                "vigor": return 3.0 + maxf(0.0, value) * 0.5
                "debt_resolve", "debt_resolve_oldest": return 5.0
                "resource_add": return 3.0 + maxf(0.0, value) * 0.5
                "item_add": return 2.5
                "debt_create": return -4.0
                "mark_add", "mark_intensify": return -1.0
                _: return 0.0
        "explorer":
            match op:
                "travel_location", "travel_world": return 6.0
                "mark_add", "mark_intensify": return 4.0 + value
                "flag_set": return 4.0
                "item_add": return 3.0
                "debt_create", "debt_resolve", "debt_resolve_oldest": return 2.0
                "resource_add": return 1.0 + maxf(0.0, value) * 0.2
                _: return 0.0
        _:
            match op:
                "heal": return 3.0 + maxf(0.0, value) * 0.6
                "vigor": return 2.0 + maxf(0.0, value) * 0.4
                "resource_add": return 2.0 + maxf(0.0, value) * 0.4
                "item_add": return 2.5
                "mark_add", "mark_intensify": return 2.0 + value * 0.4
                "debt_resolve", "debt_resolve_oldest": return 2.5
                "debt_create": return -1.0
                "travel_location", "travel_world": return 1.5
                _: return 0.0

func _item_score(policy_id: String, item: Dictionary) -> float:
    var item_id: String = str(item.get("id", ""))
    var price: float = float(maxi(1, MerchantEngine.price(item_id)))
    var kind: String = str(item.get("kind", ""))
    var effect: Dictionary = item.get("effect", {}) as Dictionary
    var effect_value: float = float(effect.get("value", effect.get("count", 1)))
    var score: float = effect_value + 10.0 / price
    match policy_id:
        "aggressive":
            if kind == "equipment": score += 5.0
            if str(item.get("visual_archetype", "")) in InventoryEngine.WEAPONS: score += 5.0
        "cautious":
            if kind in ["consumable", "tool"]: score += 5.0
            if str(effect.get("op", "")) in ["heal", "vigor"]: score += 6.0
        "explorer":
            if not InventoryEngine.has_item(item_id): score += 5.0
            score += 2.0 / price
        _:
            if kind == "equipment": score += 2.0
    return score

func _best_ability(payable: Array, mechanics: Array[String]) -> Dictionary:
    for mechanic in mechanics:
        for ability_variant in payable:
            var ability: Dictionary = ability_variant as Dictionary
            if str(ability.get("mechanic", "")) == mechanic:
                return ability
    return {}
