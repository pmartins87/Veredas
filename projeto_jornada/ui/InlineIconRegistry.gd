extends RefCounted
class_name InlineIconRegistry

# Narrative authoring syntax:
#   "Você perde [icon:health] 2 de Vida e ganha [icon:mark] uma Marca."
# Icons are inserted as real textures cropped from our original hand-drawn atlas.

const DEFAULT_SIZE := 24
const ALIASES := {
    "movement":"distance", "journal":"codex", "thread":"trama", "route":"travel",
    "consequence":"debt", "currency":"coin", "provisions":"provision", "merchant":"shop",
    "elite":"boss", "talisman":"talism"
}

static func canonical_token(token: String) -> String:
    return str(ALIASES.get(token, token))

static func texture(token: String) -> Texture2D:
    var canonical := canonical_token(token)
    if not VectorAtlasRegistry.SYSTEM_INDEX.has(canonical):
        return null
    return VectorAtlasRegistry.system_icon(canonical)

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
        if texture(token) == null and not unknown.has(token):
            unknown.append(token)
        cursor = close + 1
    return unknown

static func render_into(label: RichTextLabel, source: String, size: int = DEFAULT_SIZE) -> void:
    if label == null:
        return
    label.clear()
    var cursor := 0
    while cursor < source.length():
        var start := source.find("[icon:", cursor)
        if start < 0:
            label.add_text(source.substr(cursor))
            break
        if start > cursor:
            label.add_text(source.substr(cursor, start - cursor))
        var close := source.find("]", start)
        if close < 0:
            label.add_text(source.substr(start))
            break
        var token := source.substr(start + 6, close - (start + 6))
        var tex := texture(token)
        if tex != null:
            label.add_image(tex, size, size, Color.WHITE, INLINE_ALIGNMENT_CENTER)
        else:
            label.add_text("[%s]" % token)
        cursor = close + 1

static func append_icon(label: RichTextLabel, token: String, size: int = DEFAULT_SIZE) -> bool:
    var tex := texture(token)
    if label == null or tex == null:
        return false
    label.add_image(tex, size, size, Color.WHITE, INLINE_ALIGNMENT_CENTER)
    return true
