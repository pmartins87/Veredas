extends RefCounted
class_name MetaEconomyEngine

const CURRENCY_ID := "vigil_threads"
const CURRENCY_NAME := "Fios de Vigília"

const PRODUCTS := {
    "setup_slot_2": {"name":"Segundo Marcador de Jornada","description":"Guarda uma segunda preparação de jornada.","cost":10,"kind":"capacity","target":"journey_presets","value":2},
    "setup_slot_3": {"name":"Terceiro Marcador de Jornada","description":"Guarda uma terceira preparação de jornada.","cost":18,"kind":"capacity","target":"journey_presets","value":3,"requires":"setup_slot_2"},
    "seed_slot_2": {"name":"Segunda Página de Seeds","description":"Amplia o caderno para duas seeds lembradas.","cost":8,"kind":"capacity","target":"seed_notebook","value":2},
    "seed_slot_3": {"name":"Terceira Página de Seeds","description":"Amplia o caderno para três seeds lembradas.","cost":14,"kind":"capacity","target":"seed_notebook","value":3,"requires":"seed_slot_2"},
    "codex_pins_10": {"name":"Fita de Arquivista","description":"Amplia as marcações favoritas do Códice para dez.","cost":6,"kind":"capacity","target":"codex_pins","value":10},
    "codex_pins_20": {"name":"Caixa de Fitas","description":"Amplia as marcações favoritas do Códice para vinte.","cost":12,"kind":"capacity","target":"codex_pins","value":20,"requires":"codex_pins_10"},
    "ornament_ink": {"name":"Moldura de Nanquim","description":"Ornamento puramente visual para o Nó de Vigília.","cost":4,"kind":"cosmetic","value":"ink"},
    "ornament_echo": {"name":"Selo de Eco","description":"Ornamento puramente visual para o Nó de Vigília.","cost":7,"kind":"cosmetic","value":"echo"},
}

const CODEX_REWARDS := {
    25:5,
    50:7,
    100:10,
    250:16,
    500:25,
    1000:40,
}

func ensure_state() -> Dictionary:
    var raw = GameState.profile.get("meta_economy", {})
    var source: Dictionary = raw as Dictionary if typeof(raw) == TYPE_DICTIONARY else {}
    var state := _normalize_state(source)
    _store_state(state)
    _normalize_convenience_state(state)
    return state.duplicate(true)

func sync_rewards() -> Dictionary:
    CodexProgressEngine.new().evaluate_achievements()
    var state := ensure_state()
    var claims: Array = _string_array(state.get("claimed_rewards", []))
    var new_keys: Array[String] = []
    var balance_value := int(state.get("balance", 0))
    var lifetime_earned := int(state.get("lifetime_earned", 0))

    for candidate_variant in _reward_candidates():
        var candidate: Dictionary = candidate_variant as Dictionary
        var key := str(candidate.get("key", ""))
        var amount := int(candidate.get("amount", 0))
        if key == "" or amount <= 0 or key in claims:
            continue
        claims.append(key)
        new_keys.append(key)
        balance_value += amount
        lifetime_earned += amount

    claims.sort()
    state.claimed_rewards = claims
    state.balance = balance_value
    state.lifetime_earned = lifetime_earned
    _store_state(state)
    return {"awarded":lifetime_earned - int(ensure_state().get("lifetime_earned", lifetime_earned)) + 0,"new_rewards":new_keys,"balance":balance_value} if false else {"awarded":_reward_amount_for_keys(new_keys),"new_rewards":new_keys,"balance":balance_value}

func balance() -> int:
    var state := ensure_state()
    return int(state.get("balance", 0))

func product_state(product_id: String) -> Dictionary:
    var state := ensure_state()
    return _product_state_from_state(product_id, state)

func catalog() -> Array:
    var state := ensure_state()
    var result: Array = []
    for product_id in PRODUCTS:
        result.append(_product_state_from_state(str(product_id), state))
    result.sort_custom(func(a,b): return int((a as Dictionary).get("cost",0)) < int((b as Dictionary).get("cost",0)))
    return result

