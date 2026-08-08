extends RefCounted
class_name ProfileMigrationEngine

const CURRENT_SCHEMA_VERSION := 3
const KNOWN_MODES := ["journey", "fixed_seed", "echo_run", "convergence"]
const DEFAULT_CHARACTER := "character.mata_fio_verde.01"
const DEFAULT_ROUTE := "world.mata_fio_verde"

func fresh_profile() -> Dictionary:
    return {
        "profile_schema_version":CURRENT_SCHEMA_VERSION,
        "unlocked_characters":[DEFAULT_CHARACTER],
        "codex":[DEFAULT_CHARACTER, DEFAULT_ROUTE],
        "codex_records":{},
        "discovery_history":[],
        "achievements":{},
        "echo_marks":{},
        "consequences":{},
        "endings":[],
        "settings":{},
        "hub":{},
        "meta_economy":{},
        "saved_journey_presets":{},
        "saved_seeds":[],
        "codex_pins":[],
        "entitlements":{},
        "unlocks":{
            "characters":[DEFAULT_CHARACTER],
            "routes":[DEFAULT_ROUTE],
            "modes":["journey"],
            "codex":[DEFAULT_CHARACTER, DEFAULT_ROUTE],
        },
    }

func can_migrate(raw_profile: Dictionary) -> bool:
    return int(raw_profile.get("profile_schema_version", 0)) <= CURRENT_SCHEMA_VERSION

func migrate_raw(raw_profile: Dictionary) -> Dictionary:
    var profile := raw_profile.duplicate(true)
    var unlocks := _dict(profile.get("unlocks", {}))
    var hub := _dict(profile.get("hub", {}))

    var characters := _array(unlocks.get("characters", []))
    characters.append_array(_array(profile.get("unlocked_characters", [])))
    characters = _valid_content_ids(characters, "character.")
    _append_unique(characters, DEFAULT_CHARACTER)

    var routes := _array(unlocks.get("routes", []))
    routes.append_array(_array(hub.get("routes", [])))
    routes = _valid_content_ids(routes, "world.")
    _append_unique(routes, DEFAULT_ROUTE)

    var modes: Array = []
    for mode_variant in _array(unlocks.get("modes", [])):
        var mode_id := str(mode_variant)
        if mode_id in KNOWN_MODES and mode_id not in modes:
            modes.append(mode_id)
    _append_unique(modes, "journey")
    modes.sort()

    var codex := _array(unlocks.get("codex", []))
    codex.append_array(_array(profile.get("codex", [])))
    var records_source := _dict(profile.get("codex_records", {}))
    codex.append_array(records_source.keys())
    codex = _valid_content_ids(codex)
    _append_unique(codex, DEFAULT_CHARACTER)
    _append_unique(codex, DEFAULT_ROUTE)

    profile["unlocks"] = {
        "characters":characters,
        "routes":routes,
        "modes":modes,
        "codex":codex,
    }
    profile["unlocked_characters"] = characters.duplicate()
    profile["codex"] = codex.duplicate()
    profile["endings"] = _valid_content_ids(_array(profile.get("endings", [])))
    profile["codex_records"] = _filtered_record_dictionary(records_source)
    profile["discovery_history"] = _array(profile.get("discovery_history", []))
    profile["achievements"] = _dict(profile.get("achievements", {}))
    profile["echo_marks"] = _filtered_record_dictionary(_dict(profile.get("echo_marks", {})), "mark.")
    profile["consequences"] = _filtered_record_dictionary(_dict(profile.get("consequences", {})))
    profile["settings"] = _dict(profile.get("settings", {}))
    profile["meta_economy"] = _dict(profile.get("meta_economy", {}))
    profile["entitlements"] = _dict(profile.get("entitlements", {}))
    profile["codex_pins"] = _valid_content_ids(_array(profile.get("codex_pins", [])))
    profile["saved_seeds"] = _normalize_saved_seeds(_array(profile.get("saved_seeds", [])))
    profile["saved_journey_presets"] = _normalize_presets(_dict(profile.get("saved_journey_presets", {})))

    hub["stage"] = clampi(int(hub.get("stage", 1)), 1, 5)
    hub["visit_count"] = maxi(0, int(hub.get("visit_count", 0)))
    hub["routes"] = routes.duplicate()
    hub["residents"] = _valid_content_ids(_array(hub.get("residents", [])), "npc.")
    hub["facilities"] = _dict(hub.get("facilities", {}))
    var hub_history := _array(hub.get("history", []))
    if hub_history.size() > 40:
        hub_history = hub_history.slice(hub_history.size() - 40, hub_history.size())
    hub["history"] = hub_history
    profile["hub"] = hub
    profile["profile_schema_version"] = CURRENT_SCHEMA_VERSION
    return profile

