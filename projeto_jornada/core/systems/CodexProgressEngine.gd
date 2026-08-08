extends RefCounted
class_name CodexProgressEngine

const HISTORY_LIMIT := 500

const ACHIEVEMENTS := {
    "first_trace": {"name":"Primeiro Traço","description":"Registrar a primeira descoberta no Códice.","kind":"codex_count","value":1},
    "first_ending": {"name":"Uma Vereda Fecha","description":"Testemunhar o primeiro final.","kind":"ending_count","value":1},
    "three_routes": {"name":"Cartógrafo da Ruptura","description":"Conhecer três Domínios como rotas possíveis.","kind":"route_count","value":3},
    "bestiary_25": {"name":"Olhos para o Estranho","description":"Registrar 25 monstros ou chefes.","kind":"bestiary_count","value":25},
    "collector_25": {"name":"Mãos de Arquivista","description":"Registrar 25 itens distintos.","kind":"item_count","value":25},
    "codex_100": {"name":"Arquivo Vivo","description":"Alcançar 100 registros distintos no Códice.","kind":"codex_count","value":100},
    "echo_witness": {"name":"Aquilo que Permanece","description":"Carregar ao menos uma Marca de Eco entre jornadas.","kind":"echo_count","value":1},
    "all_wanderers": {"name":"Trinta e Seis Caminhos","description":"Desbloquear os 36 Andarilhos.","kind":"character_unlock_count","value":36},
}

func ensure_state() -> Dictionary:
    var records_raw = GameState.profile.get("codex_records", {})
    var history_raw = GameState.profile.get("discovery_history", [])
    var achievements_raw = GameState.profile.get("achievements", {})
    var legacy_codex_raw = GameState.profile.get("codex", [])

    var records: Dictionary = {}
    if typeof(records_raw) == TYPE_DICTIONARY:
        for id_variant in (records_raw as Dictionary).keys():
            var content_id := str(id_variant)
            var raw_record = (records_raw as Dictionary).get(id_variant, {})
            if typeof(raw_record) != TYPE_DICTIONARY:
                continue
            var record: Dictionary = raw_record as Dictionary
            records[content_id] = {
                "id":content_id,
                "category":str(record.get("category", category_for(content_id))),
                "first_seen":int(record.get("first_seen", 0)),
                "last_seen":int(record.get("last_seen", record.get("first_seen", 0))),
                "encounters":maxi(1, int(record.get("encounters", 1))),
                "source":str(record.get("source", "legacy")),
            }

    if typeof(legacy_codex_raw) == TYPE_ARRAY:
        for id_variant in legacy_codex_raw as Array:
            var content_id := str(id_variant)
            if content_id == "" or ContentRegistry.get_record(content_id).is_empty():
                continue
            if not records.has(content_id):
                records[content_id] = {
                    "id":content_id,
                    "category":category_for(content_id),
                    "first_seen":0,
                    "last_seen":0,
                    "encounters":1,
                    "source":"legacy",
                }

    var history: Array = []
    if typeof(history_raw) == TYPE_ARRAY:
        for entry_variant in history_raw as Array:
            if typeof(entry_variant) != TYPE_DICTIONARY:
                continue
            var entry: Dictionary = entry_variant as Dictionary
            var content_id := str(entry.get("id", ""))
            if content_id == "" or not records.has(content_id):
                continue
            history.append({
                "id":content_id,
                "category":str(entry.get("category", category_for(content_id))),
                "at":int(entry.get("at", 0)),
                "source":str(entry.get("source", "legacy")),
            })
    if history.size() > HISTORY_LIMIT:
        history = history.slice(history.size() - HISTORY_LIMIT, history.size())

    var achievements: Dictionary = {}
    if typeof(achievements_raw) == TYPE_DICTIONARY:
        for achievement_id_variant in (achievements_raw as Dictionary).keys():
            var achievement_id := str(achievement_id_variant)
            if not ACHIEVEMENTS.has(achievement_id):
                continue
            var raw_record = (achievements_raw as Dictionary).get(achievement_id_variant, {})
            if typeof(raw_record) != TYPE_DICTIONARY:
                continue
            var record: Dictionary = raw_record as Dictionary
            achievements[achievement_id] = {
                "id":achievement_id,
                "unlocked":bool(record.get("unlocked", false)),
                "unlocked_at":int(record.get("unlocked_at", 0)),
            }

    GameState.profile.codex_records = records
    GameState.profile.discovery_history = history
    GameState.profile.achievements = achievements
    _sync_legacy_codex(records)
    evaluate_achievements()
    return {
        "records":GameState.profile.codex_records,
        "history":GameState.profile.discovery_history,
        "achievements":GameState.profile.achievements,
    }

