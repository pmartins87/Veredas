extends RefCounted
class_name JourneySimulationEngine

const BUILD_IDS := ["baseline", "offense", "defense", "utility"]
const DEFAULT_MAX_STEPS := 80
const MAX_COMBAT_ROUNDS := 80

var policy_engine := PlayerPolicyEngine.new()

func simulate(config: Dictionary) -> Dictionary:
    var original_profile := GameState.profile.duplicate(true)
    var original_run := GameState.run.duplicate(true)
    var original_rng := RNGService.snapshot().duplicate(true)
    var original_combat := CombatEngine.combat.duplicate(true)
    var result := _simulate_internal(config)
    GameState.profile = original_profile
    GameState.run = original_run
    RNGService.restore(original_rng)
    CombatEngine.combat = original_combat
    return result

func simulate_matrix(spec: Dictionary) -> Dictionary:
    var character_ids := _string_array(spec.get("character_ids", []))
    var policy_ids := _string_array(spec.get("policy_ids", policy_engine.policy_ids()))
    var build_ids := _string_array(spec.get("build_ids", BUILD_IDS))
    var seeds_per_combination := maxi(1, int(spec.get("seeds_per_combination", 1)))
    var base_seed := maxi(1, int(spec.get("base_seed", 100000)))
    var max_steps := maxi(12, int(spec.get("max_steps", DEFAULT_MAX_STEPS)))
    var results: Array[Dictionary] = []
    var ordinal := 0
    for character_id in character_ids:
        for policy_id in policy_ids:
            for build_id in build_ids:
                for sample_index in range(seeds_per_combination):
                    var seed_value := base_seed + ordinal * 1009 + sample_index * 97
                    results.append(simulate({
                        "character_id":character_id,
                        "policy_id":policy_id,
                        "build_id":build_id,
                        "seed":seed_value,
                        "max_steps":max_steps,
                    }))
                ordinal += 1
    return {
        "results":results,
        "summary":summarize(results),
        "signature":result_signature(results),
    }

func summarize(results: Array) -> Dictionary:
    var groups: Dictionary = {}
    var total_victories := 0
    var total_defeats := 0
    var total_timeouts := 0
    for result_variant in results:
        if typeof(result_variant) != TYPE_DICTIONARY:
            continue
        var result: Dictionary = result_variant as Dictionary
        var key := "%s|%s|%s|%s" % [
            str(result.get("world_id", "")),
            str(result.get("character_id", "")),
            str(result.get("policy_id", "")),
            str(result.get("build_id", "")),
        ]
        var group: Dictionary = groups.get(key, {
            "world_id":str(result.get("world_id", "")),
            "character_id":str(result.get("character_id", "")),
            "policy_id":str(result.get("policy_id", "")),
            "build_id":str(result.get("build_id", "")),
            "runs":0,
            "victories":0,
            "defeats":0,
            "timeouts":0,
            "boss_reached":0,
            "boss_wins":0,
            "turns_total":0,
            "events_total":0,
            "combats_total":0,
            "purchases_total":0,
            "locations_total":0,
            "health_total":0,
        }) as Dictionary
        group.runs = int(group.runs) + 1
        var outcome := str(result.get("result", ""))
        if outcome == "victory":
            group.victories = int(group.victories) + 1
            total_victories += 1
        elif outcome == "timeout":
            group.timeouts = int(group.timeouts) + 1
            total_timeouts += 1
        else:
            group.defeats = int(group.defeats) + 1
            total_defeats += 1
        if bool(result.get("boss_reached", false)):
            group.boss_reached = int(group.boss_reached) + 1
        if bool(result.get("boss_win", false)):
            group.boss_wins = int(group.boss_wins) + 1
        group.turns_total = int(group.turns_total) + int(result.get("turns", 0))
        group.events_total = int(group.events_total) + int(result.get("events", 0))
        group.combats_total = int(group.combats_total) + int(result.get("combats", 0))
        group.purchases_total = int(group.purchases_total) + int(result.get("purchases", 0))
        group.locations_total = int(group.locations_total) + int(result.get("locations_visited", 0))
        group.health_total = int(group.health_total) + int(result.get("final_health", 0))
        groups[key] = group

    var group_rows: Array[Dictionary] = []
    var group_keys: Array = groups.keys()
    group_keys.sort()
    for key_variant in group_keys:
        var group: Dictionary = groups[key_variant] as Dictionary
        var runs := maxi(1, int(group.runs))
        group["victory_rate"] = float(group.victories) / float(runs)
        group["boss_reach_rate"] = float(group.boss_reached) / float(runs)
        group["boss_win_rate"] = float(group.boss_wins) / float(runs)
        group["avg_turns"] = float(group.turns_total) / float(runs)
        group["avg_events"] = float(group.events_total) / float(runs)
        group["avg_combats"] = float(group.combats_total) / float(runs)
        group["avg_purchases"] = float(group.purchases_total) / float(runs)
        group["avg_locations"] = float(group.locations_total) / float(runs)
        group["avg_final_health"] = float(group.health_total) / float(runs)
        group_rows.append(group)

    return {
        "runs":results.size(),
        "victories":total_victories,
        "defeats":total_defeats,
        "timeouts":total_timeouts,
        "victory_rate":float(total_victories) / float(maxi(1, results.size())),
        "groups":group_rows,
    }

