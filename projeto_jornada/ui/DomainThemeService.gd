extends Node
class_name DomainThemeService

const PALETTE_PATH := "res://ui/domain_palettes.json"

var _shared: Dictionary = {}
var _domains: Dictionary = {}

func _ready() -> void:
    reload()

func reload() -> void:
    _shared.clear()
    _domains.clear()
    if not FileAccess.file_exists(PALETTE_PATH):
        push_error("DomainThemeService: palette file missing: %s" % PALETTE_PATH)
        return
    var file := FileAccess.open(PALETTE_PATH, FileAccess.READ)
    if file == null:
        push_error("DomainThemeService: cannot open palette file")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("DomainThemeService: invalid palette JSON")
        return
    _shared = parsed.get("shared", {})
    _domains = parsed.get("domains", {})

func has_domain(domain_id: String) -> bool:
    return _domains.has(domain_id)

func _lookup_color(token: String, domain_id: String = "") -> Color:
    if domain_id != "" and _domains.has(domain_id):
        var domain: Dictionary = _domains[domain_id]
        if domain.has(token):
            return Color(domain[token])
    if _shared.has(token):
        return Color(_shared[token])
    return Color.WHITE

func _high_contrast_enabled() -> bool:
    var service := get_node_or_null("/root/AccessibilityService")
    return service != null and bool(service.high_contrast())

func color(token: String, domain_id: String = "") -> Color:
    if _high_contrast_enabled():
        if token == "paper":
            return _lookup_color("paper_light", domain_id)
        if token == "ink_soft" or token == "line":
            return _lookup_color("ink", domain_id)
    var found_domain := domain_id != "" and _domains.has(domain_id) and (_domains[domain_id] as Dictionary).has(token)
    if found_domain or _shared.has(token):
        return _lookup_color(token, domain_id)
    push_warning("DomainThemeService: unknown color token %s for %s" % [token, domain_id])
    return Color.WHITE

func palette(domain_id: String) -> Dictionary:
    var result := _shared.duplicate(true)
    if _domains.has(domain_id):
        for key in _domains[domain_id]:
            result[key] = _domains[domain_id][key]
    if _high_contrast_enabled():
        result["paper"] = result.get("paper_light", result.get("paper", "#FFFFFF"))
        result["ink_soft"] = result.get("ink", "#000000")
        result["line"] = result.get("ink", "#000000")
    return result

func motif(domain_id: String) -> String:
    if not _domains.has(domain_id):
        return "thread_knot"
    return str(_domains[domain_id].get("motif", "thread_knot"))

func apply_domain_accents(root: Node, domain_id: String) -> void:
    if root == null:
        return
    _apply_recursive(root, domain_id)

func _apply_recursive(node: Node, domain_id: String) -> void:
    if node.has_meta("art_color_token"):
        var token := str(node.get_meta("art_color_token"))
        var value := color(token, domain_id)
        if node is CanvasItem:
            node.modulate = value
    for child in node.get_children():
        _apply_recursive(child, domain_id)
