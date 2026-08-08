extends Node

var failures: Array[String] = []
var commercial := CommercialPolicyEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    _policy_gate()
    _product_gate()
    _trial_scope_gate()
    _no_pay_to_win_gate()
    _separation_gate()
    _finish()

func _policy_gate() -> void:
    var validation := commercial.validate_policy()
    expect(bool(validation.get("ok", false)), "9.7 commercial policy invalid: %s" % str(validation.get("errors", [])))
    var policy := commercial.policy()
    expect(str(policy.get("model_id", "")) == "free_trial_one_time_unlock", "9.7 commercial model id mismatch")
    var principles: Dictionary = policy.get("principles", {}) as Dictionary
    for key in ["no_ads","no_subscriptions","no_paid_consumables","no_loot_boxes","no_real_money_meta_currency","no_pay_to_win"]:
        expect(bool(principles.get(key, false)), "9.7 required commercial principle disabled: %s" % key)

func _product_gate() -> void:
    var products := commercial.products()
    expect(products.size() == 2, "9.7 paid catalog must contain exactly two products")
    var full_unlock := commercial.product(commercial.full_unlock_product_id())
    var supporter := commercial.product(commercial.supporter_product_id())
    expect(not full_unlock.is_empty(), "9.7 full-game unlock missing")
    expect(not supporter.is_empty(), "9.7 supporter cosmetic pack missing")
    if not full_unlock.is_empty():
        expect(str(full_unlock.get("store_type", "")) == "one_time_non_consumable", "9.7 full unlock is not one-time/non-consumable")
        expect(str(full_unlock.get("effect_kind", "")) == "content_license", "9.7 full unlock grants something other than content access")
        expect(str(full_unlock.get("content_scope", "")) == "all_game_content", "9.7 full unlock content scope mismatch")
    if not supporter.is_empty():
        expect(str(supporter.get("store_type", "")) == "one_time_non_consumable", "9.7 supporter pack is not one-time/non-consumable")
        expect(str(supporter.get("effect_kind", "")) == "cosmetic_only", "9.7 supporter pack is not cosmetic-only")
        expect(str(supporter.get("content_scope", "")) == "cosmetics_only", "9.7 supporter content scope mismatch")

func _trial_scope_gate() -> void:
    var free_worlds := commercial.free_trial_worlds()
    expect(free_worlds == ["world.mata_fio_verde"], "9.7 free-trial scope must be exactly the first Domain")
    expect(not commercial.world_requires_full_unlock("world.mata_fio_verde"), "9.7 first Domain incorrectly requires purchase")
    expect(commercial.world_requires_full_unlock("world.varzea_espelhos"), "9.7 paid Domain incorrectly exposed by free trial")

func _no_pay_to_win_gate() -> void:
    for product_variant in commercial.products():
        var product: Dictionary = product_variant as Dictionary
        expect(not bool(product.get("consumable", true)), "9.7 paid consumable found")
        expect(not bool(product.get("repeatable", true)), "9.7 repeatable paid purchase found")
        for key in ["grants_power","grants_currency","grants_stats","grants_drop_rate"]:
            expect(not bool(product.get(key, true)), "9.7 paid product grants gameplay advantage: %s/%s" % [product.get("id", ""), key])
        expect(str(product.get("billing_channel", "")) == "platform_billing", "9.7 digital product bypasses platform billing policy")

    for forbidden in ["vigil_threads","health","vigor","damage","loot_chance","revives","consumables","random_rewards","difficulty_reduction"]:
        expect(commercial.is_real_money_product_forbidden(forbidden), "9.7 missing real-money prohibition for %s" % forbidden)

func _separation_gate() -> void:
    expect(commercial.product("vigil_threads").is_empty(), "9.7 Fios de Vigilia exposed as paid product")
    for product_id in MetaEconomyEngine.PRODUCTS.keys():
        expect(commercial.product(str(product_id)).is_empty(), "9.7 internal earned economy product leaked into paid catalog: %s" % product_id)

    GameState.reset_profile()
    MetaUnlockEngine.ensure_state()
    expect(RunFlowEngine.start_journey("character.mata_fio_verde.01", 97001), "9.7 could not start power-neutrality journey")
    expect(int(GameState.run.get("max_health", 0)) == 16, "9.7 commercial policy altered max health")
    expect(int(GameState.run.get("max_vigor", 0)) == 8, "9.7 commercial policy altered max vigor")

func _finish() -> void:
    if failures.is_empty():
        print("COMMERCIAL_POLICY_CERTIFICATION PASS: 9.7")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("COMMERCIAL_POLICY_CERTIFICATION: %s" % failure)
        print("COMMERCIAL_POLICY_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
