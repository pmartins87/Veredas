extends Node

var failures: Array[String] = []
var setup_engine := JourneySetupEngine.new()
var economy := MetaEconomyEngine.new()
var migration := ProfileMigrationEngine.new()
var entitlements := EntitlementEngine.new()

const WORLD_A := "world.mata_fio_verde"
const SEED_A := 910001
const SEED_B := 910002
const SEED_C := 910003

var world_b := ""
var character_b := ""
var ending_a := ""
var ending_b := ""
var ending_c := ""
var mark_a := "mark.mata_fio_verde.01"
var mark_b := ""
var base_health := 0
var base_vigor := 0

func _ready() -> void:
    await get_tree().process_frame
    _resolve_fixtures()
    _fresh_loop_gate()
    _journey_a_gate()
    _paid_route_boundary_gate()
    _journey_b_gate()
    _journey_c_gate()
    _final_integrity_gate()
    _finish()

func _resolve_fixtures() -> void:
    var worlds := ContentRegistry.all("worlds")
    expect(worlds.size() >= 2, "9.10 requires at least two Domains")
    for world_variant in worlds:
        var world: Dictionary = world_variant as Dictionary
        var world_id := str(world.get("id", ""))
        if world_id != "" and world_id != WORLD_A:
            world_b = world_id
            break
    expect(world_b != "", "9.10 second Domain could not be resolved")

    var endings_a := _endings_for_world(WORLD_A)
    var endings_b := _endings_for_world(world_b)
    expect(endings_a.size() >= 2, "9.10 first Domain needs at least two endings")
    expect(not endings_b.is_empty(), "9.10 second Domain needs an ending")
    if endings_a.size() >= 2:
        ending_a = endings_a[0]
        ending_c = endings_a[1]
    if not endings_b.is_empty():
        ending_b = endings_b[0]

    expect(not ContentRegistry.get_record(mark_a).is_empty(), "9.10 canonical first-Domain mark missing")
    mark_b = _mark_for_world(world_b)
    if mark_b == "":
        mark_b = mark_a

func _fresh_loop_gate() -> void:
    GameState.reset_profile()
    GameState.run = {}
    var report := migration.normalize_live_profile()
    expect(bool(report.get("ok", false)), "9.10 fresh profile integrity failed")
    expect(not entitlements.has_full_game(), "9.10 fresh profile unexpectedly owns full game")
    expect(entitlements.can_access_world(WORLD_A), "9.10 demo Domain is inaccessible")
    expect(not entitlements.can_access_world(world_b), "9.10 paid Domain accessible on fresh profile")
    expect(int(MetaUnlockEngine.summary().get("characters", 0)) == 1, "9.10 fresh profile character count mismatch")
    expect(int(MetaUnlockEngine.summary().get("routes", 0)) == 1, "9.10 fresh profile route count mismatch")

func _journey_a_gate() -> void:
    var setup := setup_engine.default_setup()
    setup.world_id = WORLD_A
    setup.character_id = ProfileMigrationEngine.DEFAULT_CHARACTER
    setup.journey_mode = "journey"
    setup.difficulty_id = "andarilho"
    setup.seed = SEED_A
    setup.modifiers = []
    expect(bool(setup_engine.validate(setup).get("ok", false)), "9.10 journey A setup rejected")
    expect(setup_engine.start(setup), "9.10 journey A did not start")
    expect(int(GameState.run.get("seed", 0)) == SEED_A, "9.10 journey A seed mismatch")
    base_health = int(GameState.run.get("max_health", 0))
    base_vigor = int(GameState.run.get("max_vigor", 0))
    expect(base_health == 16 and base_vigor == 8, "9.10 journey A baseline power mismatch")

    GameState.add_mark(mark_a, 2)
    expect(int((GameState.run.get("marks", {}) as Dictionary).get(mark_a, 0)) == 2, "9.10 journey A mark missing")
    expect(RunFlowEngine.finish(ending_a), "9.10 journey A could not finish")
    expect(str(RunFlowEngine.debrief().get("ending_id", "")) == ending_a, "9.10 journey A debrief mismatch")
    expect(EchoConsequenceEngine.has_echo(mark_a, 2), "9.10 journey A mark did not persist as Echo")
    expect(EchoConsequenceEngine.ending_witnessed(ending_a), "9.10 journey A ending not persisted")
    expect(MetaUnlockEngine.is_mode_unlocked("fixed_seed"), "9.10 first ending did not unlock fixed-seed mode")

    HubEngine.enter()
    var first_reward := economy.sync_rewards()
    expect(int(first_reward.get("awarded", 0)) > 0, "9.10 journey A produced no new meta reward")
    var first_balance := economy.balance()
    var repeated := economy.sync_rewards()
    expect(int(repeated.get("awarded", -1)) == 0, "9.10 journey A reward duplicated")
    expect(economy.balance() == first_balance, "9.10 journey A repeated reward changed balance")
    _save_load_fingerprint("journey A")

