extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    GameState.reset_profile()
    GameState.run = {}
    var hub := HubEngine.enter()
    expect(int(hub.get("stage",0)) == 1, "9.1 initial hub stage mismatch")
    expect("world.mata_fio_verde" in HubEngine.routes(), "9.1 initial route missing")
    expect(bool((hub.get("facilities",{}) as Dictionary).get("hearth",false)), "9.1 hearth not available")
    expect(not bool((hub.get("facilities",{}) as Dictionary).get("threshold",true)), "9.1 advanced threshold unlocked too early")
    expect(HubEngine.add_resident("npc.mata_fio_verde.01"), "9.1 could not add resident")
    expect(HubEngine.unlock_route("world.varzea_espelhos"), "9.1 could not unlock route")
    GameState.profile.endings = ["ending.mata_fio_verde.01","ending.mata_fio_verde.02"]
    HubEngine.ensure_state()
    expect(HubEngine.stage() >= 2, "9.1 hub did not grow from milestones")
    expect(SaveService.save_game(), "9.1 hub profile save failed")
    GameState.profile.hub = {}
    expect(SaveService.load_game(), "9.1 hub profile reload failed")
    expect("npc.mata_fio_verde.01" in HubEngine.residents(), "9.1 resident did not persist")
    expect("world.varzea_espelhos" in HubEngine.routes(), "9.1 route did not persist")
    expect(ResourceLoader.exists("res://scenes/Hub.tscn"), "9.1 hub scene missing")
    expect(str(ProjectSettings.get_setting("application/run/main_scene","")) == "res://scenes/Hub.tscn", "9.1 hub is not entry scene")
    if failures.is_empty():
        print("HUB_CERTIFICATION PASS: 9.1")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("HUB_CERTIFICATION: %s" % failure)
        print("HUB_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
