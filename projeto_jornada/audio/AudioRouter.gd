extends Node
class_name AudioRouter

const MANIFEST_PATH := "res://audio/audio_events.json"

var _manifest: Dictionary = {}
var _ui_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer

func _ready() -> void:
    _load_manifest()
    _ui_player = _make_player("UI", "UI")
    _sfx_player = _make_player("SFX", "SFX")
    _music_player = _make_player("Music", "Music")
    _ambience_player = _make_player("Ambience", "Ambience")

func _make_player(node_name: String, bus_name: String) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    player.name = node_name
    player.bus = bus_name
    add_child(player)
    return player

func _load_manifest() -> void:
    if not FileAccess.file_exists(MANIFEST_PATH):
        push_error("AudioRouter: manifest missing")
        return
    var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        _manifest = parsed
    else:
        push_error("AudioRouter: invalid manifest")

func play_ui(event_id: String) -> void:
    _play_path(_ui_player, str(_manifest.get("ui", {}).get(event_id, "")))

func play_combat(event_id: String) -> void:
    _play_path(_sfx_player, str(_manifest.get("combat", {}).get(event_id, "")))

func enter_domain(domain_id: String, crossfade: float = 0.8) -> void:
    var domain: Dictionary = _manifest.get("domains", {}).get(domain_id, {})
    _crossfade_to(_music_player, str(domain.get("music", "")), crossfade)
    _crossfade_to(_ambience_player, str(domain.get("ambience", "")), crossfade)

func stop_domain_audio(fade: float = 0.5) -> void:
    _fade_out(_music_player, fade)
    _fade_out(_ambience_player, fade)

func _play_path(player: AudioStreamPlayer, path: String) -> void:
    if path == "" or not ResourceLoader.exists(path):
        return
    var stream = load(path)
    if stream is AudioStream:
        player.stream = stream
        player.play()

func _crossfade_to(player: AudioStreamPlayer, path: String, duration: float) -> void:
    if path == "" or not ResourceLoader.exists(path):
        return
    var stream = load(path)
    if not stream is AudioStream:
        return
    var tween := create_tween()
    if player.playing:
        tween.tween_property(player, "volume_db", -30.0, maxf(0.05, duration * 0.5))
    tween.tween_callback(func():
        player.stream = stream
        player.volume_db = -30.0
        player.play()
    )
    tween.tween_property(player, "volume_db", 0.0, maxf(0.05, duration * 0.5))

func _fade_out(player: AudioStreamPlayer, duration: float) -> void:
    if not player.playing:
        return
    var tween := create_tween()
    tween.tween_property(player, "volume_db", -30.0, duration)
    tween.tween_callback(func():
        player.stop()
        player.volume_db = 0.0
    )
