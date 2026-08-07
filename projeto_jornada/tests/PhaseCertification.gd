extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _phase1_architecture()
    _phase2_full_journey()
    _phase3_content_runtime()
    _phase4_deep_combat()
    if failures.is_empty():
        print("PHASE_CERTIFICATION PASS: 1.10 2.10 3.10 4.10")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("PHASE_CERTIFICATION: %s" % failure)
        print("PHASE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _phase1_architecture() -> void:
    expect(RuntimeContentValidator.validate().is_empty(), "1.10 runtime content validation failed")
    RNGService.start(99117)
    var a := [RNGService.range_int(0,9999), RNGService.range_int(0,9999), RNGService.range_int(0,9999)]
    RNGService.start(99117)
    var b := [RNGService.range_int(0,9999), RNGService.range_int(0,9999), RNGService.range_int(0,9999)]
    expect(a == b, "1.10 deterministic RNG failed")
    RunFlowEngine.start_journey("character.mata_fio_verde.01", 10101)
    var marker := "phase1_roundtrip"
    GameState.run.flags[marker] = true
    expect(SaveService.save_game(), "1.10 save failed")
    GameState.run.flags.erase(marker)
    expect(SaveService.load_game(), "1.10 load failed")
    expect(bool(GameState.run.get("flags",{}).get(marker,false)), "1.10 save roundtrip lost state")

func _phase2_full_journey() -> void:
    expect(RunFlowEngine.start_journey("character.mata_fio_verde.01", 20202), "2.10 could not start journey")
    var event := RunFlowEngine.story_event()
    expect(not event.is_empty(), "2.10 story event missing")
    if not event.is_empty():
        expect(RunFlowEngine.choose(event, 0), "2.10 could not resolve story choice")
    var debt_id := "debt.mata_fio_verde.01"
    expect(NarrativeDebtEngine.create(debt_id), "2.10 debt creation failed")
    NarrativeDebtEngine.age_all(20)
    expect(NarrativeDebtEngine.overdue_count() >= 1, "2.10 debt did not age to overdue")
    var callback := ContentRegistry.get_record("event.mata_fio_verde.transit_consequence")
    expect(not callback.is_empty(), "2.10 transit callback missing")
    if not callback.is_empty():
        expect(RunFlowEngine.choose(callback, 0), "2.10 callback choice failed")
        expect(NarrativeDebtEngine.overdue_count() == 0, "2.10 callback did not resolve overdue debt")

    var resources: Dictionary = GameState.run.get("resources", {})
    resources.fragments = 500
    GameState.run.resources = resources
    var weapon := _first_weapon("world.mata_fio_verde")
    expect(not weapon.is_empty(), "2.10 no weapon found for merchant test")
    if not weapon.is_empty():
        var weapon_id := str(weapon.get("id",""))
        expect(MerchantEngine.buy(weapon_id), "2.10 merchant purchase failed")
        expect(InventoryEngine.equip(weapon_id), "2.10 equipment failed")
        expect(str(GameState.run.get("equipped",{}).get("weapon","")) == weapon_id, "2.10 weapon slot mismatch")

    var locations := LocationEngine.available_locations()
    expect(locations.size() == 10, "2.10 expected ten local travel destinations")
    if locations.size() > 1:
        expect(RunFlowEngine.travel(str(locations[1])), "2.10 travel failed")
    var monsters := RunFlowEngine.local_monsters()
    expect(not monsters.is_empty(), "2.10 local monster missing")
    if not monsters.is_empty():
        var fight := RunFlowEngine.start_combat(str(monsters[0].get("id","")))
        fight.player.guard = 50
        CombatEngine.combat = fight
        _fight_to_end(false)
        expect(str(CombatEngine.combat.get("result","")) == "victory", "2.10 representative monster fight not won")

    var boss := _first_boss("world.mata_fio_verde")
    expect(not boss.is_empty(), "2.10 boss missing")
    if not boss.is_empty():
        expect(LocationEngine.travel_to(str(boss.get("location_id",""))), "2.10 could not travel to boss")
        GameState.run.health = GameState.run.max_health
        GameState.run.vigor = GameState.run.max_vigor
        var boss_fight := RunFlowEngine.start_combat(str(boss.get("id","")))
        boss_fight.player.guard = 120
        CombatEngine.combat = boss_fight
        _fight_to_end(true)
        expect(str(CombatEngine.combat.get("result","")) == "victory", "2.10 representative boss fight not won")
        expect(str(GameState.run.get("mode","")) == "final_choice", "2.10 boss victory did not open final choice")

    var endings := RunFlowEngine.endings_for_current_world()
    expect(endings.size() == 3, "2.10 expected three local endings")
    if not endings.is_empty():
        var ending_id := str(endings[0].get("id",""))
        expect(RunFlowEngine.finish(ending_id), "2.10 ending could not finish journey")
        var report := RunFlowEngine.debrief()
        expect(str(report.get("result","")) == "victory", "2.10 debrief result mismatch")
        expect(str(report.get("ending_id","")) == ending_id, "2.10 debrief ending mismatch")
        expect(ending_id in GameState.profile.get("endings",[]), "2.10 ending did not persist in profile")

func _phase3_content_runtime() -> void:
    RunFlowEngine.start_journey("character.mata_fio_verde.01", 30303)
    var ids: Array[String] = []
    for _i in range(10):
        var event := EventDirector.choose_event(str(GameState.run.world_id), str(GameState.run.location_id))
        if event.is_empty():
            break
        ids.append(str(event.get("id","")))
    var unique := {}
    for event_id in ids:
        unique[event_id] = true
    expect(ids.size() >= 8, "3.10 insufficient procedural selections")
    expect(unique.size() == ids.size(), "3.10 immediate procedural repetition detected")
    GameState.add_mark("mark.mata_fio_verde.01", 1)
    expect(ConditionEngine.evaluate({"op":"mark_has","mark_id":"mark.mata_fio_verde.01"}), "3.10 condition engine failed")
    expect(EffectEngine.apply({"op":"resource_add","resource":"essence","value":2}), "3.10 effect engine failed")
    expect(int(GameState.run.resources.essence) == 2, "3.10 effect did not alter state")

func _phase4_deep_combat() -> void:
    RunFlowEngine.start_journey("character.mata_fio_verde.01", 40404)
    var target := {"hp":10,"max_hp":10,"posture":8,"max_posture":8,"states":[]}
    target = StatusEngine.apply_status(target,"wet",1,3)
    target = StatusEngine.apply_status(target,"shock",1,2)
    expect(int(target.hp) == 8 and int(target.posture) == 5, "4.10 wet+shock reaction failed")

    var rare_item := _first_item_of_rarity("world.mata_fio_verde","rare")
    expect(not rare_item.is_empty(), "4.10 rare item missing")
    if not rare_item.is_empty():
        expect(not AffixEngine.affixes_for(rare_item).is_empty(), "4.10 rare item received no affix")

    var character := ContentRegistry.get_record("character.mata_fio_verde.01")
    var ability_id := str(character.get("abilities",[])[0])
    var state := CombatEngine.start("monster.mata_fio_verde.01", "character.mata_fio_verde.01")
    var ability := ContentRegistry.get_record(ability_id)
    var resource_key := str(ability.get("resource",""))
    state.signature_resource[resource_key] = 9
    CombatEngine.combat = state
    var before_resource := int(state.signature_resource[resource_key])
    var after := CombatEngine.use_character_ability(ability_id)
    expect(int(after.signature_resource.get(resource_key,0)) < before_resource, "4.10 signature ability did not spend its own resource")

    var boss := _first_boss("world.mata_fio_verde")
    if not boss.is_empty():
        expect(BossPhaseEngine.phase_index(boss,15,30) == 1, "4.10 boss phase two threshold failed")
        expect(BossPhaseEngine.phase_index(boss,5,30) == 2, "4.10 boss phase three threshold failed")

func _fight_to_end(boss: bool) -> void:
    var safety := 0
    while bool(CombatEngine.combat.get("active",false)) and safety < (30 if boss else 15):
        safety += 1
        var player: Dictionary = CombatEngine.combat.player
        var limits := InventoryEngine.weapon_range()
        var distance := int(player.get("distance",1))
        if not InventoryEngine.equipped_item("weapon").is_empty() and distance < limits.x:
            RunFlowEngine.combat_action("retreat")
        elif not InventoryEngine.equipped_item("weapon").is_empty() and distance > limits.y:
            RunFlowEngine.combat_action("advance")
        elif int(player.get("vigor",0)) >= 2:
            RunFlowEngine.combat_action("precise")
        else:
            RunFlowEngine.combat_action("strike")
    expect(safety < (30 if boss else 15), "combat certification exceeded safety limit")

func _first_weapon(world_id: String) -> Dictionary:
    for item in ContentRegistry.all("items"):
        if str(item.get("world_id","")) == world_id and InventoryEngine.slot_for(item) == "weapon":
            return item
    return {}

func _first_boss(world_id: String) -> Dictionary:
    for boss in ContentRegistry.all("bosses"):
        if str(boss.get("world_id","")) == world_id:
            return boss
    return {}

func _first_item_of_rarity(world_id: String, rarity: String) -> Dictionary:
    for item in ContentRegistry.all("items"):
        if str(item.get("world_id","")) == world_id and str(item.get("rarity","")) == rarity:
            return item
    return {}
