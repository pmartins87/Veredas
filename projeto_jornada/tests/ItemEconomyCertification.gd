extends Node

const EXPECTED_PER_WORLD := {"common":40, "uncommon":24, "rare":14, "singular":8, "relic":5, "echo":2}
const EXPECTED_GLOBAL := {"common":480, "uncommon":288, "rare":168, "singular":96, "relic":60, "echo":24}
const AFFIX_COUNT := {"common":0, "uncommon":1, "rare":1, "singular":2, "relic":2, "echo":3}
const EQUIPMENT_OPS := ["damage", "posture", "guard", "range", "status_power", "status_resist", "vigor", "heal", "resource_gain", "mark_synergy", "debt_pressure"]
const ALL_BONUS_OPS := ["damage", "guard", "status_power", "posture", "vigor", "mark_synergy", "load", "range", "status_resist", "heal", "debt_pressure", "resource_gain"]

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _catalog_gate()
    _semantics_and_affix_gate()
    _price_gate()
    _merchant_gate()
    _loot_gate()
    _runtime_bonus_gate()
    _simulation_gate()
    _finish()

func _catalog_gate() -> void:
    var items := ContentRegistry.all("items")
    expect(items.size() == 1116, "10.4 requires exactly 1116 items")
    var global_counts: Dictionary = {}
    var by_world: Dictionary = {}
    for item_variant in items:
        var item: Dictionary = item_variant as Dictionary
        var rarity := str(item.get("rarity", ""))
        var world_id := str(item.get("world_id", ""))
        global_counts[rarity] = int(global_counts.get(rarity, 0)) + 1
        var row: Dictionary = by_world.get(world_id, {}) as Dictionary
        row[rarity] = int(row.get(rarity, 0)) + 1
        by_world[world_id] = row
        expect(int(item.get("economy_tier", 0)) == ItemEconomyEngine.rarity_rank(rarity) + 1, "%s economy tier mismatch" % str(item.get("id", "")))
        expect(int(item.get("loot_weight", 0)) > 0, "%s missing loot weight" % str(item.get("id", "")))
        expect(int(item.get("merchant_weight", 0)) > 0, "%s missing merchant weight" % str(item.get("id", "")))
    expect(by_world.size() == 12, "10.4 items do not span all 12 Domains")
    for rarity in EXPECTED_GLOBAL:
        expect(int(global_counts.get(rarity, 0)) == int(EXPECTED_GLOBAL[rarity]), "10.4 global rarity %s mismatch" % rarity)
    for world_id_variant in by_world.keys():
        var world_id := str(world_id_variant)
        var row: Dictionary = by_world[world_id] as Dictionary
        var total := 0
        for rarity in EXPECTED_PER_WORLD:
            expect(int(row.get(rarity, 0)) == int(EXPECTED_PER_WORLD[rarity]), "%s rarity %s mismatch" % [world_id, rarity])
            total += int(row.get(rarity, 0))
        expect(total == 93, "%s does not contain 93 items" % world_id)

func _semantics_and_affix_gate() -> void:
    var affix_ops: Dictionary = {}
    for affix_variant in AffixEngine.AFFIXES:
        var affix: Dictionary = affix_variant as Dictionary
        affix_ops[str(affix.get("op", ""))] = true
    expect(affix_ops.size() == ALL_BONUS_OPS.size(), "10.4 affix operation coverage is incomplete")
    for op in ALL_BONUS_OPS:
        expect(affix_ops.has(op), "10.4 missing affix operation %s" % op)

    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        var item_id := str(item.get("id", ""))
        var kind := str(item.get("kind", ""))
        var rarity := str(item.get("rarity", ""))
        var effect: Dictionary = item.get("effect", {}) as Dictionary
        var op := str(effect.get("op", ""))
        var affixes := AffixEngine.affixes_for(item)
        if kind == "equipment":
            expect(InventoryEngine.slot_for(item) != "", "%s equipment has no slot" % item_id)
            expect(op in EQUIPMENT_OPS, "%s has invalid equipment effect %s" % [item_id, op])
            expect(affixes.size() == int(AFFIX_COUNT.get(rarity, 0)), "%s affix count does not match rarity" % item_id)
            var seen: Dictionary = {}
            for affix_variant in affixes:
                var affix: Dictionary = affix_variant as Dictionary
                var affix_id := str(affix.get("id", ""))
                expect(not seen.has(affix_id), "%s repeats affix %s" % [item_id, affix_id])
                seen[affix_id] = true
        elif kind == "consumable":
            expect(op in ["heal", "vigor"], "%s consumable is not usable" % item_id)
            expect(affixes.is_empty(), "%s non-equipment has passive affixes" % item_id)
        elif kind == "tool":
            expect(op == "resource_add" and str(effect.get("resource", "")) in ["provisions", "essence"], "%s tool has unusable effect" % item_id)
            expect(affixes.is_empty(), "%s non-equipment has passive affixes" % item_id)
        elif kind == "component":
            expect(op == "trade_value" and int(effect.get("value", 0)) > 0, "%s component lacks trade value" % item_id)
            expect(affixes.is_empty(), "%s non-equipment has passive affixes" % item_id)
        else:
            expect(false, "%s has unknown kind %s" % [item_id, kind])

