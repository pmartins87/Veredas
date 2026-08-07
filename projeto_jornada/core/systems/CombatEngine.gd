extends Node

var combat: Dictionary = {}

func start(enemy_id: String, character_id: String) -> Dictionary:
    var enemy := ContentRegistry.get_record(enemy_id)
    var character := ContentRegistry.get_record(character_id)
    combat = {"active":true,"turn":1,"player":{"hp":16,"max_hp":16,"posture":10,"guard":0,"distance":1,"states":[]},"enemy":{"id":enemy_id,"name":enemy.get("name","Enemy"),"hp":int(enemy.get("hp",12)),"max_hp":int(enemy.get("hp",12)),"posture":int(enemy.get("posture",8)),"guard":0,"distance":1,"states":[]},"character_id":character_id,"signature_resource":{str(character.get("resource","Focus")):0},"intent":{}}
    roll_intent()
    return combat

func roll_intent() -> Dictionary:
    if combat.is_empty(): return {}
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
    return intent

func player_action(action: String) -> Dictionary:
    if combat.is_empty() or not combat.get("active", false): return combat
    var p: Dictionary = combat.player
    var e: Dictionary = combat.enemy
    match action:
        "strike":
            var dealt := maxi(0, 4 - int(e.get("guard",0))); e.hp = maxi(0, int(e.hp)-dealt); e.guard = 0
        "precise": e.hp = maxi(0,int(e.hp)-3); e.posture = maxi(0,int(e.posture)-4)
        "guard": p.guard = int(p.get("guard",0)) + 4
        "advance": p.distance = maxi(0,int(p.get("distance",1))-1)
        "retreat": p.distance = mini(2,int(p.get("distance",1))+1)
        _: pass
    combat.player = p; combat.enemy = e
    if int(e.hp) <= 0:
        combat.active = false; combat.result = "victory"; return combat
    _resolve_enemy()
    combat.turn = int(combat.turn) + 1
    if combat.get("active", false): roll_intent()
    return combat

func use_character_ability(ability_id: String) -> Dictionary:
    var ability := ContentRegistry.get_record(ability_id)
    var result := CharacterKitEngine.execute(ability, combat.player, combat.enemy, combat.signature_resource)
    if not result.get("ok", false): return combat
    combat.player = result.actor; combat.enemy = result.target; combat.signature_resource = result.resources
    if int(combat.enemy.hp) <= 0:
        combat.active = false; combat.result = "victory"; return combat
    _resolve_enemy(); combat.turn = int(combat.turn)+1
    if combat.get("active", false): roll_intent()
    return combat

func _resolve_enemy() -> void:
    var p: Dictionary = combat.player; var e: Dictionary = combat.enemy; var intent: Dictionary = combat.intent
    if intent.get("id","") == "recover": e.posture = mini(int(e.get("posture",0))+3,12)
    else:
        var damage := int(intent.get("damage",0)); var absorbed := mini(damage,int(p.get("guard",0)))
        p.guard = maxi(0,int(p.get("guard",0))-absorbed); p.hp = maxi(0,int(p.hp)-(damage-absorbed))
        if intent.has("move"): p.distance = clampi(int(p.distance)+int(intent.move),0,2)
        if intent.has("guard"): e.guard = int(e.get("guard",0))+int(intent.guard)
    combat.player = p; combat.enemy = e
    if int(p.hp) <= 0: combat.active = false; combat.result = "defeat"
