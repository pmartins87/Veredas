extends Node

const BASIC_GUARD_CAP := 6

var combat: Dictionary = {}

func start(enemy_id: String, character_id: String) -> Dictionary:
    var enemy_record := ContentRegistry.get_record(enemy_id)
    if enemy_record.is_empty():
        return {}
    var is_boss := enemy_id.begins_with("boss.")
    var difficulty_id := DifficultyEngine.current_id()
    var enemy_hp := DifficultyEngine.scale_enemy_health(int(enemy_record.get("hp", 30 if is_boss else 12)), difficulty_id)
    var enemy_posture := DifficultyEngine.scale_enemy_posture(int(enemy_record.get("posture", 18 if is_boss else 8)), difficulty_id)
    var bonuses := InventoryEngine.equipment_bonuses()
    var base_max_vigor := int(GameState.run.get("max_vigor", 8))
    var effective_load := maxi(0, int(bonuses.get("load", 0)))
    var vigor_bonus := maxi(0, int(bonuses.get("vigor", 0)))
    var effective_max_vigor := maxi(1, base_max_vigor + vigor_bonus - effective_load)
    var player_hp := int(GameState.run.get("health", 16))
    var player_vigor := mini(effective_max_vigor, int(GameState.run.get("vigor", 8)) + vigor_bonus)
    var base_posture := maxi(1, int(GameState.run.get("base_posture", 10)))
    var base_guard := maxi(0, int(GameState.run.get("base_guard", 0)))
    combat = {
        "active": true,
        "turn": 1,
        "difficulty_id":difficulty_id,
        "player": {
            "hp":player_hp,"max_hp":int(GameState.run.get("max_health",16)),
            "vigor":player_vigor,"max_vigor":effective_max_vigor,
            "posture":base_posture + int(bonuses.get("posture",0)),
            "max_posture":base_posture + int(bonuses.get("posture",0)),
            "guard":base_guard + int(bonuses.get("guard",0)),"distance":1,"states":[],
            "damage_bonus":int(bonuses.get("damage",0)),
            "posture_bonus":int(bonuses.get("posture",0)),
            "range_bonus":int(bonuses.get("range",0)),
            "status_power_bonus":int(bonuses.get("status_power",0)),
            "status_resist":int(bonuses.get("status_resist",0)),
            "heal_bonus":int(bonuses.get("heal",0)),
            "resource_gain_bonus":int(bonuses.get("resource_gain",0)),
            "mark_synergy_bonus":int(bonuses.get("mark_synergy",0)),
            "debt_pressure_bonus":int(bonuses.get("debt_pressure",0)),
            "equipment_load":effective_load,
        },
        "enemy": {
            "id":enemy_id,"name":enemy_record.get("name","Enemy"),
            "hp":enemy_hp,"max_hp":enemy_hp,"posture":enemy_posture,"max_posture":enemy_posture,
            "guard":maxi(0, int(enemy_record.get("starting_guard",0))),"distance":1,"states":[],
            "mechanic":enemy_record.get("mechanic",""),
            "rank":enemy_record.get("rank", "boss" if is_boss else "normal"),
            "elite_affix":enemy_record.get("elite_affix", ""),
        },
        "enemy_record":enemy_record,
        "character_id": character_id,
        "signature_resource": CharacterKitEngine.initial_resource_pool(character_id),
        "intent": {},
        "is_boss": is_boss,
        "boss_phase": 0,
        "boss_record": enemy_record if is_boss else {},
    }
    roll_intent()
    return combat

func roll_intent() -> Dictionary:
    if combat.is_empty():
        return {}
    var enemy: Dictionary = combat.enemy
    var enemy_record: Dictionary = combat.get("enemy_record", {}) as Dictionary
    var phase: Dictionary = {}
    if bool(combat.get("is_boss", false)):
        phase = BossPhaseEngine.phase(enemy_record, int(enemy.get("hp",0)), int(enemy.get("max_hp",1)))
    var intent := EnemyBalanceEngine.new().roll_intent(enemy_record, phase, RNGService.next_float())
    combat.intent = intent
    PresentationBus.intent(intent)
    return intent