func result_signature(results: Array) -> String:
    var rows: Array[String] = []
    for result_variant in results:
        if typeof(result_variant) != TYPE_DICTIONARY:
            continue
        var result: Dictionary = result_variant as Dictionary
        rows.append("%s;%s;%s;%s;%d;%s;%d;%d;%d;%d;%d;%d;%s" % [
            str(result.get("world_id", "")),
            str(result.get("character_id", "")),
            str(result.get("policy_id", "")),
            str(result.get("build_id", "")),
            int(result.get("seed", 0)),
            str(result.get("result", "")),
            int(result.get("turns", 0)),
            int(result.get("events", 0)),
            int(result.get("combats", 0)),
            int(result.get("purchases", 0)),
            int(result.get("locations_visited", 0)),
            int(result.get("final_health", 0)),
            str(result.get("ending_id", "")),
        ]))
    return "\n".join(rows).sha256_text()

func build_ids() -> Array[String]:
    var result: Array[String] = []
    for build_id_variant in BUILD_IDS:
        result.append(str(build_id_variant))
    return result

func _simulate_internal(config: Dictionary) -> Dictionary:
    var character_id := str(config.get("character_id", ""))
    var policy_id := str(config.get("policy_id", "balanced"))
    var build_id := str(config.get("build_id", "baseline"))
    var seed_value := maxi(1, int(config.get("seed", 1)))
    var max_steps := maxi(12, int(config.get("max_steps", DEFAULT_MAX_STEPS)))
    var character := ContentRegistry.get_record(character_id)
    if character.is_empty() or not character_id.begins_with("character."):
        return _invalid_result(character_id, policy_id, build_id, seed_value, "invalid_character")
    if not policy_engine.is_valid(policy_id):
        return _invalid_result(character_id, policy_id, build_id, seed_value, "invalid_policy")
    if build_id not in BUILD_IDS:
        return _invalid_result(character_id, policy_id, build_id, seed_value, "invalid_build")
    var world_id := str(character.get("world_id", ""))
    if ContentRegistry.get_record(world_id).is_empty():
        return _invalid_result(character_id, policy_id, build_id, seed_value, "invalid_world")

    _prepare_isolated_profile(world_id, character_id)
    if not RunFlowEngine.start_journey(character_id, seed_value):
        return _invalid_result(character_id, policy_id, build_id, seed_value, "start_failed")
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["simulation.no_persist"] = true
    flags["simulation.policy"] = policy_id
    flags["simulation.build"] = build_id
    GameState.run.flags = flags
    var build_items := _apply_build(world_id, build_id)

    var stats := {
        "events":0,
        "choices":0,
        "combats":0,
        "combat_wins":0,
        "combat_losses":0,
        "boss_reached":false,
        "boss_win":false,
        "purchases":0,
        "travel_actions":0,
        "deadlocks":0,
    }
    var steps := 0
    while bool(GameState.run.get("active", false)) and steps < max_steps:
        steps += 1
        var mode := str(GameState.run.get("mode", "story"))
        match mode:
            "story":
                _simulate_story_step(policy_id, stats)
            "merchant":
                _simulate_merchant_step(policy_id, stats)
            "travel":
                _simulate_travel_step(policy_id, stats, false)
            "combat":
                _simulate_combat(policy_id, stats)
            "final_choice":
                _simulate_final_step(policy_id)
            "inventory":
                _use_recovery_item_if_needed(policy_id)
                RunFlowEngine.resume_story()
            "debrief":
                break
            _:
                stats.deadlocks = int(stats.deadlocks) + 1
                RunFlowEngine.resume_story()

    if bool(GameState.run.get("active", false)):
        GameState.run.active = false
        GameState.run.mode = "debrief"
        GameState.run.result = "timeout"

    var visited: Array = GameState.run.get("visited_locations", []) as Array
    var result := {
        "ok":true,
        "world_id":world_id,
        "character_id":character_id,
        "policy_id":policy_id,
        "build_id":build_id,
        "build_items":build_items,
        "seed":seed_value,
        "result":str(GameState.run.get("result", "timeout")),
        "ending_id":str(GameState.run.get("ending_id", "")),
        "steps":steps,
        "turns":int(GameState.run.get("turn", 0)),
        "events":int(stats.events),
        "choices":int(stats.choices),
        "combats":int(stats.combats),
        "combat_wins":int(stats.combat_wins),
        "combat_losses":int(stats.combat_losses),
        "boss_reached":bool(stats.boss_reached),
        "boss_win":bool(stats.boss_win),
        "purchases":int(stats.purchases),
        "travel_actions":int(stats.travel_actions),
        "deadlocks":int(stats.deadlocks),
        "locations_visited":visited.size(),
        "final_health":int(GameState.run.get("health", 0)),
        "final_vigor":int(GameState.run.get("vigor", 0)),
        "final_fragments":int((GameState.run.get("resources", {}) as Dictionary).get("fragments", 0)),
        "marks":(GameState.run.get("marks", {}) as Dictionary).size(),
        "debts":(GameState.run.get("debts", []) as Array).size(),
    }
    result["trajectory_hash"] = _trajectory_hash(result)
    return result

