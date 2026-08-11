extends Node

var failures: Array[String] = []
var routed_events: Array[String] = []
var routed_domains: Array[String] = []

func _ready() -> void:
    AudioRouter.event_routed.connect(_on_event_routed)
    AudioRouter.domain_routed.connect(_on_domain_routed)
    call_deferred("_run")

func _fail(message: String) -> void:
    failures.append(message)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)

func _on_event_routed(event_id: String, category: String, _resolved: bool, _path: String) -> void:
    routed_events.append("%s:%s" % [category, event_id])

func _on_domain_routed(domain_id: String, _music_resolved: bool, _ambience_resolved: bool) -> void:
    routed_domains.append(domain_id)

func _run() -> void:
    var audit: Dictionary = AudioRouter.audit_manifest()
    _expect(int(audit.get("schema_version", 0)) == 1, "audio manifest schema must be v1")
    _expect(int(audit.get("ui_events", 0)) == 7, "expected 7 UI audio events")
    _expect(int(audit.get("combat_events", 0)) == 7, "expected 7 combat audio events")
    _expect(int(audit.get("domains", 0)) == 12, "expected 12 domain audio identities")
    _expect(int(audit.get("reference_count", 0)) == 38, "expected 38 launch audio references")
    _expect((audit.get("missing_buses", []) as Array).is_empty(), "runtime audio buses must exist")
    _expect((audit.get("invalid_domains", []) as Array).is_empty(), "every domain needs at least three signature motifs")

    var mix: Dictionary = AudioRouter.audit_mix()
    _expect(int(mix.get("schema_version", 0)) == 1, "audio mix schema must be v1")
    _expect(str(mix.get("principle", "")) == "sound_supports_reading", "reading-first mix principle missing")
    _expect((mix.get("missing_levels", []) as Array).is_empty(), "every required bus needs an explicit launch level")
    _expect(bool(mix.get("music_within_cap", false)), "music bus exceeds reading-first cap")
    _expect(bool(mix.get("ambience_within_cap", false)), "ambience bus exceeds reading-first cap")
    var margin_required := float(mix.get("foreground_min_margin_db", 4.0))
    _expect(float(mix.get("music_foreground_margin_db", 0.0)) >= margin_required, "music/foreground margin is too small")
    _expect(float(mix.get("ambience_foreground_margin_db", 0.0)) >= margin_required, "ambience/foreground margin is too small")
    _expect(not bool(mix.get("essential_information_requires_audio", true)), "essential gameplay information cannot require audio")
    _expect(bool(mix.get("visual_text_feedback_required", false)), "sound-relevant feedback must also have visual/text presentation")

    for bus_name in ["Master", "Music", "Ambience", "SFX", "UI"]:
        var index := AudioServer.get_bus_index(bus_name)
        _expect(index >= 0, "runtime bus missing: %s" % bus_name)
    var expected_levels := {
        "Master": 0.0,
        "Music": -15.0,
        "Ambience": -18.0,
        "SFX": -9.0,
        "UI": -8.0,
    }
    for bus_name in expected_levels:
        var index := AudioServer.get_bus_index(bus_name)
        if index >= 0:
            _expect(absf(AudioServer.get_bus_volume_db(index) - float(expected_levels[bus_name])) < 0.01, "runtime bus level mismatch: %s" % bus_name)

    # Exercise the actual presentation layer used by gameplay. Missing final audio
    # must never break page/choice/combat feedback or make the UI unusable.
    PresentationBus.page()
    PresentationBus.choice()
    PresentationBus.mark("mark.qa")
    PresentationBus.damage("hero", 1)
    PresentationBus.intent({"kind": "attack"})
    PresentationBus.boss_phase(2)

    var expected_events := [
        "ui:ui.page_turn",
        "ui:ui.confirm",
        "ui:ui.mark_acquired",
        "combat:combat.attack_light",
        "ui:ui.ink_mark",
        "combat:combat.boss_phase",
    ]
    for event_key in expected_events:
        _expect(event_key in routed_events, "presentation event not routed: %s" % event_key)

    var domain_ids := [
        "mata_fio_verde", "varzea_espelhos", "costa_sinos_afogados",
        "chapada_sol_oco", "salinas_ossamar", "vertice", "forja_rubra",
        "mar_cinza", "noite_iscara", "cidade_mil_portas", "arquivo_ecos",
        "tear_desfeito",
    ]
    for domain_id in domain_ids:
        AudioRouter.enter_domain(domain_id, 0.0)
    for domain_id in domain_ids:
        _expect(domain_id in routed_domains, "domain route not exercised: %s" % domain_id)

    # Accessibility requirement: the same essential presentation signals complete
    # even when every audio resource is unresolved. Resolution is a final-asset gate,
    # not a prerequisite for game-state feedback.
    _expect(routed_events.size() >= expected_events.size(), "presentation routing stopped when audio was unavailable")

    var missing_assets: Array = audit.get("missing_assets", [])
    var require_final_assets := OS.get_environment("VEREDAS_REQUIRE_FINAL_AUDIO") == "1"
    if require_final_assets and not missing_assets.is_empty():
        _fail("final audiovisual QA requires all 38 audio references to resolve; missing=%d" % missing_assets.size())

    if failures.is_empty():
        if missing_assets.is_empty():
            print("AUDIOVISUAL_CONTEXT_CERTIFICATION PASS: 11.7 routes=6 domains=12 assets=38/38 buses=5 mix=reading-first")
        else:
            print("AUDIOVISUAL_CONTEXT_PREFLIGHT PASS: routes=6 domains=12 buses=5 mix=reading-first final_assets_missing=%d" % missing_assets.size())
            print("AUDIOVISUAL_CONTEXT_BLOCKED: 7.8/7.10 final audio assets are required before 11.7 can be promoted")
        get_tree().quit(0)
        return

    print("AUDIOVISUAL_CONTEXT_CERTIFICATION FAIL: %d issue(s)" % failures.size())
    for failure in failures:
        print(" - ", failure)
    get_tree().quit(1)
