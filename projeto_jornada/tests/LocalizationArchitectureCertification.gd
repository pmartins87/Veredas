extends Node

var failures: Array[String] = []
var localization := LocalizationService.new()
var alias_checks := 0
var ui_key_checks := 0
var content_overlay_checks := 0
var label_checks := 0
var panel_checks := 0

func _ready() -> void:
    await get_tree().process_frame
    GameState.reset_profile()
    _architecture_gate()
    _locale_resolution_gate()
    _ui_catalog_gate()
    _label_catalog_gate()
    _profile_persistence_gate()
    _content_overlay_gate()
    await _panel_integration_gate()
    _finish()

func _architecture_gate() -> void:
    expect(localization.is_ready(), "11.5 localization service did not load: %s" % str(localization.errors()))
    var manifest := localization.manifest()
    expect(int(manifest.get("schema_version", 0)) == 2, "11.5 localization manifest schema mismatch")
    expect(localization.source_locale() == "pt_BR", "11.5 source locale must be pt_BR")
    expect(localization.launch_locales() == ["pt_BR", "en", "es_419"], "11.5 launch locales mismatch: %s" % str(localization.launch_locales()))
    expect((manifest.get("content_overlay_fields", []) as Array).size() == 20, "11.5 overlay field classification count mismatch")
    expect((manifest.get("content_internal_string_fields", []) as Array).size() == 22, "11.5 internal string field classification count mismatch")
    expect((manifest.get("content_label_fields", []) as Array).size() == 14, "11.5 logical label field classification count mismatch")
    expect(bool((manifest.get("policy", {}) as Dictionary).get("logic_values_use_separate_label_catalogs", false)), "11.5 logical values are not protected by separate label catalogs")
    expect(str((manifest.get("policy", {}) as Dictionary).get("translation_completeness_gate_step", "")) == "11.6", "11.5 translation completeness must be deferred to 11.6")

func _locale_resolution_gate() -> void:
    var cases := {"pt-BR":"pt_BR", "en-US":"en", "es-MX":"es_419"}
    for raw_variant in cases.keys():
        var raw := str(raw_variant)
        expect(localization.resolve_locale(raw, false) == str(cases[raw_variant]), "11.5 locale alias failed: %s" % raw)
        alias_checks += 1
    expect(not localization.is_supported("zz-ZZ"), "11.5 unknown locale was reported supported")
    expect(localization.resolve_locale("zz-ZZ", true) == "pt_BR", "11.5 unknown locale did not fall back to source")
    expect(localization.current_locale() == "pt_BR", "11.5 fresh profile should default to source locale")

func _ui_catalog_gate() -> void:
    var required: Array = localization.manifest().get("ui_required_keys", []) as Array
    expect(required.size() >= 14, "11.5 expected at least 14 required UI architecture keys")
    for key_variant in required:
        var key := str(key_variant)
        var source_placeholders := localization.placeholders("pt_BR", key)
        for locale_id in localization.launch_locales():
            expect(localization.has_ui_key(locale_id, key), "11.5 required UI key missing: %s:%s" % [locale_id,key])
            expect(localization.placeholders(locale_id, key) == source_placeholders, "11.5 placeholder mismatch: %s:%s" % [locale_id,key])
            ui_key_checks += 1
    expect(localization.text("settings.font_size", {"percent":125}, "en") == "Text size: 125%", "11.5 placeholder formatting failed in English")
    expect(localization.text("settings.font_size", {"percent":125}, "es_419") == "Tamaño del texto: 125%", "11.5 placeholder formatting failed in Spanish")
    expect(localization.text("architecture.source_only_probe", {}, "en") == "Texto de fallback canônico", "11.5 English missing-key fallback failed")
    expect(localization.text("architecture.source_only_probe", {}, "es_419") == "Texto de fallback canônico", "11.5 Spanish missing-key fallback failed")

func _label_catalog_gate() -> void:
    var cases := [
        ["rarity", "common", "Comum", "Common", "Común"],
        ["status", "rooted", "Enraizado", "Rooted", "Enraizado"],
        ["kind", "equipment", "Equipamento", "Equipment", "Equipo"],
        ["tier", "intermediate", "Intermediário", "Intermediate", "Intermedio"],
    ]
    for case_variant in cases:
        var row: Array = case_variant as Array
        var field := str(row[0])
        var canonical := str(row[1])
        expect(localization.label(field, canonical, "pt_BR") == str(row[2]), "11.5 pt_BR label failed: %s:%s" % [field,canonical])
        expect(localization.label(field, canonical, "en") == str(row[3]), "11.5 English label failed: %s:%s" % [field,canonical])
        expect(localization.label(field, canonical, "es_419") == str(row[4]), "11.5 Spanish label failed: %s:%s" % [field,canonical])
        label_checks += 3
    expect(localization.label("resource", "ValorDesconhecido", "en") == "ValorDesconhecido", "11.5 missing logical label did not fall back to canonical value")
    expect(not localization.has_label("en", "resource", "ValorDesconhecido"), "11.5 unknown logical label reported as translated")

func _profile_persistence_gate() -> void:
    expect(localization.set_locale("en-US", false), "11.5 could not set supported locale alias")
    expect(localization.current_locale() == "en", "11.5 locale alias did not normalize in profile")
    var settings_before: Dictionary = GameState.profile.get("settings", {}) as Dictionary
    expect(not localization.set_locale("zz-ZZ", false), "11.5 invalid locale mutation was accepted")
    expect(GameState.profile.get("settings", {}) == settings_before, "11.5 invalid locale mutation changed profile settings")
    var payload := GameState.serialize()
    GameState.reset_profile()
    expect(localization.current_locale() == "pt_BR", "11.5 reset profile did not return to source locale")
    expect(GameState.deserialize(payload), "11.5 localized profile failed save/load round-trip")
    expect(localization.current_locale() == "en", "11.5 locale preference was not preserved through save/load")
    var audit := ProfileMigrationEngine.new().audit_live_profile()
    expect(bool(audit.get("ok", false)), "11.5 locale setting broke profile integrity: %s" % str(audit.get("errors", [])))