func purchase(product_id: String) -> bool:
    var state := ensure_state()
    var spec := _product_state_from_state(product_id, state)
    if spec.is_empty() or bool(spec.get("owned", false)) or not bool(spec.get("requirement_met", false)):
        return false
    var cost := int(spec.get("cost", 0))
    if int(state.get("balance", 0)) < cost:
        return false

    var purchases: Array = _string_array(state.get("purchases", []))
    purchases.append(product_id)
    purchases = _string_array(purchases)
    state.purchases = purchases
    state.balance = int(state.get("balance", 0)) - cost
    state.lifetime_spent = int(state.get("lifetime_spent", 0)) + cost

    match str(spec.get("kind", "")):
        "capacity":
            var capacities: Dictionary = (state.get("capacities", {}) as Dictionary).duplicate(true)
            var target := str(spec.get("target", ""))
            capacities[target] = maxi(int(capacities.get(target, 0)), int(spec.get("value", 0)))
            state.capacities = capacities
        "cosmetic":
            var cosmetics: Array = _string_array(state.get("cosmetics", ["plain"]))
            var cosmetic_id := str(spec.get("value", ""))
            if cosmetic_id != "":
                cosmetics.append(cosmetic_id)
                cosmetics = _string_array(cosmetics)
            state.cosmetics = cosmetics
        _:
            return false

    _store_state(state)
    _normalize_convenience_state(state)
    SaveService.save_game()
    return true

func capacity(kind: String) -> int:
    var state := ensure_state()
    var capacities: Dictionary = state.get("capacities", {}) as Dictionary
    return int(capacities.get(kind, 0))

func save_journey_preset(slot: int, setup: Dictionary) -> bool:
    var state := ensure_state()
    var capacities: Dictionary = state.get("capacities", {}) as Dictionary
    var limit := int(capacities.get("journey_presets", 1))
    if slot < 0 or slot >= limit:
        return false
    var normalized := JourneySetupEngine.new().normalize_setup(setup)
    var presets := _normalize_presets(GameState.profile.get("saved_journey_presets", {}), limit)
    presets[str(slot)] = normalized.duplicate(true)
    GameState.profile.saved_journey_presets = presets.duplicate(true)
    return true

func load_journey_preset(slot: int) -> Dictionary:
    var state := ensure_state()
    var capacities: Dictionary = state.get("capacities", {}) as Dictionary
    var presets := _normalize_presets(GameState.profile.get("saved_journey_presets", {}), int(capacities.get("journey_presets", 1)))
    GameState.profile.saved_journey_presets = presets.duplicate(true)
    var raw = presets.get(str(slot), {})
    if typeof(raw) != TYPE_DICTIONARY:
        return {}
    return JourneySetupEngine.new().normalize_setup(raw as Dictionary)

func remember_seed(seed_value: int, label: String = "") -> bool:
    if seed_value <= 0:
        return false
    var state := ensure_state()
    var capacities: Dictionary = state.get("capacities", {}) as Dictionary
    var limit := int(capacities.get("seed_notebook", 1))
    var seeds := _normalize_seeds(GameState.profile.get("saved_seeds", []), limit)

    for i in range(seeds.size()):
        var entry: Dictionary = seeds[i] as Dictionary
        if int(entry.get("seed", 0)) == seed_value:
            seeds[i] = {"seed":seed_value,"label":label}
            GameState.profile.saved_seeds = seeds.duplicate(true)
            return true

    if seeds.size() >= limit:
        GameState.profile.saved_seeds = seeds.duplicate(true)
        return false
    seeds.append({"seed":seed_value,"label":label})
    GameState.profile.saved_seeds = seeds.duplicate(true)
    return true

