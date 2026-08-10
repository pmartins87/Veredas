extends RefCounted
class_name RunStateIntegrityEngine

const DICT_DEFAULTS := ["marks","flags","equipped","event_counts","event_last_turn","echo_context"]
const ARRAY_DEFAULTS := ["inventory","debts","recent_events","visited_locations","defeated_enemies","purchases","loot_found"]

func normalize_and_audit(raw_run: Dictionary) -> Dictionary:
    if raw_run.is_empty():
        return {"ok":true,"run":{},"errors":[]}

    var result := raw_run.duplicate(true)
    var errors: Array[String] = []

    if result.has("setup"):
        if typeof(result.get("setup")) != TYPE_DICTIONARY:
            errors.append("type:setup")
        else:
            result = JourneySetupEngine.new().normalize_run_state(result)
    elif not result.has("difficulty_id"):
        result.difficulty_id = DifficultyEngine.DEFAULT_ID

    for field in DICT_DEFAULTS:
        if not result.has(field):
            result[field] = {}
        elif typeof(result.get(field)) != TYPE_DICTIONARY:
            errors.append("type:%s" % field)
    for field in ARRAY_DEFAULTS:
        if not result.has(field):
            result[field] = []
        elif typeof(result.get(field)) != TYPE_ARRAY:
            errors.append("type:%s" % field)

    if not result.has("turn"):
        result.turn = 0
    if not result.has("mode"):
        result.mode = "story"
    if not result.has("active"):
        result.active = true
    if not result.has("ending_id"):
        result.ending_id = ""

    var character_id := str(result.get("character_id", ""))
    var world_id := str(result.get("world_id", ""))
    var location_id := str(result.get("location_id", ""))
    var character := ContentRegistry.get_record(character_id)
    var world := ContentRegistry.get_record(world_id)
    if character_id == "" or character.is_empty() or not character_id.begins_with("character."):
        errors.append("character_id")
    if world_id == "" or world.is_empty() or not world_id.begins_with("world."):
        errors.append("world_id")
    if not character.is_empty() and world_id != "" and str(character.get("world_id", "")) != world_id:
        errors.append("character_world_mismatch")
    if location_id == "" or ContentRegistry.get_record(location_id).is_empty() or not location_id.begins_with("location."):
        errors.append("location_id")
    elif not world.is_empty() and location_id not in (world.get("locations", []) as Array):
        errors.append("location_world_mismatch")

    _positive_bounded(result, "health", "max_health", errors)
    _positive_bounded(result, "vigor", "max_vigor", errors)
    if not _is_number(result.get("seed", null)) or int(result.get("seed", 0)) <= 0:
        errors.append("seed")
    if not _is_number(result.get("turn", null)) or int(result.get("turn", 0)) < 0:
        errors.append("turn")

    if not result.has("resources") or typeof(result.get("resources")) != TYPE_DICTIONARY:
        errors.append("type:resources")
    else:
        var resources: Dictionary = result.get("resources", {}) as Dictionary
        for key in ["fragments","essence","provisions"]:
            if not resources.has(key):
                resources[key] = 0
            elif not _is_number(resources.get(key)) or int(resources.get(key, 0)) < 0:
                errors.append("resource:%s" % key)
        result.resources = resources

    var difficulty_id := str(result.get("difficulty_id", DifficultyEngine.DEFAULT_ID))
    if difficulty_id not in DifficultyEngine.ids():
        errors.append("difficulty_id")

    if result.has("setup") and typeof(result.get("setup")) == TYPE_DICTIONARY:
        var setup: Dictionary = result.get("setup", {}) as Dictionary
        if str(setup.get("world_id", "")) != world_id:
            errors.append("setup_world")
        if str(setup.get("character_id", "")) != character_id:
            errors.append("setup_character")
        if str(setup.get("difficulty_id", "")) not in DifficultyEngine.ids():
            errors.append("setup_difficulty")
        if str(setup.get("difficulty_id", "")) != difficulty_id:
            errors.append("setup_difficulty_mismatch")
        if str(setup.get("journey_mode", "")) not in ProfileMigrationEngine.KNOWN_MODES:
            errors.append("setup_mode")
        var setup_modifiers = setup.get("modifiers", [])
        if typeof(setup_modifiers) != TYPE_ARRAY:
            errors.append("type:setup_modifiers")
        else:
            for modifier_variant in setup_modifiers as Array:
                if not JourneySetupEngine.MODIFIERS.has(str(modifier_variant)):
                    errors.append("setup_modifier:%s" % str(modifier_variant))

    if result.has("modifiers"):
        if typeof(result.get("modifiers")) != TYPE_ARRAY:
            errors.append("type:modifiers")
        else:
            var normalized_modifiers: Array = []
            for modifier_variant in result.get("modifiers", []) as Array:
                var modifier_id := str(modifier_variant)
                if not JourneySetupEngine.MODIFIERS.has(modifier_id):
                    errors.append("modifier:%s" % modifier_id)
                elif modifier_id not in normalized_modifiers:
                    normalized_modifiers.append(modifier_id)
            normalized_modifiers.sort()
            result.modifiers = normalized_modifiers

    _audit_content_array(result.get("inventory", []), "item.", "inventory", errors)
    _audit_content_array(result.get("defeated_enemies", []), "monster.", "defeated_enemies", errors)
    _audit_content_array(result.get("purchases", []), "item.", "purchases", errors)
    _audit_content_array(result.get("loot_found", []), "item.", "loot_found", errors)
    _audit_content_array(result.get("recent_events", []), "event.", "recent_events", errors)

    if typeof(result.get("visited_locations")) == TYPE_ARRAY:
        var visited: Array = result.get("visited_locations", []) as Array
        if location_id != "" and location_id not in visited:
            visited.append(location_id)
        for location_variant in visited:
            var visited_id := str(location_variant)
            if ContentRegistry.get_record(visited_id).is_empty() or not visited_id.begins_with("location."):
                errors.append("visited_location:%s" % visited_id)
            elif not world.is_empty() and visited_id not in (world.get("locations", []) as Array):
                errors.append("visited_world:%s" % visited_id)
        result.visited_locations = visited

    if typeof(result.get("equipped")) == TYPE_DICTIONARY:
        var inventory: Array = result.get("inventory", []) as Array
        for slot_variant in (result.get("equipped", {}) as Dictionary).keys():
            var item_id := str((result.get("equipped", {}) as Dictionary).get(slot_variant, ""))
            if ContentRegistry.get_record(item_id).is_empty() or not item_id.begins_with("item."):
                errors.append("equipped:%s" % item_id)
            elif item_id not in inventory:
                errors.append("equipped_not_owned:%s" % item_id)

    if typeof(result.get("marks")) == TYPE_DICTIONARY:
        for mark_variant in (result.get("marks", {}) as Dictionary).keys():
            var mark_id := str(mark_variant)
            var amount = (result.get("marks", {}) as Dictionary).get(mark_variant)
            if ContentRegistry.get_record(mark_id).is_empty() or not mark_id.begins_with("mark."):
                errors.append("mark:%s" % mark_id)
            elif not _is_number(amount) or int(amount) < 0 or int(amount) > 5:
                errors.append("mark_amount:%s" % mark_id)

    if typeof(result.get("debts")) == TYPE_ARRAY:
        var seen_debts := {}
        for debt_variant in result.get("debts", []) as Array:
            if typeof(debt_variant) != TYPE_DICTIONARY:
                errors.append("type:debt")
                continue
            var debt: Dictionary = debt_variant as Dictionary
            var debt_id := str(debt.get("id", ""))
            if ContentRegistry.get_record(debt_id).is_empty() or not debt_id.begins_with("debt."):
                errors.append("debt:%s" % debt_id)
                continue
            if seen_debts.has(debt_id):
                errors.append("duplicate_debt:%s" % debt_id)
            seen_debts[debt_id] = true
            for field in ["age","pressure","soft_deadline","hard_deadline"]:
                if debt.has(field) and (not _is_number(debt.get(field)) or float(debt.get(field, 0)) < 0.0):
                    errors.append("debt_%s:%s" % [field,debt_id])
            if int(debt.get("hard_deadline", 10)) < int(debt.get("soft_deadline", 4)):
                errors.append("debt_deadline:%s" % debt_id)

    _audit_event_dictionary(result.get("event_counts", {}), "event_counts", false, errors)
    _audit_event_dictionary(result.get("event_last_turn", {}), "event_last_turn", true, errors)

    var ending_id := str(result.get("ending_id", ""))
    if ending_id != "" and (ContentRegistry.get_record(ending_id).is_empty() or not ending_id.begins_with("ending.")):
        errors.append("ending_id")

    if not result.has("rng"):
        if _is_number(result.get("seed", null)) and int(result.get("seed", 0)) > 0:
            var local_rng := RandomNumberGenerator.new()
            local_rng.seed = int(result.seed)
            result.rng = {"seed":int(result.seed), "state":local_rng.state}
    elif typeof(result.get("rng")) != TYPE_DICTIONARY:
        errors.append("type:rng")
    else:
        var rng: Dictionary = result.get("rng", {}) as Dictionary
        if not rng.has("seed") or not _is_number(rng.get("seed")) or int(rng.get("seed", 0)) <= 0:
            errors.append("rng_seed")
        if not rng.has("state") or not _is_number(rng.get("state")):
            errors.append("rng_state")

    return {"ok":errors.is_empty(),"run":result,"errors":errors}

