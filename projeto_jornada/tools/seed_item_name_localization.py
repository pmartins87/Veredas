#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from export_localization_catalog import build_catalog

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
TARGETS = ("en", "es_419")
EXPECTED = 1116

BASES = {
    "Lâmina": {"en": "Blade", "es_419": "Hoja"},
    "Adaga": {"en": "Dagger", "es_419": "Daga"},
    "Machado": {"en": "Axe", "es_419": "Hacha"},
    "Lança": {"en": "Spear", "es_419": "Lanza"},
    "Arco": {"en": "Bow", "es_419": "Arco"},
    "Broquel": {"en": "Buckler", "es_419": "Broquel"},
    "Elmo": {"en": "Helm", "es_419": "Yelmo"},
    "Couraça": {"en": "Cuirass", "es_419": "Coraza"},
    "Botas": {"en": "Boots", "es_419": "Botas"},
    "Manto": {"en": "Cloak", "es_419": "Manto"},
    "Anel": {"en": "Ring", "es_419": "Anillo"},
    "Amuleto": {"en": "Amulet", "es_419": "Amuleto"},
    "Frasco": {"en": "Flask", "es_419": "Frasco"},
    "Erva": {"en": "Herb", "es_419": "Hierba"},
    "Pergaminho": {"en": "Scroll", "es_419": "Pergamino"},
    "Chave": {"en": "Key", "es_419": "Llave"},
    "Martelo": {"en": "Hammer", "es_419": "Martillo"},
    "Corda": {"en": "Rope", "es_419": "Cuerda"},
    "Lanterna": {"en": "Lantern", "es_419": "Linterna"},
    "Moeda": {"en": "Coin", "es_419": "Moneda"},
    "Cristal": {"en": "Crystal", "es_419": "Cristal"},
    "Ração": {"en": "Ration", "es_419": "Ración"},
    "Relíquia": {"en": "Relic", "es_419": "Reliquia"},
    "Ferramenta": {"en": "Tool", "es_419": "Herramienta"},
    "Faca": {"en": "Knife", "es_419": "Cuchillo"},
    "Escudo": {"en": "Shield", "es_419": "Escudo"},
    "Capuz": {"en": "Hood", "es_419": "Capucha"},
    "Colete": {"en": "Vest", "es_419": "Chaleco"},
    "Sandálias": {"en": "Sandals", "es_419": "Sandalias"},
    "Talismã": {"en": "Talisman", "es_419": "Talismán"},
    "Unguento": {"en": "Ointment", "es_419": "Ungüento"},
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
    "Musgo Luminoso": {"en": "Luminescent Moss", "es_419": "Musgo Luminoso"},
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

SUFFIXES = {
    "do Juramento": {"en": "of the Oath", "es_419": "del Juramento"},
    "da Vigília": {"en": "of the Vigil", "es_419": "de la Vigilia"},
    "do Retorno": {"en": "of the Return", "es_419": "del Retorno"},
}


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected object: {path}")
    return value


def parse_item_name(source: str) -> tuple[str, str, str]:
    suffix = next((value for value in SUFFIXES if source.endswith(" " + value)), None)
    if suffix is None:
        raise SystemExit(f"unmapped item suffix: {source}")
    core = source[: -(len(suffix) + 1)]
    if " de " not in core:
        raise SystemExit(f"item name lacks base/material split: {source}")
    base, material = core.split(" de ", 1)
    if base not in BASES:
        raise SystemExit(f"unmapped item base: {base}")
    if material not in MATERIALS:
        raise SystemExit(f"unmapped item material: {material}")
    return base, material, suffix


def translate(source: str, locale: str) -> str:
    base, material, suffix = parse_item_name(source)
    if locale == "en":
        return f"{MATERIALS[material][locale]} {BASES[base][locale]} {SUFFIXES[suffix][locale]}"
    return f"{BASES[base][locale]} de {MATERIALS[material][locale]} {SUFFIXES[suffix][locale]}"


def collect_units() -> dict[str, list[dict]]:
    catalog = build_catalog()
    result = {locale: [] for locale in TARGETS}
    count = 0
    for unit in catalog["units"]:
        record_id = str(unit.get("record_id", ""))
        path = str(unit.get("path", ""))
        if not record_id.startswith("item.") or path != "name":
            continue
        source = str(unit.get("source", ""))
        count += 1
        for locale in TARGETS:
            result[locale].append({
                "record_id": record_id,
                "translation": translate(source, locale),
            })
    if count != EXPECTED:
        raise SystemExit(f"item-name inventory drifted: {count}/{EXPECTED}")
    if len(BASES) != 31 or len(MATERIALS) != 49 or len(SUFFIXES) != 3:
        raise SystemExit(f"item grammar vocabulary drifted: bases={len(BASES)} materials={len(MATERIALS)} suffixes={len(SUFFIXES)}")
    return result


def apply(locale: str, units: list[dict], check_only: bool) -> tuple[int, int]:
    path = LOC / "content" / f"{locale}.json"
    overlay = read_object(path)
    missing = 0
    added = 0
    for unit in units:
        record_id = unit["record_id"]
        record = overlay.get(record_id)
        if not isinstance(record, dict):
            record = {}
            if not check_only:
                overlay[record_id] = record
        current = record.get("name") if isinstance(record, dict) else None
        if isinstance(current, str) and current.strip():
            continue
        missing += 1
        if not check_only:
            record["name"] = unit["translation"]
            added += 1
    if check_only and missing:
        raise SystemExit(f"{locale}: {missing} item-name translations missing")
    if not check_only:
        path.write_text(json.dumps(overlay, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return added, missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed deterministic translations for the closed item-name grammar.")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    units = collect_units()
    for locale in TARGETS:
        added, missing = apply(locale, units[locale], args.check)
        print(
            "ITEM_NAME_LOCALIZATION %s: required=%d added=%d missing_before=%d mode=%s"
            % (locale, EXPECTED, added, missing, "check" if args.check else "apply")
        )
    print("ITEM_NAME_LOCALIZATION PASS: items=%d bases=%d materials=%d suffixes=%d" % (EXPECTED, len(BASES), len(MATERIALS), len(SUFFIXES)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