func normalize_live_profile() -> Dictionary:
    GameState.profile = migrate_raw(GameState.profile)
    EchoConsequenceEngine.ensure_state()
    MetaUnlockEngine.ensure_state()
    _sync_hub_routes_from_unlocks()
    HubEngine.ensure_state()
    MetaUnlockEngine.evaluate_progression()
    CodexProgressEngine.new().ensure_state()
    MetaEconomyEngine.new().ensure_state()
    EntitlementEngine.new().ensure_state()
    _sync_hub_routes_from_unlocks()
    GameState.profile.profile_schema_version = CURRENT_SCHEMA_VERSION
    return audit_live_profile()

func audit_live_profile() -> Dictionary:
    var errors: Array[String] = []
    var profile := GameState.profile
    if int(profile.get("profile_schema_version", 0)) != CURRENT_SCHEMA_VERSION:
        errors.append("schema_version")

    for field in ["unlocks", "codex_records", "achievements", "echo_marks", "consequences", "settings", "hub", "meta_economy", "entitlements"]:
        if typeof(profile.get(field, {})) != TYPE_DICTIONARY:
            errors.append("type:%s" % field)
    for field in ["unlocked_characters", "codex", "discovery_history", "endings", "saved_seeds", "codex_pins"]:
        if typeof(profile.get(field, [])) != TYPE_ARRAY:
            errors.append("type:%s" % field)

    var unlocks := _dict(profile.get("unlocks", {}))
    var characters := _array(unlocks.get("characters", []))
    var routes := _array(unlocks.get("routes", []))
    var modes := _array(unlocks.get("modes", []))
    var codex := _array(unlocks.get("codex", []))
    if DEFAULT_CHARACTER not in characters:
        errors.append("default_character_missing")
    if DEFAULT_ROUTE not in routes:
        errors.append("default_route_missing")
    if "journey" not in modes:
        errors.append("default_mode_missing")
    _audit_id_list(characters, "characters", errors, "character.")
    _audit_id_list(routes, "routes", errors, "world.")
    _audit_id_list(codex, "codex", errors)
    if _has_duplicates(modes):
        errors.append("duplicate:modes")
    for mode_variant in modes:
        if str(mode_variant) not in KNOWN_MODES:
            errors.append("invalid_mode:%s" % str(mode_variant))

    if _canonical_strings(profile.get("unlocked_characters", [])) != _canonical_strings(characters):
        errors.append("legacy_character_desync")
    if _canonical_strings(profile.get("codex", [])) != _canonical_strings(codex):
        errors.append("legacy_codex_desync")

    _audit_id_list(_array(profile.get("endings", [])), "endings", errors)
    _audit_id_list(_array(profile.get("codex_pins", [])), "codex_pins", errors)

    var hub := _dict(profile.get("hub", {}))
    if _canonical_strings(hub.get("routes", [])) != _canonical_strings(routes):
        errors.append("hub_route_desync")
    _audit_id_list(_array(hub.get("residents", [])), "hub_residents", errors, "npc.")

    var economy := _dict(profile.get("meta_economy", {}))
    if int(economy.get("balance", 0)) < 0 or int(economy.get("lifetime_earned", 0)) < 0 or int(economy.get("lifetime_spent", 0)) < 0:
        errors.append("negative_meta_economy")
    var capacity_seeds := MetaEconomyEngine.new().capacity("seed_notebook")
    var seeds := _array(profile.get("saved_seeds", []))
    if seeds.size() > capacity_seeds:
        errors.append("seed_capacity")
    var seen_seeds: Dictionary = {}
    for entry_variant in seeds:
        if typeof(entry_variant) != TYPE_DICTIONARY:
            errors.append("invalid_seed_record")
            continue
        var seed_value := int((entry_variant as Dictionary).get("seed", 0))
        if seed_value <= 0 or seen_seeds.has(seed_value):
            errors.append("invalid_seed:%d" % seed_value)
        seen_seeds[seed_value] = true

    var entitlements := _dict(profile.get("entitlements", {}))
    for forbidden_key in ["damage_bonus", "currency_grant", "health_bonus", "vigor_bonus", "drop_rate_bonus"]:
        if entitlements.has(forbidden_key):
            errors.append("entitlement_power_key:%s" % forbidden_key)

    return {
        "ok":errors.is_empty(),
        "errors":errors,
        "schema_version":CURRENT_SCHEMA_VERSION,
        "fingerprint":progress_fingerprint(),
    }