func _paid_route_boundary_gate() -> void:
    expect(HubEngine.unlock_route(world_b), "9.10 second route could not be unlocked")
    var chars := MetaUnlockEngine.unlocked_characters(world_b)
    expect(not chars.is_empty(), "9.10 second route did not unlock its first character")
    if not chars.is_empty():
        character_b = str((chars[0] as Dictionary).get("id", ""))
    expect(character_b != "", "9.10 second route character id missing")

    var setup_b := _setup_for(world_b, character_b, SEED_B, ["sem_trocas"])
    var blocked := setup_engine.validate(setup_b)
    expect(not bool(blocked.get("ok", true)), "9.10 paid Domain setup accepted without entitlement")
    expect("entitlement_required" in (blocked.get("errors", []) as Array), "9.10 paid Domain setup missing entitlement error")
    expect(not setup_engine.start(setup_b), "9.10 paid Domain journey started without entitlement")
    expect(not RunFlowEngine.travel_world(world_b), "9.10 cross-Domain travel bypassed entitlement")

    entitlements.apply_authoritative_snapshot([
        {"product_id":"full_game_unlock","owned":true,"transaction_id":"loop-full-910"}
    ], "9.10_mock_store")
    expect(entitlements.has_full_game(), "9.10 full-game entitlement was not restored")
    expect(entitlements.can_access_world(world_b), "9.10 restored entitlement did not open second Domain")
    expect(bool(setup_engine.validate(setup_b).get("ok", false)), "9.10 paid Domain setup remained blocked after entitlement")
    _save_load_fingerprint("entitlement restore")

func _journey_b_gate() -> void:
    var setup_b := _setup_for(world_b, character_b, SEED_B, ["sem_trocas"])
    expect(setup_engine.start(setup_b), "9.10 journey B did not start")
    expect(int(GameState.run.get("seed", 0)) == SEED_B, "9.10 journey B seed mismatch")
    expect(str(GameState.run.get("world_id", "")) == world_b, "9.10 journey B world mismatch")
    expect(int(GameState.run.get("max_health", 0)) == base_health, "9.10 journey B entitlement/unlock changed max health")
    expect(int(GameState.run.get("max_vigor", 0)) == base_vigor, "9.10 journey B entitlement/unlock changed max vigor")
    expect(bool((GameState.run.get("flags", {}) as Dictionary).get("modifier.no_trade", false)), "9.10 journey B no-trade modifier missing")

    var echo_context := GameState.run.get("echo_context", {}) as Dictionary
    expect((echo_context.get("echo_marks", {}) as Dictionary).has(mark_a), "9.10 journey B did not inherit journey A Echo")
    expect((echo_context.get("consequences", {}) as Dictionary).has(ending_a), "9.10 journey B did not inherit journey A consequence")

    GameState.add_mark(mark_b, 3)
    expect(not RunFlowEngine.finish(ending_a), "9.10 journey B accepted an ending from the wrong Domain")
    expect(bool(GameState.run.get("active", false)), "9.10 rejected foreign ending mutated active journey")
    expect(RunFlowEngine.finish(ending_b), "9.10 journey B could not finish its own ending")
    expect(EchoConsequenceEngine.ending_witnessed(ending_b), "9.10 journey B ending not persisted")
    expect(EchoConsequenceEngine.has_echo(mark_b, 3), "9.10 journey B mark did not persist")

    HubEngine.enter()
    var reward := economy.sync_rewards()
    expect(int(reward.get("awarded", 0)) > 0, "9.10 journey B produced no new meta reward")
    var balance_after := economy.balance()
    expect(int(economy.sync_rewards().get("awarded", -1)) == 0, "9.10 journey B reward duplicated")
    expect(economy.balance() == balance_after, "9.10 journey B duplicate reward changed balance")
    expect(setup_engine.modifier_available("mochila_leve"), "9.10 two endings did not unlock light-pack modifier")
    expect(HubEngine.stage() >= 2, "9.10 hub did not progress after two journeys")
    _save_load_fingerprint("journey B")

