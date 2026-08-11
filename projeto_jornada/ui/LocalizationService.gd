extends RefCounted
class_name LocalizationService

const MANIFEST_PATH := "res://localization/manifest.json"
const UI_DIR := "res://localization/ui"
const CONTENT_DIR := "res://localization/content"
const LABEL_DIR := "res://localization/labels"

var _manifest: Dictionary = {}
var _ui_catalogs: Dictionary = {}
var _content_catalogs: Dictionary = {}
var _label_catalogs: Dictionary = {}
var _errors: Array[String] = []

func _init() -> void:
    _load()

func is_ready() -> bool:
    return _errors.is_empty() and not _manifest.is_empty()

func errors() -> Array[String]:
    return _errors.duplicate()

func manifest() -> Dictionary:
    return _manifest.duplicate(true)

func source_locale() -> String:
    return str(_manifest.get("source_locale", "pt_BR"))

func launch_locales() -> Array[String]:
    var result: Array[String] = []
    for locale_variant in _manifest.get("launch_locales", []):
        result.append(str(locale_variant))
    return result

func locale_label(locale_id: String) -> String:
    var resolved := resolve_locale(locale_id, false)
    if resolved == "":
        return locale_id
    var locales: Dictionary = _manifest.get("locales", {}) as Dictionary
    var entry: Dictionary = locales.get(resolved, {}) as Dictionary
    return str(entry.get("native_name", resolved))

func resolve_locale(raw_locale: String, allow_fallback: bool = true) -> String:
    var raw := raw_locale.strip_edges()
    if raw == "":
        return source_locale() if allow_fallback else ""
    var launch := launch_locales()
    if raw in launch:
        return raw
    var normalized := raw.replace("-", "_")
    if normalized in launch:
        return normalized
    var aliases: Dictionary = _manifest.get("aliases", {}) as Dictionary
    for alias_variant in aliases.keys():
        var alias := str(alias_variant)
        if alias.to_lower().replace("-", "_") == normalized.to_lower():
            var target := str(aliases.get(alias_variant, ""))
            if target in launch:
                return target
    var lower := normalized.to_lower()
    if lower.begins_with("pt") and "pt_BR" in launch:
        return "pt_BR"
    if lower.begins_with("en") and "en" in launch:
        return "en"
    if lower.begins_with("es") and "es_419" in launch:
        return "es_419"
    return source_locale() if allow_fallback else ""

func is_supported(raw_locale: String) -> bool:
    return resolve_locale(raw_locale, false) != ""

func current_locale() -> String:
    var settings: Dictionary = GameState.profile.get("settings", {}) as Dictionary
    var stored := str(settings.get("locale", source_locale()))
    return resolve_locale(stored, true)

func set_locale(raw_locale: String, persist: bool = false) -> bool:
    var resolved := resolve_locale(raw_locale, false)
    if resolved == "":
        return false
    var settings: Dictionary = GameState.profile.get("settings", {}) as Dictionary
    settings["locale"] = resolved
    GameState.profile.settings = settings
    if persist:
        return SaveService.save_game()
    return true

func text(key: String, values: Dictionary = {}, locale_id: String = "") -> String:
    var locale := current_locale() if locale_id == "" else resolve_locale(locale_id, true)
    var raw := _catalog_text(locale, key)
    if raw == "" and locale != source_locale():
        raw = _catalog_text(source_locale(), key)
    if raw == "":
        raw = key
    return _format(raw, values)

func has_ui_key(locale_id: String, key: String) -> bool:
    var resolved := resolve_locale(locale_id, false)
    if resolved == "" or not _ui_catalogs.has(resolved):
        return false
    return (_ui_catalogs[resolved] as Dictionary).has(key)

func placeholders(locale_id: String, key: String) -> Array[String]:
    var resolved := resolve_locale(locale_id, false)
    if resolved == "":
        return []
    var raw := _catalog_text(resolved, key)
    return _placeholders_in(raw)

func label(field: String, canonical_value: String, locale_id: String = "") -> String:
    var locale := current_locale() if locale_id == "" else resolve_locale(locale_id, true)
    var translated := _label_text(locale, field, canonical_value)
    if translated == "" and locale != source_locale():
        translated = _label_text(source_locale(), field, canonical_value)
    return canonical_value if translated == "" else translated

func has_label(locale_id: String, field: String, canonical_value: String) -> bool:
    var resolved := resolve_locale(locale_id, false)
    if resolved == "":
        return false
    return _label_text(resolved, field, canonical_value) != ""

func content_value(record: Dictionary, path: String, locale_id: String = "") -> Variant:
    var localized := localize_record(record, locale_id)
    return _value_at_path(localized, path)

