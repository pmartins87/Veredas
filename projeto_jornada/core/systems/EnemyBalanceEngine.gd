extends RefCounted
class_name EnemyBalanceEngine

const MECHANICS := [
    "distance_pressure",
    "status_combo",
    "posture_break",
    "defense_cycle",
    "multi_attack",
    "telegraphed_range",
    "resource_drain",
    "intent_trick",
]

func roll_intent(enemy_record: Dictionary, phase: Dictionary, roll: float) -> Dictionary:
    var mechanic := str(phase.get("mechanic", enemy_record.get("mechanic", "distance_pressure")))
    if mechanic not in MECHANICS:
        mechanic = "distance_pressure"
    var status_id := str(phase.get("status", enemy_record.get("domain_status", "fear")))
    var intent := _base_intent(mechanic, clampf(roll, 0.0, 0.999999), status_id)
    return _apply_modifiers(intent, enemy_record, phase)

func _base_intent(mechanic: String, roll: float, status_id: String) -> Dictionary:
    match mechanic:
        "distance_pressure":
            if roll < 0.42:
                return {"id":"pressure","telegraph":"abaixa o centro de peso e avança para fechar o espaço","damage":3,"move":-1}
            if roll < 0.68:
                return {"id":"lunge","telegraph":"estende o corpo inteiro em uma investida comprometida","damage":4,"move":-1}
            if roll < 0.86:
                return {"id":"guard","telegraph":"fecha a linha de aproximação e espera seu passo","damage":1,"guard":3}
            return {"id":"recover","telegraph":"cede terreno para recompor a postura","damage":0,"posture":-4}
        "status_combo":
            if roll < 0.40:
                return {"id":"inflict","telegraph":"prepara um contato contaminado que deixa um segundo problema para depois","damage":2,"status":status_id}
            if roll < 0.67:
                return {"id":"heavy","telegraph":"ergue o golpe para explorar o estado que acabou de criar","damage":4}
            if roll < 0.85:
                return {"id":"guard","telegraph":"protege a abertura enquanto o efeito se acumula","damage":1,"guard":3}
            return {"id":"recover","telegraph":"se afasta para prolongar o desgaste","damage":0,"posture":-3}
        "posture_break":
            if roll < 0.44:
                return {"id":"crush","telegraph":"mira seu apoio em vez de sua vida","damage":3,"posture_damage":4}
            if roll < 0.70:
                return {"id":"heavy","telegraph":"carrega um golpe pesado que ameaça romper sua base","damage":5,"posture_damage":2}
            if roll < 0.87:
                return {"id":"guard","telegraph":"ancora o próprio peso e força você a iniciar a troca","damage":1,"guard":3}
            return {"id":"recover","telegraph":"reassenta a postura antes de outra tentativa de ruptura","damage":0,"posture":-4}
        "defense_cycle":
            if roll < 0.34:
                return {"id":"guard","telegraph":"fecha a guarda e convida você a gastar recursos primeiro","damage":1,"guard":5}
            if roll < 0.54:
                return {"id":"recover","telegraph":"usa a janela defensiva para reconstruir a postura","damage":0,"posture":-5}
            if roll < 0.80:
                return {"id":"heavy","telegraph":"abandona a defesa por um único golpe pesado","damage":4}
            return {"id":"pressure","telegraph":"avança atrás da própria guarda","damage":2,"move":-1}
        "multi_attack":
            if roll < 0.46:
                return {"id":"flurry","telegraph":"divide o ataque em duas batidas rápidas","damage":2,"hits":2}
            if roll < 0.70:
                return {"id":"pressure","telegraph":"encadeia passos curtos para manter você ocupado","damage":3,"move":-1}
            if roll < 0.88:
                return {"id":"guard","telegraph":"interrompe a sequência e cobre a resposta","damage":1,"guard":2}
            return {"id":"heavy","telegraph":"condensa a sequência inteira em um golpe pesado","damage":5}
        "telegraphed_range":
            if roll < 0.44:
                return {"id":"volley","telegraph":"marca a trajetória antes de disparar de longe","damage":4}
            if roll < 0.64:
                return {"id":"guard","telegraph":"protege o intervalo para preparar outro disparo","damage":1,"guard":3}
            if roll < 0.84:
                return {"id":"heavy","telegraph":"firma a mira para um disparo mais lento e pesado","damage":5}
            return {"id":"recover","telegraph":"recalibra alcance e postura","damage":0,"posture":-3}
        "resource_drain":
            if roll < 0.42:
                return {"id":"drain","telegraph":"mira seu fôlego e não sua carne","damage":2,"vigor_damage":2}
            if roll < 0.68:
                return {"id":"heavy","telegraph":"prepara impacto que também esgota sua reserva","damage":4,"vigor_damage":1}
            if roll < 0.86:
                return {"id":"pressure","telegraph":"mantém pressão para impedir recuperação confortável","damage":3,"move":-1}
            return {"id":"guard","telegraph":"espera você gastar o que ainda tem","damage":1,"guard":3}
        "intent_trick":
            if roll < 0.38:
                return {"id":"feint","telegraph":"mostra uma abertura deliberadamente imperfeita","damage":3}
            if roll < 0.62:
                return {"id":"guard","telegraph":"parece recuar, mas conserva o peso pronto para reagir","damage":1,"guard":3}
            if roll < 0.84:
                return {"id":"pressure","telegraph":"troca a linha do ataque no último instante e avança","damage":3,"move":-1}
            return {"id":"heavy","telegraph":"abandona o blefe e compromete todo o peso","damage":4}
    return {"id":"pressure","telegraph":"avança de forma legível","damage":3,"move":-1}

func _apply_modifiers(intent: Dictionary, enemy_record: Dictionary, phase: Dictionary) -> Dictionary:
    var result := intent.duplicate(true)
    var intent_id := str(result.get("id", ""))
    var affix: Dictionary = enemy_record.get("elite_affix_data", {}) as Dictionary
    var offensive := intent_id not in ["guard", "recover"]

    if offensive:
        result.damage = maxi(0, int(result.get("damage", 0)) + int(enemy_record.get("damage_bonus", 0)) + int(phase.get("damage_bonus", 0)))
    if intent_id == "guard":
        result.guard = maxi(0, int(result.get("guard", 0)) + int(phase.get("guard_bonus", 0)))
    if intent_id == "heavy":
        result.damage = maxi(0, int(result.get("damage", 0)) + int(affix.get("heavy_bonus", 0)))
    if intent_id in ["pressure", "lunge"]:
        result.damage = maxi(0, int(result.get("damage", 0)) + int(affix.get("pressure_bonus", 0)))
    if offensive and str(affix.get("status", "")) != "":
        result.status = str(affix.get("status", ""))
    if offensive and int(affix.get("vigor_damage", 0)) > 0:
        result.vigor_damage = int(result.get("vigor_damage", 0)) + int(affix.get("vigor_damage", 0))
    if offensive and int(affix.get("posture_damage", 0)) > 0:
        result.posture_damage = int(result.get("posture_damage", 0)) + int(affix.get("posture_damage", 0))
    return result
