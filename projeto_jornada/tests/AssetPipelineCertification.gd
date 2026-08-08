extends Node

var failures: Array[String] = []

func _ready() -> void:
    await get_tree().process_frame
    _budget_gate()
    _cache_gate()
    if failures.is_empty():
        print("ASSET_PIPELINE_CERTIFICATION PASS: 8.6")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("ASSET_PIPELINE_CERTIFICATION: %s" % failure)
        print("ASSET_PIPELINE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _budget_gate() -> void:
    var file := FileAccess.open("res://mobile/asset_budgets.json", FileAccess.READ)
    expect(file != null, "8.6 asset budget file missing")
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    expect(typeof(parsed) == TYPE_DICTIONARY, "8.6 asset budget JSON invalid")
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var package: Dictionary = parsed.get("package", {}) as Dictionary
    expect(float(package.get("hard_mb",0)) > float(package.get("soft_mb",9999)), "8.6 hard package budget must exceed soft budget")
    var profiles: Dictionary = parsed.get("profiles", {}) as Dictionary
    for profile in ["domain_key_art","location","character","monster_family","boss","npc","ui"]:
        expect(profiles.has(profile), "8.6 missing image profile %s" % profile)

func _cache_gate() -> void:
    var original_max := MobileAssetCache.max_textures
    MobileAssetCache.release_all()
    MobileAssetCache.max_textures = 2
    var paths := [
        "res://ui/assets/vector/system_icons_atlas.svg",
        "res://ui/assets/vector/mark_glyphs_atlas.svg",
        "res://ui/assets/vector/domain_ornaments_atlas.svg"
    ]
    for path in paths:
        expect(MobileAssetCache.texture(path) != null, "8.6 cache could not load %s" % path)
    expect(MobileAssetCache.cached_count() == 2, "8.6 LRU cache did not enforce bound")
    var cached := MobileAssetCache.cached_paths()
    expect(paths[0] not in cached, "8.6 LRU did not evict oldest texture")
    MobileAssetCache.release_all()
    expect(MobileAssetCache.cached_count() == 0, "8.6 cache release_all failed")
    MobileAssetCache.max_textures = original_max