func _positive_bounded(data: Dictionary, value_key: String, max_key: String, errors: Array[String]) -> void:
    if not _is_number(data.get(max_key, null)) or int(data.get(max_key, 0)) <= 0:
        errors.append(max_key)
        return
    if not _is_number(data.get(value_key, null)):
        errors.append(value_key)
        return
    var value := int(data.get(value_key, 0))
    var maximum := int(data.get(max_key, 0))
    if value < 0 or value > maximum:
        errors.append(value_key)

func _audit_content_array(raw, prefix: String, label: String, errors: Array[String]) -> void:
    if typeof(raw) != TYPE_ARRAY:
        return
    for value_variant in raw as Array:
        var content_id := str(value_variant)
        if ContentRegistry.get_record(content_id).is_empty() or not content_id.begins_with(prefix):
            errors.append("%s:%s" % [label,content_id])

func _audit_event_dictionary(raw, label: String, allow_negative: bool, errors: Array[String]) -> void:
    if typeof(raw) != TYPE_DICTIONARY:
        return
    for event_variant in (raw as Dictionary).keys():
        var event_id := str(event_variant)
        var value = (raw as Dictionary).get(event_variant)
        if ContentRegistry.get_record(event_id).is_empty() or not event_id.begins_with("event."):
            errors.append("%s:%s" % [label,event_id])
        elif not _is_number(value) or (not allow_negative and int(value) < 0):
            errors.append("%s_value:%s" % [label,event_id])

func _is_number(value) -> bool:
    return typeof(value) in [TYPE_INT, TYPE_FLOAT]
