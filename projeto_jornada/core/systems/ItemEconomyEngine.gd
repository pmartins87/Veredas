extends Node

const RARITIES := ["common", "uncommon", "rare", "singular", "relic", "echo"]
const BUY_BASE := {"common":6, "uncommon":13, "rare":24, "singular":40, "relic":66, "echo":108}
const FALLBACK_LOOT_WEIGHT := {"common":100, "uncommon":50, "rare":20, "singular":8, "relic":3, "echo":1}
const FALLBACK_MERCHANT_WEIGHT := {"common":100, "uncommon":70, "rare":35, "singular":15, "relic":5, "echo":1}

const BONUS_WEIGHTS := {
    "damage":4.0,
    "posture":2.5,
    "guard":2.5,
    "range":3.0,
    "status_power":2.0,
    "status_resist":2.0,
    "vigor":2.5,
    "heal":2.0,
    "resource_gain":3.0,
    "mark_synergy":2.5,
    "debt_pressure":2.0,
    "load":-1.5,
}

func rarity_rank(rarity: String) -> int:
    return RARITIES.find(rarity)

func buy_price(item_id: String) -> int:
    var item := ContentRegistry.get_record(item_id)
    if item.is_empty():
        return 0
    var rarity := str(item.get("rarity", "common"))
    var base := int(BUY_BASE.get(rarity, 6))
    var kind := str(item.get("kind", ""))
    if kind == "component":
        var effect: Dictionary = item.get("effect", {}) as Dictionary
        return base + maxi(0, int(effect.get("value", 0))) * 2
    return base + maxi(0, roundi(power_score(item) * 1.5))

func sell_price(item_id: String) -> int:
    var purchase := buy_price(item_id)
    if purchase <= 0:
        return 0
    var item := ContentRegistry.get_record(item_id)
    var ratio := 0.60 if str(item.get("kind", "")) == "component" else 0.45
    return maxi(1, floori(float(purchase) * ratio))

func power_score(item: Dictionary) -> float:
    if item.is_empty():
        return 0.0
    var kind := str(item.get("kind", ""))
    if kind == "equipment":
        var bonuses := AffixEngine.combined_effects(item)
        var total := 0.0
        for op_variant in BONUS_WEIGHTS.keys():
            var op := str(op_variant)
            total += float(bonuses.get(op, 0)) * float(BONUS_WEIGHTS[op])
        return maxf(0.0, total)
    var effect: Dictionary = item.get("effect", {}) as Dictionary
    var op := str(effect.get("op", ""))
    var value := float(effect.get("value", 0))
    if op in ["heal", "vigor"]:
        return value * 1.8
    if op == "resource_add":
        return value * (2.2 if str(effect.get("resource", "")) == "essence" else 1.5)
    if op == "trade_value":
        return value
    return maxf(0.0, value)

func merchant_stock(world_id: String, size: int = 8) -> Array:
    if size <= 0:
        return []
    var candidates: Array[Dictionary] = []
    var purchased: Array = GameState.run.get("purchases", []) as Array
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("world_id", "")) != world_id:
            continue
        if str(item.get("kind", "")) == "equipment" and str(item.get("id", "")) in purchased:
            continue
        candidates.append(item)
    var rng := _local_rng("merchant:%s:%d" % [world_id, int(GameState.run.get("turn", 0))])
    var result: Array = []
    while not candidates.is_empty() and result.size() < size:
        var index := _weighted_index(candidates, rng, "merchant")
        result.append(candidates[index])
        candidates.remove_at(index)
    return result

func fragment_reward(enemy_record: Dictionary) -> int:
    var rank := str(enemy_record.get("rank", "normal"))
    var tier := maxi(1, int(enemy_record.get("encounter_tier", enemy_record.get("boss_tier", 1))))
    match rank:
        "elite": return 8 + int((tier - 1) / 2)
        "subboss": return 13 + tier
        "boss": return 18 + tier * 2
        _: return 5 + int((tier - 1) / 2)