func progress_fingerprint() -> Dictionary:
    var profile := GameState.profile
    var unlocks := _dict(profile.get("unlocks", {}))
    var records := _dict(profile.get("codex_records", {}))
    var achievements := _dict(profile.get("achievements", {}))
    var echoes := _dict(profile.get("echo_marks", {}))
    var consequences := _dict(profile.get("consequences", {}))
    var economy := _dict(profile.get("meta_economy", {}))
    var entitlements := _dict(profile.get("entitlements", {}))
    var grants := _dict(entitlements.get("grants", {}))
    var hub := _dict(profile.get("hub", {}))

    var unlocked_achievements: Array = []
    for achievement_variant in achievements.keys():
        var achievement_id := str(achievement_variant)
        if bool((_dict(achievements.get(achievement_variant, {}))).get("unlocked", false)):
            unlocked_achievements.append(achievement_id)
    unlocked_achievements.sort()

    var owned_products: Array = []
    for product_variant in grants.keys():
        var product_id := str(product_variant)
        if bool((_dict(grants.get(product_variant, {}))).get("owned", false)):
            owned_products.append(product_id)
    owned_products.sort()

    return {
        "schema":int(profile.get("profile_schema_version", 0)),
        "characters":_canonical_strings(unlocks.get("characters", [])),
        "routes":_canonical_strings(unlocks.get("routes", [])),
        "modes":_canonical_strings(unlocks.get("modes", [])),
        "codex":_canonical_strings(records.keys()),
        "endings":_canonical_strings(profile.get("endings", [])),
        "echo_marks":_canonical_strings(echoes.keys()),
        "consequences":_canonical_strings(consequences.keys()),
        "achievements":unlocked_achievements,
        "hub_stage":int(hub.get("stage", 1)),
        "hub_residents":_canonical_strings(hub.get("residents", [])),
        "meta_balance":int(economy.get("balance", 0)),
        "meta_earned":int(economy.get("lifetime_earned", 0)),
        "meta_spent":int(economy.get("lifetime_spent", 0)),
        "meta_claims":_canonical_strings(economy.get("claimed_rewards", [])),
        "meta_purchases":_canonical_strings(economy.get("purchases", [])),
        "saved_seeds":_normalize_saved_seeds(_array(profile.get("saved_seeds", []))),
        "codex_pins":_canonical_strings(profile.get("codex_pins", [])),
        "owned_products":owned_products,
        "settings":_dict(profile.get("settings", {})),
    }

func _sync_hub_routes_from_unlocks() -> void:
    var unlocks := _dict(GameState.profile.get("unlocks", {}))
    var hub := _dict(GameState.profile.get("hub", {}))
    hub["routes"] = _canonical_strings(unlocks.get("routes", []))
    GameState.profile.hub = hub

func _normalize_presets(raw: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    var engine := JourneySetupEngine.new()
    for key_variant in raw.keys():
        var key := str(key_variant)
        if not key.is_valid_int() or int(key) < 0:
            continue
        var record_raw = raw.get(key_variant, {})
        if typeof(record_raw) != TYPE_DICTIONARY:
            continue
        result[key] = engine.normalize_setup(record_raw as Dictionary)
    return result

func _normalize_saved_seeds(raw: Array) -> Array:
    var by_seed: Dictionary = {}
    for entry_variant in raw:
        if typeof(entry_variant) != TYPE_DICTIONARY:
            continue
        var entry := entry_variant as Dictionary
        var seed_value := int(entry.get("seed", 0))
        if seed_value <= 0:
            continue
        by_seed[seed_value] = {"seed":seed_value, "label":str(entry.get("label", ""))}
    var keys: Array = by_seed.keys()
    keys.sort()
    var result: Array = []
    for seed_variant in keys:
        result.append((by_seed[seed_variant] as Dictionary).duplicate(true))
    return result

func _filtered_record_dictionary(raw: Dictionary, prefix: String = "") -> Dictionary:
    var result: Dictionary = {}
    for key_variant in raw.keys():
        var content_id := str(key_variant)
        if not _valid_content_id(content_id, prefix):
            continue
        var value = raw.get(key_variant, {})
        if typeof(value) == TYPE_DICTIONARY:
            result[content_id] = (value as Dictionary).duplicate(true)
    return result

func _valid_content_ids(raw: Array, prefix: String = "") -> Array:
    var result: Array = []
    for id_variant in raw:
        var content_id := str(id_variant)
        if _valid_content_id(content_id, prefix) and content_id not in result:
            result.append(content_id)
    result.sort()
    return result

func _valid_content_id(content_id: String, prefix: String = "") -> bool:
    if content_id == "" or (prefix != "" and not content_id.begins_with(prefix)):
        return false
    return not ContentRegistry.get_record(content_id).is_empty()

func _audit_id_list(raw: Array, label: String, errors: Array[String], prefix: String = "") -> void:
    if _has_duplicates(raw):
        errors.append("duplicate:%s" % label)
    for id_variant in raw:
        var content_id := str(id_variant)
        if not _valid_content_id(content_id, prefix):
            errors.append("invalid:%s:%s" % [label, content_id])

func _has_duplicates(raw: Array) -> bool:
    var seen: Dictionary = {}
    for value_variant in raw:
        var value := str(value_variant)
        if seen.has(value):
            return true
        seen[value] = true
    return false

func _canonical_strings(raw) -> Array:
    var result: Array = []
    if typeof(raw) != TYPE_ARRAY:
        return result
    for value_variant in raw as Array:
        var value := str(value_variant)
        if value != "" and value not in result:
            result.append(value)
    result.sort()
    return result

func _append_unique(target: Array, value: String) -> void:
    if value != "" and value not in target:
        target.append(value)
        target.sort()

func _array(raw) -> Array:
    return (raw as Array).duplicate(true) if typeof(raw) == TYPE_ARRAY else []

func _dict(raw) -> Dictionary:
    return (raw as Dictionary).duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}
