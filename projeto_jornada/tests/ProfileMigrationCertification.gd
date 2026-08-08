extends Node

var failures: Array[String] = []
var migration := ProfileMigrationEngine.new()
var second_world_id := ""
var second_character_id := ""
var ending_id := ""
var mark_id := ""
var npc_id := ""
var item_id := ""
var expected_settings: Dictionary = {}

func _ready() -> void:
    await get_tree().process_frame
    _resolve_fixture_ids()
    _fresh_profile_gate()
    _legacy_migration_gate()
    _idempotence_gate()
    _save_load_gate()
    _future_schema_gate()
    _power_neutrality_gate()
    _finish()

func _resolve_fixture_ids() -> void:
    var worlds := ContentRegistry.all("worlds")
    var finals := ContentRegistry.all("finals")
    var marks := ContentRegistry.all("marks")
    var npcs := ContentRegistry.all("npcs")
    var items := ContentRegistry.all("items")
    expect(worlds.size() >= 2, "9.9 requires at least two worlds")
    expect(not finals.is_empty(), "9.9 requires at least one ending")
    expect(not marks.is_empty(), "9.9 requires at least one mark")
    expect(not npcs.is_empty(), "9.9 requires at least one npc")
    expect(not items.is_empty(), "9.9 requires at least one item")
    if worlds.size() >= 2:
        second_world_id = str((worlds[1] as Dictionary).get("id", ""))
    if not finals.is_empty():
        ending_id = str((finals[0] as Dictionary).get("id", ""))
    if not marks.is_empty():
        mark_id = str((marks[0] as Dictionary).get("id", ""))
    if not npcs.is_empty():
        npc_id = str((npcs[0] as Dictionary).get("id", ""))
    if not items.is_empty():
        item_id = str((items[0] as Dictionary).get("id", ""))
    for character_variant in ContentRegistry.all("characters"):
        var character: Dictionary = character_variant as Dictionary
        if str(character.get("world_id", "")) == second_world_id:
            second_character_id = str(character.get("id", ""))
            break
    expect(second_character_id != "", "9.9 could not resolve a character for second world")

func _fresh_profile_gate() -> void:
    GameState.reset_profile()
    var report := migration.normalize_live_profile()
    expect(bool(report.get("ok", false)), "9.9 fresh profile failed integrity: %s" % str(report.get("errors", [])))
    expect(int(GameState.profile.get("profile_schema_version", 0)) == ProfileMigrationEngine.CURRENT_SCHEMA_VERSION, "9.9 fresh profile schema mismatch")
    expect(MetaUnlockEngine.is_character_unlocked(ProfileMigrationEngine.DEFAULT_CHARACTER), "9.9 default character missing after fresh normalization")
    expect(MetaUnlockEngine.is_route_unlocked(ProfileMigrationEngine.DEFAULT_ROUTE), "9.9 default route missing after fresh normalization")

