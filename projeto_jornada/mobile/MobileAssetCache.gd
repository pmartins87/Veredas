extends Node

const DEFAULT_MAX_TEXTURES := 24
var max_textures := DEFAULT_MAX_TEXTURES
var _cache: Dictionary = {}
var _usage: Array[String] = []

func _ready() -> void:
    _load_budget()

func _load_budget() -> void:
    var file := FileAccess.open("res://mobile/asset_budgets.json", FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    max_textures = int((parsed.get("runtime_cache", {}) as Dictionary).get("max_textures", DEFAULT_MAX_TEXTURES))

func texture(path: String) -> Texture2D:
    if path == "":
        return null
    if _cache.has(path):
        _touch(path)
        return _cache[path] as Texture2D
    if not ResourceLoader.exists(path):
        return null
    var loaded = ResourceLoader.load(path)
    if not (loaded is Texture2D):
        return null
    _cache[path] = loaded
    _touch(path)
    _evict_if_needed()
    return loaded as Texture2D

func preload_paths(paths: Array) -> int:
    var loaded := 0
    for path_variant in paths:
        if texture(str(path_variant)) != null:
            loaded += 1
    return loaded

func release(path: String) -> void:
    _cache.erase(path)
    _usage.erase(path)

func release_all() -> void:
    _cache.clear()
    _usage.clear()

func release_except(paths: Array) -> void:
    var keep := {}
    for path_variant in paths:
        keep[str(path_variant)] = true
    for path in _cache.keys():
        if not keep.has(str(path)):
            release(str(path))

func cached_count() -> int:
    return _cache.size()

func cached_paths() -> Array[String]:
    return _usage.duplicate()

func _touch(path: String) -> void:
    _usage.erase(path)
    _usage.append(path)

func _evict_if_needed() -> void:
    while _usage.size() > max_textures:
        var oldest := _usage.pop_front()
        _cache.erase(oldest)
