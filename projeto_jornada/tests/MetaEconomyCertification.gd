extends Node

var failures: Array[String] = []
var economy := MetaEconomyEngine.new()
var codex := CodexProgressEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    GameState.reset_profile()
    GameState.run = {}
    MetaUnlockEngine.ensure_state()
    codex.ensure_state()
    economy.ensure_state()

    _catalog_policy_gate()
    _idempotent_reward_gate()
    _horizontal_purchase_gate()
    _convenience_gate()
    _save_load_gate()
    _power_neutrality_gate()
    _scene_gate()
    _finish()

func _catalog_policy_gate() -> void:
    var catalog := economy.catalog()
    expect(catalog.size() == MetaEconomyEngine.PRODUCTS.size(), "9.6 catalog size mismatch")
    for product_variant in catalog:
        var product: Dictionary = product_variant as Dictionary
        expect(not bool(product.get("real_money", true)), "9.6 internal meta product marked as real-money purchasable: %s" % product.get("id", ""))
        expect(not bool(product.get("power_effect", true)), "9.6 meta product has power effect: %s" % product.get("id", ""))
        expect(str(product.get("kind", "")) in ["capacity", "cosmetic"], "9.6 unsupported vertical product kind")

func _idempotent_reward_gate() -> void:
    codex.ensure_state()
    var first := economy.sync_rewards()
    var first_award := int(first.get("awarded", 0))
    expect(first_award > 0, "9.6 initial earned milestone produced no Fios")
    var after_first := economy.balance()
    var second := economy.sync_rewards()
    expect(int(second.get("awarded", -1)) == 0, "9.6 repeating same milestones awarded Fios again")
    expect(economy.balance() == after_first, "9.6 idempotent reward sync changed balance")

    var endings := _ids("finals", 1)
    expect(not endings.is_empty(), "9.6 canonical ending missing")
    if not endings.is_empty():
        GameState.profile.endings = [endings[0]]
        codex.evaluate_achievements()
        var ending_reward := economy.sync_rewards()
        expect(int(ending_reward.get("awarded", 0)) >= 12, "9.6 first unique ending did not award expected one-time Fios")
        var after_ending := economy.balance()
        expect(int(economy.sync_rewards().get("awarded", -1)) == 0, "9.6 same ending paid twice")
        expect(economy.balance() == after_ending, "9.6 repeated ending sync changed balance")

func _horizontal_purchase_gate() -> void:
    _earn_more_if_needed(40)
    var health_before := 16
    var vigor_before := 8
    expect(economy.purchase("ornament_ink"), "9.6 could not purchase cosmetic ornament")
    expect(economy.select_ornament("ink"), "9.6 purchased cosmetic could not be selected")
    expect(str(economy.summary().get("selected_ornament", "")) == "ink", "9.6 selected ornament state mismatch")

    expect(economy.purchase("setup_slot_2"), "9.6 could not purchase second journey preset slot")
    expect(economy.capacity("journey_presets") == 2, "9.6 journey preset capacity did not increase")
    expect(economy.purchase("seed_slot_2"), "9.6 could not purchase second seed slot")
    expect(economy.capacity("seed_notebook") == 2, "9.6 seed notebook capacity did not increase")
    expect(economy.purchase("codex_pins_10"), "9.6 could not purchase Codex pin capacity")
    expect(economy.capacity("codex_pins") == 10, "9.6 Codex pin capacity did not increase")
    expect(not economy.purchase("setup_slot_2"), "9.6 one-time product could be purchased twice")

    MetaUnlockEngine.evaluate_progression()
    expect(RunFlowEngine.start_journey("character.mata_fio_verde.01", 96001), "9.6 could not start neutrality journey")
    expect(int(GameState.run.get("max_health", 0)) == health_before, "9.6 meta purchases changed max health")
    expect(int(GameState.run.get("max_vigor", 0)) == vigor_before, "9.6 meta purchases changed max vigor")