func localize_record(record: Dictionary, locale_id: String = "") -> Dictionary:
    var result := record.duplicate(true)
    var locale := current_locale() if locale_id == "" else resolve_locale(locale_id, true)
    if locale == source_locale():
        return result
    var overlay := _content_overlay(locale, str(record.get("id", "")))
    var allowed: Array = _manifest.get("content_overlay_fields", []) as Array
    for path_variant in overlay.keys():
        var path := str(path_variant)
        var parts := path.split(".", false)
        if parts.is_empty():
            continue
        var terminal := str(parts[parts.size() - 1])
        if terminal not in allowed:
            continue
        var value = overlay[path_variant]
        if typeof(value) != TYPE_STRING:
            continue
        _set_value_at_path(result, path, value)
    return result

func _load() -> void:
    _errors.clear()
    _ui_catalogs.clear()
    _content_catalogs.clear()
    _label_catalogs.clear()
    _manifest = _load_json_object(MANIFEST_PATH, "manifest")
    if _manifest.is_empty():
        return
    for locale_id in launch_locales():
        _ui_catalogs[locale_id] = _load_json_object("%s/%s.json" % [UI_DIR, locale_id], "ui:%s" % locale_id)
        _content_catalogs[locale_id] = _load_json_object("%s/%s.json" % [CONTENT_DIR, locale_id], "content:%s" % locale_id)
        _label_catalogs[locale_id] = _load_json_object("%s/%s.json" % [LABEL_DIR, locale_id], "labels:%s" % locale_id)

func _load_json_object(path: String, label_name: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        _errors.append("missing:%s:%s" % [label_name, path])
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _errors.append("open:%s:%s" % [label_name, path])
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        _errors.append("json_object:%s:%s" % [label_name, path])
        return {}
    return (parsed as Dictionary).duplicate(true)

func _catalog_text(locale_id: String, key: String) -> String:
    if not _ui_catalogs.has(locale_id):
        return ""
    var catalog: Dictionary = _ui_catalogs[locale_id] as Dictionary
    return str(catalog.get(key, ""))

func _label_text(locale_id: String, field: String, canonical_value: String) -> String:
    if not _label_catalogs.has(locale_id):
        return ""
    var catalog: Dictionary = _label_catalogs[locale_id] as Dictionary
    var field_map_variant = catalog.get(field, {})
    if typeof(field_map_variant) != TYPE_DICTIONARY:
        return ""
    var field_map: Dictionary = field_map_variant as Dictionary
    return str(field_map.get(canonical_value, ""))

func _content_overlay(locale_id: String, record_id: String) -> Dictionary:
    if record_id == "" or not _content_catalogs.has(locale_id):
        return {}
    var catalog: Dictionary = _content_catalogs[locale_id] as Dictionary
    var raw = catalog.get(record_id, {})
    return (raw as Dictionary).duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func _value_at_path(root: Variant, path: String) -> Variant:
    var current = root
    for part_variant in path.split(".", false):
        var part := str(part_variant)
        if typeof(current) == TYPE_DICTIONARY:
            var dictionary: Dictionary = current as Dictionary
            if not dictionary.has(part):
                return null
            current = dictionary[part]
        elif typeof(current) == TYPE_ARRAY:
            if not part.is_valid_int():
                return null
            var index := int(part)
            var array: Array = current as Array
            if index < 0 or index >= array.size():
                return null
            current = array[index]
        else:
            return null
    return current

func _set_value_at_path(root: Dictionary, path: String, value: String) -> bool:
    var parts := path.split(".", false)
    if parts.is_empty():
        return false
    var current: Variant = root
    for i in range(parts.size() - 1):
        var part := str(parts[i])
        if typeof(current) == TYPE_DICTIONARY:
            var dictionary: Dictionary = current as Dictionary
            if not dictionary.has(part):
                return false
            current = dictionary[part]
        elif typeof(current) == TYPE_ARRAY:
            if not part.is_valid_int():
                return false
            var index := int(part)
            var array: Array = current as Array
            if index < 0 or index >= array.size():
                return false
            current = array[index]
        else:
            return false
    var last := str(parts[parts.size() - 1])
    if typeof(current) == TYPE_DICTIONARY:
        var dictionary: Dictionary = current as Dictionary
        if not dictionary.has(last) or typeof(dictionary[last]) != TYPE_STRING:
            return false
        dictionary[last] = value
        return true
    if typeof(current) == TYPE_ARRAY:
        if not last.is_valid_int():
            return false
        var index := int(last)
        var array: Array = current as Array
        if index < 0 or index >= array.size() or typeof(array[index]) != TYPE_STRING:
            return false
        array[index] = value
        return true
    return false

func _format(raw: String, values: Dictionary) -> String:
    var result := raw
    for key_variant in values.keys():
        result = result.replace("{%s}" % str(key_variant), str(values[key_variant]))
    return result

func _placeholders_in(raw: String) -> Array[String]:
    var result: Array[String] = []
    var regex := RegEx.new()
    if regex.compile("\\{([A-Za-z0-9_]+)\\}") != OK:
        return result
    for match_variant in regex.search_all(raw):
        var value := str((match_variant as RegExMatch).get_string(1))
        if value not in result:
            result.append(value)
    result.sort()
    return result
