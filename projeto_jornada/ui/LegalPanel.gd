extends PanelContainer
class_name LegalPanel

signal closed

const DOCUMENT_PATH := "res://product/legal_documents.json"
const DEFAULT_DOCUMENT := "privacy"

var domain_id := "mata_fio_verde"
var localization := LocalizationService.new()
var _document_data: Dictionary = {}
var _locale_data: Dictionary = {}
var _active_document := DEFAULT_DOCUMENT
var _body: RichTextLabel
var _privacy_button: Button
var _terms_button: Button
var _url_label: Label

static func entry_label(locale_id: String) -> String:
    var data := _read_document()
    var payload := _localized_payload(data, locale_id)
    return str(payload.get("entry_label", ""))

static func _read_document() -> Dictionary:
    if not FileAccess.file_exists(DOCUMENT_PATH):
        return {}
    var file := FileAccess.open(DOCUMENT_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed as Dictionary

static func _localized_payload(data: Dictionary, locale_id: String) -> Dictionary:
    var locales: Dictionary = data.get("locales", {}) as Dictionary
    var source_locale := str(data.get("source_locale", "pt_BR"))
    var requested := locale_id
    if requested == "" or not locales.has(requested):
        requested = source_locale
    var payload: Dictionary = locales.get(requested, {}) as Dictionary
    if payload.is_empty() and requested != source_locale:
        payload = locales.get(source_locale, {}) as Dictionary
    return payload

func _ready() -> void:
    visible = false
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

func open_for(domain: String, initial_document: String = DEFAULT_DOCUMENT) -> void:
    domain_id = domain
    _active_document = initial_document if initial_document in ["privacy", "terms"] else DEFAULT_DOCUMENT
    _document_data = _read_document()
    _locale_data = _localized_payload(_document_data, localization.current_locale())
    if _document_data.is_empty() or _locale_data.is_empty():
        push_error("LegalPanel could not load runtime legal document resource")
        return
    _rebuild()
    visible = true
    move_to_front()

func close_panel() -> void:
    visible = false
    closed.emit()

func _rebuild() -> void:
    for child in get_children():
        child.queue_free()

    BookCardStyle.apply_panel(self, domain_id, DomainThemeService, "selected")

    var safe := SafeAreaMargin.new()
    safe.name = "LegalSafeArea"
    add_child(safe)

    var margin := MarginContainer.new()
    margin.name = "LegalMargin"
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    safe.add_child(margin)

    var column := VBoxContainer.new()
    column.name = "LegalColumn"
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 12)
    margin.add_child(column)

    var title := Label.new()
    title.name = "LegalTitle"
    title.text = str(_locale_data.get("screen_title", ""))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.set_meta("base_font_size", 28)
    BookCardStyle.apply_heading(title, domain_id, DomainThemeService, 1)
    column.add_child(title)

    var notice := Label.new()
    notice.name = "LegalPreReleaseNotice"
    notice.text = str(_locale_data.get("pre_release_notice", ""))
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.set_meta("base_font_size", 15)
    column.add_child(notice)

    var tabs := HBoxContainer.new()
    tabs.name = "LegalTabs"
    tabs.add_theme_constant_override("separation", 8)
    column.add_child(tabs)

    _privacy_button = Button.new()
    _privacy_button.name = "LegalPrivacyTab"
    _privacy_button.text = str(_locale_data.get("privacy_tab", ""))
    _privacy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _privacy_button.custom_minimum_size.y = 52
    _privacy_button.set_meta("base_font_size", 16)
    _privacy_button.pressed.connect(func(): _select_document("privacy"))
    tabs.add_child(_privacy_button)

    _terms_button = Button.new()
    _terms_button.name = "LegalTermsTab"
    _terms_button.text = str(_locale_data.get("terms_tab", ""))
    _terms_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _terms_button.custom_minimum_size.y = 52
    _terms_button.set_meta("base_font_size", 16)
    _terms_button.pressed.connect(func(): _select_document("terms"))
    tabs.add_child(_terms_button)

    _body = RichTextLabel.new()
    _body.name = "LegalDocumentBody"
    _body.bbcode_enabled = false
    _body.fit_content = false
    _body.scroll_active = true
    _body.selection_enabled = true
    _body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _body.custom_minimum_size = Vector2(0, 300)
    _body.set_meta("base_font_size", 16)
    BookCardStyle.apply_body(_body, domain_id, DomainThemeService)
    column.add_child(_body)

    _url_label = Label.new()
    _url_label.name = "LegalPublicUrl"
    _url_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _url_label.set_meta("base_font_size", 14)
    column.add_child(_url_label)

    var done := Button.new()
    done.name = "LegalDone"
    done.text = str(_locale_data.get("done_label", ""))
    done.custom_minimum_size = Vector2(0, 54)
    done.set_meta("base_font_size", 17)
    BookCardStyle.apply_button(done, domain_id, DomainThemeService, true)
    done.pressed.connect(close_panel)
    column.add_child(done)

    _refresh_document()
    AccessibilityService.apply_font_scale(self)
    MobilePlatformService.apply_touch_targets(self)

func _select_document(document_id: String) -> void:
    if document_id not in ["privacy", "terms"]:
        return
    _active_document = document_id
    _refresh_document()

func _refresh_document() -> void:
    if _body == null or _privacy_button == null or _terms_button == null or _url_label == null:
        return
    var body_key := "privacy_body" if _active_document == "privacy" else "terms_body"
    _body.text = str(_locale_data.get(body_key, ""))
    _body.scroll_to_line(0)
    BookCardStyle.apply_button(_privacy_button, domain_id, DomainThemeService, _active_document == "privacy")
    BookCardStyle.apply_button(_terms_button, domain_id, DomainThemeService, _active_document == "terms")

    var url_key := "public_privacy_url" if _active_document == "privacy" else "public_terms_url"
    var public_url := str(_document_data.get(url_key, "")).strip_edges()
    _url_label.text = public_url
    _url_label.visible = public_url != ""