func _convenience_gate() -> void:
    var setup_engine := JourneySetupEngine.new()
    var setup := setup_engine.default_setup()
    setup.seed = 123456
    expect(economy.save_journey_preset(0, setup), "9.6 could not save first journey preset")
    setup.seed = 654321
    expect(economy.save_journey_preset(1, setup), "9.6 purchased second journey preset slot is not functional")
    expect(not economy.save_journey_preset(2, setup), "9.6 journey preset exceeded purchased capacity")
    expect(int(economy.load_journey_preset(1).get("seed", 0)) == 654321, "9.6 saved journey preset did not round-trip")

    expect(economy.remember_seed(111111, "Primeira"), "9.6 could not remember first seed")
    expect(economy.remember_seed(222222, "Segunda"), "9.6 purchased second seed slot is not functional")
    expect(not economy.remember_seed(333333, "Terceira"), "9.6 seed notebook exceeded purchased capacity")

    var item_ids := _ids("items", 10)
    expect(item_ids.size() == 10, "9.6 needs ten canonical Codex entries for pin gate")
    for item_id in item_ids:
        expect(economy.pin_codex(item_id), "9.6 purchased Codex pin capacity rejected valid pin")
    var extra_items := _ids("items", 11)
    if extra_items.size() >= 11:
        expect(not economy.pin_codex(extra_items[10]), "9.6 Codex pins exceeded purchased capacity")

func _save_load_gate() -> void:
    var before := economy.summary().duplicate(true)
    var state_before: Dictionary = (GameState.profile.get("meta_economy", {}) as Dictionary).duplicate(true)
    var preset_before := economy.load_journey_preset(1).duplicate(true)
    expect(SaveService.save_game(), "9.6 save failed")
    GameState.profile.meta_economy = {}
    GameState.profile.saved_journey_presets = {}
    GameState.profile.saved_seeds = []
    GameState.profile.codex_pins = []
    expect(SaveService.load_game(), "9.6 reload failed")
    var after := economy.summary()
    expect(int(after.balance) == int(before.balance), "9.6 balance changed after save/load")
    expect(int(after.lifetime_earned) == int(before.lifetime_earned), "9.6 lifetime earnings changed after save/load")
    expect(int(after.lifetime_spent) == int(before.lifetime_spent), "9.6 lifetime spending changed after save/load")
    expect(int(after.journey_presets) == int(before.journey_presets), "9.6 capacity changed after save/load")
    expect(str(after.selected_ornament) == str(before.selected_ornament), "9.6 cosmetic selection changed after save/load")
    expect(economy.load_journey_preset(1) == preset_before, "9.6 saved preset changed after save/load")
    expect((GameState.profile.get("meta_economy", {}) as Dictionary).get("claimed_rewards", []).size() == state_before.get("claimed_rewards", []).size(), "9.6 reward claim ledger changed after save/load")
    expect(int(economy.sync_rewards().get("awarded", -1)) == 0, "9.6 save/load allowed already claimed rewards to pay again")

func _power_neutrality_gate() -> void:
    for key in ["health_bonus","vigor_bonus","damage_bonus","loot_bonus","rake","win_rate"]:
        expect(not (GameState.profile.get("meta_economy", {}) as Dictionary).has(key), "9.6 forbidden vertical economy field present: %s" % key)

func _scene_gate() -> void:
    expect(ResourceLoader.exists("res://scenes/VigilThreads.tscn"), "9.6 Fios de Vigilia scene missing")
    var packed := ResourceLoader.load("res://scenes/VigilThreads.tscn") as PackedScene
    expect(packed != null, "9.6 Fios scene could not load")
    if packed != null:
        var instance := packed.instantiate()
        expect(instance != null, "9.6 Fios scene could not instantiate")
        if instance != null:
            instance.queue_free()

func _earn_more_if_needed(target_balance: int) -> void:
    if economy.balance() >= target_balance:
        return
    var endings := _ids("finals", 6)
    GameState.profile.endings = endings.duplicate()
    for world_variant in ContentRegistry.all("worlds"):
        var world: Dictionary = world_variant as Dictionary
        MetaUnlockEngine.unlock_route(str(world.get("id", "")))
        if economy.balance() >= target_balance:
            break
    var items := _ids("items", 100)
    for item_id in items:
        codex.discover(item_id, "economy_test")
    codex.evaluate_achievements()
    economy.sync_rewards()

func _ids(group: String, limit: int) -> Array[String]:
    var result: Array[String] = []
    for record_variant in ContentRegistry.all(group):
        var record: Dictionary = record_variant as Dictionary
        var content_id := str(record.get("id", ""))
        if content_id != "":
            result.append(content_id)
        if result.size() >= limit:
            break
    return result

func _finish() -> void:
    if failures.is_empty():
        print("META_ECONOMY_CERTIFICATION PASS: 9.6")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("META_ECONOMY_CERTIFICATION: %s" % failure)
        print("META_ECONOMY_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