func _simulate_story_step(policy_id: String, stats: Dictionary) -> void:
    var turn := int(GameState.run.get("turn", 0))
    var health := int(GameState.run.get("health", 0))
    var max_health := int(GameState.run.get("max_health", 16))
    var bosses := RunFlowEngine.local_bosses()
    if not bosses.is_empty() and policy_engine.should_fight_boss(policy_id, turn, health, max_health):
        var boss: Dictionary = bosses[0] as Dictionary
        stats.boss_reached = true
        RunFlowEngine.start_combat(str(boss.get("id", "")))
        _simulate_combat(policy_id, stats)
        return
    if bosses.is_empty() and policy_engine.should_fight_boss(policy_id, turn, health, max_health):
        if _travel_to_boss_location(stats):
            return

    var event := RunFlowEngine.story_event()
    if event.is_empty():
        if not _simulate_travel_step(policy_id, stats, true):
            stats.deadlocks = int(stats.deadlocks) + 1
        return
    stats.events = int(stats.events) + 1
    var available := EventDirector.available_choices(event)
    var choice_index := policy_engine.choose_event_choice(policy_id, event, available)
    if choice_index < 0:
        stats.deadlocks = int(stats.deadlocks) + 1
        _simulate_travel_step(policy_id, stats, true)
        return
    var pool := str(event.get("pool", ""))
    if not RunFlowEngine.choose(event, choice_index):
        stats.deadlocks = int(stats.deadlocks) + 1
        return
    stats.choices = int(stats.choices) + 1
    match pool:
        "creature":
            var monsters := RunFlowEngine.local_monsters()
            if not monsters.is_empty():
                var monster_index := RNGService.range_int(0, monsters.size() - 1)
                var monster: Dictionary = monsters[monster_index] as Dictionary
                RunFlowEngine.start_combat(str(monster.get("id", "")))
                _simulate_combat(policy_id, stats)
            else:
                RunFlowEngine.resume_story()
        "trade":
            RunFlowEngine.open_merchant(8)
        "route":
            RunFlowEngine.open_travel()
        _:
            RunFlowEngine.resume_story()

