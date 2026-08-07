extends Node

const RARITY_PRICE := {"common":8,"uncommon":13,"rare":22,"singular":36,"relic":58,"echo":90}

func price(item_id: String) -> int:
    var item := ContentRegistry.get_record(item_id)
    if item.is_empty():
        return 0
    var rarity := str(item.get("rarity", "common"))
    var base := int(RARITY_PRICE.get(rarity, 8))
    var effect: Dictionary = item.get("effect", {})
    return base + maxi(0, int(effect.get("value", 0)) - 1) * 2

func stock(world_id: String, size: int = 8) -> Array:
    var items: Array = []
    for item in ContentRegistry.all("items"):
        if str(item.get("world_id", "")) == world_id:
            items.append(item)
    items.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
    if items.size() <= size:
        return items
    var offset := abs(int(GameState.run.get("seed", 0)) + int(GameState.run.get("turn", 0)) * 17) % items.size()
    var result: Array = []
    for i in range(size):
        result.append(items[(offset + i * 11) % items.size()])
    return result

func can_buy(item_id: String) -> bool:
    return int(GameState.run.get("resources", {}).get("fragments", 0)) >= price(item_id)

func buy(item_id: String) -> bool:
    var cost := price(item_id)
    if cost <= 0 or not can_buy(item_id):
        return false
    var resources: Dictionary = GameState.run.get("resources", {})
    resources.fragments = int(resources.get("fragments", 0)) - cost
    GameState.run.resources = resources
    return InventoryEngine.add_item(item_id)

func sell(item_id: String) -> bool:
    if not InventoryEngine.has_item(item_id):
        return false
    if not InventoryEngine.remove_item(item_id):
        return false
    var resources: Dictionary = GameState.run.get("resources", {})
    resources.fragments = int(resources.get("fragments", 0)) + maxi(1, price(item_id) / 2)
    GameState.run.resources = resources
    return true
