extends Node

var combat: Dictionary = {}

func start(enemy_id: String, character_id: String) -> Dictionary:
    var enemy := ContentRegistry.get_record(enemy_id)
    var character := ContentRegistry.get_record(character_id)
    var enemy_hp := int(enemy.get("hp", 12))
    combat = {
        "active": true,
        "turn": 1,
        "player": {"hp":16,"max_hp":16,"posture":10,"guard":0,"distance":1,"states":[]},
        "enemy": {"id":enemy_id,"name":enemy.get("name","Enemy"),"hp":enemy_hp,"max_hp":enemy_hp,"posture":int(enemy.get("posture",8)),"guard":0,"distance":1,"states":[]},
        "character_id": character_id,
        "signature_resource": {str(character.get("resource", "Focus")): 0},
        "intent": {},
        "is_boss": enemy_id.begins_with("boss."),
        "boss_phase": 0,
    }
    roll_intent()
    return combat

func roll_intent() -> Dictionary:
    if combat.is_empty():
        return {}
    var enemy: Dictionary = combat.enemy
    var hp_ratio := float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
    var roll := RNGService.next_float()
    var intent := {}
    if hp_ratio < 0.30 and roll < 0.35:
        intent = {"id":"recover","telegraph":"recua e recompõe a postura","damage":0,"posture":-3}
    elif roll < 0.45:
        intent = {"id":"heavy","telegraph":"prepara um golpe pesado","damage":5,"posture":2}
    elif roll < 0.75:
        intent = {"id":"pressure","telegraph":"avança para limitar seu espaço","damage":3,"move":-1}
    else:
        intent = {"id":"guard","telegraph":"fecha a guarda e observa","damage":1,"guard":3}
    combat.intent = intent
    PresentationBus.intent(intent)
    return intent

func player_action(action: String) -> Dictionary:
    if combat.is_empty() or not combat.get("active", false):
        return combat
    var player: Dictionary = combat.player
    var enemy: Dictionary = combat.enemy
    var before_enemy_hp := int(enemy.hp)
    match action:
        "strike":
            var dealt := maxi(0, 4 - int(enemy.get("guard", 0)))
            enemy.hp = maxi(0, int(enemy.hp) - dealt)
            enemy.guard = 0
        "precise":
            enemy.hp = maxi(0, int(enemy.hp) - 3)
            enemy.posture = maxi(0, int(enemy.posture) - 4)
        "guard":
            player.guard = int(player.get("guard", 0)) + 4
        "advance":
            player.distance = maxi(0, int(player.get("distance", 1)) - 1)
        "retreat":
            player.distance = mini(2, int(player.get("distance", 1)) + 1)
        _:
            pass
    combat.player = player
    combat.enemy = enemy
    var enemy_damage := before_enemy_hp - int(enemy.hp)
    PresentationBus.damage("enemy", enemy_damage)
    _update_boss_phase()
    if int(enemy.hp) <= 0:
        combat.active = false
        combat.result = "victory"
        return combat
    _resolve_enemy()
    combat.turn = int(combat.turn) + 1
    if combat.get("active", false):
        roll_intent()
    return combat

func use_character_ability(ability_id: String) -> Dictionary:
    if combat.is_empty() or not combat.get("active", false):
        return combat
    var ability := ContentRegistry.get_record(ability_id)
    var before_enemy_hp := int(combat.enemy.hp)
    var result := CharacterKitEngine.execute(ability, combat.player, combat.enemy, combat.signature_resource)
    if not result.get("ok", false):
        return combat
    combat.player = result.actor
    combat.enemy = result.target
    combat.signature_resource = result.resources
    PresentationBus.damage("enemy", before_enemy_hp - int(combat.enemy.hp))
    _update_boss_phase()
    if int(combat.enemy.hp) <= 0:
        combat.active = false
        combat.result = "victory"
        return combat
    _resolve_enemy()
    combat.turn = int(combat.turn) + 1
    if combat.get("active", false):
        roll_intent()
    return combat

func _resolve_enemy() -> void:
    var player: Dictionary = combat.player
    var enemy: Dictionary = combat.enemy
    var intent: Dictionary = combat.intent
    var before_player_hp := int(player.hp)
    if intent.get("id", "") == "recover":
        enemy.posture = mini(int(enemy.get("posture", 0)) + 3, 12)
    else:
        var damage := int(intent.get("damage", 0))
        var absorbed := mini(damage, int(player.get("guard", 0)))
        player.guard = maxi(0, int(player.get("guard", 0)) - absorbed)
        player.hp = maxi(0, int(player.hp) - (damage - absorbed))
        if intent.has("move"):
            player.distance = clampi(int(player.distance) + int(intent.move), 0, 2)
        if intent.has("guard"):
            enemy.guard = int(enemy.get("guard", 0)) + int(intent.guard)
    combat.player = player
    combat.enemy = enemy
    PresentationBus.damage("player", before_player_hp - int(player.hp))
    if int(player.hp) <= 0:
        combat.active = false
        combat.result = "defeat"

func _update_boss_phase() -> void:
    if not bool(combat.get("is_boss", false)):
        return
    var enemy: Dictionary = combat.enemy
    var ratio := float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
    var new_phase := 0
    if ratio <= 0.33:
        new_phase = 2
    elif ratio <= 0.66:
        new_phase = 1
    var old_phase := int(combat.get("boss_phase", 0))
    if new_phase > old_phase:
        combat.boss_phase = new_phase
        PresentationBus.boss_phase(new_phase)