func discover(content_id: String, source: String = "journey") -> bool:
    if content_id == "" or ContentRegistry.get_record(content_id).is_empty():
        return false
    _ensure_without_achievement_recursion()
    var records: Dictionary = GameState.profile.get("codex_records", {}) as Dictionary
    var history: Array = GameState.profile.get("discovery_history", []) as Array
    var now := int(Time.get_unix_time_from_system())
    if records.has(content_id):
        var record: Dictionary = records[content_id] as Dictionary
        record.last_seen = now
        record.encounters = int(record.get("encounters", 1)) + 1
        records[content_id] = record
    else:
        records[content_id] = {
            "id":content_id,
            "category":category_for(content_id),
            "first_seen":now,
            "last_seen":now,
            "encounters":1,
            "source":source,
        }
        history.append({"id":content_id,"category":category_for(content_id),"at":now,"source":source})
        if history.size() > HISTORY_LIMIT:
            history.pop_front()
    GameState.profile.codex_records = records
    GameState.profile.discovery_history = history
    _sync_legacy_codex(records)
    evaluate_achievements()
    return true

func record(content_id: String) -> Dictionary:
    ensure_state()
    return ((GameState.profile.get("codex_records", {}) as Dictionary).get(content_id, {}) as Dictionary).duplicate(true)

func history(limit: int = 50) -> Array:
    ensure_state()
    var all_history: Array = GameState.profile.get("discovery_history", []) as Array
    if limit <= 0 or all_history.size() <= limit:
        return all_history.duplicate(true)
    return all_history.slice(all_history.size() - limit, all_history.size()).duplicate(true)

func collection_summary() -> Dictionary:
    ensure_state()
    var records: Dictionary = GameState.profile.get("codex_records", {}) as Dictionary
    var discovered: Dictionary = {}
    for record_variant in records.values():
        var record: Dictionary = record_variant as Dictionary
        var category := str(record.get("category", "other"))
        discovered[category] = int(discovered.get(category, 0)) + 1

    var total: Dictionary = {}
    for group in ["worlds","locations","characters","monsters","bosses","items","npcs","marks","debts","events","finals","abilities"]:
        var count := ContentRegistry.all(group).size()
        if count > 0:
            total[_category_for_group(group)] = count
    return {"discovered":discovered,"total":total,"overall":records.size()}

func achievements() -> Array:
    ensure_state()
    var saved: Dictionary = GameState.profile.get("achievements", {}) as Dictionary
    var result: Array = []
    for achievement_id in ACHIEVEMENTS:
        var spec: Dictionary = (ACHIEVEMENTS[achievement_id] as Dictionary).duplicate(true)
        var state: Dictionary = saved.get(achievement_id, {}) as Dictionary
        spec.id = achievement_id
        spec.unlocked = bool(state.get("unlocked", false))
        spec.unlocked_at = int(state.get("unlocked_at", 0))
        spec.progress = _achievement_progress(spec)
        spec.target = int(spec.get("value", 1))
        result.append(spec)
    result.sort_custom(func(a,b): return str((a as Dictionary).id) < str((b as Dictionary).id))
    return result