func player_action(action: String) -> Dictionary:
    if combat.is_empty() or not combat.get("active", false):
        return combat
    var player: Dictionary = combat.player
    var enemy: Dictionary = combat.enemy
    var before_enemy_hp := int(enemy.hp)
    var did_act := true
    var marked_bonus := _marked_damage_bonus(player, enemy)
    match action:
        "strike":
            if _in_weapon_range(player):
                var raw := 4 + int(player.get("damage_bonus",0)) + marked_bonus
                var dealt := maxi(0, roundi(float(raw) * StatusEngine.damage_multiplier(enemy)) - int(enemy.get("guard",0)))
                enemy.hp = maxi(0, int(enemy.hp) - dealt)
                enemy.guard = 0
            else:
                did_act = false
        "precise":
            if int(player.get("vigor",0)) < 2 or not _in_weapon_range(player):
                did_act = false
            else:
                player.vigor = int(player.vigor) - 2
                var damage := roundi(float(3 + int(player.get("damage_bonus",0)) + marked_bonus) * StatusEngine.damage_multiplier(enemy))
                enemy.hp = maxi(0, int(enemy.hp) - damage)
                enemy.posture = maxi(0, int(enemy.posture) - (4 + int(player.get("posture_bonus",0))))
        "guard":
            # Basic guard is a temporary defensive stance, not an unbounded
            # bank of future damage absorption. Signature guard/counter tools
            # may still exceed this through their explicit power budget.
            player.guard = mini(BASIC_GUARD_CAP, int(player.get("guard",0)) + 4)
        "advance":
            if StatusEngine.movement_locked(player):
                did_act = false
            else:
                player.distance = maxi(0, int(player.get("distance",1)) - 1)
        "retreat":
            if StatusEngine.movement_locked(player):
                did_act = false
            else:
                player.distance = mini(2, int(player.get("distance",1)) + 1)
        _:
            did_act = false
    if not did_act:
        combat.player = player
        combat.enemy = enemy
        combat.last_error = "action_unavailable"
        return combat
    combat.erase("last_error")
    var resource_gain_amount := 1 + mini(1, maxi(0, int(player.get("resource_gain_bonus", 0))))
    combat.signature_resource = CharacterKitEngine.gain_resource(str(combat.character_id), combat.signature_resource, resource_gain_amount)
    combat.player = player
    combat.enemy = _check_posture_break(enemy)
    PresentationBus.damage("enemy", before_enemy_hp - int(combat.enemy.hp))
    _update_boss_phase()
    if int(combat.enemy.hp) <= 0:
        _finish("victory")
        return combat
    _resolve_enemy()
    _after_round()
    return combat

func use_character_ability(ability_id: String) -> Dictionary:
    if combat.is_empty() or not combat.get("active", false):
        return combat
    var ability := ContentRegistry.get_record(ability_id)
    var before_enemy_hp := int(combat.enemy.hp)
    var result := CharacterKitEngine.execute(ability, combat.player, combat.enemy, combat.signature_resource)
    if not result.get("ok", false):
        combat.last_error = str(result.get("reason", "ability_failed"))
        return combat
    combat.erase("last_error")
    combat.player = result.actor
    combat.enemy = _check_posture_break(result.target)
    combat.signature_resource = result.resources
    PresentationBus.damage("enemy", before_enemy_hp - int(combat.enemy.hp))
    _update_boss_phase()
    if int(combat.enemy.hp) <= 0:
        _finish("victory")
        return combat
    _resolve_enemy()
    _after_round()
    return combat