func _journey_c_gate() -> void:
    var chars_a := MetaUnlockEngine.unlocked_characters(WORLD_A)
    expect(chars_a.size() >= 2, "9.10 first ending did not unlock a second first-Domain character")
    if chars_a.size() < 2:
        return
    var character_c := str((chars_a[1] as Dictionary).get("id", ""))
    var setup_c := _setup_for(WORLD_A, character_c, SEED_C, ["mochila_leve"])
    setup_c.difficulty_id = "ruptura"
    expect(bool(setup_engine.validate(setup_c).get("ok", false)), "9.10 journey C setup rejected")
    expect(setup_engine.start(setup_c), "9.10 journey C did not start")
    expect(int(GameState.run.get("seed", 0)) == SEED_C, "9.10 journey C seed mismatch")
    expect(str(GameState.run.get("character_id", "")) == character_c, "9.10 journey C character mismatch")
    expect(int(GameState.run.get("max_health", 0)) == base_health, "9.10 journey C difficulty/meta changed max health")
    expect(int(GameState.run.get("max_vigor", 0)) == base_vigor, "9.10 journey C difficulty/meta changed max vigor")
    expect(int((GameState.run.get("resources", {}) as Dictionary).get("provisions", 99)) <= 1, "9.10 journey C light-pack modifier did not apply")

    var echo_context := GameState.run.get("echo_context", {}) as Dictionary
    var consequences := echo_context.get("consequences", {}) as Dictionary
    expect(consequences.has(ending_a) and consequences.has(ending_b), "9.10 journey C did not receive both prior consequences")
    expect(RunFlowEngine.finish(ending_c), "9.10 journey C could not finish")
    HubEngine.enter()

    var reward := economy.sync_rewards()
    expect(int(reward.get("awarded", 0)) > 0, "9.10 journey C produced no new meta reward")
    var balance_after := economy.balance()
    expect(int(economy.sync_rewards().get("awarded", -1)) == 0, "9.10 journey C reward duplicated")
    expect(economy.balance() == balance_after, "9.10 journey C duplicate reward changed balance")
    expect((GameState.profile.get("endings", []) as Array).size() >= 3, "9.10 three completed journeys did not persist three endings")
    expect(MetaUnlockEngine.is_mode_unlocked("echo_run"), "9.10 three endings did not unlock Echo Run")
    _save_load_fingerprint("journey C")

func _final_integrity_gate() -> void:
    var report := migration.normalize_live_profile()
    expect(bool(report.get("ok", false)), "9.10 final profile integrity failed: %s" % str(report.get("errors", [])))
    expect(entitlements.has_full_game(), "9.10 entitlement was lost across journey loop")
    expect(MetaUnlockEngine.is_route_unlocked(world_b), "9.10 second route was lost across journey loop")
    expect(MetaUnlockEngine.is_discovered(ending_a), "9.10 first ending missing from Codex")
    expect(MetaUnlockEngine.is_discovered(ending_b), "9.10 second ending missing from Codex")
    expect(MetaUnlockEngine.is_discovered(ending_c), "9.10 third ending missing from Codex")
    expect(EchoConsequenceEngine.summary().get("consequences", 0) >= 3, "9.10 persistent consequence count mismatch")
    expect(HubEngine.stage() >= 2, "9.10 final hub stage regressed")
    expect(economy.balance() >= 0, "9.10 meta economy ended negative")
    var entitlement_state := GameState.profile.get("entitlements", {}) as Dictionary
    for forbidden in ["damage_bonus","health_bonus","vigor_bonus","currency_grant","drop_rate_bonus"]:
        expect(not entitlement_state.has(forbidden), "9.10 forbidden power field present in entitlement: %s" % forbidden)
    expect(int(GameState.profile.get("profile_schema_version", 0)) == ProfileMigrationEngine.CURRENT_SCHEMA_VERSION, "9.10 profile schema regressed")

func _setup_for(world_id: String, character_id: String, seed_value: int, modifiers: Array) -> Dictionary:
    return setup_engine.normalize_setup({
        "world_id":world_id,
        "character_id":character_id,
        "journey_mode":"fixed_seed",
        "difficulty_id":"andarilho",
        "seed":seed_value,
        "modifiers":modifiers,
    })

func _save_load_fingerprint(label: String) -> void:
    var before := migration.normalize_live_profile()
    expect(bool(before.get("ok", false)), "9.10 %s integrity failed before save" % label)
    var fingerprint := migration.progress_fingerprint().duplicate(true)
    expect(SaveService.save_game(), "9.10 %s save failed" % label)
    GameState.profile = {}
    GameState.run = {}
    expect(SaveService.load_game(), "9.10 %s reload failed" % label)
    var after := migration.audit_live_profile()
    expect(bool(after.get("ok", false)), "9.10 %s integrity failed after reload" % label)
    expect(migration.progress_fingerprint() == fingerprint, "9.10 %s profile fingerprint changed after save/load" % label)

func _endings_for_world(world_id: String) -> Array[String]:
    var result: Array[String] = []
    for ending_variant in ContentRegistry.all("finals"):
        var ending: Dictionary = ending_variant as Dictionary
        if str(ending.get("world_id", "")) == world_id:
            var ending_id := str(ending.get("id", ""))
            if ending_id != "":
                result.append(ending_id)
    result.sort()
    return result

func _mark_for_world(world_id: String) -> String:
    for mark_variant in ContentRegistry.all("marks"):
        var mark: Dictionary = mark_variant as Dictionary
        if str(mark.get("world_id", "")) == world_id:
            return str(mark.get("id", ""))
    return ""

func _finish() -> void:
    if failures.is_empty():
        print("MULTI_JOURNEY_LOOP_CERTIFICATION PASS: 9.10")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("MULTI_JOURNEY_LOOP_CERTIFICATION: %s" % failure)
        print("MULTI_JOURNEY_LOOP_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
