#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from export_localization_catalog import build_catalog

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
TARGETS = ("en", "es_419")
EXPECTED_ABILITY_NAMES = 72
EXPECTED_BOSS_PHASE_NAMES = 180

VERBS = {
    "Cortar": {"en": "Cut", "es_419": "Cortar"},
    "Ancorar": {"en": "Anchor", "es_419": "Anclar"},
    "Ouvir": {"en": "Listen to", "es_419": "Escuchar"},
    "Fisgar": {"en": "Hook", "es_419": "Enganchar"},
    "Dobrar": {"en": "Bend", "es_419": "Doblar"},
    "Ressoar": {"en": "Resonate", "es_419": "Resonar"},
}

MATERIALS = {
    "Brasa Branca": {"en": "White Ember", "es_419": "Brasa Blanca"},
    "Bronze Aquecido": {"en": "Heated Bronze", "es_419": "Bronce Caliente"},
    "Bronze Salgado": {"en": "Salted Bronze", "es_419": "Bronce Salado"},
    "Cabos Trançados": {"en": "Braided Cables", "es_419": "Cables Trenzados"},
    "Casca Viva": {"en": "Living Bark", "es_419": "Corteza Viva"},
    "Cinza Fina": {"en": "Fine Ash", "es_419": "Ceniza Fina"},
    "Cipós Tensos": {"en": "Taut Vines", "es_419": "Enredaderas Tensas"},
    "Conchas Secas": {"en": "Dry Shells", "es_419": "Conchas Secas"},
    "Contrapesos De Ferro": {"en": "Iron Counterweights", "es_419": "Contrapesos de Hierro"},
    "Coral Negro": {"en": "Black Coral", "es_419": "Coral Negro"},
    "Cordas De Poço": {"en": "Well Ropes", "es_419": "Cuerdas de Pozo"},
    "Cordas Encharcadas": {"en": "Soaked Ropes", "es_419": "Cuerdas Empapadas"},
    "Couro De Códice": {"en": "Codex Leather", "es_419": "Cuero de Códice"},
    "Cristal De Aurora": {"en": "Aurora Crystal", "es_419": "Cristal de Aurora"},
    "Escória Quente": {"en": "Hot Slag", "es_419": "Escoria Caliente"},
    "Estacas Sem Fundo": {"en": "Bottomless Stakes", "es_419": "Estacas sin Fondo"},
    "Ferro Vivo": {"en": "Living Iron", "es_419": "Hierro Vivo"},
    "Fio Causal": {"en": "Causal Thread", "es_419": "Hilo Causal"},
    "Fuligem Fria": {"en": "Cold Soot", "es_419": "Hollín Frío"},
    "Gelo Azul": {"en": "Blue Ice", "es_419": "Hielo Azul"},
    "Juncos De Duas Sombras": {"en": "Two-Shadow Reeds", "es_419": "Juncos de Dos Sombras"},
    "Latão De Chave": {"en": "Key Brass", "es_419": "Latón de Llave"},
    "Lodo Espelhado": {"en": "Mirrored Silt", "es_419": "Lodo Espejado"},
    "Madeira De Soleira": {"en": "Threshold Wood", "es_419": "Madera de Umbral"},
    "Matrizes De Bronze": {"en": "Bronze Matrices", "es_419": "Matrices de Bronce"},
    "Nácar Frio": {"en": "Cold Nacre", "es_419": "Nácar Frío"},
    "Nós De Luz Opaca": {"en": "Knots of Dim Light", "es_419": "Nudos de Luz Opaca"},
    "Osso Fossilizado": {"en": "Fossilized Bone", "es_419": "Hueso Fosilizado"},
    "Papel De Memória": {"en": "Memory Paper", "es_419": "Papel de Memoria"},
    "Papel Queimado": {"en": "Burnt Paper", "es_419": "Papel Quemado"},
    "Pedra Alaranjada": {"en": "Orange Stone", "es_419": "Piedra Anaranjada"},
    "Pedra Impossível": {"en": "Impossible Stone", "es_419": "Piedra Imposible"},
    "Pedra Sem Nome": {"en": "Nameless Stone", "es_419": "Piedra sin Nombre"},
    "Pedra Suspensa": {"en": "Suspended Stone", "es_419": "Piedra Suspendida"},
    "Pedra Topológica": {"en": "Topological Stone", "es_419": "Piedra Topológica"},
    "Pele De Neve": {"en": "Snow Hide", "es_419": "Piel de Nieve"},
    "Raízes Antigas": {"en": "Ancient Roots", "es_419": "Raíces Antiguas"},
    "Rebites Incandescentes": {"en": "Incandescent Rivets", "es_419": "Remaches Incandescentes"},
    "Sal Vivo": {"en": "Living Salt", "es_419": "Sal Viva"},
    "Seiva Negra": {"en": "Black Sap", "es_419": "Savia Negra"},
    "Tecido De Sombra": {"en": "Shadowcloth", "es_419": "Tela de Sombra"},
    "Tecido De Vento": {"en": "Windcloth", "es_419": "Tela de Viento"},
    "Tinta De Endereço": {"en": "Address Ink", "es_419": "Tinta de Dirección"},
    "Tinta Viva": {"en": "Living Ink", "es_419": "Tinta Viva"},
    "Vidro De Futuro": {"en": "Future Glass", "es_419": "Vidrio del Futuro"},
    "Vidro De Índice": {"en": "Index Glass", "es_419": "Vidrio de Índice"},
    "Vidro Solar": {"en": "Sun Glass", "es_419": "Vidrio Solar"},
    "Água Prateada": {"en": "Silvered Water", "es_419": "Agua Plateada"},
}