func _content_overlay_gate() -> void:
    var source_world := ContentRegistry.get_record("world.mata_fio_verde")
    expect(not source_world.is_empty(), "11.5 top-level overlay probe source record missing")
    if not source_world.is_empty():
        var canonical_name := str(source_world.get("name", ""))
        var english_world := localization.localize_record(source_world, "en")
        var spanish_world := localization.localize_record(source_world, "es_419")
        expect(str(english_world.get("name", "")) == "Green Thread Forest", "11.5 English stable-ID content overlay failed")
        expect(str(spanish_world.get("name", "")) == "Bosque del Hilo Verde", "11.5 Spanish stable-ID content overlay failed")
        expect(str(english_world.get("id", "")) == "world.mata_fio_verde", "11.5 localized world changed stable id")
        expect(str(ContentRegistry.get_record("world.mata_fio_verde").get("name", "")) == canonical_name, "11.5 top-level presentation overlay mutated canonical content")
        content_overlay_checks += 2

    var source_event := ContentRegistry.get_record("event.mata_fio_verde.loc01.01")
    expect(not source_event.is_empty(), "11.5 nested overlay probe event missing")
    if not source_event.is_empty():
        var source_choices: Array = source_event.get("choices", []) as Array
        expect(not source_choices.is_empty(), "11.5 nested overlay probe event has no choices")
        if not source_choices.is_empty():
            var canonical_choice := str((source_choices[0] as Dictionary).get("text", ""))
            var english_event := localization.localize_record(source_event, "en")
            var spanish_event := localization.localize_record(source_event, "es_419")
            var english_choices: Array = english_event.get("choices", []) as Array
            var spanish_choices: Array = spanish_event.get("choices", []) as Array
            expect(str((english_choices[0] as Dictionary).get("text", "")) == "Inspect the black sap before deciding", "11.5 nested English choice overlay failed")
            expect(str((spanish_choices[0] as Dictionary).get("text", "")) == "Examinar la savia negra antes de decidir", "11.5 nested Spanish choice overlay failed")
            expect(str(localization.content_value(source_event, "choices.0.text", "en")) == "Inspect the black sap before deciding", "11.5 nested content_value path lookup failed")
            var canonical_after: Array = ContentRegistry.get_record("event.mata_fio_verde.loc01.01").get("choices", []) as Array
            expect(str((canonical_after[0] as Dictionary).get("text", "")) == canonical_choice, "11.5 nested presentation overlay mutated canonical event")
            content_overlay_checks += 2

func _panel_integration_gate() -> void:
    expect(localization.set_locale("en", false), "11.5 could not switch to English for panel integration")
    var panel_en := AccessibilityPanel.new()
    add_child(panel_en)
    await get_tree().process_frame
    panel_en.open_for("mata_fio_verde")
    await get_tree().process_frame
    _check_panel(panel_en, "Accessibility", "Language", "Done")
    panel_en.queue_free()
    await get_tree().process_frame
    expect(localization.set_locale("es_419", false), "11.5 could not switch to Spanish for panel integration")
    var panel_es := AccessibilityPanel.new()
    add_child(panel_es)
    await get_tree().process_frame
    panel_es.open_for("mata_fio_verde")
    await get_tree().process_frame
    _check_panel(panel_es, "Accesibilidad", "Idioma", "Listo")
    panel_es.queue_free()
    await get_tree().process_frame

func _check_panel(panel: AccessibilityPanel, expected_title: String, expected_language: String, expected_done: String) -> void:
    var title := panel.find_child("AccessibilityTitle", true, false) as Label
    var language_label := panel.find_child("LanguageLabel", true, false) as Label
    var language_option := panel.find_child("LanguageOption", true, false) as OptionButton
    var done := panel.find_child("AccessibilityDone", true, false) as Button
    expect(title != null and title.text == expected_title, "11.5 panel title not localized: expected=%s" % expected_title)
    expect(language_label != null and language_label.text == expected_language, "11.5 panel language label not localized: expected=%s" % expected_language)
    expect(language_option != null and language_option.item_count == 3, "11.5 panel language selector does not expose 3 launch locales")
    expect(done != null and done.text == expected_done, "11.5 panel done button not localized: expected=%s" % expected_done)
    if language_option != null:
        expect(language_option.get_item_text(0) == "Português (Brasil)", "11.5 locale selector must use native locale names")
        expect(language_option.get_item_text(1) == "English", "11.5 English native locale label missing")
        expect(language_option.get_item_text(2) == "Español (Latinoamérica)", "11.5 Spanish native locale label missing")
    panel_checks += 1

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        print("ERROR: LOCALIZATION_ARCHITECTURE_CERTIFICATION: %s" % message)

func _finish() -> void:
    if failures.is_empty():
        print("LOCALIZATION_ARCHITECTURE_CERTIFICATION PASS: 11.5 schema=2 launch_locales=3 aliases=%d ui_checks=%d label_checks=%d content_overlays=%d panels=%d nested_paths=2" % [alias_checks,ui_key_checks,label_checks,content_overlay_checks,panel_checks])
        get_tree().quit(0)
    else:
        print("LOCALIZATION_ARCHITECTURE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)
