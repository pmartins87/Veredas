extends Node

const DEFAULT_CHARACTER := "character.mata_fio_verde.01"
const ROOTED_CHARACTER := "character.mata_fio_verde.02"
const BASIC_GUARD_CAP := 6

var failures: Array[String] = []
var scenarios_passed := 0

func _ready() -> void:
    await get_tree().process_frame
    _guard_stack_and_stall_playtest()
    _invalid_action_playtest()
    _movement_lock_playtest()
    _narrative_debt_playtest()
    _travel_attrition_playtest()
    _merchant_arbitrage_playtest()
    _event_choice_and_cooldown_playtest()
    _manual_determinism_playtest()
    _normal_run_has_no_free_synthetic_build_playtest()
    _finish()

func _new_run(character_id: String = DEFAULT_CHARACTER, seed_value: int = 109001, difficulty_id: String = "andarilho") -> void:
    GameState.reset_profile()
    GameState.new_run(character_id, seed_value)
    DifficultyEngine.apply_to_run(difficulty_id)
    EventDirector.clear_candidate_cache()

func _first_monster_id() -> String:
    var world_id := str(GameState.run.get("world_id", ""))
    var location_id := str(GameState.run.get("location_id", ""))
    var world_fallback := ""
    for monster_variant in ContentRegistry.all("monsters"):
        var monster: Dictionary = monster_variant as Dictionary
        if str(monster.get("world_id", "")) != world_id:
            continue
        if world_fallback == "":
            world_fallback = str(monster.get("id", ""))
        if str(monster.get("location_id", "")) == location_id:
            return str(monster.get("id", ""))
    return world_fallback

func _guard_stack_and_stall_playtest() -> void:
    _new_run(DEFAULT_CHARACTER, 109101, "ruptura")
    var best_by_slot := {}
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("kind", "")) != "equipment":
            continue
        var slot := InventoryEngine.slot_for(item)
        if slot == "":
            continue
        var bonuses := AffixEngine.combined_effects(item)
        var guard_bonus := int(bonuses.get("guard", 0))
        if guard_bonus <= 0:
            continue
        if not best_by_slot.has(slot) or guard_bonus > int((best_by_slot[slot] as Dictionary).get("guard", 0)):
            best_by_slot[slot] = {"id":str(item.get("id", "")), "guard":guard_bonus}
    for slot in best_by_slot.keys():
        var item_id := str((best_by_slot[slot] as Dictionary).get("id", ""))
        expect(InventoryEngine.add_item(item_id), "guard-stack: failed to add %s" % item_id)
        expect(InventoryEngine.equip(item_id), "guard-stack: failed to equip %s" % item_id)
    var raw_guard := int(GameState.run.get("base_guard", 0)) + int(InventoryEngine.equipment_bonuses().get("guard", 0))
    expect(raw_guard > BASIC_GUARD_CAP, "guard-stack fixture is not adversarial enough: raw=%d" % raw_guard)
    var enemy_id := _first_monster_id()
    expect(enemy_id != "", "guard-stack: no enemy found")
    var state := CombatEngine.start(enemy_id, DEFAULT_CHARACTER)
    expect(not state.is_empty(), "guard-stack: combat failed to start")
    if state.is_empty():
        return
    expect(int(state.player.get("guard", -1)) == BASIC_GUARD_CAP, "guard-stack bypassed cap: raw=%d start=%d" % [raw_guard, int(state.player.get("guard", -1))])
    var enemy_hp_start := int(state.enemy.get("hp", 0))
    var rounds := 0
    while bool(CombatEngine.combat.get("active", false)) and rounds < 8:
        CombatEngine.player_action("guard")
        expect(int(CombatEngine.combat.player.get("guard", 0)) <= BASIC_GUARD_CAP, "guard spam exceeded cap on round %d" % rounds)
        rounds += 1
    expect(str(CombatEngine.combat.get("result", "")) != "victory", "guard-only play produced a victory")
    expect(int(CombatEngine.combat.enemy.get("hp", enemy_hp_start)) == enemy_hp_start, "guard-only play damaged the enemy")
    _scenario_pass("guard stacking + guard-only stall", "raw_guard=%d capped=%d rounds=%d result=%s" % [raw_guard,BASIC_GUARD_CAP,rounds,str(CombatEngine.combat.get("result","active"))])