func _price_gate() -> void:
    var totals: Dictionary = {}
    var counts: Dictionary = {}
    var affordable_common := 0
    var affordable_high := 0
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        var item_id := str(item.get("id", ""))
        var rarity := str(item.get("rarity", "common"))
        var buy := ItemEconomyEngine.buy_price(item_id)
        var sell := ItemEconomyEngine.sell_price(item_id)
        expect(buy > 0, "%s has non-positive buy price" % item_id)
        expect(sell > 0 and sell < buy, "%s sell price must be positive and below buy price" % item_id)
        totals[rarity] = float(totals.get(rarity, 0.0)) + float(buy)
        counts[rarity] = int(counts.get(rarity, 0)) + 1
        if buy <= 12:
            if rarity == "common": affordable_common += 1
            if ItemEconomyEngine.rarity_rank(rarity) >= ItemEconomyEngine.rarity_rank("rare"):
                affordable_high += 1
    expect(affordable_common > 0, "10.4 starting fragments cannot buy any common item")
    expect(affordable_high == 0, "10.4 starting fragments can immediately buy rare-or-better items")
    var previous := -1.0
    for rarity in ItemEconomyEngine.RARITIES:
        var average := float(totals.get(rarity, 0.0)) / float(maxi(1, int(counts.get(rarity, 0))))
        expect(average > previous, "10.4 average price is not increasing at rarity %s" % rarity)
        previous = average

func _merchant_gate() -> void:
    var first_character: Dictionary = (ContentRegistry.all("characters")[0] as Dictionary)
    GameState.new_run(str(first_character.get("id", "")), 104104)
    var first_world := str(first_character.get("world_id", ""))
    GameState.run.world_id = first_world
    GameState.run.turn = 17
    var a := _ids(ItemEconomyEngine.merchant_stock(first_world, 8))
    var b := _ids(ItemEconomyEngine.merchant_stock(first_world, 8))
    expect(a == b and a.size() == 8, "10.4 merchant stock is not deterministic")

    var rarity_counts: Dictionary = {}
    var total := 0
    for world_variant in ContentRegistry.all("worlds"):
        var world: Dictionary = world_variant as Dictionary
        GameState.run.world_id = str(world.get("id", ""))
        for turn in range(80):
            GameState.run.turn = turn
            for item_variant in ItemEconomyEngine.merchant_stock(str(world.get("id", "")), 8):
                var item: Dictionary = item_variant as Dictionary
                var rarity := str(item.get("rarity", "common"))
                rarity_counts[rarity] = int(rarity_counts.get(rarity, 0)) + 1
                total += 1
    var accessible := int(rarity_counts.get("common", 0)) + int(rarity_counts.get("uncommon", 0))
    expect(total > 0 and float(accessible) / float(total) >= 0.80, "10.4 merchant stock is not dominated by common/uncommon supply")
    expect(float(rarity_counts.get("echo", 0)) / float(maxi(1, total)) <= 0.01, "10.4 Echo items are too common at merchants")
    print("10.4 merchant sample: total=%d rarity=%s" % [total, str(rarity_counts)])

