extends Node

var combat: Dictionary = {}

func start(enemy_id: String, character_id: String) -> Dictionary:
    var enemy_record := ContentRegistry.get_record(enemy_id)
    if enemy_record.is_empty():
        return {}
    var is_boss := enemy_id.begins_with("boss.")
    var enemy_hp := int(enemy_record.get("hp", 30 if is_boss else 12))
    var enemy_posture := int(enemy_record.get("posture", 18 if is_boss else 8))
    var bonuses := InventoryEngine.equipment_bonuses()
    var player_hp := int(GameState.run.get("health", 16))
    var player_vigor := int(GameState.run.get("vigor", 8))
    combat = {
        "active": true,
        "turn": 1,
        "player": {
            "hp":player_hp,"max_hp":int(GameState.run.get("max_health",16)),
            "vigor":player_vigor,"max_vigor":int(GameState.run.get("max_vigor",8)),
            "posture":10 + int(bonuses.get("posture",0)),
            "max_posture":10 + int(bonuses.get("posture",0)),
            "guard":int(bonuses.get("guard",0)),"distance":1,"states":[],
            "damage_bonus":int(bonuses.get("damage",0)),
            "posture_bonus":int(bonuses.get("posture",0)),
            "range_bonus":int(bonuses.get("range",0)),
        },
        "enemy": {
            "id":enemy_id,"name":enemy_record.get("name","Enemy"),
            "hp":enemy_hp,"max_hp":enemy_hp,"posture":enemy_posture,"max_posture":enemy_posture,
            "guard":0,"distance":1,"states":[],"mechanic":enemy_record.get("mechanic","")
        },
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
    var hp_ratio := float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
    var roll := RNGService.next_float()
    var intent: Dictionary = {}
    var mechanic := str(enemy.get("mechanic", ""))
    if bool(combat.get("is_boss", false)):
        roll = clampf(roll - 0.05 * int(combat.get("boss_phase", 0)), 0.0, 1.0)
    if hp_ratio < 0.30 and roll < 0.28:
        intent = {"id":"recover","telegraph":"recua e recompõe a postura","damage":0,"posture":-4}
    elif roll < 0.42:
        intent = {"id":"heavy","telegraph":"prepara um golpe pesado","damage":5,"posture":2}
    elif roll < 0.72:
        intent = {"id":"pressure","telegraph":"avança para limitar seu espaço","damage":3,"move":-1}
    else:
        intent = {"id":"guard","telegraph":"fecha a guarda e observa","damage":1,"guard":3}
    if mechanic == "status_combo" and intent.id == "pressure":
        intent.status = "wet"
    elif mechanic == "resource_drain" and intent.id == "heavy":
        intent.vigor_damage = 1
    elif mechanic == "intent_trick" and intent.id == "guard":
        intent.telegraph = "desvia o olhar, mas mantém o peso pronto para reagir"
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
    match action:
        "strike":
            if _in_weapon_range(player):
                var raw := 4 + int(player.get("damage_bonus",0))
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
                var damage := roundi(float(3 + int(player.get("damage_bonus",0))) * StatusEngine.damage_multiplier(enemy))
                enemy.hp = maxi(0, int(enemy.hp) - damage)
                enemy.posture = maxi(0, int(enemy.posture) - (4 + int(player.get("posture_bonus",0))))
        "guard":
            player.guard = int(player.get("guard",0)) + 4
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
    combat.signature_resource = CharacterKitEngine.gain_resource(str(combat.character_id), combat.signature_resource, 1)
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
        enemy.posture = mini(int(enemy.get("posture",0)) + 4, int(enemy.get("max_posture",12)))
    else:
        var damage := int(intent.get("damage",0))
        var absorbed := mini(damage, int(player.get("guard",0)))
        player.guard = maxi(0, int(player.get("guard",0)) - absorbed)
        player.hp = maxi(0, int(player.hp) - (damage - absorbed))
        if intent.has("move") and not StatusEngine.movement_locked(player):
            player.distance = clampi(int(player.distance) + int(intent.move), 0, 2)
        if intent.has("guard"):
            enemy.guard = int(enemy.get("guard",0)) + int(intent.guard)
        if intent.has("status"):
            player = StatusEngine.apply_status(player, str(intent.status), 1, 2)
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
    GameState.run.vigor = int(combat.player.get("vigor",GameState.run.get("vigor",0)))
