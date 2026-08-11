#!/usr/bin/env python3
from pathlib import Path
import json, re, sys

ROOT = Path(__file__).resolve().parents[1]
errors = []

def need(path: str):
    p = ROOT / path
    if not p.exists():
        errors.append(f"missing {path}")
    return p

def text(path: str) -> str:
    p = need(path)
    return p.read_text(encoding="utf-8") if p.exists() else ""

project = text("project.godot")
for singleton in ["DomainThemeService", "AccessibilityService", "PresentationBus", "PresentationVFXController", "AudioRouter"]:
    if f'{singleton}="*res://' not in project:
        errors.append(f"autoload missing: {singleton}")

for path, autoload_name in [
    ("ui/DomainThemeService.gd", "DomainThemeService"),
    ("ui/AccessibilityService.gd", "AccessibilityService"),
    ("ui/PresentationBus.gd", "PresentationBus"),
    ("ui/PresentationVFXController.gd", "PresentationVFXController"),
    ("audio/AudioRouter.gd", "AudioRouter"),
]:
    source = text(path)
    if re.search(rf"^class_name\s+{re.escape(autoload_name)}\s*$", source, re.M):
        errors.append(f"autoload/global class collision: {autoload_name}")

main = text("scenes/Main.gd")
for token in ["BookVFX.page_settle", "BookVFX.choice_press", "AccessibilityPanel.new", "AccessibilityService.apply_font_scale"]:
    if token not in main:
        errors.append(f"Main integration missing: {token}")

vfx = text("ui/BookVFX.gd")
for fn in ["page_settle", "choice_press", "ink_stain", "stitch_mark", "intent_reveal", "thread_rupture", "location_transition"]:
    if f"func {fn}(" not in vfx:
        errors.append(f"VFX function missing: {fn}")

controller = text("ui/PresentationVFXController.gd")
for signal_hook in [
    "PresentationBus.damage_applied.connect",
    "PresentationBus.intent_revealed.connect",
    "PresentationBus.boss_phase_changed.connect",
    "PresentationBus.location_changed.connect",
    "PresentationBus.mark_added.connect",
]:
    if signal_hook not in controller:
        errors.append(f"presentation controller hook missing: {signal_hook}")
for effect_call in ["BookVFX.ink_stain", "BookVFX.intent_reveal", "BookVFX.thread_rupture", "BookVFX.location_transition", "BookVFX.stitch_mark"]:
    if effect_call not in controller:
        errors.append(f"presentation controller effect missing: {effect_call}")

access = text("ui/AccessibilityService.gd")
for token in ["font_size", "high_contrast", "reduce_motion", "flashes_disabled", "icon_labels_enabled", "haptic", "SETTINGS_PATH"]:
    if token not in access:
        errors.append(f"accessibility feature missing: {token}")

palette_path = need("ui/domain_palettes.json")
if palette_path.exists():
    palettes = json.loads(palette_path.read_text(encoding="utf-8"))
    if len(palettes.get("domains", {})) != 12:
        errors.append("expected 12 domain palettes")

for path in [
    "ui/assets/vector/system_icons_atlas.svg",
    "ui/assets/vector/mark_glyphs_atlas.svg",
    "ui/assets/vector/item_archetypes_atlas.svg",
    "ui/assets/vector/domain_ornaments_atlas.svg",
    "ui/shaders/parchment_paper.gdshader",
]:
    need(path)

presentation = text("ui/PresentationBus.gd")
for signal_name in ["page_changed", "choice_committed", "mark_added", "damage_applied", "intent_revealed", "boss_phase_changed", "location_changed"]:
    if f"signal {signal_name}" not in presentation:
        errors.append(f"presentation signal missing: {signal_name}")

audio_router = text("audio/AudioRouter.gd")
for hook in [
    "PresentationBus.page_changed.connect",
    "PresentationBus.choice_committed.connect",
    "PresentationBus.mark_added.connect",
    "PresentationBus.damage_applied.connect",
    "PresentationBus.intent_revealed.connect",
    "PresentationBus.boss_phase_changed.connect",
    "PresentationBus.location_changed.connect",
]:
    if hook not in audio_router:
        errors.append(f"audio presentation hook missing: {hook}")
for token in ["REQUIRED_BUSES", "audit_manifest", "play_ui", "play_combat", "enter_domain"]:
    if token not in audio_router:
        errors.append(f"audio router contract missing: {token}")

audio_manifest_path = need("audio/audio_events.json")
if audio_manifest_path.exists():
    audio_manifest = json.loads(audio_manifest_path.read_text(encoding="utf-8"))
    if audio_manifest.get("schema_version") != 1:
        errors.append("audio manifest schema must be v1")
    if len(audio_manifest.get("ui", {})) != 7:
        errors.append("expected 7 UI audio events")
    if len(audio_manifest.get("combat", {})) != 7:
        errors.append("expected 7 combat audio events")
    domains = audio_manifest.get("domains", {})
    if len(domains) != 12:
        errors.append("expected 12 domain audio identities")
    for domain_id, domain in domains.items():
        if len(domain.get("signature", [])) < 3:
            errors.append(f"domain audio signature incomplete: {domain_id}")
        for layer in ["music", "ambience"]:
            if not str(domain.get(layer, "")):
                errors.append(f"domain audio layer missing: {domain_id}.{layer}")

combat = text("core/systems/CombatEngine.gd")
for hook in ["PresentationBus.intent", "PresentationBus.damage", "BossPhaseEngine.transition_if_needed"]:
    if hook not in combat:
        errors.append(f"combat presentation/phase hook missing: {hook}")

boss_phase = text("core/systems/BossPhaseEngine.gd")
if "PresentationBus.boss_phase" not in boss_phase:
    errors.append("boss phase engine does not emit presentation hook")

if errors:
    print("PHASE7_INTEGRATION FAIL")
    for error in errors:
        print(" -", error)
    sys.exit(1)

print("PHASE7_INTEGRATION PASS")
print("12 domain palettes; VFX, accessibility, presentation and audio routing hooks present")
