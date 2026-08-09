extends Node

func trading_disabled() -> bool:
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    return bool(flags.get("modifier.no_trade", false)) or bool(flags.get("simulation.disable_item_economy", false))

func price(item_id: String) -> int:
    return ItemEconomyEngine.buy_price(item_id)

func stock(world_id: String, size: int = 8) -> Array:
    if trading_disabled():
        return []
    return ItemEconomyEngine.merchant_stock(world_id, size)

func can_buy(item_id: String) -> bool:
    if trading_disabled():
        return false
    var cost := price(item_id)
    if cost <= 0:
        return false
    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    return int(resources.get("fragments", 0)) >= cost

func buy(item_id: String) -> bool:
    if trading_disabled():
        return false
    var cost: int = price(item_id)
    if cost <= 0 or not can_buy(item_id):
        return false
    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    resources.fragments = int(resources.get("fragments", 0)) - cost
    GameState.run.resources = resources
    return InventoryEngine.add_item(item_id)

func sell(item_id: String) -> bool:
    if trading_disabled():
        return false
    if not InventoryEngine.has_item(item_id):
        return false
    var value := ItemEconomyEngine.sell_price(item_id)
    if value <= 0 or not InventoryEngine.remove_item(item_id):
        return false
    var resources: Dictionary = GameState.run.get("resources", {}) as Dictionary
    resources.fragments = int(resources.get("fragments", 0)) + value
    GameState.run.resources = resources
    return true
