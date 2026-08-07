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
for singleton in ["DomainThemeService", "AccessibilityService", "PresentationBus"]:
    if f'{singleton}="*res://' not in project:
        errors.append(f"autoload missing: {singleton}")

for path, autoload_name in [
    ("ui/DomainThemeService.gd", "DomainThemeService"),
    ("ui/AccessibilityService.gd", "AccessibilityService"),
    ("ui/PresentationBus.gd", "PresentationBus"),
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

access = text("ui/AccessibilityService.gd")
for token in ["font_size", "high_contrast", "reduce_motion", "flashes_disabled", "icon_labels_enabled", "haptic", "SETTINGS_PATH"]:
    if token not in access:
        errors.append(f"accessibility feature missing: {token}")

palette_path = need("ui/domain_palettes.json")
if palette_path.exists():
    palettes = json.loads(palette_path.read_text(encoding="utf-8"))
    if len(palettes.get("domains", {})) != 12:
        errors.append("expected 12 domain palettes")

def count_groups(path: str, prefix: str) -> int:
    source = text(path)
    return len(re.findall(rf'<g\s+id="{re.escape(prefix)}[^\"]*"', source))

# Atlas QA uses known manifest structure rather than visual similarity.
for path in [
    "ui/assets/vector/system_icons_atlas.svg",
    "ui/assets/vector/mark_glyphs_atlas.svg",
    "ui/assets/vector/item_archetypes_atlas.svg",
    "ui/assets/vector/domain_ornaments_atlas.svg",
    "ui/shaders/parchment_paper.gdshader",
]:
    need(path)

presentation = text("ui/PresentationBus.gd")
for signal_name in ["mark_added", "damage_applied", "intent_revealed", "boss_phase_changed", "location_changed"]:
    if f"signal {signal_name}" not in presentation:
        errors.append(f"presentation signal missing: {signal_name}")

combat = text("core/systems/CombatEngine.gd")
for hook in ["PresentationBus.intent", "PresentationBus.damage", "PresentationBus.boss_phase"]:
    if hook not in combat:
        errors.append(f"combat presentation hook missing: {hook}")

if errors:
    print("PHASE7_INTEGRATION FAIL")
    for error in errors:
        print(" -", error)
    sys.exit(1)

print("PHASE7_INTEGRATION PASS")
print("12 domain palettes; VFX, accessibility and presentation hooks present")
