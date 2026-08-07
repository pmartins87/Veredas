extends Node

const AFFIXES := [
    {"id":"balanced_knot","name":"Nó Equilibrado","op":"damage","value":1},
    {"id":"resilient_bark","name":"Casca Resiliente","op":"guard","value":2},
    {"id":"conductive_thread","name":"Fio Condutor","op":"status_power","value":2},
    {"id":"hollow_edge","name":"Fio Oco","op":"posture","value":2},
    {"id":"wayfarer","name":"de Andarilho","op":"vigor","value":1},
    {"id":"echo_bound","name":"Vinculado ao Eco","op":"mark_synergy","value":1},
    {"id":"light_load","name":"Carga Leve","op":"load","value":-1},
    {"id":"far_reach","name":"Alcance Longo","op":"range","value":1},
    {"id":"ash_tempered","name":"Temperado em Cinza","op":"status_resist","value":2},
    {"id":"living_metal","name":"Metal Vivo","op":"heal","value":1},
    {"id":"debt_reader","name":"Leitor de Dívida","op":"debt_pressure","value":1},
    {"id":"thread_tuned","name":"Afinado à Trama","op":"resource_gain","value":1},
]

func affixes_for(item: Dictionary) -> Array:
    var rarity: String = str(item.get("rarity", "common"))
    var count: int = int({"common":0,"uncommon":1,"rare":1,"singular":2,"relic":2,"echo":3}.get(rarity, 0))
    if count <= 0:
        return []
    var item_id: String = str(item.get("id", ""))
    var hash_value: int = absi(int(item_id.hash()))
    var result: Array = []
    for i: int in range(count):
        var index: int = int((hash_value + i * 7) % AFFIXES.size())
        result.append((AFFIXES[index] as Dictionary).duplicate(true))
    return result

func combined_effects(item: Dictionary) -> Dictionary:
    var bonuses: Dictionary = {}
    var base: Dictionary = item.get("effect", {}) as Dictionary
    var base_op: String = str(base.get("op", ""))
    if base_op != "":
        bonuses[base_op] = int(base.get("value", 0))
    for affix_variant in affixes_for(item):
        var affix: Dictionary = affix_variant as Dictionary
        var op: String = str(affix.get("op", ""))
        bonuses[op] = int(bonuses.get(op, 0)) + int(affix.get("value", 0))
    return bonuses

func display_name(item: Dictionary) -> String:
    var affixes: Array = affixes_for(item)
    if affixes.is_empty():
        return str(item.get("name", "Item"))
    var first_affix: Dictionary = affixes[0] as Dictionary
    return "%s — %s" % [item.get("name", "Item"), first_affix.get("name", "")]
