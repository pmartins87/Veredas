extends Node

const WEAPONS := ["short_sword","dagger","axe","spear","bow","hammer"]

func add_item(item_id: String, count: int = 1) -> bool:
    if ContentRegistry.get_record(item_id).is_empty() or count <= 0:
        return false
    var inventory: Array = GameState.run.get("inventory", [])
    for _i in range(count):
        inventory.append(item_id)
    GameState.run.inventory = inventory
    return true

func remove_item(item_id: String, count: int = 1) -> bool:
    if count <= 0 or not has_item(item_id, count):
        return false
    var inventory: Array = GameState.run.get("inventory", [])
    for _i in range(count):
        inventory.erase(item_id)
    GameState.run.inventory = inventory
    var equipped: Dictionary = GameState.run.get("equipped", {})
    for slot in equipped.keys():
        if str(equipped[slot]) == item_id and not has_item(item_id, 1):
            equipped.erase(slot)
    GameState.run.equipped = equipped
    return true

func has_item(item_id: String, count: int = 1) -> bool:
    var found := 0
    for current in GameState.run.get("inventory", []):
        if str(current) == item_id:
            found += 1
    return found >= count

func count_item(item_id: String) -> int:
    var found := 0
    for current in GameState.run.get("inventory", []):
        if str(current) == item_id:
            found += 1
    return found

func slot_for(item: Dictionary) -> String:
    if str(item.get("kind", "")) != "equipment":
        return ""
    var visual := str(item.get("visual_archetype", ""))
    if visual in WEAPONS:
        return "weapon"
    if visual == "shield":
        return "offhand"
    if visual == "helmet":
        return "head"
    if visual in ["chest_armor", "cloak"]:
        return "body"
    if visual == "boots":
        return "feet"
    if visual in ["ring", "amulet", "relic"]:
        return "talisman"
    return "tool"

func equip(item_id: String) -> bool:
    if not has_item(item_id):
        return false
    var item := ContentRegistry.get_record(item_id)
    var slot := slot_for(item)
    if slot == "":
        return false
    var equipped: Dictionary = GameState.run.get("equipped", {})
    equipped[slot] = item_id
    GameState.run.equipped = equipped
    return true

func unequip(slot: String) -> void:
    var equipped: Dictionary = GameState.run.get("equipped", {})
    equipped.erase(slot)
    GameState.run.equipped = equipped

func equipped_item(slot: String) -> Dictionary:
    var item_id := str(GameState.run.get("equipped", {}).get(slot, ""))
    return ContentRegistry.get_record(item_id) if item_id != "" else {}

func use_item(item_id: String) -> bool:
    if not has_item(item_id):
        return false
    var item := ContentRegistry.get_record(item_id)
    if str(item.get("kind", "")) not in ["consumable", "tool"]:
        return false
    if not EffectEngine.apply(item.get("effect", {})):
        return false
    return remove_item(item_id, 1)

func equipment_bonuses() -> Dictionary:
    var result := {"damage":0,"posture":0,"guard":0,"range":0,"status_power":0,"status_resist":0,"load":0}
    for item_id in GameState.run.get("equipped", {}).values():
        var item := ContentRegistry.get_record(str(item_id))
        var effect: Dictionary = item.get("effect", {})
        var op := str(effect.get("op", ""))
        if result.has(op):
            result[op] = int(result[op]) + int(effect.get("value", 0))
    return result