func _simulate_combat(policy_id: String, stats: Dictionary) -> void:
    if CombatEngine.combat.is_empty():
        stats.deadlocks = int(stats.deadlocks) + 1
        RunFlowEngine.resume_story()
        return
    stats.combats = int(stats.combats) + 1
    var was_boss := bool(CombatEngine.combat.get("is_boss", false))
    if was_boss:
        stats.boss_reached = true
    var rounds := 0
    while bool(CombatEngine.combat.get("active", false)) and rounds < MAX_COMBAT_ROUNDS:
        rounds += 1
        var before_turn := int(CombatEngine.combat.get("turn", 0))
        var before_enemy_hp := int((CombatEngine.combat.get("enemy", {}) as Dictionary).get("hp", 0))
        var before_player_hp := int((CombatEngine.combat.get("player", {}) as Dictionary).get("hp", 0))
        var decision := policy_engine.choose_combat_decision(policy_id, CombatEngine.combat)
        _apply_combat_decision(decision)
        if bool(CombatEngine.combat.get("active", false)):
            var after_turn := int(CombatEngine.combat.get("turn", 0))
            var after_enemy_hp := int((CombatEngine.combat.get("enemy", {}) as Dictionary).get("hp", 0))
            var after_player_hp := int((CombatEngine.combat.get("player", {}) as Dictionary).get("hp", 0))
            if after_turn == before_turn and after_enemy_hp == before_enemy_hp and after_player_hp == before_player_hp:
                _combat_fallback()
    if bool(CombatEngine.combat.get("active", false)):
        stats.deadlocks = int(stats.deadlocks) + 1
        RunFlowEngine.fail("combat_timeout")
        return
    var combat_result := str(CombatEngine.combat.get("result", ""))
    if combat_result == "victory":
        stats.combat_wins = int(stats.combat_wins) + 1
        if was_boss:
            stats.boss_win = true
    else:
        stats.combat_losses = int(stats.combat_losses) + 1

func _simulate_merchant_step(policy_id: String, stats: Dictionary) -> void:
    var stock := MerchantEngine.stock(str(GameState.run.get("world_id", "")), 8)
    var buy_limit := 2 if policy_id in ["balanced", "explorer"] else 1
    for _i in range(buy_limit):
        var item_id := policy_engine.choose_purchase(policy_id, stock)
        if item_id == "" or not RunFlowEngine.buy(item_id):
            break
        stats.purchases = int(stats.purchases) + 1
        var item := ContentRegistry.get_record(item_id)
        if str(item.get("kind", "")) == "equipment":
            InventoryEngine.equip(item_id)
        stock = MerchantEngine.stock(str(GameState.run.get("world_id", "")), 8)
    _use_recovery_item_if_needed(policy_id)
    RunFlowEngine.resume_story()

func _simulate_travel_step(policy_id: String, stats: Dictionary, direct: bool) -> bool:
    var current := str(GameState.run.get("location_id", ""))
    var locations := LocationEngine.available_locations()
    var destination := policy_engine.choose_travel(policy_id, locations, current, LocationEngine.visited_locations())
    if destination == "":
        if not direct:
            RunFlowEngine.resume_story()
        return false
    var ok := RunFlowEngine.travel(destination)
    if ok:
        stats.travel_actions = int(stats.travel_actions) + 1
    if not direct and bool(GameState.run.get("active", false)):
        RunFlowEngine.resume_story()
    return ok

func _simulate_final_step(policy_id: String) -> void:
    var ending_id := policy_engine.choose_ending(policy_id, RunFlowEngine.endings_for_current_world())
    if ending_id == "" or not RunFlowEngine.finish(ending_id):
        RunFlowEngine.fail("ending_unavailable")

