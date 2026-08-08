extends Node

func _ready() -> void:
    await get_tree().process_frame
    var policy_script = load("res://core/systems/PlayerPolicyEngine.gd")
    if policy_script == null:
        push_error("SIMULATION_PARSER_PROBE policy load failed")
        get_tree().quit(1)
        return
    print("SIMULATION_PARSER_PROBE policy loaded")
    var simulation_script = load("res://core/systems/JourneySimulationEngine.gd")
    if simulation_script == null:
        push_error("SIMULATION_PARSER_PROBE simulation load failed")
        get_tree().quit(1)
        return
    print("SIMULATION_PARSER_PROBE simulation loaded")
    print("SIMULATION_PARSER_PROBE PASS")
    get_tree().quit(0)