func _invalid_action_playtest() -> void:
    _new_run(DEFAULT_CHARACTER, 109202, "andarilho")
    var enemy_id := _first_monster_id()
    var state := CombatEngine.start(enemy_id, DEFAULT_CHARACTER)
    expect(not state.is_empty(), "invalid-action: combat failed to start")
    if state.is_empty():
        return
    # An unarmed character starts at distance 1 while unarmed range is 0.
    var before_turn := int(state.get("turn", 0))
    var before_hp := int(state.player.get("hp", 0))
    var before_enemy_hp := int(state.enemy.get("hp", 0))
    var before_resource := (state.get("signature_resource", {}) as Dictionary).duplicate(true)
    var rejected := CombatEngine.player_action("strike")
    expect(str(rejected.get("last_error", "")) == "action_unavailable", "invalid strike was not rejected")
    expect(int(rejected.get("turn", -1)) == before_turn, "invalid strike consumed a turn")
    expect(int(rejected.player.get("hp", -1)) == before_hp, "invalid strike let enemy damage player")
    expect(int(rejected.enemy.get("hp", -1)) == before_enemy_hp, "invalid strike changed enemy HP")
    expect((rejected.get("signature_resource", {}) as Dictionary) == before_resource, "invalid strike generated signature resource")
    var advanced := CombatEngine.player_action("advance")
    expect(not advanced.has("last_error"), "valid recovery action remained rejected")
    expect(int(advanced.get("turn", before_turn)) > before_turn or not bool(advanced.get("active", true)), "valid action did not progress combat")
    _scenario_pass("invalid action is non-exploitable", "turn=%d hp=%d enemy_hp=%d" % [before_turn,before_hp,before_enemy_hp])

func _movement_lock_playtest() -> void:
    _new_run(ROOTED_CHARACTER, 109303, "contemplativa")
    var enemy_id := _first_monster_id()
    var state := CombatEngine.start(enemy_id, ROOTED_CHARACTER)
    expect(not state.is_empty(), "movement-lock: combat failed to start")
    if state.is_empty():
        return
    CombatEngine.combat.player.hp = 99
    CombatEngine.combat.player.max_hp = 99
    CombatEngine.combat.player.distance = 2
    CombatEngine.combat.player = StatusEngine.apply_status(CombatEngine.combat.player, "rooted", 1, 2)
    var policy := PlayerPolicyEngine.new()
    var first := policy.choose_combat_decision("balanced", CombatEngine.combat)
    expect(str(first.get("kind", "")) == "action" and str(first.get("id", "")) == "guard", "movement-lock policy retried impossible movement: %s" % str(first))
    for _i in range(2):
        if bool(CombatEngine.combat.get("active", false)):
            CombatEngine.player_action("guard")
    expect(not StatusEngine.movement_locked(CombatEngine.combat.player), "movement lock failed to expire under legal defensive turns")
    if bool(CombatEngine.combat.get("active", false)):
        CombatEngine.combat.player.distance = 2
        var after := policy.choose_combat_decision("balanced", CombatEngine.combat)
        expect(not (str(after.get("kind", "")) == "action" and str(after.get("id", "")) == "guard"), "policy stayed in defensive lock after rooted expired: %s" % str(after))
    _scenario_pass("movement lock recovery", "rooted expired without retry deadlock")