func loot_for_victory(enemy_record: Dictionary, defeat_ordinal: int) -> Array[String]:
    if enemy_record.is_empty():
        return []
    var rank := str(enemy_record.get("rank", "normal"))
    var world_id := str(enemy_record.get("world_id", GameState.run.get("world_id", "")))
    var enemy_id := str(enemy_record.get("id", "enemy"))
    var rng := _local_rng("loot:%s:%d" % [enemy_id, defeat_ordinal])
    var drop_count := 0
    var max_rank := 2
    match rank:
        "elite":
            drop_count = 1 if rng.randf() <= 0.90 else 0
            max_rank = 3
        "subboss":
            drop_count = 1
            max_rank = 4
        "boss":
            drop_count = 2
            max_rank = 5
        _:
            drop_count = 1 if rng.randf() <= 0.38 else 0
            max_rank = 2
    if drop_count <= 0:
        return []

    var candidates: Array[Dictionary] = []
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("world_id", "")) != world_id:
            continue
        if rarity_rank(str(item.get("rarity", "common"))) <= max_rank:
            candidates.append(item)

    var result: Array[String] = []
    while not candidates.is_empty() and result.size() < drop_count:
        var index := _weighted_index(candidates, rng, rank)
        var chosen: Dictionary = candidates[index] as Dictionary
        result.append(str(chosen.get("id", "")))
        candidates.remove_at(index)
    return result

func inventory_value(inventory: Array = []) -> int:
    var source: Array = inventory
    if source.is_empty():
        source = GameState.run.get("inventory", []) as Array
    var total := 0
    for item_variant in source:
        total += sell_price(str(item_variant))
    return total

func equipment_score(policy_id: String, item: Dictionary) -> float:
    if str(item.get("kind", "")) != "equipment":
        return -1000000.0
    var bonuses := AffixEngine.combined_effects(item)
    var score := 0.0
    match policy_id:
        "aggressive":
            score += float(bonuses.get("damage", 0)) * 8.0
            score += float(bonuses.get("posture", 0)) * 5.0
            score += float(bonuses.get("range", 0)) * 3.0
            score += float(bonuses.get("status_power", 0)) * 2.0
            score += float(bonuses.get("resource_gain", 0)) * 2.0
        "cautious":
            score += float(bonuses.get("guard", 0)) * 8.0
            score += float(bonuses.get("status_resist", 0)) * 5.0
            score += float(bonuses.get("heal", 0)) * 5.0
            score += float(bonuses.get("vigor", 0)) * 3.0
            score -= float(bonuses.get("load", 0)) * 2.0
        "explorer":
            score += float(bonuses.get("resource_gain", 0)) * 6.0
            score += float(bonuses.get("mark_synergy", 0)) * 5.0
            score += float(bonuses.get("debt_pressure", 0)) * 4.0
            score += float(bonuses.get("status_power", 0)) * 4.0
            score += float(bonuses.get("range", 0)) * 2.0
            score -= float(bonuses.get("load", 0))
        _:
            score = power_score(item)
    score += float(rarity_rank(str(item.get("rarity", "common"))) + 1) * 0.02
    return score

func should_equip(policy_id: String, item_id: String) -> bool:
    var item := ContentRegistry.get_record(item_id)
    if item.is_empty() or str(item.get("kind", "")) != "equipment":
        return false
    var slot := InventoryEngine.slot_for(item)
    if slot == "":
        return false
    var current := InventoryEngine.equipped_item(slot)
    if current.is_empty():
        return true
    return equipment_score(policy_id, item) > equipment_score(policy_id, current) + 0.001

func _weighted_index(candidates: Array[Dictionary], rng: RandomNumberGenerator, source: String) -> int:
    var weights: Array[int] = []
    var total := 0
    for item in candidates:
        var rarity := str(item.get("rarity", "common"))
        var weight := int(item.get("merchant_weight", FALLBACK_MERCHANT_WEIGHT.get(rarity, 1)))
        if source != "merchant":
            weight = int(item.get("loot_weight", FALLBACK_LOOT_WEIGHT.get(rarity, 1)))
            weight = maxi(1, roundi(float(weight) * _source_multiplier(source, rarity)))
        weights.append(maxi(1, weight))
        total += weights[-1]
    if total <= 1:
        return 0
    var roll := rng.randi_range(1, total)
    var cursor := 0
    for index in range(weights.size()):
        cursor += weights[index]
        if roll <= cursor:
            return index
    return weights.size() - 1

func _source_multiplier(source: String, rarity: String) -> float:
    var rank := maxi(0, rarity_rank(rarity))
    match source:
        "elite": return [1.0, 1.4, 2.2, 4.0, 0.0, 0.0][rank]
        "subboss": return [0.6, 1.0, 2.0, 4.0, 8.0, 0.0][rank]
        "boss": return [0.25, 0.5, 1.0, 3.0, 8.0, 20.0][rank]
        _: return [1.0, 1.1, 1.5, 0.0, 0.0, 0.0][rank]

func _local_rng(channel: String) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    var seed_value := int(GameState.run.get("seed", 1))
    var mixed := absi(int(("%d|%s" % [seed_value, channel]).hash()))
    rng.seed = maxi(1, mixed)
    return rng