func _loot_gate() -> void:
    var normal := _enemy_by_rank("normal", false)
    var elite := _enemy_by_rank("elite", false)
    var subboss := _enemy_by_rank("subboss", true)
    var boss := _enemy_by_rank("boss", true)
    expect(not normal.is_empty() and not elite.is_empty() and not subboss.is_empty() and not boss.is_empty(), "10.4 loot probes are missing enemy ranks")
    if normal.is_empty() or elite.is_empty() or subboss.is_empty() or boss.is_empty():
        return
    GameState.run.seed = 104204
    expect(ItemEconomyEngine.loot_for_victory(normal, 41) == ItemEconomyEngine.loot_for_victory(normal, 41), "10.4 loot is not deterministic")

    var normal_drops := 0
    var elite_drops := 0
    var boss_echoes := 0
    for ordinal in range(1, 401):
        var normal_loot := ItemEconomyEngine.loot_for_victory(normal, ordinal)
        normal_drops += normal_loot.size()
        _expect_max_rarity(normal_loot, "rare", "normal")
        var elite_loot := ItemEconomyEngine.loot_for_victory(elite, ordinal)
        elite_drops += elite_loot.size()
        _expect_max_rarity(elite_loot, "singular", "elite")
        var subboss_loot := ItemEconomyEngine.loot_for_victory(subboss, ordinal)
        expect(subboss_loot.size() == 1, "10.4 subboss must guarantee one drop")
        _expect_max_rarity(subboss_loot, "relic", "subboss")
        var boss_loot := ItemEconomyEngine.loot_for_victory(boss, ordinal)
        expect(boss_loot.size() == 2, "10.4 boss must guarantee two drops")
        for item_id in boss_loot:
            if str(ContentRegistry.get_record(str(item_id)).get("rarity", "")) == "echo":
                boss_echoes += 1
    var normal_rate := float(normal_drops) / 400.0
    var elite_rate := float(elite_drops) / 400.0
    expect(normal_rate >= 0.28 and normal_rate <= 0.48, "10.4 normal drop rate outside calibrated envelope: %.3f" % normal_rate)
    expect(elite_rate >= 0.82 and elite_rate <= 0.97, "10.4 elite drop rate outside calibrated envelope: %.3f" % elite_rate)
    expect(boss_echoes > 0, "10.4 boss loot never exposes the Echo rarity")
    expect(ItemEconomyEngine.fragment_reward(normal) < ItemEconomyEngine.buy_price(_cheapest_item("relic")), "10.4 one normal victory can finance a relic")
    print("10.4 loot sample: normal=%.3f elite=%.3f boss_echoes=%d" % [normal_rate, elite_rate, boss_echoes])

func _runtime_bonus_gate() -> void:
    var character: Dictionary = ContentRegistry.all("characters")[0] as Dictionary
    var enemy: Dictionary = _enemy_by_rank("normal", false)
    if character.is_empty() or enemy.is_empty():
        expect(false, "10.4 runtime bonus probe lacks character/enemy")
        return
    var covered: Dictionary = {}
    for op in ALL_BONUS_OPS:
        var item := _equipment_with_bonus(op)
        expect(not item.is_empty(), "10.4 no equipment exposes bonus %s" % op)
        if item.is_empty():
            continue
        GameState.new_run(str(character.get("id", "")), 104304 + ALL_BONUS_OPS.find(op))
        InventoryEngine.add_item(str(item.get("id", "")))
        expect(InventoryEngine.equip(str(item.get("id", ""))), "10.4 could not equip %s probe" % op)
        var bonuses := InventoryEngine.equipment_bonuses()
        expect(int(bonuses.get(op, 0)) != 0, "10.4 equipped bonus %s vanished before combat" % op)
        var combat := CombatEngine.start(str(enemy.get("id", "")), str(character.get("id", "")))
        var player: Dictionary = combat.get("player", {}) as Dictionary
        match op:
            "damage": expect(int(player.get("damage_bonus", 0)) == int(bonuses.get(op, 0)), "10.4 damage bonus is inert")
            "posture": expect(int(player.get("posture_bonus", 0)) == int(bonuses.get(op, 0)), "10.4 posture bonus is inert")
            "range": expect(int(player.get("range_bonus", 0)) == int(bonuses.get(op, 0)), "10.4 range bonus is inert")
            "status_power": expect(int(player.get("status_power_bonus", 0)) == int(bonuses.get(op, 0)), "10.4 status power is inert")
            "status_resist": expect(int(player.get("status_resist", 0)) == int(bonuses.get(op, 0)), "10.4 status resist is inert")
            "heal": expect(int(player.get("heal_bonus", 0)) == int(bonuses.get(op, 0)), "10.4 heal bonus is inert")
            "resource_gain": expect(int(player.get("resource_gain_bonus", 0)) == int(bonuses.get(op, 0)), "10.4 resource gain is inert")
            "mark_synergy": expect(int(player.get("mark_synergy_bonus", 0)) == int(bonuses.get(op, 0)), "10.4 mark synergy is inert")
            "debt_pressure": expect(int(player.get("debt_pressure_bonus", 0)) == int(bonuses.get(op, 0)), "10.4 debt pressure is inert")
            "guard": expect(int(player.get("guard", 0)) >= int(bonuses.get(op, 0)), "10.4 guard bonus is inert")
            "vigor": expect(int(player.get("max_vigor", 0)) != int(GameState.run.get("max_vigor", 8)) or int(bonuses.get("load", 0)) != 0, "10.4 vigor bonus is inert")
            "load": expect(int(player.get("equipment_load", 0)) == maxi(0, int(bonuses.get(op, 0))), "10.4 load is not applied")
        covered[op] = true
    expect(covered.size() == ALL_BONUS_OPS.size(), "10.4 runtime bonus coverage incomplete")

    var actor := {"hp":8,"max_hp":16,"vigor":8,"max_vigor":8,"posture":10,"max_posture":10,"guard":0,"distance":0,"states":[],"heal_bonus":2,"status_power_bonus":2,"mark_synergy_bonus":2,"debt_pressure_bonus":2,"resource_gain_bonus":1}
    var marked_target := StatusEngine.apply_status({"hp":30,"max_hp":30,"posture":20,"max_posture":20,"guard":0,"distance":1,"states":[]}, "marked", 1, 2)
    var pool := {"Focus":5}
    var heal_result := CharacterKitEngine.execute({"mechanic":"heal","resource":"Focus","cost":0,"power":2}, actor, marked_target, pool)
    expect(int((heal_result.get("actor", {}) as Dictionary).get("hp", 0)) == 12, "10.4 heal equipment bonus does not change ability output")
    var damage_result := CharacterKitEngine.execute({"mechanic":"damage","resource":"Focus","cost":0,"power":2}, actor, marked_target, pool)
    expect(int((damage_result.get("target", {}) as Dictionary).get("hp", 30)) == 26, "10.4 mark synergy does not change damage output")

