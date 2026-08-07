extends RefCounted
class_name VectorAtlasRegistry

const CELL := 64
const SYSTEM_ATLAS := "res://ui/assets/vector/system_icons_atlas.svg"
const MARK_ATLAS := "res://ui/assets/vector/mark_glyphs_atlas.svg"
const ITEM_ATLAS := "res://ui/assets/vector/item_archetypes_atlas.svg"
const DOMAIN_ATLAS := "res://ui/assets/vector/domain_ornaments_atlas.svg"

const SYSTEM_INDEX := {
    "health":0,"vigor":1,"guard":2,"attack":3,"precision":4,"posture":5,"distance":6,"focus":7,
    "trama":8,"mark":9,"debt":10,"echo":11,"inventory":12,"map":13,"codex":14,"character":15,
    "coin":16,"essence":17,"provision":18,"load":19,"key":20,"tool":21,"weapon":22,"armor":23,
    "talism":24,"consumable":25,"shop":26,"travel":27,"boss":28,"intent":29,"warning":30,"choice":31
}

const DOMAIN_INDEX := {
    "mata_fio_verde":0,"varzea_espelhos":1,"costa_sinos_afogados":2,"chapada_sol_oco":3,
    "salinas_ossamar":4,"vertice":5,"forja_rubra":6,"mar_cinza":7,
    "noite_iscara":8,"cidade_mil_portas":9,"arquivo_ecos":10,"tear_desfeito":11
}

const MARK_FAMILY_ROW := {
    "action":0,"bond":1,"knowledge":2,"condition":3,"world":4,"echo":5,
    "acao":0,"vinculo":1,"conhecimento":2,"condicao":3,"mundo":4,"eco":5
}

static func _region_texture(path: String, cols: int, index: int) -> AtlasTexture:
    var source := load(path)
    var result := AtlasTexture.new()
    result.atlas = source
    var col := index % cols
    var row := int(index / cols)
    result.region = Rect2(col * CELL, row * CELL, CELL, CELL)
    return result

static func system_icon(icon_id: String) -> AtlasTexture:
    var index: int = SYSTEM_INDEX.get(icon_id, SYSTEM_INDEX.warning)
    return _region_texture(SYSTEM_ATLAS, 8, index)

static func domain_ornament(domain_id: String) -> AtlasTexture:
    var index: int = DOMAIN_INDEX.get(domain_id, 0)
    return _region_texture(DOMAIN_ATLAS, 4, index)

static func mark_glyph(family: String, variant: int) -> AtlasTexture:
    var row: int = MARK_FAMILY_ROW.get(family.to_lower(), 0)
    var col := clampi(variant, 0, 7)
    return _region_texture(MARK_ATLAS, 8, row * 8 + col)

static func stable_mark_variant(mark_id: String) -> int:
    var h := 2166136261
    for b in mark_id.to_utf8_buffer():
        h = int((h ^ b) * 16777619) & 0x7fffffff
    return h % 8

static func mark_texture(mark: Dictionary) -> AtlasTexture:
    var family := str(mark.get("type", mark.get("family", "action")))
    return mark_glyph(family, stable_mark_variant(str(mark.get("id", "mark.unknown"))))

static func validate_sources() -> PackedStringArray:
    var errors := PackedStringArray()
    for path in [SYSTEM_ATLAS, MARK_ATLAS, ITEM_ATLAS, DOMAIN_ATLAS]:
        if not ResourceLoader.exists(path):
            errors.append("Missing vector atlas: %s" % path)
    return errors