func _resolve_enemy() -> void:
    var player: Dictionary = combat.player
    var enemy: Dictionary = combat.enemy
    var intent: Dictionary = combat.intent
    var before_player_hp := int(player.hp)
    if intent.get("id", "") == "recover":
        var posture_gain := absi(int(intent.get("posture", -4)))
        enemy.posture = mini(int(enemy.get("posture",0)) + posture_gain, int(enemy.get("max_posture",12)))
    else:
        var damage := DifficultyEngine.scale_enemy_damage(maxi(0, int(intent.get("damage",0))), str(combat.get("difficulty_id", DifficultyEngine.DEFAULT_ID)))
        var hits := maxi(1, int(intent.get("hits",1)))
        for _hit in range(hits):
            var absorbed := mini(damage, int(player.get("guard",0)))
            player.guard = maxi(0, int(player.get("guard",0)) - absorbed)
            player.hp = maxi(0, int(player.hp) - (damage - absorbed))
            if int(player.hp) <= 0:
                break
        if intent.has("posture_damage"):
            player.posture = maxi(0, int(player.get("posture",0)) - int(intent.get("posture_damage",0)))
            player = _check_posture_break(player)
        if intent.has("move") and not StatusEngine.movement_locked(player):
            player.distance = clampi(int(player.distance) + int(intent.move), 0, 2)
        if intent.has("guard"):
            enemy.guard = int(enemy.get("guard",0)) + int(intent.guard)
        if intent.has("status"):
            var resistance := maxi(0, int(player.get("status_resist", 0)))
            var duration := 1 if resistance >= 2 else 2
            player = StatusEngine.apply_status(player, str(intent.status), 1, duration)
        if intent.has("vigor_damage"):
            player.vigor = maxi(0, int(player.get("vigor",0)) - int(intent.vigor_damage))
    combat.player = player
    combat.enemy = enemy
    PresentationBus.damage("player", before_player_hp - int(player.hp))
    if int(player.hp) <= 0:
        _finish("defeat")

func _after_round() -> void:
    if not combat.get("active", false):
        return
    combat.player = StatusEngine.tick(combat.player)
    combat.enemy = StatusEngine.tick(combat.enemy)
    if int(combat.player.hp) <= 0:
        _finish("defeat")
        return
    if int(combat.enemy.hp) <= 0:
        _finish("victory")
        return
    combat.turn = int(combat.turn) + 1
    _sync_run_resources()
    roll_intent()

func _check_posture_break(target: Dictionary) -> Dictionary:
    var result := target
    if int(result.get("posture",1)) <= 0 and not StatusEngine.has_status(result,"exposed"):
        result = StatusEngine.apply_status(result,"exposed",1,2)
        result.posture = int(result.get("max_posture",8))
    return result

func _in_weapon_range(player: Dictionary) -> bool:
    var limits := InventoryEngine.weapon_range()
    var distance := int(player.get("distance",1))
    if InventoryEngine.equipped_item("weapon").is_empty():
        return distance == 0
    var bonus := int(player.get("range_bonus",0))
    return distance >= limits.x and distance <= mini(2, limits.y + bonus)

func _marked_damage_bonus(player: Dictionary, enemy: Dictionary) -> int:
    if not StatusEngine.has_status(enemy, "marked"):
        return 0
    return maxi(0, int(player.get("mark_synergy_bonus", 0)))

func _update_boss_phase() -> void:
    if not bool(combat.get("is_boss",false)):
        return
    var transition := BossPhaseEngine.transition_if_needed(combat.boss_record, int(combat.get("boss_phase",0)), int(combat.enemy.hp), int(combat.enemy.max_hp))
    combat.boss_phase = int(transition.get("index",combat.get("boss_phase",0)))

func _finish(result: String) -> void:
    combat.active = false
    combat.result = result
    _sync_run_resources()

func _sync_run_resources() -> void:
    if combat.is_empty():
        return
    GameState.run.health = int(combat.player.get("hp",GameState.run.get("health",0)))
    var base_max_vigor := maxi(1, int(GameState.run.get("max_vigor", 8)))
    GameState.run.vigor = mini(base_max_vigor, int(combat.player.get("vigor",GameState.run.get("vigor",0))))