func _legacy_migration_gate() -> void:
    GameState.reset_profile()
    MetaUnlockEngine.ensure_state()
    expect(MetaUnlockEngine.unlock_route(second_world_id), "9.9 fixture route unlock failed")
    expect(MetaUnlockEngine.unlock_character(second_character_id), "9.9 fixture character unlock failed")
    expect(CodexProgressEngine.new().discover(item_id, "9.9_fixture"), "9.9 fixture codex discovery failed")
    expect(HubEngine.add_resident(npc_id), "9.9 fixture resident add failed")

    GameState.profile.endings = [ending_id]
    GameState.run = {"world_id":second_world_id,"marks":{mark_id:2}}
    EchoConsequenceEngine.record_outcome(ending_id, "victory")
    MetaUnlockEngine.evaluate_progression()
    CodexProgressEngine.new().ensure_state()

    expected_settings = {"font_scale":1.15,"reduced_motion":true,"high_contrast":false}
    GameState.profile.settings = expected_settings.duplicate(true)
    var economy := MetaEconomyEngine.new()
    var reward := economy.sync_rewards()
    expect(int(reward.get("awarded", 0)) > 0, "9.9 fixture meta reward was not created")
    expect(economy.purchase("ornament_ink"), "9.9 fixture meta purchase failed")
    expect(economy.remember_seed(990099, "Seed preservada"), "9.9 fixture seed could not be remembered")
    expect(economy.pin_codex(item_id), "9.9 fixture codex pin failed")

    var entitlements := EntitlementEngine.new()
    entitlements.apply_authoritative_snapshot([
        {"product_id":"full_game_unlock","owned":true,"transaction_id":"9.9-legacy-full"}
    ], "9.9_fixture")
    expect(entitlements.has_full_game(), "9.9 fixture entitlement was not granted")

    var canonical_report := migration.normalize_live_profile()
    expect(bool(canonical_report.get("ok", false)), "9.9 canonical fixture invalid before legacy conversion")
    var canonical := GameState.profile.duplicate(true)
    var canonical_fingerprint := migration.progress_fingerprint().duplicate(true)

    var legacy := canonical.duplicate(true)
    legacy.erase("profile_schema_version")
    var unlocks: Dictionary = legacy.get("unlocks", {}) as Dictionary
    (unlocks.characters as Array).append(second_character_id)
    (unlocks.characters as Array).append("character.nonexistent.99")
    (unlocks.routes as Array).append(second_world_id)
    (unlocks.routes as Array).append("world.nonexistent")
    (unlocks.modes as Array).append("journey")
    (unlocks.modes as Array).append("paid_power_mode")
    (unlocks.codex as Array).append(item_id)
    (unlocks.codex as Array).append("item.nonexistent.99")
    legacy.unlocks = unlocks

    var legacy_chars: Array = legacy.get("unlocked_characters", []) as Array
    legacy_chars.append(second_character_id)
    legacy_chars.append("character.nonexistent.99")
    legacy.unlocked_characters = legacy_chars
    var legacy_codex: Array = legacy.get("codex", []) as Array
    legacy_codex.append(item_id)
    legacy_codex.append("content.nonexistent")
    legacy.codex = legacy_codex
    var legacy_endings: Array = legacy.get("endings", []) as Array
    legacy_endings.append(ending_id)
    legacy_endings.append("ending.nonexistent")
    legacy.endings = legacy_endings

    var hub: Dictionary = legacy.get("hub", {}) as Dictionary
    var hub_routes: Array = hub.get("routes", []) as Array
    hub_routes.append(second_world_id)
    hub_routes.append("world.nonexistent")
    hub.routes = hub_routes
    var residents: Array = hub.get("residents", []) as Array
    residents.append(npc_id)
    residents.append("npc.nonexistent.99")
    hub.residents = residents
    legacy.hub = hub

    var records: Dictionary = legacy.get("codex_records", {}) as Dictionary
    records["item.nonexistent.99"] = {"id":"item.nonexistent.99","encounters":77}
    legacy.codex_records = records
    var echoes: Dictionary = legacy.get("echo_marks", {}) as Dictionary
    echoes["mark.nonexistent.99"] = {"mark_id":"mark.nonexistent.99","max_intensity":5}
    legacy.echo_marks = echoes
    var consequences: Dictionary = legacy.get("consequences", {}) as Dictionary
    consequences["ending.nonexistent"] = {"ending_id":"ending.nonexistent","witnessed":true}
    legacy.consequences = consequences
    var achievements: Dictionary = legacy.get("achievements", {}) as Dictionary
    achievements["pay_to_win_master"] = {"unlocked":true}
    legacy.achievements = achievements

    legacy.saved_seeds = [
        {"seed":990099.0,"label":"antiga"},
        {"seed":990099,"label":"Seed preservada"},
        {"seed":0,"label":"inválida"},
        "registro quebrado"
    ]
    var pins: Array = legacy.get("codex_pins", []) as Array
    pins.append(item_id)
    pins.append("item.nonexistent.99")
    legacy.codex_pins = pins
    var ent_raw: Dictionary = legacy.get("entitlements", {}) as Dictionary
    ent_raw.damage_bonus = 999
    ent_raw.currency_grant = 999999
    legacy.entitlements = ent_raw

    var roundtrip = JSON.parse_string(JSON.stringify({"profile":legacy,"run":{}}))
    expect(typeof(roundtrip) == TYPE_DICTIONARY, "9.9 legacy JSON roundtrip failed")
    if typeof(roundtrip) == TYPE_DICTIONARY:
        expect(GameState.deserialize(roundtrip as Dictionary), "9.9 legacy profile was not migrated")

    var report := migration.audit_live_profile()
    expect(bool(report.get("ok", false)), "9.9 migrated legacy profile failed integrity: %s" % str(report.get("errors", [])))
    expect(MetaUnlockEngine.is_route_unlocked(second_world_id), "9.9 valid route was lost in migration")
    expect(MetaUnlockEngine.is_character_unlocked(second_character_id), "9.9 valid character was lost in migration")
    expect(ending_id in (GameState.profile.get("endings", []) as Array), "9.9 valid ending was lost in migration")
    expect(CodexProgressEngine.new().record(item_id).size() > 0, "9.9 valid codex record was lost in migration")
    expect(HubEngine.residents().has(npc_id), "9.9 valid hub resident was lost in migration")
    expect(EntitlementEngine.new().has_full_game(), "9.9 verified entitlement was lost in migration")
    expect(bool(MetaEconomyEngine.new().product_state("ornament_ink").get("owned", false)), "9.9 earned meta purchase was lost in migration")
    expect(GameState.profile.get("settings", {}) == expected_settings, "9.9 settings changed during migration")
    expect("world.nonexistent" not in (GameState.profile.unlocks.routes as Array), "9.9 invalid route survived migration")
    expect("character.nonexistent.99" not in (GameState.profile.unlocks.characters as Array), "9.9 invalid character survived migration")
    expect("paid_power_mode" not in (GameState.profile.unlocks.modes as Array), "9.9 unknown mode survived migration")
    expect("content.nonexistent" not in (GameState.profile.codex as Array), "9.9 invalid codex id survived migration")
    expect("ending.nonexistent" not in (GameState.profile.endings as Array), "9.9 invalid ending survived migration")
    expect(not (GameState.profile.entitlements as Dictionary).has("damage_bonus"), "9.9 forbidden entitlement power field survived migration")
    expect(not (GameState.profile.entitlements as Dictionary).has("currency_grant"), "9.9 forbidden entitlement currency field survived migration")
    expect(migration.progress_fingerprint() == canonical_fingerprint, "9.9 semantic progress fingerprint changed during legacy migration")

