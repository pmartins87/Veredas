extends Node

const DATA_DIR := "res://data"
var by_id: Dictionary = {}
var by_type: Dictionary = {}

func _ready() -> void:
    reload()

func reload() -> void:
    by_id.clear()
    by_type.clear()
    var dir := DirAccess.open(DATA_DIR)
    if dir == null:
        push_error("ContentRegistry: missing data dir")
        return
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".json"):
            _load_file(DATA_DIR.path_join(file_name))
        file_name = dir.get_next()
    dir.list_dir_end()

func _load_file(path: String) -> void:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        push_error("ContentRegistry: cannot open %s" % path)
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_ARRAY:
        push_error("ContentRegistry: expected array in %s" % path)
        return
    var type_name := path.get_file().get_basename()
    var bucket: Array = []
    for entry in parsed:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var id := str(entry.get("id", ""))
        if id == "":
            push_error("ContentRegistry: missing id in %s" % path)
            continue
        if by_id.has(id):
            push_error("ContentRegistry: duplicate id %s" % id)
            continue
        by_id[id] = entry
        bucket.append(entry)
    by_type[type_name] = bucket

func get_record(id: String) -> Dictionary:
    return by_id.get(id, {})

func all(type_name: String) -> Array:
    return by_type.get(type_name, [])