func _narrative_debt_playtest() -> void:
    _new_run(DEFAULT_CHARACTER, 109404, "andarilho")
    var debts := ContentRegistry.all("debts")
    expect(not debts.is_empty(), "debt playtest has no debt records")
    if debts.is_empty():
        return
    var debt: Dictionary = debts[0] as Dictionary
    var debt_id := str(debt.get("id", ""))
    var callback := {}
    var unrelated := {}
    var transit := {}
    for event_variant in ContentRegistry.all("events"):
        var event: Dictionary = event_variant as Dictionary
        var pool := str(event.get("pool", ""))
        if pool == "callback" and str(event.get("debt_id", "")) == debt_id:
            callback = event
        elif pool == "callback" and str(event.get("debt_id", "")) != "" and str(event.get("debt_id", "")) != debt_id and unrelated.is_empty():
            unrelated = event
        elif pool == "transit_callback" and transit.is_empty():
            transit = event
    expect(not callback.is_empty(), "debt playtest missing exact callback")
    expect(not unrelated.is_empty(), "debt playtest missing unrelated callback")
    expect(not transit.is_empty(), "debt playtest missing transit callback")
    expect(NarrativeDebtEngine.create(debt_id), "failed to create debt")
    expect(NarrativeDebtEngine.create(debt_id), "duplicate debt create should be idempotent")
    expect(NarrativeDebtEngine.active_count() == 1, "duplicate debt create duplicated active obligation")
    var active := NarrativeDebtEngine.active_debt(debt_id)
    NarrativeDebtEngine.age_all(int(active.get("hard_deadline", 10)))
    var exact_multiplier := NarrativeDebtEngine.event_multiplier(callback)
    var unrelated_multiplier := NarrativeDebtEngine.event_multiplier(unrelated)
    var transit_multiplier := NarrativeDebtEngine.event_multiplier(transit)
    expect(exact_multiplier > 25.0, "overdue exact callback did not receive urgency: %.2f" % exact_multiplier)
    expect(is_equal_approx(unrelated_multiplier, 1.0), "unrelated callback inherited debt pressure: %.2f" % unrelated_multiplier)
    expect(transit_multiplier > 1.0, "transit callback ignored active debt pressure")
    expect(NarrativeDebtEngine.resolve(debt_id), "exact debt failed to resolve")
    expect(not NarrativeDebtEngine.is_active(debt_id), "resolved debt remained active")
    _scenario_pass("debt pressure + callback isolation", "exact=%.2f unrelated=%.2f transit=%.2f" % [exact_multiplier,unrelated_multiplier,transit_multiplier])

func _travel_attrition_playtest() -> void:
    _new_run(DEFAULT_CHARACTER, 109505, "andarilho")
    var locations := LocationEngine.available_locations()
    expect(locations.size() >= 2, "travel playtest requires at least two locations")
    if locations.size() < 2:
        return
    var first := str(GameState.run.get("location_id", ""))
    var second := ""
    for loc_variant in locations:
        var loc_id := str(loc_variant)
        if loc_id != first:
            second = loc_id
            break
    expect(second != "", "travel playtest could not find alternate location")
    GameState.run.resources.provisions = 1
    GameState.run.vigor = 2
    GameState.run.health = 4
    expect(LocationEngine.travel_to(first), "same-location travel failed")
    expect(int(GameState.run.resources.provisions) == 1 and int(GameState.run.vigor) == 2 and int(GameState.run.health) == 4, "same-location travel consumed attrition")
    expect(LocationEngine.travel_to(second), "travel to alternate location failed")
    expect(int(GameState.run.resources.provisions) == 0, "first travel did not consume provision")
    expect(LocationEngine.travel_to(first), "return travel failed")
    expect(int(GameState.run.vigor) == 1, "supply-free travel did not consume vigor first")
    expect(LocationEngine.travel_to(second), "second supply-free travel failed")
    expect(int(GameState.run.vigor) == 0, "vigor did not reach zero as expected")
    expect(LocationEngine.travel_to(first), "health-attrition travel failed")
    expect(int(GameState.run.health) == 3, "travel without supply/vigor did not consume health")
    for i in range(12):
        var target := second if i % 2 == 0 else first
        expect(LocationEngine.travel_to(target), "repeated adversarial travel failed at %d" % i)
    expect(int(GameState.run.resources.provisions) >= 0, "provisions became negative")
    expect(int(GameState.run.vigor) >= 0, "vigor became negative")
    expect(int(GameState.run.health) == 1, "travel attrition should be nonlethal and floor at 1 HP, got %d" % int(GameState.run.health))
    _scenario_pass("travel attrition exhaustion", "provisions=%d vigor=%d health=%d" % [int(GameState.run.resources.provisions),int(GameState.run.vigor),int(GameState.run.health)])