func _idempotence_gate() -> void:
    var before := migration.progress_fingerprint().duplicate(true)
    var first := migration.normalize_live_profile()
    var middle := migration.progress_fingerprint().duplicate(true)
    var second := migration.normalize_live_profile()
    var after := migration.progress_fingerprint().duplicate(true)
    expect(bool(first.get("ok", false)) and bool(second.get("ok", false)), "9.9 repeated normalization failed integrity")
    expect(before == middle and middle == after, "9.9 migration is not idempotent")

func _save_load_gate() -> void:
    var before := migration.progress_fingerprint().duplicate(true)
    expect(SaveService.save_game(), "9.9 canonical save failed")
    GameState.reset_profile()
    GameState.run = {}
    expect(SaveService.load_game(), "9.9 canonical reload failed")
    var report := migration.audit_live_profile()
    expect(bool(report.get("ok", false)), "9.9 reloaded profile failed integrity")
    expect(migration.progress_fingerprint() == before, "9.9 fingerprint changed after save/load")

func _future_schema_gate() -> void:
    var before := migration.progress_fingerprint().duplicate(true)
    var future := GameState.profile.duplicate(true)
    future.profile_schema_version = ProfileMigrationEngine.CURRENT_SCHEMA_VERSION + 1
    expect(not GameState.deserialize({"profile":future,"run":{}}), "9.9 future profile schema was incorrectly accepted")
    expect(migration.progress_fingerprint() == before, "9.9 rejected future profile modified live progress")
    expect(not GameState.deserialize({"profile":42,"run":{}}), "9.9 non-dictionary profile was incorrectly accepted")
    expect(migration.progress_fingerprint() == before, "9.9 rejected malformed profile modified live progress")

func _power_neutrality_gate() -> void:
    expect(RunFlowEngine.start_journey(ProfileMigrationEngine.DEFAULT_CHARACTER, 99001), "9.9 could not start post-migration journey")
    expect(int(GameState.run.get("max_health", 0)) == 16, "9.9 migration altered max health")
    expect(int(GameState.run.get("max_vigor", 0)) == 8, "9.9 migration altered max vigor")

func _finish() -> void:
    if failures.is_empty():
        print("PROFILE_MIGRATION_CERTIFICATION PASS: 9.9")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("PROFILE_MIGRATION_CERTIFICATION: %s" % failure)
        print("PROFILE_MIGRATION_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