func _apply_combat_decision(decision: Dictionary) -> void:
    var kind := str(decision.get("kind", "action"))
    var decision_id := str(decision.get("id", "strike"))
    if kind == "ability":
        RunFlowEngine.combat_ability(decision_id)
    else:
        RunFlowEngine.combat_action(decision_id)

func _combat_fallback() -> void:
    var player: Dictionary = CombatEngine.combat.get("player", {}) as Dictionary
    var distance := int(player.get("distance", 1))
    if distance > 0:
        RunFlowEngine.combat_action("advance")
    else:
        RunFlowEngine.combat_action("strike")
    if bool(CombatEngine.combat.get("active", false)) and str(CombatEngine.combat.get("last_error", "")) != "":
        RunFlowEngine.combat_action("guard")

func _travel_to_boss_location(stats: Dictionary) -> bool:
    var world_id := str(GameState.run.get("world_id", ""))
    var current := str(GameState.run.get("location_id", ""))
    var candidates: Array[String] = []
    for boss_variant in ContentRegistry.all("bosses"):
        var boss: Dictionary = boss_variant as Dictionary
        if str(boss.get("world_id", "")) != world_id:
            continue
        var location_id := str(boss.get("location_id", ""))
        if location_id != "" and location_id != current and location_id not in candidates:
            candidates.append(location_id)
    candidates.sort()
    if candidates.is_empty():
        return false
    var ok := RunFlowEngine.travel(candidates[0])
    if ok:
        stats.travel_actions = int(stats.travel_actions) + 1
    return ok

func _use_recovery_item_if_needed(policy_id: String) -> void:
    if policy_id == "aggressive":
        return
    var health := int(GameState.run.get("health", 0))
    var max_health := maxi(1, int(GameState.run.get("max_health", 16)))
    var vigor := int(GameState.run.get("vigor", 0))
    var max_vigor := maxi(1, int(GameState.run.get("max_vigor", 8)))
    if float(health) / float(max_health) > 0.65 and float(vigor) / float(max_vigor) > 0.35:
        return
    var unique_items: Array[String] = []
    for item_variant in GameState.run.get("inventory", []) as Array:
        var item_id := str(item_variant)
        if item_id not in unique_items:
            unique_items.append(item_id)
    unique_items.sort()
    for item_id in unique_items:
        var item := ContentRegistry.get_record(item_id)
        if str(item.get("kind", "")) not in ["consumable", "tool"]:
            continue
        var effect: Dictionary = item.get("effect", {}) as Dictionary
        var op := str(effect.get("op", ""))
        if (op == "heal" and health < max_health) or (op == "vigor" and vigor < max_vigor):
            if InventoryEngine.use_item(item_id):
                return

func _prepare_isolated_profile(world_id: String, character_id: String) -> void:
    var profile := ProfileMigrationEngine.new().fresh_profile()
    var unlocks: Dictionary = profile.get("unlocks", {}) as Dictionary
    var characters: Array = unlocks.get("characters", []) as Array
    if character_id not in characters:
        characters.append(character_id)
    characters.sort()
    var routes: Array = unlocks.get("routes", []) as Array
    if world_id not in routes:
        routes.append(world_id)
    routes.sort()
    unlocks.characters = characters
    unlocks.routes = routes
    profile.unlocks = unlocks
    profile.unlocked_characters = characters.duplicate()
    profile.hub = {
        "stage":1,
        "visit_count":0,
        "routes":routes.duplicate(),
        "residents":[],
        "facilities":{},
        "history":[],
    }
    profile["_simulation_ephemeral"] = true

    var commercial := CommercialPolicyEngine.new()
    var grants: Dictionary = {}
    for product_variant in commercial.products():
        var product: Dictionary = product_variant as Dictionary
        var product_id := str(product.get("id", ""))
        if product_id == "":
            continue
        grants[product_id] = {
            "owned":product_id == commercial.full_unlock_product_id(),
            "verified_at":1,
            "source":"simulation",
            "transaction_id":"simulation-only" if product_id == commercial.full_unlock_product_id() else "",
            "revoked_at":0,
        }
    profile.entitlements = {
        "schema_version":EntitlementEngine.SCHEMA_VERSION,
        "provider":"simulation",
        "grants":grants,
        "last_restore_at":1,
        "last_store_contact_at":1,
        "last_store_error":"",
        "offline_cache_valid":true,
    }
    GameState.profile = profile
    GameState.run = {}

