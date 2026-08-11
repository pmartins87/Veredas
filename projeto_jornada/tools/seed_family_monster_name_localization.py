#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from export_localization_catalog import build_catalog

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
TARGETS = ("en", "es_419")
EXPECTED_FAMILIES = 96
EXPECTED_MONSTERS = 300
FAMILIES_PER_WORLD = 8
MONSTERS_PER_WORLD = 25

FAMILY_NAMES = {
    "Rasuras": {"en": "Erasures", "es_419": "Borraduras"},
    "Copistas Vazios": {"en": "Empty Copyists", "es_419": "Copistas Vacíos"},
    "Bibliotecários Mortos": {"en": "Dead Librarians", "es_419": "Bibliotecarios Muertos"},
    "Ecos Predatórios": {"en": "Predatory Echoes", "es_419": "Ecos Depredadores"},
    "Índices Vivos": {"en": "Living Indexes", "es_419": "Índices Vivos"},
    "Manchas de Tinta": {"en": "Ink Stains", "es_419": "Manchas de Tinta"},
    "Folhas Cortantes": {"en": "Cutting Pages", "es_419": "Hojas Cortantes"},
    "Memórias Órfãs": {"en": "Orphaned Memories", "es_419": "Memorias Huérfanas"},
    "Homens de Sol": {"en": "Sun Men", "es_419": "Hombres del Sol"},
    "Escorpiões de Sombra": {"en": "Shadow Scorpions", "es_419": "Escorpiones de Sombra"},
    "Lagartos de Vidro": {"en": "Glass Lizards", "es_419": "Lagartos de Vidrio"},
    "Abutres de Meio-Dia": {"en": "Midday Vultures", "es_419": "Buitres del Mediodía"},
    "Serpentes de Calor": {"en": "Heat Serpents", "es_419": "Serpientes de Calor"},
    "Cabras do Eclipse": {"en": "Eclipse Goats", "es_419": "Cabras del Eclipse"},
    "Besouros de Obelisco": {"en": "Obelisk Beetles", "es_419": "Escarabajos de Obelisco"},
    "Miras de Luz": {"en": "Light Sights", "es_419": "Miras de Luz"},
    "Mímicos de Porta": {"en": "Door Mimics", "es_419": "Mímicos de Puerta"},
    "Cães de Soleira": {"en": "Threshold Hounds", "es_419": "Perros de Umbral"},
    "Chaveiros Vazios": {"en": "Empty Locksmiths", "es_419": "Cerrajeros Vacíos"},
    "Aranhas de Fechadura": {"en": "Lock Spiders", "es_419": "Arañas de Cerradura"},
    "Guardas de Limiar": {"en": "Threshold Guards", "es_419": "Guardias del Umbral"},
    "Ratos de Corredor": {"en": "Corridor Rats", "es_419": "Ratas de Corredor"},
    "Sombras de Endereço": {"en": "Address Shadows", "es_419": "Sombras de Dirección"},
    "Portas Famintas": {"en": "Hungry Doors", "es_419": "Puertas Hambrientas"},
    "Cavaleiros de Coral": {"en": "Coral Knights", "es_419": "Caballeros de Coral"},
    "Gaivotas de Tempestade": {"en": "Storm Gulls", "es_419": "Gaviotas de Tormenta"},
    "Caranguejos de Bronze": {"en": "Bronze Crabs", "es_419": "Cangrejos de Bronce"},
    "Enguias de Sino": {"en": "Bell Eels", "es_419": "Anguilas de Campana"},
    "Afogados de Odria": {"en": "Drowned of Odria", "es_419": "Ahogados de Odria"},
    "Medusas de Nácar": {"en": "Nacre Jellyfish", "es_419": "Medusas de Nácar"},
    "Lobos de Espuma": {"en": "Foam Wolves", "es_419": "Lobos de Espuma"},
    "Leviatãs Menores": {"en": "Lesser Leviathans", "es_419": "Leviatanes Menores"},
    "Soldados Inacabados": {"en": "Unfinished Soldiers", "es_419": "Soldados Inacabados"},
    "Cães de Escória": {"en": "Slag Hounds", "es_419": "Perros de Escoria"},
    "Autômatos de Martelo": {"en": "Hammer Automatons", "es_419": "Autómatas de Martillo"},
    "Vermes de Fornalha": {"en": "Furnace Worms", "es_419": "Gusanos de Horno"},
    "Tecelões de Arame": {"en": "Wire Weavers", "es_419": "Tejedores de Alambre"},
    "Gárgulas de Ferro": {"en": "Iron Gargoyles", "es_419": "Gárgolas de Hierro"},
    "Enxames de Rebite": {"en": "Rivet Swarms", "es_419": "Enjambres de Remaches"},
    "Moldes Vivos": {"en": "Living Molds", "es_419": "Moldes Vivos"},
    "Devoradores de Marca": {"en": "Mark Devourers", "es_419": "Devoradores de Marcas"},
    "Lobos de Fuligem": {"en": "Soot Wolves", "es_419": "Lobos de Hollín"},
    "Monges Vazios": {"en": "Empty Monks", "es_419": "Monjes Vacíos"},
    "Nomes Perdidos": {"en": "Lost Names", "es_419": "Nombres Perdidos"},
    "Corvos de Cinza": {"en": "Ash Crows", "es_419": "Cuervos de Ceniza"},
    "Vultos Apagados": {"en": "Erased Figures", "es_419": "Siluetas Borradas"},
    "Cervos sem Rastro": {"en": "Trackless Deer", "es_419": "Ciervos sin Rastro"},
    "Erasores": {"en": "Erasers", "es_419": "Borradores"},
    "Cães de Casca": {"en": "Bark Hounds", "es_419": "Perros de Corteza"},
    "Onças de Casca": {"en": "Bark Jaguars", "es_419": "Jaguares de Corteza"},
    "Aranhas de Nó": {"en": "Knot Spiders", "es_419": "Arañas de Nudo"},
    "Macacos de Liana": {"en": "Vine Monkeys", "es_419": "Monos de Liana"},
    "Vespas de Seiva": {"en": "Sap Wasps", "es_419": "Avispas de Savia"},
    "Cervos de Musgo": {"en": "Moss Deer", "es_419": "Ciervos de Musgo"},
    "Fungos Caminhantes": {"en": "Walking Fungi", "es_419": "Hongos Caminantes"},
    "Predadores de Raiz": {"en": "Root Predators", "es_419": "Depredadores de Raíz"},
    "Lobos de Vidro": {"en": "Glass Wolves", "es_419": "Lobos de Vidrio"},
    "Ursos de Aurora": {"en": "Aurora Bears", "es_419": "Osos de Aurora"},
    "Cervos de Gelo": {"en": "Ice Deer", "es_419": "Ciervos de Hielo"},
    "Corujas do Futuro": {"en": "Future Owls", "es_419": "Búhos del Futuro"},
    "Serpentes de Brasa": {"en": "Ember Serpents", "es_419": "Serpientes de Brasa"},
    "Espectros Boreais": {"en": "Boreal Specters", "es_419": "Espectros Boreales"},
    "Caribus de Cristal": {"en": "Crystal Caribou", "es_419": "Caribúes de Cristal"},
    "Caçadores de Neve": {"en": "Snow Hunters", "es_419": "Cazadores de Nieve"},
    "Fósseis Andantes": {"en": "Walking Fossils", "es_419": "Fósiles Caminantes"},
    "Lagartos de Sal": {"en": "Salt Lizards", "es_419": "Lagartos de Sal"},
    "Abutres de Osso": {"en": "Bone Vultures", "es_419": "Buitres de Hueso"},
    "Escorpiões Calcificados": {"en": "Calcified Scorpions", "es_419": "Escorpiones Calcificados"},
    "Peixes de Areia": {"en": "Sand Fish", "es_419": "Peces de Arena"},
    "Vermes de Concha": {"en": "Shell Worms", "es_419": "Gusanos de Concha"},
    "Carneiros de Salmoura": {"en": "Brine Rams", "es_419": "Carneros de Salmuera"},
    "Sirenes Secas": {"en": "Dry Sirens", "es_419": "Sirenas Secas"},
    "Futuros Abortados": {"en": "Aborted Futures", "es_419": "Futuros Abortados"},
    "Nós Famintos": {"en": "Hungry Knots", "es_419": "Nudos Hambrientos"},
    "Tecelões Invertidos": {"en": "Inverted Weavers", "es_419": "Tejedores Invertidos"},
    "Bestas de Possibilidade": {"en": "Beasts of Possibility", "es_419": "Bestias de Posibilidad"},
    "Fragmentos Humanos": {"en": "Human Fragments", "es_419": "Fragmentos Humanos"},
    "Rupturas Ambulantes": {"en": "Walking Ruptures", "es_419": "Rupturas Ambulantes"},
    "Paradoxos Menores": {"en": "Lesser Paradoxes", "es_419": "Paradojas Menores"},
    "Formas sem Causa": {"en": "Causeless Forms", "es_419": "Formas sin Causa"},
    "Reflexos Famintos": {"en": "Hungry Reflections", "es_419": "Reflejos Hambrientos"},
    "Jacarés de Espelho": {"en": "Mirror Caimans", "es_419": "Caimanes de Espejo"},
    "Enguias de Duplo Corpo": {"en": "Double-Bodied Eels", "es_419": "Anguilas de Doble Cuerpo"},
    "Garças Invertidas": {"en": "Inverted Herons", "es_419": "Garzas Invertidas"},
    "Cardumes de Memória": {"en": "Shoals of Memory", "es_419": "Cardúmenes de Memoria"},
    "Lodos Reflexivos": {"en": "Reflective Slimes", "es_419": "Lodos Reflexivos"},
    "Anfíbios de Prata": {"en": "Silver Amphibians", "es_419": "Anfibios de Plata"},
    "Afogados sem Rosto": {"en": "Faceless Drowned", "es_419": "Ahogados sin Rostro"},
    "Serpes de Nuvem": {"en": "Cloud Serpents", "es_419": "Serpientes de Nube"},
    "Corvos de Cabo": {"en": "Cable Crows", "es_419": "Cuervos de Cable"},
    "Cabras de Penhasco": {"en": "Cliff Goats", "es_419": "Cabras de Acantilado"},
    "Aranhas de Ponte": {"en": "Bridge Spiders", "es_419": "Arañas de Puente"},
    "Mantos de Vento": {"en": "Wind Mantles", "es_419": "Mantos de Viento"},
    "Golems de Contrapeso": {"en": "Counterweight Golems", "es_419": "Gólems de Contrapeso"},
    "Morcegos de Abismo": {"en": "Abyss Bats", "es_419": "Murciélagos de Abismo"},
    "Falcões de Tensão": {"en": "Tension Hawks", "es_419": "Halcones de Tensión"},
}

