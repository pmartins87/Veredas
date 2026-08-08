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
    var state: Dictionary = raw as Dictionary if typeof(raw) == TYPE_DICTIONARY else {}
    var capacities_raw = state.get("capacities", {})
    var capacities: Dictionary = capacities_raw as Dictionary if typeof(capacities_raw) == TYPE_DICTIONARY else {}
    capacities.journey_presets = maxi(1, int(capacities.get("journey_presets", 1)))
    capacities.seed_notebook = maxi(1, int(capacities.get("seed_notebook", 1)))
    capacities.codex_pins = maxi(5, int(capacities.get("codex_pins", 5)))

    var claims := _string_array(state.get("claimed_rewards", []))
    var purchases := _string_array(state.get("purchases", []))
    var cosmetics := _string_array(state.get("cosmetics", ["plain"]))
    if "plain" not in cosmetics:
        cosmetics.append("plain")
    cosmetics.sort()

    state = {
        "currency_id":CURRENCY_ID,
        "balance":maxi(0, int(state.get("balance", 0))),
        "lifetime_earned":maxi(0, int(state.get("lifetime_earned", state.get("balance", 0)))),
        "lifetime_spent":maxi(0, int(state.get("lifetime_spent", 0))),
        "claimed_rewards":claims,
        "purchases":purchases,
        "capacities":capacities,
        "cosmetics":cosmetics,
        "selected_ornament":str(state.get("selected_ornament", "plain")),
    }
    if state.selected_ornament not in cosmetics:
        state.selected_ornament = "plain"
    GameState.profile.meta_economy = state

    if typeof(GameState.profile.get("saved_journey_presets", {})) != TYPE_DICTIONARY:
        GameState.profile.saved_journey_presets = {}
    if typeof(GameState.profile.get("saved_seeds", [])) != TYPE_ARRAY:
        GameState.profile.saved_seeds = []
    if typeof(GameState.profile.get("codex_pins", [])) != TYPE_ARRAY:
        GameState.profile.codex_pins = []
    _trim_convenience_state()
    return state

func sync_rewards() -> Dictionary:
    var state := ensure_state()
    var new_keys: Array[String] = []
    var awarded := 0

    for ending_variant in (GameState.profile.get("endings", []) as Array):
        var ending_id := str(ending_variant)
        if ending_id != "" and not ContentRegistry.get_record(ending_id).is_empty():
            awarded += _claim_reward(state, "ending:%s" % ending_id, 12, new_keys)

    var unlocks: Dictionary = GameState.profile.get("unlocks", {}) as Dictionary
    for route_variant in (unlocks.get("routes", []) as Array):
        var world_id := str(route_variant)
        if world_id != "world.mata_fio_verde" and world_id != "":
            awarded += _claim_reward(state, "route:%s" % world_id, 4, new_keys)

    var achievements: Dictionary = GameState.profile.get("achievements", {}) as Dictionary
    for achievement_id_variant in achievements.keys():
        var achievement_id := str(achievement_id_variant)
        var record: Dictionary = achievements.get(achievement_id_variant, {}) as Dictionary
        if bool(record.get("unlocked", false)):
            awarded += _claim_reward(state, "achievement:%s" % achievement_id, 6, new_keys)

    var codex_count := (GameState.profile.get("codex_records", {}) as Dictionary).size()
    for threshold_variant in CODEX_REWARDS.keys():
        var threshold := int(threshold_variant)
        if codex_count >= threshold:
            awarded += _claim_reward(state, "codex:%d" % threshold, int(CODEX_REWARDS[threshold]), new_keys)

    GameState.profile.meta_economy = state
    return {"awarded":awarded,"new_rewards":new_keys,"balance":int(state.balance)}

func balance() -> int:
    return int(ensure_state().get("balance", 0))

func product_state(product_id: String) -> Dictionary:
    var state := ensure_state()
    if not PRODUCTS.has(product_id):
        return {}
    var spec: Dictionary = (PRODUCTS[product_id] as Dictionary).duplicate(true)
    var purchases: Array = state.purchases as Array
    spec.id = product_id
    spec.owned = product_id in purchases
    spec.affordable = balance() >= int(spec.get("cost", 0))
    var requirement := str(spec.get("requires", ""))
    spec.requirement_met = requirement == "" or requirement in purchases
    spec.real_money = false
    spec.power_effect = false
    return spec

func catalog() -> Array:
    var result: Array = []
    for product_id in PRODUCTS:
        result.append(product_state(product_id))
    result.sort_custom(func(a,b): return int((a as Dictionary).get("cost",0)) < int((b as Dictionary).get("cost",0)))
    return result

