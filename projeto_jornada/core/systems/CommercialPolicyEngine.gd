extends RefCounted
class_name CommercialPolicyEngine

const POLICY_PATH := "res://product/commercial_model.json"
const REQUIRED_PRODUCTS := ["full_game_unlock", "supporter_cosmetic_pack"]
const FORBIDDEN_EFFECT_KEYS := ["grants_power", "grants_currency", "grants_stats", "grants_drop_rate"]

var _policy: Dictionary = {}

func policy() -> Dictionary:
    if _policy.is_empty():
        _policy = _load_policy()
    return _policy.duplicate(true)

func validate_policy() -> Dictionary:
    var p := policy()
    var errors: Array[String] = []
    if p.is_empty():
        errors.append("policy_missing")
        return {"ok":false,"errors":errors}

    var principles: Dictionary = p.get("principles", {}) as Dictionary
    for required_true in [
        "no_ads","no_subscriptions","no_paid_consumables","no_loot_boxes",
        "no_paid_random_rewards","no_real_money_meta_currency","no_pay_to_win",
        "no_paid_combat_stats","no_paid_drop_rate","no_paid_difficulty_relief"
    ]:
        if not bool(principles.get(required_true, false)):
            errors.append("principle_required:%s" % required_true)

    var free_trial: Dictionary = p.get("free_trial", {}) as Dictionary
    if int(free_trial.get("price", -1)) != 0:
        errors.append("free_trial_not_free")
    var free_worlds: Array = free_trial.get("worlds", []) as Array
    if free_worlds != ["world.mata_fio_verde"]:
        errors.append("free_trial_scope_mismatch")

    var seen := {}
    var products_raw = p.get("products", [])
    if typeof(products_raw) != TYPE_ARRAY:
        errors.append("products_invalid")
        return {"ok":false,"errors":errors}
    for product_variant in products_raw as Array:
        if typeof(product_variant) != TYPE_DICTIONARY:
            errors.append("product_invalid")
            continue
        var product: Dictionary = product_variant as Dictionary
        var product_id := str(product.get("id", ""))
        if product_id == "" or seen.has(product_id):
            errors.append("product_id_invalid:%s" % product_id)
            continue
        seen[product_id] = true
        if str(product.get("store_type", "")) != "one_time_non_consumable":
            errors.append("product_not_non_consumable:%s" % product_id)
        if str(product.get("billing_channel", "")) != "platform_billing":
            errors.append("billing_channel_invalid:%s" % product_id)
        if bool(product.get("consumable", true)) or bool(product.get("repeatable", true)):
            errors.append("repeatable_or_consumable:%s" % product_id)
        for key in FORBIDDEN_EFFECT_KEYS:
            if bool(product.get(key, true)):
                errors.append("paid_power_effect:%s:%s" % [product_id, key])
        var effect_kind := str(product.get("effect_kind", ""))
        if product_id == "full_game_unlock" and effect_kind != "content_license":
            errors.append("full_unlock_not_content_license")
        if product_id == "supporter_cosmetic_pack" and effect_kind != "cosmetic_only":
            errors.append("supporter_pack_not_cosmetic")

    for required_product in REQUIRED_PRODUCTS:
        if not seen.has(required_product):
            errors.append("required_product_missing:%s" % required_product)
    if seen.size() != REQUIRED_PRODUCTS.size():
        errors.append("unexpected_paid_product_count")

    var forbidden: Array = p.get("forbidden_real_money_products", []) as Array
    for required_forbidden in ["vigil_threads","health","vigor","damage","loot_chance","revives","consumables","random_rewards","difficulty_reduction"]:
        if required_forbidden not in forbidden:
            errors.append("forbidden_product_guard_missing:%s" % required_forbidden)

    return {"ok":errors.is_empty(),"errors":errors}

func products() -> Array:
    var p := policy()
    var raw = p.get("products", [])
    if typeof(raw) != TYPE_ARRAY:
        return []
    return (raw as Array).duplicate(true)

func product(product_id: String) -> Dictionary:
    for product_variant in products():
        var item: Dictionary = product_variant as Dictionary
        if str(item.get("id", "")) == product_id:
            return item.duplicate(true)
    return {}

func free_trial_worlds() -> Array[String]:
    var p := policy()
    var free_trial: Dictionary = p.get("free_trial", {}) as Dictionary
    var result: Array[String] = []
    for world_variant in (free_trial.get("worlds", []) as Array):
        var world_id := str(world_variant)
        if world_id != "" and ContentRegistry.get_record(world_id).size() > 0:
            result.append(world_id)
    return result

func world_requires_full_unlock(world_id: String) -> bool:
    return world_id not in free_trial_worlds()

func is_real_money_product_forbidden(subject: String) -> bool:
    var forbidden: Array = policy().get("forbidden_real_money_products", []) as Array
    return subject in forbidden

func full_unlock_product_id() -> String:
    return "full_game_unlock"

func supporter_product_id() -> String:
    return "supporter_cosmetic_pack"

func _load_policy() -> Dictionary:
    var file := FileAccess.open(POLICY_PATH, FileAccess.READ)
    if file == null:
        push_error("CommercialPolicyEngine: missing commercial policy")
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("CommercialPolicyEngine: invalid commercial policy JSON")
        return {}
    return parsed as Dictionary