MODIFIERS = [
    "Jovem", "Ancião", "Errante", "Pálido", "Fendido", "Veloz", "Couraçado", "Silencioso",
    "Faminto", "Ressonante", "Cego", "Vermelho", "Oco", "Vigilante", "Solitário", "Deformado",
    "Marcado", "Trepador", "Submerso", "Crepuscular", "Cintilante", "Enraizado", "Migrante", "Guardião", "Predador",
]

MODIFIER_TRANSLATIONS = {
    "Jovem": {"en": "Young", "es_419": "Jóvenes"},
    "Ancião": {"en": "Ancient", "es_419": "Ancestrales"},
    "Errante": {"en": "Wandering", "es_419": "Errantes"},
    "Pálido": {"en": "Pale", "es_419": "de Palidez Espectral"},
    "Fendido": {"en": "Split", "es_419": "con Fisuras"},
    "Veloz": {"en": "Swift", "es_419": "Veloces"},
    "Couraçado": {"en": "Armored", "es_419": "con Coraza"},
    "Silencioso": {"en": "Silent", "es_419": "Silentes"},
    "Faminto": {"en": "Hungry", "es_419": "Voraces"},
    "Ressonante": {"en": "Resonant", "es_419": "Resonantes"},
    "Cego": {"en": "Blind", "es_419": "sin Vista"},
    "Vermelho": {"en": "Red", "es_419": "Carmesí"},
    "Oco": {"en": "Hollow", "es_419": "de Interior Vacío"},
    "Vigilante": {"en": "Watchful", "es_419": "Vigilantes"},
    "Solitário": {"en": "Solitary", "es_419": "en Soledad"},
    "Deformado": {"en": "Deformed", "es_419": "Deformes"},
    "Marcado": {"en": "Marked", "es_419": "con Marca"},
    "Trepador": {"en": "Climbing", "es_419": "que Trepan"},
    "Submerso": {"en": "Submerged", "es_419": "bajo el Agua"},
    "Crepuscular": {"en": "Twilight", "es_419": "Crepusculares"},
    "Cintilante": {"en": "Shimmering", "es_419": "Centelleantes"},
    "Enraizado": {"en": "Rooted", "es_419": "con Raíces"},
    "Migrante": {"en": "Migratory", "es_419": "Migrantes"},
    "Guardião": {"en": "Guardian", "es_419": "de Guardia"},
    "Predador": {"en": "Predatory", "es_419": "de Caza"},
}


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected object: {path}")
    return value


