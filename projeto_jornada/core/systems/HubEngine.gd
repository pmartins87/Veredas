extends Node

const FACILITIES := {
    "hearth": {"name":"Fogueira do Nó","description":"Reúne Andarilhos e preserva relatos de jornadas.","unlock_stage":1},
    "cartography": {"name":"Mesa das Veredas","description":"Registra Domínios, localidades e rotas descobertas.","unlock_stage":1},
    "archive": {"name":"Arquivo de Ecos","description":"Organiza Códice, finais e Marcas de Eco sem apagar versões contraditórias.","unlock_stage":2},
    "workshop": {"name":"Oficina de Relíquias","description":"Cataloga equipamentos e prepara variações horizontais para jornadas futuras.","unlock_stage":3},
    "threshold": {"name":"Limiar de Convergência","description":"Permite preparar jornadas avançadas e alcançar Veredas profundas.","unlock_stage":4},
}

func ensure_state() -> Dictionary:
    var hub: Dictionary = GameState.profile.get("hub", {}) as Dictionary
    if hub.is_empty():
        hub = {
            "stage":1,
            "visit_count":0,
            "residents":[],
            "routes":["world.mata_fio_verde"],
            "facilities":{"hearth":true,"cartography":true,"archive":false,"workshop":false,"threshold":false},
            "history":[],
        }
    GameState.profile.hub = hub
    _recalculate_stage()
    return GameState.profile.hub

func enter() -> Dictionary:
    var hub: Dictionary = ensure_state()
    MetaUnlockEngine.evaluate_progression()
    hub = GameState.profile.get("hub", {}) as Dictionary
    hub.visit_count = int(hub.get("visit_count",0)) + 1
    var history: Array = hub.get("history", [])
    history.push_front({"kind":"visit","at":int(Time.get_unix_time_from_system()),"endings":GameState.profile.get("endings",[]).size()})
    if history.size() > 40:
        history.resize(40)
    hub.history = history
    GameState.profile.hub = hub
    if GameState.run.is_empty():
        GameState.run = {"active":false,"mode":"hub","world_id":"world.mata_fio_verde","location_id":"location.mata_fio_verde.01","health":0,"max_health":0,"vigor":0,"max_vigor":0,"resources":{"fragments":0},"marks":{},"seed":0}
    else:
        GameState.run.active = false
        GameState.run.mode = "hub"
    SaveService.save_game()
    return hub

func stage() -> int:
    return int(ensure_state().get("stage",1))

func facility_state() -> Array:
    var hub: Dictionary = ensure_state()
    var result: Array = []
    var facilities: Dictionary = hub.get("facilities", {}) as Dictionary
    for facility_id in FACILITIES:
        var spec: Dictionary = FACILITIES[facility_id] as Dictionary
        result.append({
            "id":facility_id,
            "name":spec.name,
            "description":spec.description,
            "unlocked":bool(facilities.get(facility_id,false)),
            "unlock_stage":int(spec.unlock_stage),
        })
    result.sort_custom(func(a,b): return int(a.unlock_stage) < int(b.unlock_stage))
    return result

func add_resident(npc_id: String) -> bool:
    var npc: Dictionary = ContentRegistry.get_record(npc_id)
    if npc.is_empty() or not npc_id.begins_with("npc."):
        return false
    var hub: Dictionary = ensure_state()
    var residents: Array = hub.get("residents", [])
    if npc_id not in residents:
        residents.append(npc_id)
        hub.residents = residents
        GameState.profile.hub = hub
        MetaUnlockEngine.discover(npc_id)
        _recalculate_stage()
    return true

func unlock_route(world_id: String) -> bool:
    if not MetaUnlockEngine.unlock_route(world_id):
        return false
    _recalculate_stage()
    return true

func routes() -> Array:
    MetaUnlockEngine.evaluate_progression()
    return (MetaUnlockEngine.ensure_state().get("routes", []) as Array).duplicate()

func residents() -> Array:
    return ensure_state().get("residents", []).duplicate()

func summary() -> Dictionary:
    var hub: Dictionary = ensure_state()
    var unlock_summary: Dictionary = MetaUnlockEngine.summary()
    return {
        "stage":int(hub.get("stage",1)),
        "visits":int(hub.get("visit_count",0)),
        "routes":int(unlock_summary.get("routes",0)),
        "residents":hub.get("residents",[]).size(),
        "endings":GameState.profile.get("endings",[]).size(),
        "codex":int(unlock_summary.get("codex",0)),
        "characters":int(unlock_summary.get("characters",0)),
        "modes":int(unlock_summary.get("modes",0)),
        "facilities":facility_state(),
    }

func _recalculate_stage() -> void:
    var hub: Dictionary = GameState.profile.get("hub", {}) as Dictionary
    if hub.is_empty():
        return
    var milestones: int = int(GameState.profile.get("endings",[]).size()) * 2
    milestones += int(hub.get("routes",[]).size()) - 1
    milestones += mini(4, int(hub.get("residents",[]).size()))
    var new_stage: int = clampi(1 + int(floor(float(milestones) / 3.0)), 1, 5)
    hub.stage = maxi(int(hub.get("stage",1)), new_stage)
    var facilities: Dictionary = hub.get("facilities", {}) as Dictionary
    for facility_id in FACILITIES:
        var spec: Dictionary = FACILITIES[facility_id] as Dictionary
        if int(hub.stage) >= int(spec.unlock_stage):
            facilities[facility_id] = true
    hub.facilities = facilities
    GameState.profile.hub = hub