BOSS_PHASES = {
    "Leitura": {"en": "Reading", "es_419": "Lectura"},
    "Ruptura": {"en": "Rupture", "es_419": "Ruptura"},
    "Consequência": {"en": "Consequence", "es_419": "Consecuencia"},
}


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected object: {path}")
    return value


def translate_ability_name(source: str, locale: str) -> str:
    if " " not in source:
        raise SystemExit(f"ability name lacks verb/material split: {source}")
    verb, material = source.split(" ", 1)
    if verb not in VERBS or material not in MATERIALS:
        raise SystemExit(f"unmapped ability name: {source}")
    return f"{VERBS[verb][locale]} {MATERIALS[material][locale]}"


def collect_units() -> dict[str, list[dict]]:
    catalog = build_catalog()
    result = {locale: [] for locale in TARGETS}
    ability_count = 0
    phase_count = 0
    for unit in catalog["units"]:
        key = str(unit.get("key", ""))
        record_id = str(unit.get("record_id", ""))
        path = str(unit.get("path", ""))
        source = str(unit.get("source", ""))
        translations = None
        group = ""
        if record_id.startswith("ability.") and path == "name":
            translations = {locale: translate_ability_name(source, locale) for locale in TARGETS}
            ability_count += 1
            group = "ability_name"
        elif record_id.startswith("boss.") and re.fullmatch(r"phases\.\d+\.name", path):
            if source not in BOSS_PHASES:
                raise SystemExit(f"unmapped boss phase name: {source}")
            translations = BOSS_PHASES[source]
            phase_count += 1
            group = "boss_phase_name"
        if translations is None:
            continue
        for locale in TARGETS:
            result[locale].append({
                "key": key,
                "record_id": record_id,
                "path": path,
                "source": source,
                "translation": translations[locale],
                "group": group,
            })
    if ability_count != EXPECTED_ABILITY_NAMES or phase_count != EXPECTED_BOSS_PHASE_NAMES:
        raise SystemExit(
            f"structured name inventory drifted: abilities={ability_count}/{EXPECTED_ABILITY_NAMES} "
            f"boss_phases={phase_count}/{EXPECTED_BOSS_PHASE_NAMES}"
        )
    return result


def apply(locale: str, units: list[dict], check_only: bool) -> tuple[int, int]:
    path = LOC / "content" / f"{locale}.json"
    overlay = read_object(path)
    missing = 0
    added = 0
    for unit in units:
        record_id = unit["record_id"]
        field_path = unit["path"]
        record = overlay.get(record_id)
        if not isinstance(record, dict):
            record = {}
            if not check_only:
                overlay[record_id] = record
        current = record.get(field_path) if isinstance(record, dict) else None
        if isinstance(current, str) and current.strip():
            continue
        missing += 1
        if not check_only:
            record[field_path] = unit["translation"]
            added += 1
    if check_only and missing:
        raise SystemExit(f"{locale}: {missing} structured name translations missing")
    if not check_only:
        path.write_text(json.dumps(overlay, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return added, missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed deterministic translations for ability names and boss phase names.")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    units = collect_units()
    expected = EXPECTED_ABILITY_NAMES + EXPECTED_BOSS_PHASE_NAMES
    for locale in TARGETS:
        added, missing = apply(locale, units[locale], args.check)
        print(
            "STRUCTURED_NAME_LOCALIZATION %s: required=%d added=%d missing_before=%d mode=%s"
            % (locale, expected, added, missing, "check" if args.check else "apply")
        )
    print(
        "STRUCTURED_NAME_LOCALIZATION PASS: ability_names=%d boss_phase_names=%d units_per_target=%d"
        % (EXPECTED_ABILITY_NAMES, EXPECTED_BOSS_PHASE_NAMES, expected)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