func purchase(product_id: String) -> bool:
    var spec := product_state(product_id)
    if spec.is_empty() or bool(spec.owned) or not bool(spec.requirement_met):
        return false
    var cost := int(spec.get("cost", 0))
    var state := ensure_state()
    if int(state.balance) < cost:
        return false
    state.balance = int(state.balance) - cost
    state.lifetime_spent = int(state.lifetime_spent) + cost
    var purchases: Array = state.purchases as Array
    purchases.append(product_id)
    purchases.sort()
    state.purchases = purchases

    match str(spec.get("kind", "")):
        "capacity":
            var capacities: Dictionary = state.capacities as Dictionary
            var target := str(spec.get("target", ""))
            capacities[target] = maxi(int(capacities.get(target, 0)), int(spec.get("value", 0)))
            state.capacities = capacities
        "cosmetic":
            var cosmetics: Array = state.cosmetics as Array
            var cosmetic_id := str(spec.get("value", ""))
            if cosmetic_id != "" and cosmetic_id not in cosmetics:
                cosmetics.append(cosmetic_id)
                cosmetics.sort()
            state.cosmetics = cosmetics
        _:
            return false

    GameState.profile.meta_economy = state
    _trim_convenience_state()
    SaveService.save_game()
    return true

func capacity(kind: String) -> int:
    var capacities: Dictionary = ensure_state().get("capacities", {}) as Dictionary
    return int(capacities.get(kind, 0))

func save_journey_preset(slot: int, setup: Dictionary) -> bool:
    if slot < 0 or slot >= capacity("journey_presets"):
        return false
    var normalized := JourneySetupEngine.new().normalize_setup(setup)
    var presets: Dictionary = GameState.profile.get("saved_journey_presets", {}) as Dictionary
    presets[str(slot)] = normalized
    GameState.profile.saved_journey_presets = presets
    return true

func load_journey_preset(slot: int) -> Dictionary:
    ensure_state()
    var presets: Dictionary = GameState.profile.get("saved_journey_presets", {}) as Dictionary
    var raw = presets.get(str(slot), {})
    if typeof(raw) != TYPE_DICTIONARY:
        return {}
    return JourneySetupEngine.new().normalize_setup(raw as Dictionary)

func remember_seed(seed_value: int, label: String = "") -> bool:
    if seed_value <= 0:
        return false
    ensure_state()
    var seeds: Array = GameState.profile.get("saved_seeds", []) as Array
    for entry_variant in seeds:
        var entry: Dictionary = entry_variant as Dictionary
        if int(entry.get("seed", 0)) == seed_value:
            entry.label = label
            return true
    if seeds.size() >= capacity("seed_notebook"):
        return false
    seeds.append({"seed":seed_value,"label":label})
    GameState.profile.saved_seeds = seeds
    return true

func pin_codex(content_id: String) -> bool:
    if ContentRegistry.get_record(content_id).is_empty():
        return false
    ensure_state()
    var pins: Array = GameState.profile.get("codex_pins", []) as Array
    if content_id in pins:
        return true
    if pins.size() >= capacity("codex_pins"):
        return false
    pins.append(content_id)
    GameState.profile.codex_pins = pins
    return true

func select_ornament(ornament_id: String) -> bool:
    var state := ensure_state()
    if ornament_id not in (state.cosmetics as Array):
        return false
    state.selected_ornament = ornament_id
    GameState.profile.meta_economy = state
    return true

func summary() -> Dictionary:
    var state := ensure_state()
    return {
        "currency":CURRENCY_NAME,
        "balance":int(state.balance),
        "lifetime_earned":int(state.lifetime_earned),
        "lifetime_spent":int(state.lifetime_spent),
        "purchases":(state.purchases as Array).size(),
        "journey_presets":capacity("journey_presets"),
        "seed_notebook":capacity("seed_notebook"),
        "codex_pins":capacity("codex_pins"),
        "selected_ornament":str(state.selected_ornament),
    }

func _claim_reward(state: Dictionary, key: String, amount: int, new_keys: Array[String]) -> int:
    var claims: Array = state.claimed_rewards as Array
    if key in claims or amount <= 0:
        return 0
    claims.append(key)
    claims.sort()
    state.claimed_rewards = claims
    state.balance = int(state.balance) + amount
    state.lifetime_earned = int(state.lifetime_earned) + amount
    new_keys.append(key)
    return amount

func _trim_convenience_state() -> void:
    var state: Dictionary = GameState.profile.get("meta_economy", {}) as Dictionary
    var capacities: Dictionary = state.get("capacities", {}) as Dictionary
    var presets: Dictionary = GameState.profile.get("saved_journey_presets", {}) as Dictionary
    for key_variant in presets.keys():
        var key := str(key_variant)
        if not key.is_valid_int() or int(key) < 0 or int(key) >= int(capacities.get("journey_presets", 1)):
            presets.erase(key_variant)
    GameState.profile.saved_journey_presets = presets

    var seeds: Array = GameState.profile.get("saved_seeds", []) as Array
    if seeds.size() > int(capacities.get("seed_notebook", 1)):
        seeds.resize(int(capacities.get("seed_notebook", 1)))
    GameState.profile.saved_seeds = seeds

    var pins: Array = GameState.profile.get("codex_pins", []) as Array
    if pins.size() > int(capacities.get("codex_pins", 5)):
        pins.resize(int(capacities.get("codex_pins", 5)))
    GameState.profile.codex_pins = pins

func _string_array(raw) -> Array:
    var result: Array = []
    if typeof(raw) == TYPE_ARRAY:
        for value_variant in raw as Array:
            var value := str(value_variant)
            if value != "" and value not in result:
                result.append(value)
    result.sort()
    return result