func pin_codex(content_id: String) -> bool:
    if ContentRegistry.get_record(content_id).is_empty():
        return false
    var state := ensure_state()
    var capacities: Dictionary = state.get("capacities", {}) as Dictionary
    var limit := int(capacities.get("codex_pins", 5))
    var pins := _normalize_pins(GameState.profile.get("codex_pins", []), limit)
    if content_id in pins:
        GameState.profile.codex_pins = pins.duplicate()
        return true
    if pins.size() >= limit:
        GameState.profile.codex_pins = pins.duplicate()
        return false
    pins.append(content_id)
    GameState.profile.codex_pins = pins.duplicate()
    return true

func select_ornament(ornament_id: String) -> bool:
    var state := ensure_state()
    var cosmetics: Array = _string_array(state.get("cosmetics", ["plain"]))
    if ornament_id not in cosmetics:
        return false
    state.selected_ornament = ornament_id
    _store_state(state)
    return true

func summary() -> Dictionary:
    var state := ensure_state()
    var capacities: Dictionary = state.get("capacities", {}) as Dictionary
    return {
        "currency":CURRENCY_NAME,
        "balance":int(state.get("balance", 0)),
        "lifetime_earned":int(state.get("lifetime_earned", 0)),
        "lifetime_spent":int(state.get("lifetime_spent", 0)),
        "purchases":(state.get("purchases", []) as Array).size(),
        "journey_presets":int(capacities.get("journey_presets", 1)),
        "seed_notebook":int(capacities.get("seed_notebook", 1)),
        "codex_pins":int(capacities.get("codex_pins", 5)),
        "selected_ornament":str(state.get("selected_ornament", "plain")),
    }

func _normalize_state(source: Dictionary) -> Dictionary:
    var capacities_raw = source.get("capacities", {})
    var capacities_source: Dictionary = capacities_raw as Dictionary if typeof(capacities_raw) == TYPE_DICTIONARY else {}
    var capacities := {
        "journey_presets":maxi(1, int(capacities_source.get("journey_presets", 1))),
        "seed_notebook":maxi(1, int(capacities_source.get("seed_notebook", 1))),
        "codex_pins":maxi(5, int(capacities_source.get("codex_pins", 5))),
    }
    var claims: Array = _string_array(source.get("claimed_rewards", []))
    var purchases: Array = _string_array(source.get("purchases", []))
    var cosmetics: Array = _string_array(source.get("cosmetics", ["plain"]))
    if "plain" not in cosmetics:
        cosmetics.append("plain")
        cosmetics = _string_array(cosmetics)
    var selected := str(source.get("selected_ornament", "plain"))
    if selected not in cosmetics:
        selected = "plain"
    return {
        "currency_id":CURRENCY_ID,
        "balance":maxi(0, int(source.get("balance", 0))),
        "lifetime_earned":maxi(0, int(source.get("lifetime_earned", source.get("balance", 0)))),
        "lifetime_spent":maxi(0, int(source.get("lifetime_spent", 0))),
        "claimed_rewards":claims.duplicate(),
        "purchases":purchases.duplicate(),
        "capacities":capacities.duplicate(true),
        "cosmetics":cosmetics.duplicate(),
        "selected_ornament":selected,
    }

func _store_state(state: Dictionary) -> void:
    GameState.profile.meta_economy = _normalize_state(state).duplicate(true)

func _product_state_from_state(product_id: String, state: Dictionary) -> Dictionary:
    if not PRODUCTS.has(product_id):
        return {}
    var spec: Dictionary = (PRODUCTS[product_id] as Dictionary).duplicate(true)
    var purchases: Array = _string_array(state.get("purchases", []))
    spec.id = product_id
    spec.owned = product_id in purchases
    spec.affordable = int(state.get("balance", 0)) >= int(spec.get("cost", 0))
    var requirement := str(spec.get("requires", ""))
    spec.requirement_met = requirement == "" or requirement in purchases
    spec.real_money = false
    spec.power_effect = false
    return spec