func _apply_build(world_id: String, build_id: String) -> Array[String]:
    if build_id == "baseline":
        return []
    var best_by_slot: Dictionary = {}
    var best_score_by_slot: Dictionary = {}
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("world_id", "")) != world_id or str(item.get("kind", "")) != "equipment":
            continue
        var slot := InventoryEngine.slot_for(item)
        if slot == "":
            continue
        var score := _build_item_score(build_id, item)
        var item_id := str(item.get("id", ""))
        if not best_score_by_slot.has(slot) or score > float(best_score_by_slot[slot]) or (is_equal_approx(score, float(best_score_by_slot[slot])) and item_id < str(best_by_slot[slot])):
            best_score_by_slot[slot] = score
            best_by_slot[slot] = item_id
    var selected: Array[String] = []
    var slots: Array = best_by_slot.keys()
    slots.sort()
    for slot_variant in slots:
        var item_id := str(best_by_slot[slot_variant])
        if item_id == "":
            continue
        InventoryEngine.add_item(item_id)
        InventoryEngine.equip(item_id)
        selected.append(item_id)
    return selected

func _build_item_score(build_id: String, item: Dictionary) -> float:
    var bonuses := AffixEngine.combined_effects(item)
    var score := 0.0
    match build_id:
        "offense":
            score += float(bonuses.get("damage", 0)) * 8.0
            score += float(bonuses.get("posture", 0)) * 5.0
            score += float(bonuses.get("range", 0)) * 2.5
            score += float(bonuses.get("resource_gain", 0)) * 2.0
            score += float(bonuses.get("status_power", 0)) * 1.5
        "defense":
            score += float(bonuses.get("guard", 0)) * 8.0
            score += float(bonuses.get("heal", 0)) * 6.0
            score += float(bonuses.get("status_resist", 0)) * 4.0
            score += float(bonuses.get("vigor", 0)) * 2.0
            score -= maxf(0.0, float(bonuses.get("load", 0)))
        "utility":
            score += float(bonuses.get("resource_gain", 0)) * 6.0
            score += float(bonuses.get("status_power", 0)) * 5.0
            score += float(bonuses.get("mark_synergy", 0)) * 5.0
            score += float(bonuses.get("debt_pressure", 0)) * 4.0
            score += float(bonuses.get("range", 0)) * 2.0
            score -= float(bonuses.get("load", 0))
    score += float(_rarity_rank(str(item.get("rarity", "common")))) * 0.01
    return score

func _rarity_rank(rarity: String) -> int:
    return ["common", "uncommon", "rare", "singular", "relic", "echo"].find(rarity)

func _trajectory_hash(result: Dictionary) -> String:
    return ("%s|%s|%s|%s|%d|%s|%d|%d|%d|%d|%d|%d|%s" % [
        str(result.get("world_id", "")),
        str(result.get("character_id", "")),
        str(result.get("policy_id", "")),
        str(result.get("build_id", "")),
        int(result.get("seed", 0)),
        str(result.get("result", "")),
        int(result.get("turns", 0)),
        int(result.get("events", 0)),
        int(result.get("combats", 0)),
        int(result.get("purchases", 0)),
        int(result.get("locations_visited", 0)),
        int(result.get("final_health", 0)),
        str(result.get("ending_id", "")),
    ]).sha256_text()

func _invalid_result(character_id: String, policy_id: String, build_id: String, seed_value: int, error: String) -> Dictionary:
    return {
        "ok":false,
        "error":error,
        "world_id":"",
        "character_id":character_id,
        "policy_id":policy_id,
        "build_id":build_id,
        "seed":seed_value,
        "result":"invalid",
        "trajectory_hash":"",
    }

func _string_array(raw) -> Array[String]:
    var result: Array[String] = []
    if typeof(raw) != TYPE_ARRAY:
        return result
    for value_variant in raw as Array:
        var value := str(value_variant)
        if value != "" and value not in result:
            result.append(value)
    return result
