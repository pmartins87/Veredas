#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

RARITY_QUOTA = {
    "common": 40,
    "uncommon": 24,
    "rare": 14,
    "singular": 8,
    "relic": 5,
    "echo": 2,
}
RARITY_TIER = {name: index + 1 for index, name in enumerate(RARITY_QUOTA)}
RARITY_POWER = {"common": 1, "uncommon": 1, "rare": 2, "singular": 2, "relic": 3, "echo": 3}
LOOT_WEIGHT = {"common": 100, "uncommon": 50, "rare": 20, "singular": 8, "relic": 3, "echo": 1}
MERCHANT_WEIGHT = {"common": 100, "uncommon": 70, "rare": 35, "singular": 15, "relic": 5, "echo": 1}

EQUIPMENT_VISUALS = {
    "short_sword", "dagger", "axe", "spear", "bow", "hammer", "shield",
    "helmet", "chest_armor", "boots", "cloak", "ring", "amulet", "relic",
}
CONSUMABLE_VISUALS = {"bottle", "herb", "food_pouch"}
TOOL_VISUALS = {"scroll", "key", "rope", "lantern"}
COMPONENT_VISUALS = {"coin", "crystal"}
WEAPON_VISUALS = {"short_sword", "dagger", "axe", "spear", "bow", "hammer"}
ARMOR_VISUALS = {"shield", "helmet", "chest_armor", "boots", "cloak"}
TALISMAN_VISUALS = {"ring", "amulet", "relic"}

EQUIPMENT_OPS = {
    "weapons": ["damage", "posture", "range", "status_power", "resource_gain"],
    "armor": ["guard", "posture", "status_resist", "vigor", "heal"],
    "talisman": ["resource_gain", "mark_synergy", "debt_pressure", "status_power", "heal", "vigor"],
}


def read(name: str):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def write(name: str, rows) -> None:
    (DATA / f"{name}.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def stable_int(text: str) -> int:
    return int(hashlib.sha256(text.encode("utf-8")).hexdigest()[:16], 16)


def natural_kind(visual: str) -> str:
    if visual in EQUIPMENT_VISUALS:
        return "equipment"
    if visual in CONSUMABLE_VISUALS:
        return "consumable"
    if visual in TOOL_VISUALS:
        return "tool"
    if visual in COMPONENT_VISUALS:
        return "component"
    raise SystemExit(f"Unknown item visual archetype: {visual}")


def equipment_effect(item_id: str, visual: str, rarity: str) -> dict:
    if visual in WEAPON_VISUALS:
        pool = EQUIPMENT_OPS["weapons"]
    elif visual in ARMOR_VISUALS:
        pool = EQUIPMENT_OPS["armor"]
    else:
        pool = EQUIPMENT_OPS["talisman"]
    op = pool[stable_int(item_id + ":effect") % len(pool)]
    power = RARITY_POWER[rarity]
    if op == "range":
        power = 1
    elif op in {"resource_gain", "mark_synergy", "debt_pressure"}:
        power = 1 if RARITY_TIER[rarity] <= 3 else 2
    elif op in {"status_power", "status_resist", "heal"}:
        power = min(2, power)
    return {"op": op, "value": power}


def equipment_load(visual: str) -> int:
    if visual in {"hammer", "chest_armor", "shield"}:
        return 2
    if visual in {"axe", "spear", "helmet", "cloak"}:
        return 1
    return 0


def consumable_effect(item_id: str, rarity: str) -> dict:
    op = "heal" if stable_int(item_id + ":consumable") % 2 == 0 else "vigor"
    tier = RARITY_TIER[rarity]
    value = min(7, 2 + tier)
    return {"op": op, "value": value}


def tool_effect(item_id: str, rarity: str) -> dict:
    resource = "provisions" if stable_int(item_id + ":tool") % 3 else "essence"
    tier = RARITY_TIER[rarity]
    value = 1 + (1 if tier >= 4 else 0) + (1 if rarity == "echo" else 0)
    return {"op": "resource_add", "resource": resource, "value": value}


def component_effect(rarity: str) -> dict:
    tier = RARITY_TIER[rarity]
    return {"op": "trade_value", "value": 2 + tier * 2}


def assign_rarities(rows: list[dict]) -> None:
    ordered = sorted(rows, key=lambda row: (stable_int(str(row.get("id", "")) + ":rarity"), str(row.get("id", ""))))
    cursor = 0
    for rarity, count in RARITY_QUOTA.items():
        for row in ordered[cursor:cursor + count]:
            row["rarity"] = rarity
        cursor += count
    if cursor != len(rows):
        raise SystemExit(f"Rarity quota covers {cursor} items but Domain contains {len(rows)}")


def main() -> None:
    items = read("items")
    worlds = read("worlds")
    if len(items) != 1116 or len(worlds) != 12:
        raise SystemExit(f"Unexpected catalog sizes items={len(items)} worlds={len(worlds)}")

    by_world: defaultdict[str, list[dict]] = defaultdict(list)
    for item in items:
        by_world[str(item.get("world_id", ""))].append(item)

    for world in worlds:
        world_id = str(world.get("id", ""))
        rows = by_world.get(world_id, [])
        if len(rows) != 93:
            raise SystemExit(f"{world_id} has {len(rows)} items instead of 93")
        assign_rarities(rows)
        for item in rows:
            item_id = str(item.get("id", ""))
            visual = str(item.get("visual_archetype", ""))
            rarity = str(item.get("rarity", "common"))
            kind = natural_kind(visual)
            item["kind"] = kind
            item["economy_tier"] = RARITY_TIER[rarity]
            item["loot_weight"] = LOOT_WEIGHT[rarity]
            item["merchant_weight"] = MERCHANT_WEIGHT[rarity]
            item["load"] = equipment_load(visual) if kind == "equipment" else 0
            if kind == "equipment":
                item["effect"] = equipment_effect(item_id, visual, rarity)
            elif kind == "consumable":
                item["effect"] = consumable_effect(item_id, rarity)
            elif kind == "tool":
                item["effect"] = tool_effect(item_id, rarity)
            else:
                item["effect"] = component_effect(rarity)

    rarity_counts = Counter(str(item.get("rarity", "")) for item in items)
    expected = {rarity: count * 12 for rarity, count in RARITY_QUOTA.items()}
    if dict(rarity_counts) != expected:
        raise SystemExit(f"Global rarity distribution mismatch: {dict(rarity_counts)} != {expected}")

    allowed_equipment_ops = {op for values in EQUIPMENT_OPS.values() for op in values}
    for item in items:
        item_id = str(item.get("id", ""))
        kind = str(item.get("kind", ""))
        effect = item.get("effect", {})
        op = str(effect.get("op", ""))
        if kind == "equipment" and op not in allowed_equipment_ops:
            raise SystemExit(f"{item_id} has invalid equipment op {op}")
        if kind == "consumable" and op not in {"heal", "vigor"}:
            raise SystemExit(f"{item_id} has unusable consumable op {op}")
        if kind == "tool" and (op != "resource_add" or str(effect.get("resource", "")) not in {"provisions", "essence"}):
            raise SystemExit(f"{item_id} has unusable tool effect {effect}")
        if kind == "component" and op != "trade_value":
            raise SystemExit(f"{item_id} has invalid component effect {effect}")

    write("items", items)
    print("ITEM_ECONOMY_REFINEMENT PASS: 1116 items across 12 Domains; rarity/effect semantics normalized")
    print("ITEM_ECONOMY rarity=%s" % dict(sorted(rarity_counts.items())))


if __name__ == "__main__":
    main()
