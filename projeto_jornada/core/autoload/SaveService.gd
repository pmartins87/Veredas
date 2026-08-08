extends Node

const SAVE_VERSION := 1
const SAVE_PATH := "user://veredas_save.json"
const TEMP_PATH := "user://veredas_save.tmp"

func save_game() -> bool:
    var payload := {"save_schema_version":SAVE_VERSION,"game":GameState.serialize()}
    var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(payload))
    f.close()
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH)) == OK

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return false
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    if int(parsed.get("save_schema_version",0)) > SAVE_VERSION:
        push_error("Save is newer than this build")
        return false
    var game_raw = parsed.get("game", {})
    if typeof(game_raw) != TYPE_DICTIONARY:
        push_error("Save game payload is invalid")
        return false
    return GameState.deserialize(game_raw as Dictionary)
