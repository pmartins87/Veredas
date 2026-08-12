extends Node

var failures: Array[String] = []
var localization := LocalizationService.new()
var locale_checks := 0
var document_checks := 0

func _ready() -> void:
    await get_tree().process_frame
    GameState.reset_profile()
    _resource_contract_gate()
    await _locale_surface_gate("pt_BR", "Privacidade e termos", "Política de Privacidade", "Termos de Uso", "Concluir")
    await _locale_surface_gate("en", "Privacy and terms", "Privacy Policy", "Terms of Use", "Done")
    _finish()

func _resource_contract_gate() -> void:
    var file := FileAccess.open("res://product/legal_documents.json", FileAccess.READ)
    expect(file != null, "12.3 runtime legal document resource cannot be opened")
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    expect(typeof(parsed) == TYPE_DICTIONARY, "12.3 runtime legal document resource is not a JSON object")
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var data: Dictionary = parsed as Dictionary
    var launch: Array = data.get("launch_locales", []) as Array
    expect(launch == localization.launch_locales(), "12.3 runtime legal launch locales do not match LocalizationService")
    expect(str(data.get("source_locale", "")) == localization.source_locale(), "12.3 runtime legal source locale mismatch")
    expect(str(data.get("publication_status", "")) in ["pre_release", "final"], "12.3 runtime legal publication status invalid")
    expect(bool(data.get("runtime_surface_required", false)), "12.3 runtime legal contract does not require the in-app surface")

func _locale_surface_gate(locale_id: String, expected_screen_title: String, expected_privacy: String, expected_terms: String, expected_done: String) -> void:
    expect(localization.set_locale(locale_id, false), "12.3 could not activate legal-surface locale: %s" % locale_id)
    var panel := LegalPanel.new()
    add_child(panel)
    await get_tree().process_frame
    panel.open_for("mata_fio_verde")
    await get_tree().process_frame

    expect(panel.visible, "12.3 legal surface did not become visible: %s" % locale_id)
    var safe := panel.find_child("LegalSafeArea", true, false) as SafeAreaMargin
    var title := panel.find_child("LegalTitle", true, false) as Label
    var notice := panel.find_child("LegalPreReleaseNotice", true, false) as Label
    var privacy := panel.find_child("LegalPrivacyTab", true, false) as Button
    var terms := panel.find_child("LegalTermsTab", true, false) as Button
    var body := panel.find_child("LegalDocumentBody", true, false) as RichTextLabel
    var done := panel.find_child("LegalDone", true, false) as Button

    expect(safe != null, "12.3 legal surface is not wrapped in a safe-area margin: %s" % locale_id)
    expect(title != null and title.text == expected_screen_title, "12.3 legal title not localized: %s" % locale_id)
    expect(notice != null and notice.text.length() >= 80, "12.3 legal pre-release/final status notice missing: %s" % locale_id)
    expect(privacy != null and privacy.text == expected_privacy, "12.3 privacy tab not localized: %s" % locale_id)
    expect(terms != null and terms.text == expected_terms, "12.3 terms tab not localized: %s" % locale_id)
    expect(done != null and done.text == expected_done, "12.3 legal close action not localized: %s" % locale_id)
    expect(body != null and body.text.length() >= 900, "12.3 in-app privacy text missing/too short: %s" % locale_id)
    if body != null:
        expect(body.scroll_active, "12.3 legal body is not scrollable: %s" % locale_id)
        expect(body.selection_enabled, "12.3 legal body should allow text selection: %s" % locale_id)
        var privacy_text := body.text
        if terms != null:
            terms.pressed.emit()
            await get_tree().process_frame
            expect(body.text.length() >= 700, "12.3 in-app terms text missing/too short: %s" % locale_id)
            expect(body.text != privacy_text, "12.3 terms tab did not switch document body: %s" % locale_id)
            document_checks += 2

    expect(LegalPanel.entry_label(locale_id) == expected_screen_title, "12.3 Hub legal entry label not localized: %s" % locale_id)
    locale_checks += 1
    panel.queue_free()
    await get_tree().process_frame

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: LEGAL_SURFACE_CERTIFICATION: %s" % message)

func _finish() -> void:
    if failures.is_empty():
        print("LEGAL_SURFACE_CERTIFICATION PASS: 12.3 locales=%d documents=%d safe_area=1 scrollable=1 runtime_resource=1" % [locale_checks, document_checks])
        get_tree().quit(0)
    else:
        print("LEGAL_SURFACE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)
