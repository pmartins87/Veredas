extends RefCounted
class_name InlineIconRegistry

# Authoring syntax in narrative strings:
#   "Você perde [icon:health] 2 de Vida e ganha [icon:mark] uma Marca."
# This class turns semantic icon tokens into RichTextLabel BBCode.

const ICON_ROOT := "res://assets/icons/system/"
const DEFAULT_SIZE := 24

const ICONS := {
    "health": "health.svg",
    "vigor": "vigor.svg",
    "posture": "posture.svg",
    "guard": "guard.svg",
    "attack": "attack.svg",
    "precision": "precision.svg",
    "distance": "distance.svg",
    "movement": "movement.svg",
    "inventory": "inventory.svg",
    "character": "character.svg",
    "journal": "journal.svg",
    "map": "map.svg",
    "mark": "mark.svg",
    "debt": "debt.svg",
    "echo": "echo.svg",
    "thread": "thread.svg",
    "route": "route.svg",
    "consequence": "consequence.svg",
    "weapon": "item_weapon.svg",
    "armor": "item_armor.svg",
    "tool": "item_tool.svg",
    "talisman": "item_talisman.svg",
    "consumable": "item_consumable.svg",
    "key": "item_key.svg",
    "currency": "currency.svg",
    "essence": "essence.svg",
    "provisions": "provisions.svg",
    "load": "load.svg",
    "merchant": "merchant.svg",
    "boss": "boss.svg",
    "elite": "elite.svg",
    "warning": "warning.svg"
}

static func format(source: String, size: int = DEFAULT_SIZE) -> String:
    var result := source
    for token in ICONS:
        var marker := "[icon:%s]" % token
        if marker in result:
            var path := ICON_ROOT + str(ICONS[token])
            var replacement := "[img=%dx%d]%s[/img]" % [size, size, path]
            result = result.replace(marker, replacement)
    return result

static func validate_tokens(source: String) -> PackedStringArray:
    var unknown := PackedStringArray()
    var cursor := 0
    while true:
        var start := source.find("[icon:", cursor)
        if start < 0:
            break
        var close := source.find("]", start)
        if close < 0:
            unknown.append(source.substr(start))
            break
        var token := source.substr(start + 6, close - (start + 6))
        if not ICONS.has(token) and not unknown.has(token):
            unknown.append(token)
        cursor = close + 1
    return unknown

static func icon_path(token: String) -> String:
    if not ICONS.has(token):
        return ""
    return ICON_ROOT + str(ICONS[token])