func _merchant_arbitrage_playtest() -> void:
    _new_run(DEFAULT_CHARACTER, 109606, "andarilho")
    var cheapest := {}
    var cheapest_price := 1000000
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        var item_id := str(item.get("id", ""))
        var cost := ItemEconomyEngine.buy_price(item_id)
        if cost > 0 and cost < cheapest_price:
            cheapest = item
            cheapest_price = cost
    expect(not cheapest.is_empty(), "merchant playtest found no priced item")
    if cheapest.is_empty():
        return
    var item_id := str(cheapest.get("id", ""))
    var sell_value := ItemEconomyEngine.sell_price(item_id)
    expect(sell_value > 0 and sell_value < cheapest_price, "merchant spread is non-punitive: buy=%d sell=%d" % [cheapest_price,sell_value])
    GameState.run.resources.fragments = cheapest_price
    expect(MerchantEngine.buy(item_id), "merchant failed affordable purchase")
    expect(int(GameState.run.resources.fragments) == 0, "purchase did not debit exact cost")
    expect(InventoryEngine.has_item(item_id), "purchased item missing from inventory")
    expect(MerchantEngine.sell(item_id), "merchant failed resale")
    var after_sale := int(GameState.run.resources.fragments)
    expect(after_sale == sell_value, "resale credited unexpected amount: %d vs %d" % [after_sale,sell_value])
    expect(not InventoryEngine.has_item(item_id), "sold item remained in inventory")
    var before_failed_buy := int(GameState.run.resources.fragments)
    expect(not MerchantEngine.buy(item_id), "buy/sell round-trip created enough money to rebuy item")
    expect(int(GameState.run.resources.fragments) == before_failed_buy, "failed purchase changed fragments")
    _scenario_pass("merchant anti-arbitrage", "buy=%d sell=%d retained=%d" % [cheapest_price,sell_value,after_sale])

func _event_choice_and_cooldown_playtest() -> void:
    _new_run(DEFAULT_CHARACTER, 109707, "andarilho")
    var event := RunFlowEngine.story_event()
    expect(not event.is_empty(), "event playtest selected no story event")
    if event.is_empty():
        return
    var event_id := str(event.get("id", ""))
    expect(int((GameState.run.get("event_counts", {}) as Dictionary).get(event_id, 0)) == 1, "selected event was not remembered")
    var available := EventDirector.available_choices(event)
    expect(not available.is_empty(), "selected event has no legal choices")
    var turn_before := int(GameState.run.get("turn", 0))
    expect(not RunFlowEngine.choose(event, -1), "negative choice index was accepted")
    expect(int(GameState.run.get("turn", 0)) == turn_before, "invalid choice advanced narrative turn")
    if not available.is_empty():
        var choice_index := int((available[0] as Dictionary).get("index", -1))
        expect(RunFlowEngine.choose(event, choice_index), "legal event choice was rejected")
        expect(int(GameState.run.get("turn", 0)) == turn_before + 1, "legal event choice did not advance one turn")

    var cooldown_event := {}
    for event_variant in ContentRegistry.all("events"):
        var candidate: Dictionary = event_variant as Dictionary
        if int(candidate.get("cooldown_turns", 0)) > 0:
            cooldown_event = candidate
            break
    expect(not cooldown_event.is_empty(), "event catalog has no cooldown fixture")
    if not cooldown_event.is_empty():
        var cooldown_id := str(cooldown_event.get("id", ""))
        var last_turns: Dictionary = GameState.run.get("event_last_turn", {}) as Dictionary
        last_turns[cooldown_id] = int(GameState.run.get("turn", 0))
        GameState.run.event_last_turn = last_turns
        expect(not bool(EventDirector.call("_cooldown_ready", cooldown_event)), "event cooldown allowed immediate replay")
        GameState.run.turn = int(GameState.run.get("turn", 0)) + int(cooldown_event.get("cooldown_turns", 0))
        expect(bool(EventDirector.call("_cooldown_ready", cooldown_event)), "event cooldown did not expire on schedule")
    _scenario_pass("event choice + cooldown abuse", "event=%s turn=%d" % [event_id,int(GameState.run.get("turn",0))])

