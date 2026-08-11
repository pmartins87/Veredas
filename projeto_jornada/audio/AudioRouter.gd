extends Node

signal event_routed(event_id: String, category: String, resolved: bool, path: String)
signal domain_routed(domain_id: String, music_resolved: bool, ambience_resolved: bool)

const MANIFEST_PATH := "res://audio/audio_events.json"
const REQUIRED_BUSES := ["Master", "Music", "Ambience", "SFX", "UI"]

var _manifest: Dictionary = {}
var _ui_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer

func _ready() -> void:
    _load_manifest()
    _ensure_audio_buses()
    _ui_player = _make_player("UI", "UI")
    _sfx_player = _make_player("SFX", "SFX")
    _music_player = _make_player("Music", "Music")
    _ambience_player = _make_player("Ambience", "Ambience")
    _bind_presentation_bus()

func _ensure_audio_buses() -> void:
    for bus_name in REQUIRED_BUSES:
        if AudioServer.get_bus_index(bus_name) >= 0:
            continue
        AudioServer.add_bus()
        var index := AudioServer.bus_count - 1
        AudioServer.set_bus_name(index, bus_name)

func _make_player(node_name: String, bus_name: String) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    player.name = node_name
    player.bus = bus_name
    add_child(player)
    return player

func _load_manifest() -> void:
    _manifest.clear()
    if not FileAccess.file_exists(MANIFEST_PATH):
        push_error("AudioRouter: manifest missing")
        return
    var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    if f == null:
        push_error("AudioRouter: cannot open manifest")
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(parsed) == TYPE_DICTIONARY:
        _manifest = parsed
    else:
        push_error("AudioRouter: invalid manifest")

func _bind_presentation_bus() -> void:
    if not PresentationBus.page_changed.is_connected(_on_page_changed):
        PresentationBus.page_changed.connect(_on_page_changed)
    if not PresentationBus.choice_committed.is_connected(_on_choice_committed):
        PresentationBus.choice_committed.connect(_on_choice_committed)
    if not PresentationBus.mark_added.is_connected(_on_mark_added):
        PresentationBus.mark_added.connect(_on_mark_added)
    if not PresentationBus.damage_applied.is_connected(_on_damage_applied):
        PresentationBus.damage_applied.connect(_on_damage_applied)
    if not PresentationBus.intent_revealed.is_connected(_on_intent_revealed):
        PresentationBus.intent_revealed.connect(_on_intent_revealed)
    if not PresentationBus.boss_phase_changed.is_connected(_on_boss_phase_changed):
        PresentationBus.boss_phase_changed.connect(_on_boss_phase_changed)
    if not PresentationBus.location_changed.is_connected(_on_location_changed):
        PresentationBus.location_changed.connect(_on_location_changed)

func _on_page_changed() -> void:
    play_ui("ui.page_turn")

func _on_choice_committed() -> void:
    play_ui("ui.confirm")

func _on_mark_added(_mark_id: String) -> void:
    play_ui("ui.mark_acquired")

func _on_damage_applied(_target: String, _amount: int) -> void:
    play_combat("combat.attack_light")

func _on_intent_revealed(_intent: Dictionary) -> void:
    play_ui("ui.ink_mark")

func _on_boss_phase_changed(_phase_index: int) -> void:
    play_combat("combat.boss_phase")

func _on_location_changed(location_id: String) -> void:
    var domain_id := _domain_id_for_location(location_id)
    if domain_id != "":
        enter_domain(domain_id)

func _domain_id_for_location(location_id: String) -> String:
    if _manifest.get("domains", {}).has(location_id):
        return location_id
    var location := ContentRegistry.get_record(location_id)
    for key in ["domain_id", "world_id"]:
        var candidate := str(location.get(key, ""))
        candidate = candidate.trim_prefix("domain.").trim_prefix("world.")
        if candidate != "" and _manifest.get("domains", {}).has(candidate):
            return candidate
    return ""

func play_ui(event_id: String) -> void:
    var path := str(_manifest.get("ui", {}).get(event_id, ""))
    var resolved := _play_path(_ui_player, path)
    event_routed.emit(event_id, "ui", resolved, path)

func play_combat(event_id: String) -> void:
    var path := str(_manifest.get("combat", {}).get(event_id, ""))
    var resolved := _play_path(_sfx_player, path)
    event_routed.emit(event_id, "combat", resolved, path)

func enter_domain(domain_id: String, crossfade: float = 0.8) -> void:
    var domain: Dictionary = _manifest.get("domains", {}).get(domain_id, {})
    var music_path := str(domain.get("music", ""))
    var ambience_path := str(domain.get("ambience", ""))
    var music_resolved := _crossfade_to(_music_player, music_path, crossfade)
    var ambience_resolved := _crossfade_to(_ambience_player, ambience_path, crossfade)
    domain_routed.emit(domain_id, music_resolved, ambience_resolved)

func stop_domain_audio(fade: float = 0.5) -> void:
    _fade_out(_music_player, fade)
    _fade_out(_ambience_player, fade)

func _play_path(player: AudioStreamPlayer, path: String) -> bool:
    if path == "" or not ResourceLoader.exists(path):
        return false
    var stream = load(path)
    if stream is AudioStream:
        player.stream = stream
        player.play()
        return true
    return false

func _crossfade_to(player: AudioStreamPlayer, path: String, duration: float) -> bool:
    if path == "" or not ResourceLoader.exists(path):
        return false
    var stream = load(path)
    if not stream is AudioStream:
        return false
    var tween := create_tween()
    if player.playing:
        tween.tween_property(player, "volume_db", -30.0, maxf(0.05, duration * 0.5))
    tween.tween_callback(func():
        player.stream = stream
        player.volume_db = -30.0
        player.play()
    )
    tween.tween_property(player, "volume_db", 0.0, maxf(0.05, duration * 0.5))
    return true

func _fade_out(player: AudioStreamPlayer, duration: float) -> void:
    if not player.playing:
        return
    var tween := create_tween()
    tween.tween_property(player, "volume_db", -30.0, duration)
    tween.tween_callback(func():
        player.stop()
        player.volume_db = 0.0
    )

func audit_manifest() -> Dictionary:
    var missing_assets: Array[String] = []
    var invalid_domains: Array[String] = []
    var reference_count := 0
    for category in ["ui", "combat"]:
        var events: Dictionary = _manifest.get(category, {})
        for event_id in events:
            var path := str(events[event_id])
            reference_count += 1
            if path == "" or not ResourceLoader.exists(path):
                missing_assets.append("%s:%s" % [event_id, path])
    var domains: Dictionary = _manifest.get("domains", {})
    for domain_id in domains:
        var domain: Dictionary = domains[domain_id]
        var signature: Array = domain.get("signature", [])
        if signature.size() < 3:
            invalid_domains.append(str(domain_id))
        for layer in ["music", "ambience"]:
            var path := str(domain.get(layer, ""))
            reference_count += 1
            if path == "" or not ResourceLoader.exists(path):
                missing_assets.append("%s.%s:%s" % [domain_id, layer, path])
    var missing_buses: Array[String] = []
    for bus_name in REQUIRED_BUSES:
        if AudioServer.get_bus_index(bus_name) < 0:
            missing_buses.append(bus_name)
    return {
        "schema_version": int(_manifest.get("schema_version", 0)),
        "ui_events": int(_manifest.get("ui", {}).size()),
        "combat_events": int(_manifest.get("combat", {}).size()),
        "domains": int(domains.size()),
        "reference_count": reference_count,
        "missing_assets": missing_assets,
        "missing_buses": missing_buses,
        "invalid_domains": invalid_domains,
    }