func evaluate_achievements() -> Array[String]:
    var unlocked_now: Array[String] = []
    var saved_raw = GameState.profile.get("achievements", {})
    var saved: Dictionary = saved_raw as Dictionary if typeof(saved_raw) == TYPE_DICTIONARY else {}
    var now := int(Time.get_unix_time_from_system())
    for achievement_id in ACHIEVEMENTS:
        var existing: Dictionary = saved.get(achievement_id, {}) as Dictionary
        if bool(existing.get("unlocked", false)):
            continue
        var spec: Dictionary = ACHIEVEMENTS[achievement_id] as Dictionary
        if _achievement_progress(spec) >= int(spec.get("value", 1)):
            saved[achievement_id] = {"id":achievement_id,"unlocked":true,"unlocked_at":now}
            unlocked_now.append(achievement_id)
    GameState.profile.achievements = saved
    return unlocked_now

func unlocked_achievement_count() -> int:
    ensure_state()
    var count := 0
    for record_variant in (GameState.profile.get("achievements", {}) as Dictionary).values():
        if bool((record_variant as Dictionary).get("unlocked", false)):
            count += 1
    return count

func category_for(content_id: String) -> String:
    var prefix := content_id.get_slice(".", 0)
    match prefix:
        "world": return "world"
        "location": return "location"
        "character": return "character"
        "monster": return "monster"
        "boss": return "boss"
        "item": return "item"
        "npc": return "npc"
        "mark": return "mark"
        "debt": return "debt"
        "event": return "event"
        "ending": return "ending"
        "ability": return "ability"
        _: return "other"

func _achievement_progress(spec: Dictionary) -> int:
    var kind := str(spec.get("kind", ""))
    var records: Dictionary = GameState.profile.get("codex_records", {}) as Dictionary
    match kind:
        "codex_count":
            return records.size()
        "ending_count":
            return (GameState.profile.get("endings", []) as Array).size()
        "route_count":
            var unlocks: Dictionary = GameState.profile.get("unlocks", {}) as Dictionary
            return (unlocks.get("routes", []) as Array).size()
        "bestiary_count":
            return _category_count(records, ["monster","boss"])
        "item_count":
            return _category_count(records, ["item"])
        "echo_count":
            return (GameState.profile.get("echo_marks", {}) as Dictionary).size()
        "character_unlock_count":
            var unlocks: Dictionary = GameState.profile.get("unlocks", {}) as Dictionary
            return (unlocks.get("characters", []) as Array).size()
        _:
            return 0

func _category_count(records: Dictionary, categories: Array[String]) -> int:
    var count := 0
    for record_variant in records.values():
        if str((record_variant as Dictionary).get("category", "")) in categories:
            count += 1
    return count

func _sync_legacy_codex(records: Dictionary) -> void:
    var ids: Array = records.keys()
    ids.sort()
    GameState.profile.codex = ids.duplicate()
    var unlocks: Dictionary = GameState.profile.get("unlocks", {}) as Dictionary
    if not unlocks.is_empty():
        unlocks.codex = ids.duplicate()
        GameState.profile.unlocks = unlocks

func _ensure_without_achievement_recursion() -> void:
    var records_raw = GameState.profile.get("codex_records", {})
    if typeof(records_raw) != TYPE_DICTIONARY:
        GameState.profile.codex_records = {}
    var history_raw = GameState.profile.get("discovery_history", [])
    if typeof(history_raw) != TYPE_ARRAY:
        GameState.profile.discovery_history = []
    var achievements_raw = GameState.profile.get("achievements", {})
    if typeof(achievements_raw) != TYPE_DICTIONARY:
        GameState.profile.achievements = {}

func _category_for_group(group: String) -> String:
    match group:
        "worlds": return "world"
        "locations": return "location"
        "characters": return "character"
        "monsters": return "monster"
        "bosses": return "boss"
        "items": return "item"
        "npcs": return "npc"
        "marks": return "mark"
        "debts": return "debt"
        "events": return "event"
        "finals": return "ending"
        "abilities": return "ability"
        _: return group