func _manual_determinism_playtest() -> void:
    var first := _manual_combat_transcript(109808)
    var second := _manual_combat_transcript(109808)
    expect(first == second, "same-seed manual transcript diverged\nA=%s\nB=%s" % [first,second])
    expect(first != "", "manual transcript was empty")
    _scenario_pass("manual transcript determinism", first)

func _manual_combat_transcript(seed_value: int) -> String:
    _new_run(DEFAULT_CHARACTER, seed_value, "andarilho")
    var enemy_id := _first_monster_id()
    var state := CombatEngine.start(enemy_id, DEFAULT_CHARACTER)
    if state.is_empty():
        return ""
    var actions := ["advance", "guard", "strike", "precise", "strike", "guard", "strike"]
    var parts: Array[String] = []
    parts.append(_combat_stamp("start"))
    for action_variant in actions:
        if not bool(CombatEngine.combat.get("active", false)):
            break
        var action := str(action_variant)
        CombatEngine.player_action(action)
        parts.append(_combat_stamp(action))
    return "|".join(parts)

func _combat_stamp(label: String) -> String:
    var state := CombatEngine.combat
    var player: Dictionary = state.get("player", {}) as Dictionary
    var enemy: Dictionary = state.get("enemy", {}) as Dictionary
    var intent: Dictionary = state.get("intent", {}) as Dictionary
    return "%s:t%d:p%d:e%d:g%d:d%d:i%s:r%s" % [label,int(state.get("turn",0)),int(player.get("hp",0)),int(enemy.get("hp",0)),int(player.get("guard",0)),int(player.get("distance",0)),str(intent.get("id","")),str(state.get("result",""))]

func _normal_run_has_no_free_synthetic_build_playtest() -> void:
    _new_run(DEFAULT_CHARACTER, 109909, "andarilho")
    expect((GameState.run.get("inventory", []) as Array).is_empty(), "normal run starts with free inventory")
    expect((GameState.run.get("equipped", {}) as Dictionary).is_empty(), "normal run starts with free synthetic equipment")
    expect(not GameState.run.has("build_id"), "normal run leaked simulator build_id")
    var stock := RunFlowEngine.open_merchant(8)
    expect(stock.size() <= 8, "merchant returned more items than requested")
    expect((GameState.run.get("inventory", []) as Array).is_empty(), "opening merchant injected free items")
    _scenario_pass("synthetic build isolation", "inventory=0 equipped=0 merchant_stock=%d" % stock.size())

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: ADVERSARIAL_PLAYTEST_CERTIFICATION: %s" % message)

func _scenario_pass(name: String, detail: String) -> void:
    scenarios_passed += 1
    print("10.9 PLAYTEST PASS [%s] %s" % [name,detail])

func _finish() -> void:
    DifficultyEngine.clear_simulation_override()
    if failures.is_empty():
        print("ADVERSARIAL_PLAYTEST_CERTIFICATION PASS: 10.9 scenarios=%d" % scenarios_passed)
        get_tree().quit(0)
    else:
        print("ADVERSARIAL_PLAYTEST_CERTIFICATION FAIL: %d scenarios_failed; passed=%d" % [failures.size(),scenarios_passed])
        get_tree().quit(1)