def source_units() -> tuple[list[dict], list[dict]]:
    catalog = build_catalog()
    families = [u for u in catalog["units"] if str(u.get("record_id", "")).startswith("family.") and u.get("path") == "name"]
    monsters = [u for u in catalog["units"] if str(u.get("record_id", "")).startswith("monster.") and u.get("path") == "name"]
    if len(families) != EXPECTED_FAMILIES or len(monsters) != EXPECTED_MONSTERS:
        raise SystemExit(f"family/monster inventory drifted: families={len(families)} monsters={len(monsters)}")
    if len(FAMILY_NAMES) != EXPECTED_FAMILIES or len(MODIFIER_TRANSLATIONS) != len(MODIFIERS):
        raise SystemExit(f"translation vocabulary drifted: families={len(FAMILY_NAMES)} modifiers={len(MODIFIER_TRANSLATIONS)}")
    return families, monsters


def family_by_world(families: list[dict]) -> dict[str, list[dict]]:
    worlds: dict[str, list[dict]] = {}
    for unit in families:
        parts = str(unit["record_id"]).split(".")
        if len(parts) != 3:
            raise SystemExit(f"invalid family id: {unit['record_id']}")
        worlds.setdefault(parts[1], []).append(unit)
    for world, rows in worlds.items():
        rows.sort(key=lambda u: int(str(u["record_id"]).split(".")[-1]))
        if len(rows) != FAMILIES_PER_WORLD:
            raise SystemExit(f"{world}: expected 8 families, got {len(rows)}")
        for unit in rows:
            source = str(unit["source"])
            if source not in FAMILY_NAMES:
                raise SystemExit(f"unmapped family source: {source}")
    if len(worlds) != 12:
        raise SystemExit(f"expected 12 family worlds, got {len(worlds)}")
    return worlds


