extends RefCounted
class_name ItemVisualComposer

const ATLAS_PATH := "res://ui/assets/vector/item_archetypes_atlas.svg"
const CELL := 64
const COLS := 6

const ARCHETYPE_INDEX := {
    "short_sword": 0, "long_sword": 1, "dagger": 2, "axe": 3, "spear": 4, "bow": 5,
    "shield": 6, "helmet": 7, "chest_armor": 8, "boots": 9, "cloak": 10, "ring": 11,
    "amulet": 12, "bottle": 13, "herb": 14, "scroll": 15, "key": 16, "hammer": 17,
    "rope": 18, "lantern": 19, "coin": 20, "crystal": 21, "food_pouch": 22, "relic": 23
}

const RARITY_TOKENS := {
    "common": "ink_soft",
    "uncommon": "positive",
    "rare": "information",
    "singular": "rare",
    "relic": "gold",
    "echo": "accent"
}

static func archetype_for(item: Dictionary) -> String:
    if item.has("visual_archetype") and ARCHETYPE_INDEX.has(str(item.visual_archetype)):
        return str(item.visual_archetype)
    var kind := str(item.get("kind", item.get("type", ""))).to_lower()
    var slot := str(item.get("slot", "")).to_lower()
    var name := str(item.get("name", "")).to_lower()
    if "key" in kind or "chave" in name:
        return "key"
    if "potion" in kind or "elixir" in kind or "frasco" in name:
        return "bottle"
    if "herb" in kind or "erva" in name:
        return "herb"
    if "scroll" in kind or "pergaminho" in name:
        return "scroll"
    if "component" in kind:
        return "crystal" if "essence" in str(item.get("tags", [])) else "relic"
    if "currency" in kind or "coin" in kind:
        return "coin"
    if "consumable" in kind:
        return "food_pouch"
    if slot == "head":
        return "helmet"
    if slot == "body":
        return "chest_armor"
    if slot == "feet":
        return "boots"
    if slot == "talism" or slot == "talisman":
        return "amulet"
    if slot == "tool":
        return "hammer"
    if "bow" in kind or "arco" in name:
        return "bow"
    if "spear" in kind or "lanca" in name or "lança" in name:
        return "spear"
    if "axe" in kind or "machado" in name:
        return "axe"
    if "dagger" in kind or "faca" in name or "adaga" in name:
        return "dagger"
    if "weapon" in kind or slot == "weapon" or slot == "main":
        return "short_sword"
    return "relic"

static func atlas_texture(item: Dictionary) -> AtlasTexture:
    var archetype := archetype_for(item)
    var idx: int = ARCHETYPE_INDEX.get(archetype, 23)
    var tex := load(ATLAS_PATH)
    var atlas := AtlasTexture.new()
    atlas.atlas = tex
    atlas.region = Rect2((idx % COLS) * CELL, (idx / COLS) * CELL, CELL, CELL)
    return atlas

static func rarity_color(item: Dictionary, domain_id: String, theme_service: DomainThemeService) -> Color:
    var rarity := str(item.get("rarity", "common")).to_lower()
    var token := str(RARITY_TOKENS.get(rarity, "ink_soft"))
    return theme_service.color(token, domain_id)

static func domain_tint(domain_id: String, theme_service: DomainThemeService, strength: float = 0.24) -> Color:
    var primary := theme_service.color("primary", domain_id)
    return Color.WHITE.lerp(primary, clamp(strength, 0.0, 0.5))

static func visual_signature(item: Dictionary, domain_id: String) -> String:
    var affixes: Array = item.get("affixes", [])
    var sorted_affixes := []
    for affix in affixes:
        sorted_affixes.append(str(affix))
    sorted_affixes.sort()
    return "%s|%s|%s|%s" % [archetype_for(item), domain_id, str(item.get("rarity", "common")), ",".join(sorted_affixes)]