func _simulation_gate() -> void:
    var character: Dictionary = ContentRegistry.all("characters")[0] as Dictionary
    var simulator := JourneySimulationEngine.new()
    var config := {"character_id":str(character.get("id", "")), "policy_id":"balanced", "build_id":"baseline", "seed":104404, "max_steps":24}
    var first := simulator.simulate(config)
    var second := simulator.simulate(config)
    expect(bool(first.get("ok", false)) and bool(second.get("ok", false)), "10.4 economy simulation failed")
    expect(first.get("loot_drops", -1) == second.get("loot_drops", -2), "10.4 simulated loot is nondeterministic")
    expect(first.get("final_inventory_value", -1) == second.get("final_inventory_value", -2), "10.4 simulated inventory value is nondeterministic")
    expect(int(first.get("final_inventory_value", -1)) >= 0, "10.4 simulator does not report inventory value")

func _ids(items: Array) -> Array[String]:
    var result: Array[String] = []
    for item_variant in items:
        result.append(str((item_variant as Dictionary).get("id", "")))
    return result

func _enemy_by_rank(rank: String, bosses: bool) -> Dictionary:
    var bucket := ContentRegistry.all("bosses" if bosses else "monsters")
    for enemy_variant in bucket:
        var enemy: Dictionary = enemy_variant as Dictionary
        if str(enemy.get("rank", "")) == rank:
            return enemy
    return {}

func _expect_max_rarity(item_ids: Array, max_rarity: String, source: String) -> void:
    var maximum := ItemEconomyEngine.rarity_rank(max_rarity)
    for item_variant in item_ids:
        var item := ContentRegistry.get_record(str(item_variant))
        expect(ItemEconomyEngine.rarity_rank(str(item.get("rarity", "common"))) <= maximum, "10.4 %s loot exceeded rarity cap" % source)

func _cheapest_item(rarity: String) -> String:
    var best_id := ""
    var best_price := 1 << 30
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("rarity", "")) != rarity:
            continue
        var price := ItemEconomyEngine.buy_price(str(item.get("id", "")))
        if price < best_price:
            best_price = price
            best_id = str(item.get("id", ""))
    return best_id

func _equipment_with_bonus(op: String) -> Dictionary:
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("kind", "")) != "equipment":
            continue
        var bonuses := AffixEngine.combined_effects(item)
        if int(bonuses.get(op, 0)) != 0:
            return item
    return {}

func _finish() -> void:
    if failures.is_empty():
        print("ITEM_ECONOMY_CERTIFICATION PASS: 10.4")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("ITEM_ECONOMY_CERTIFICATION: %s" % failure)
        print("ITEM_ECONOMY_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
