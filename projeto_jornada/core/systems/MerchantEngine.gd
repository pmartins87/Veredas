extends Node

const RARITY_PRICE := {"common":8,"uncommon":13,"rare":22,"singular":36,"relic":58,"echo":90}

func price(item_id: String) -> int:
    var item: Dictionary = ContentRegistry.get_record(item_id)
    if item.is_empty():
        return 0
    var rarity: String = str(item.get("rarity", "common"))
    var base_price: int = int(RARITY_PRICE.get(rarity, 8))
    var effect: Dictionary = item.get("effect", {}) as Dictionary
    return base_price + maxi(0, int(effect.get("value", 0)) - 1) * 2

func stock(world_id: String, size: int = 8) -> Array:
    var items: Array = []
    for item_variant in ContentRegistry.all("items"):
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("world_id", "")) == world_id:
            items.append(item)
    items.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
    if items.size() <= size:
        return items
    var seed_value: int = int(GameState.run.get("seed", 0))
    var turn_value: int = int(GameState.run.get("turn", 0))
    var offset: int = absi(seed_value + turn_value * 17) % items.size()
    var result: Array = []
    for i: int in range(size):
        var index: int = int((offset + i * 11) % items.size())
        result.append(items[index])
    return result

func can_buy(item_id: String) -> bool:
    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    return int(resources.get("fragments", 0)) >= price(item_id)

func buy(item_id: String) -> bool:
    var cost: int = price(item_id)
    if cost <= 0 or not can_buy(item_id):
        return false
    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    resources.fragments = int(resources.get("fragments", 0)) - cost
    GameState.run.resources = resources
    return InventoryEngine.add_item(item_id)

func sell(item_id: String) -> bool:
    if not InventoryEngine.has_item(item_id):
        return false
    if not InventoryEngine.remove_item(item_id):
        return false
    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    resources.fragments = int(resources.get("fragments", 0)) + maxi(1, price(item_id) / 2)
    GameState.run.resources = resources
    return true