def collect_units() -> dict[str, list[dict]]:
    families, monsters = source_units()
    by_world = family_by_world(families)
    result = {locale: [] for locale in TARGETS}
    for unit in families:
        source = str(unit["source"])
        for locale in TARGETS:
            result[locale].append({"record_id": str(unit["record_id"]), "path": "name", "translation": FAMILY_NAMES[source][locale]})

    monster_world_counts: dict[str, int] = {}
    for unit in sorted(monsters, key=lambda u: str(u["record_id"])):
        parts = str(unit["record_id"]).split(".")
        if len(parts) != 3:
            raise SystemExit(f"invalid monster id: {unit['record_id']}")
        world = parts[1]
        index = int(parts[2])
        monster_world_counts[world] = monster_world_counts.get(world, 0) + 1
        if index < 1 or index > MONSTERS_PER_WORLD:
            raise SystemExit(f"monster index outside 1..25: {unit['record_id']}")
        family_unit = by_world[world][(index - 1) % FAMILIES_PER_WORLD]
        family_source = str(family_unit["source"])
        modifier = MODIFIERS[index - 1]
        source_name = str(unit["source"])
        if not source_name.endswith(" " + modifier):
            raise SystemExit(f"monster modifier drifted: {unit['record_id']} source={source_name!r} expected_suffix={modifier!r}")
        for locale in TARGETS:
            family_name = FAMILY_NAMES[family_source][locale]
            mod = MODIFIER_TRANSLATIONS[modifier][locale]
            translated = f"{mod} {family_name}" if locale == "en" else f"{family_name} — {mod}"
            result[locale].append({"record_id": str(unit["record_id"]), "path": "name", "translation": translated})
    if set(monster_world_counts.values()) != {MONSTERS_PER_WORLD} or len(monster_world_counts) != 12:
        raise SystemExit(f"monster world distribution drifted: {monster_world_counts}")
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
        raise SystemExit(f"{locale}: {missing} family/monster name translations missing")
    if not check_only:
        path.write_text(json.dumps(overlay, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return added, missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed editorial family names and deterministic monster variant names.")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    units = collect_units()
    expected = EXPECTED_FAMILIES + EXPECTED_MONSTERS
    for locale in TARGETS:
        added, missing = apply(locale, units[locale], args.check)
        print(
            "FAMILY_MONSTER_NAME_LOCALIZATION %s: required=%d added=%d missing_before=%d mode=%s"
            % (locale, expected, added, missing, "check" if args.check else "apply")
        )
    print("FAMILY_MONSTER_NAME_LOCALIZATION PASS: families=%d monsters=%d modifiers=%d" % (EXPECTED_FAMILIES, EXPECTED_MONSTERS, len(MODIFIERS)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