func _reward_candidates() -> Array:
    var result: Array = []
    for ending_variant in (GameState.profile.get("endings", []) as Array):
        var ending_id := str(ending_variant)
        if ending_id != "" and not ContentRegistry.get_record(ending_id).is_empty():
            result.append({"key":"ending:%s" % ending_id,"amount":12})

    var unlocks: Dictionary = GameState.profile.get("unlocks", {}) as Dictionary
    for route_variant in (unlocks.get("routes", []) as Array):
        var world_id := str(route_variant)
        if world_id != "world.mata_fio_verde" and world_id != "":
            result.append({"key":"route:%s" % world_id,"amount":4})

    var achievements: Dictionary = GameState.profile.get("achievements", {}) as Dictionary
    for achievement_id_variant in achievements.keys():
        var achievement_id := str(achievement_id_variant)
        var record: Dictionary = achievements.get(achievement_id_variant, {}) as Dictionary
        if bool(record.get("unlocked", false)):
            result.append({"key":"achievement:%s" % achievement_id,"amount":6})

    var codex_count := (GameState.profile.get("codex_records", {}) as Dictionary).size()
    for threshold_variant in CODEX_REWARDS.keys():
        var threshold := int(threshold_variant)
        if codex_count >= threshold:
            result.append({"key":"codex:%d" % threshold,"amount":int(CODEX_REWARDS[threshold])})
    return result

func _reward_amount_for_keys(keys: Array[String]) -> int:
    if keys.is_empty():
        return 0
    var wanted: Dictionary = {}
    for key in keys:
        wanted[key] = true
    var total := 0
    for candidate_variant in _reward_candidates():
        var candidate: Dictionary = candidate_variant as Dictionary
        if wanted.has(str(candidate.get("key", ""))):
            total += int(candidate.get("amount", 0))
    return total

func _normalize_convenience_state(state: Dictionary) -> void:
    var capacities: Dictionary = state.get("capacities", {}) as Dictionary
    var preset_limit := int(capacities.get("journey_presets", 1))
    var seed_limit := int(capacities.get("seed_notebook", 1))
    var pin_limit := int(capacities.get("codex_pins", 5))
    GameState.profile.saved_journey_presets = _normalize_presets(GameState.profile.get("saved_journey_presets", {}), preset_limit).duplicate(true)
    GameState.profile.saved_seeds = _normalize_seeds(GameState.profile.get("saved_seeds", []), seed_limit).duplicate(true)
    GameState.profile.codex_pins = _normalize_pins(GameState.profile.get("codex_pins", []), pin_limit).duplicate()

func _normalize_presets(raw, limit: int) -> Dictionary:
    var result: Dictionary = {}
    if typeof(raw) != TYPE_DICTIONARY:
        return result
    for key_variant in (raw as Dictionary).keys():
        var key := str(key_variant)
        if not key.is_valid_int():
            continue
        var slot := int(key)
        if slot < 0 or slot >= limit:
            continue
        var value = (raw as Dictionary).get(key_variant, {})
        if typeof(value) != TYPE_DICTIONARY:
            continue
        result[key] = JourneySetupEngine.new().normalize_setup(value as Dictionary)
    return result

func _normalize_seeds(raw, limit: int) -> Array:
    var result: Array = []
    var seen: Dictionary = {}
    if typeof(raw) != TYPE_ARRAY:
        return result
    for entry_variant in raw as Array:
        if typeof(entry_variant) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = entry_variant as Dictionary
        var seed_value := int(entry.get("seed", 0))
        if seed_value <= 0 or seen.has(seed_value):
            continue
        seen[seed_value] = true
        result.append({"seed":seed_value,"label":str(entry.get("label", ""))})
        if result.size() >= limit:
            break
    return result

func _normalize_pins(raw, limit: int) -> Array:
    var result: Array = []
    if typeof(raw) != TYPE_ARRAY:
        return result
    for id_variant in raw as Array:
        var content_id := str(id_variant)
        if content_id == "" or content_id in result or ContentRegistry.get_record(content_id).is_empty():
            continue
        result.append(content_id)
        if result.size() >= limit:
            break
    return result

func _string_array(raw) -> Array:
    var result: Array = []
    if typeof(raw) == TYPE_ARRAY:
        for value_variant in raw as Array:
            var value := str(value_variant)
            if value != "" and value not in result:
                result.append(value)
    result.sort()
    return result
