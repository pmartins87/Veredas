extends RefCounted
class_name BookCardStyle

# Creates the shared 'stitched page' visual grammar used by event, combat,
# inventory and character cards. It deliberately derives appearance from
# Veredas da Trama domain tokens rather than from fixed external layouts.

static func panel_style(domain_id: String, theme_service: DomainThemeService, emphasis: String = "normal") -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    var paper := theme_service.color("paper", domain_id)
    var ink := theme_service.color("ink", domain_id)
    var accent := theme_service.color("accent", domain_id)
    var wash := theme_service.color("wash", domain_id)

    var background := paper.lerp(wash, 0.055)
    if emphasis == "danger":
        background = background.lerp(theme_service.color("danger", domain_id), 0.10)
    elif emphasis == "selected":
        background = background.lerp(accent, 0.09)
    elif emphasis == "quiet":
        background = background.lerp(Color(0.5, 0.5, 0.5), 0.025)

    style.bg_color = background
    style.border_color = ink.lerp(accent, 0.14 if emphasis == "normal" else 0.27)
    style.set_border_width_all(2)
    style.corner_radius_top_left = 7
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 8
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 14.0
    style.content_margin_bottom = 14.0
    style.shadow_color = Color(0.05, 0.035, 0.02, 0.18)
    style.shadow_size = 3
    style.shadow_offset = Vector2(1, 2)
    return style

static func action_style(domain_id: String, theme_service: DomainThemeService, primary: bool = false) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    var ink := theme_service.color("ink", domain_id)
    var accent := theme_service.color("accent", domain_id)
    var paper := theme_service.color("paper", domain_id)
    if primary:
        style.bg_color = accent.lerp(ink, 0.18)
        style.border_color = ink
    else:
        style.bg_color = paper.lerp(accent, 0.04)
        style.border_color = ink.lerp(accent, 0.20)
    style.set_border_width_all(2)
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 7
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 5
    style.content_margin_left = 15.0
    style.content_margin_right = 15.0
    style.content_margin_top = 11.0
    style.content_margin_bottom = 11.0
    style.shadow_color = Color(0.04, 0.03, 0.02, 0.16)
    style.shadow_size = 2
    style.shadow_offset = Vector2(1, 2)
    return style

static func apply_button(button: Button, domain_id: String, theme_service: DomainThemeService, primary: bool = false) -> void:
    if button == null:
        return
    var normal := action_style(domain_id, theme_service, primary)
    var hover := normal.duplicate()
    hover.bg_color = normal.bg_color.lightened(0.045)
    var pressed := normal.duplicate()
    pressed.bg_color = normal.bg_color.darkened(0.07)
    pressed.shadow_size = 0
    var disabled := normal.duplicate()
    disabled.bg_color = normal.bg_color.lerp(Color(0.45, 0.43, 0.39), 0.38)
    disabled.border_color = normal.border_color.lerp(Color(0.5, 0.5, 0.5), 0.50)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    var button_text_token := "paper_light" if primary else "ink"
    button.add_theme_color_override("font_color", theme_service.color(button_text_token, domain_id))
    button.add_theme_color_override("font_hover_color", theme_service.color(button_text_token, domain_id))

static func apply_panel(panel: PanelContainer, domain_id: String, theme_service: DomainThemeService, emphasis: String = "normal") -> void:
    if panel == null:
        return
    panel.add_theme_stylebox_override("panel", panel_style(domain_id, theme_service, emphasis))

static func apply_heading(label: Label, domain_id: String, theme_service: DomainThemeService, level: int = 1) -> void:
    if label == null:
        return
    label.add_theme_color_override("font_color", theme_service.color("deep" if level <= 2 else "ink", domain_id))
    label.add_theme_font_size_override("font_size", 34 if level == 1 else (26 if level == 2 else 21))

static func apply_body(rich: RichTextLabel, domain_id: String, theme_service: DomainThemeService) -> void:
    if rich == null:
        return
    rich.add_theme_color_override("default_color", theme_service.color("ink", domain_id))
    rich.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
    rich.add_theme_font_size_override("normal_font_size", 19)
    rich.add_theme_constant_override("line_separation", 6)
