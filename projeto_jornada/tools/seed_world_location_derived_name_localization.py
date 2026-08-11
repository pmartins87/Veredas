#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from export_localization_catalog import build_catalog

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
TARGETS = ("en", "es_419")
EXPECTED = {"world": 12, "location": 120, "mark": 204, "npc": 300, "ending": 36}

WORLD_NAMES = {
    "Arquivo dos Ecos": {"en": "Archive of Echoes", "es_419": "Archivo de los Ecos"},
    "Chapada do Sol Oco": {"en": "Hollow Sun Plateau", "es_419": "Meseta del Sol Hueco"},
    "Cidade das Mil Portas": {"en": "City of a Thousand Doors", "es_419": "Ciudad de las Mil Puertas"},
    "Costa dos Sinos Afogados": {"en": "Coast of the Drowned Bells", "es_419": "Costa de las Campanas Ahogadas"},
    "Forja Rubra": {"en": "Crimson Forge", "es_419": "Forja Rubra"},
    "Mar de Cinza": {"en": "Sea of Ash", "es_419": "Mar de Ceniza"},
    "Mata do Fio Verde": {"en": "Forest of the Green Thread", "es_419": "Selva del Hilo Verde"},
    "Noite de Iscara": {"en": "Night of Iscara", "es_419": "Noche de Iscara"},
    "Salinas de Ossamar": {"en": "Salt Flats of Ossamar", "es_419": "Salinas de Ossamar"},
    "Tear Desfeito": {"en": "Unraveled Loom", "es_419": "Telar Deshecho"},
    "Várzea dos Espelhos": {"en": "Mirror Floodplain", "es_419": "Llanura Inundable de los Espejos"},
    "Vértice": {"en": "Vertex", "es_419": "Vértice"},
}

LOCATION_NAMES = {
    "Galeria das Mortes": {"en": "Gallery of Deaths", "es_419": "Galería de las Muertes"},
    "Sala dos Índices Vivos": {"en": "Hall of Living Indexes", "es_419": "Sala de los Índices Vivos"},
    "Biblioteca das Vozes": {"en": "Library of Voices", "es_419": "Biblioteca de las Voces"},
    "Poço de Tinta": {"en": "Ink Well", "es_419": "Pozo de Tinta"},
    "Arquivo das Jornadas": {"en": "Archive of Journeys", "es_419": "Archivo de las Jornadas"},
    "Corredor das Rasuras": {"en": "Corridor of Erasures", "es_419": "Corredor de las Borraduras"},
    "Salão dos Copistas": {"en": "Hall of Copyists", "es_419": "Salón de los Copistas"},
    "Câmara dos Nomes Mortos": {"en": "Chamber of Dead Names", "es_419": "Cámara de los Nombres Muertos"},
    "Estante sem Fim": {"en": "Endless Shelf", "es_419": "Estantería sin Fin"},
    "Pátio dos Ecos Órfãos": {"en": "Courtyard of Orphaned Echoes", "es_419": "Patio de los Ecos Huérfanos"},
    "Cratera do Sol Oco": {"en": "Hollow Sun Crater", "es_419": "Cráter del Sol Hueco"},
    "Cidade das Sete Sombras": {"en": "City of Seven Shadows", "es_419": "Ciudad de las Siete Sombras"},
    "Cisterna de Jaru": {"en": "Jaru Cistern", "es_419": "Cisterna de Jaru"},
    "Vila sem Noite": {"en": "Nightless Village", "es_419": "Aldea sin Noche"},
    "Poço de Meio-Dia": {"en": "Midday Well", "es_419": "Pozo del Mediodía"},
    "Obelisco da Oitava Sombra": {"en": "Obelisk of the Eighth Shadow", "es_419": "Obelisco de la Octava Sombra"},
    "Santuário do Eclipse": {"en": "Eclipse Sanctuary", "es_419": "Santuario del Eclipse"},
    "Campo do Vidro Solar": {"en": "Sun-Glass Field", "es_419": "Campo del Vidrio Solar"},
    "Observatório das Horas Mortas": {"en": "Observatory of Dead Hours", "es_419": "Observatorio de las Horas Muertas"},
    "Estrada do Sol Partido": {"en": "Road of the Broken Sun", "es_419": "Camino del Sol Partido"},
    "Porta Zero": {"en": "Door Zero", "es_419": "Puerta Cero"},
    "Praça das Chaves": {"en": "Square of Keys", "es_419": "Plaza de las Llaves"},
    "Tribunal do Limiar": {"en": "Threshold Court", "es_419": "Tribunal del Umbral"},
    "Corredor de Contrabando": {"en": "Smuggling Corridor", "es_419": "Corredor de Contrabando"},
    "Arquivo Topológico": {"en": "Topological Archive", "es_419": "Archivo Topológico"},
    "Estação das Doze Soleiras": {"en": "Station of the Twelve Thresholds", "es_419": "Estación de los Doce Umbrales"},
    "Mercado dos Destinos": {"en": "Market of Destinies", "es_419": "Mercado de los Destinos"},
    "Bairro sem Endereço": {"en": "District Without an Address", "es_419": "Barrio sin Dirección"},
    "Torre das Fechaduras": {"en": "Tower of Locks", "es_419": "Torre de las Cerraduras"},
    "Pátio das Portas Mortas": {"en": "Courtyard of Dead Doors", "es_419": "Patio de las Puertas Muertas"},
    "Cidade Submersa de Odria": {"en": "Submerged City of Odria", "es_419": "Ciudad Sumergida de Odria"},
    "Farol dos Destinos": {"en": "Lighthouse of Destinies", "es_419": "Faro de los Destinos"},
    "Baía do Eco Tardio": {"en": "Bay of the Late Echo", "es_419": "Bahía del Eco Tardío"},
    "Quebra-Mar dos Mortos": {"en": "Breakwater of the Dead", "es_419": "Rompeolas de los Muertos"},
    "Fossa de Nácar Negro": {"en": "Black Nacre Trench", "es_419": "Fosa de Nácar Negro"},
    "Campanário Naufragado": {"en": "Wrecked Belfry", "es_419": "Campanario Naufragado"},
    "Praia dos Salvados Impossíveis": {"en": "Beach of Impossible Salvage", "es_419": "Playa de los Salvamentos Imposibles"},
    "Recife das Correntes": {"en": "Reef of Currents", "es_419": "Arrecife de las Corrientes"},
    "Porto das Sete Marés": {"en": "Port of Seven Tides", "es_419": "Puerto de las Siete Mareas"},
    "Cemitério de Âncoras": {"en": "Anchor Cemetery", "es_419": "Cementerio de Anclas"},
    "Forja Central": {"en": "Central Forge", "es_419": "Forja Central"},
    "Bairro dos Moldes": {"en": "Mold District", "es_419": "Barrio de los Moldes"},
    "Rio de Escória": {"en": "Slag River", "es_419": "Río de Escoria"},
    "Torre de Têmpera": {"en": "Tempering Tower", "es_419": "Torre de Temple"},
    "Pátio dos Inacabados": {"en": "Courtyard of the Unfinished", "es_419": "Patio de los Inacabados"},
    "Mina do Ferro Vivo": {"en": "Living Iron Mine", "es_419": "Mina del Hierro Vivo"},
    "Galeria dos Martelos": {"en": "Gallery of Hammers", "es_419": "Galería de los Martillos"},
    "Câmara do Primeiro Fogo": {"en": "Chamber of the First Fire", "es_419": "Cámara del Primer Fuego"},
    "Ponte da Caldeira": {"en": "Boiler Bridge", "es_419": "Puente de la Caldera"},
    "Arquivo de Matrizes": {"en": "Matrix Archive", "es_419": "Archivo de Matrices"},
    "Cemitério de Marcas": {"en": "Cemetery of Marks", "es_419": "Cementerio de Marcas"},
    "Dunas sem Nome": {"en": "Nameless Dunes", "es_419": "Dunas sin Nombre"},
    "Mosteiro da Última Memória": {"en": "Monastery of the Last Memory", "es_419": "Monasterio de la Última Memoria"},
    "Estrada Apagada": {"en": "Erased Road", "es_419": "Camino Borrado"},
    "Poço de Fuligem": {"en": "Soot Well", "es_419": "Pozo de Hollín"},
    "Bosque Carbonizado": {"en": "Charred Grove", "es_419": "Bosque Carbonizado"},
    "Mercado dos Nomes": {"en": "Market of Names", "es_419": "Mercado de los Nombres"},
    "Farol Cinzento": {"en": "Gray Lighthouse", "es_419": "Faro Gris"},
    "Ruínas de Ninguém": {"en": "Ruins of Nobody", "es_419": "Ruinas de Nadie"},
    "Boca do Esquecimento": {"en": "Maw of Oblivion", "es_419": "Boca del Olvido"},
    "Catedral de Samaúma": {"en": "Samaúma Cathedral", "es_419": "Catedral de Samaúma"},
    "Casa dos Mapas de Casca": {"en": "House of Bark Maps", "es_419": "Casa de los Mapas de Corteza"},
    "Poço de Seiva Negra": {"en": "Black Sap Well", "es_419": "Pozo de Savia Negra"},
    "Trilha que Retorna": {"en": "Trail That Returns", "es_419": "Sendero que Regresa"},
    "Ponte de Cipós": {"en": "Vine Bridge", "es_419": "Puente de Lianas"},
    "Jardim dos Nomes": {"en": "Garden of Names", "es_419": "Jardín de los Nombres"},
    "Ruínas de Iramã": {"en": "Ruins of Iramã", "es_419": "Ruinas de Iramã"},
    "Covil do Cerne Faminto": {"en": "Lair of the Hungry Heartwood", "es_419": "Guarida del Duramen Hambriento"},
    "Clareira dos Juramentos": {"en": "Clearing of Oaths", "es_419": "Claro de los Juramentos"},
    "Árvore-Nó de Aru": {"en": "Aru's Knot-Tree", "es_419": "Árbol-Nudo de Aru"},
    "Palácio sob o Gelo": {"en": "Palace Beneath the Ice", "es_419": "Palacio bajo el Hielo"},
    "Campo das Auroras Baixas": {"en": "Field of Low Auroras", "es_419": "Campo de las Auroras Bajas"},
    "Fogueira de Orun": {"en": "Orun's Fire", "es_419": "Hoguera de Orun"},
    "Lago dos Futuros": {"en": "Lake of Futures", "es_419": "Lago de los Futuros"},
    "Vila do Sol Ausente": {"en": "Village of the Absent Sun", "es_419": "Aldea del Sol Ausente"},
    "Geleira dos Sussurros": {"en": "Glacier of Whispers", "es_419": "Glaciar de los Susurros"},
    "Observatório Boreal": {"en": "Boreal Observatory", "es_419": "Observatorio Boreal"},
    "Floresta de Cristal": {"en": "Crystal Forest", "es_419": "Bosque de Cristal"},
    "Estrada da Brasa": {"en": "Ember Road", "es_419": "Camino de la Brasa"},
    "Poço da Noite": {"en": "Well of Night", "es_419": "Pozo de la Noche"},
    "Costelas do Leviatã": {"en": "Leviathan's Ribs", "es_419": "Costillas del Leviatán"},
    "Poço das Sete Cordas": {"en": "Well of Seven Ropes", "es_419": "Pozo de las Siete Cuerdas"},
    "Miragem Azul": {"en": "Blue Mirage", "es_419": "Espejismo Azul"},
    "Ventre de Ossamar": {"en": "Belly of Ossamar", "es_419": "Vientre de Ossamar"},
    "Olho do Mar Ausente": {"en": "Eye of the Absent Sea", "es_419": "Ojo del Mar Ausente"},
    "Santuário da Última Gota": {"en": "Sanctuary of the Last Drop", "es_419": "Santuario de la Última Gota"},
    "Ossuário das Marés": {"en": "Ossuary of the Tides", "es_419": "Osario de las Mareas"},
    "Mercado do Sal Vivo": {"en": "Market of Living Salt", "es_419": "Mercado de la Sal Viva"},
    "Dunas de Concha": {"en": "Shell Dunes", "es_419": "Dunas de Concha"},
    "Baía sem Água": {"en": "Waterless Bay", "es_419": "Bahía sin Agua"},
    "Nó Original": {"en": "Original Knot", "es_419": "Nudo Original"},
    "Cidade de Fragmentos": {"en": "City of Fragments", "es_419": "Ciudad de Fragmentos"},
    "Oficina das Causas": {"en": "Workshop of Causes", "es_419": "Taller de las Causas"},
    "Campo dos Futuros Abortados": {"en": "Field of Aborted Futures", "es_419": "Campo de los Futuros Abortados"},
    "Ponte para Ontem": {"en": "Bridge to Yesterday", "es_419": "Puente hacia Ayer"},
    "Jardim das Versões": {"en": "Garden of Versions", "es_419": "Jardín de las Versiones"},
    "Fenda das Regras": {"en": "Rift of Rules", "es_419": "Grieta de las Reglas"},
    "Trono da Convergência": {"en": "Throne of Convergence", "es_419": "Trono de la Convergencia"},
    "Último Fio": {"en": "Last Thread", "es_419": "Último Hilo"},
    "Sala sem Causa": {"en": "Causeless Room", "es_419": "Sala sin Causa"},
    "Foz Invertida": {"en": "Inverted Estuary", "es_419": "Estuario Invertido"},
    "Lago das Duas Luas": {"en": "Lake of Two Moons", "es_419": "Lago de las Dos Lunas"},
    "Casa sobre Estacas Vazias": {"en": "House on Empty Stilts", "es_419": "Casa sobre Pilotes Vacíos"},
    "Ilha que Repete": {"en": "Repeating Island", "es_419": "Isla que Repite"},
    "Espelho Fundo": {"en": "Deep Mirror", "es_419": "Espejo Profundo"},
    "Canal das Vozes Gêmeas": {"en": "Channel of Twin Voices", "es_419": "Canal de las Voces Gemelas"},
    "Porto de Água Parada": {"en": "Stillwater Port", "es_419": "Puerto de Agua Estancada"},
    "Mangue dos Rostos": {"en": "Mangrove of Faces", "es_419": "Manglar de los Rostros"},
    "Aldeia da Maré Reversa": {"en": "Village of the Reverse Tide", "es_419": "Aldea de la Marea Inversa"},
    "Poço do Céu Afogado": {"en": "Well of the Drowned Sky", "es_419": "Pozo del Cielo Ahogado"},
    "Cidade Suspensa de Avar": {"en": "Suspended City of Avar", "es_419": "Ciudad Suspendida de Avar"},
    "Elevador de Contrapeso": {"en": "Counterweight Elevator", "es_419": "Ascensor de Contrapeso"},
    "Mercado dos Cabos": {"en": "Cable Market", "es_419": "Mercado de los Cables"},
    "Ponte sem Pilar": {"en": "Pillarless Bridge", "es_419": "Puente sin Pilar"},
    "Observatório do Abismo": {"en": "Observatory of the Abyss", "es_419": "Observatorio del Abismo"},
    "Mosteiro do Vento": {"en": "Monastery of the Wind", "es_419": "Monasterio del Viento"},
    "Ninho das Serpes": {"en": "Nest of the Serpents", "es_419": "Nido de las Serpientes"},
    "Bairro das Âncoras": {"en": "Anchor District", "es_419": "Barrio de las Anclas"},
    "Torre de Tensão": {"en": "Tension Tower", "es_419": "Torre de Tensión"},
    "Plataforma sem Sombra": {"en": "Shadowless Platform", "es_419": "Plataforma sin Sombra"},
}

MARK_PREFIX = {
    "Rastro": {"en": "Trace", "es_419": "Rastro"},
    "Vínculo": {"en": "Bond", "es_419": "Vínculo"},
    "Segredo": {"en": "Secret", "es_419": "Secreto"},
    "Cicatriz": {"en": "Scar", "es_419": "Cicatriz"},
    "Mudança": {"en": "Change", "es_419": "Cambio"},
    "Eco": {"en": "Echo", "es_419": "Eco"},
}
ENDING_PREFIX = {
    "Reatar": {"en": "Reweave", "es_419": "Reentrelazar"},
    "Liberar": {"en": "Release", "es_419": "Liberar"},
    "Recusar": {"en": "Refuse", "es_419": "Rechazar"},
}


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected object: {path}")
    return value


def indexed(rows: list[dict], prefix: str, expected_per_world: int) -> dict[str, list[dict]]:
    worlds: dict[str, list[dict]] = {}
    for unit in rows:
        parts = str(unit["record_id"]).split(".")
        if len(parts) != 3:
            raise SystemExit(f"invalid {prefix} id: {unit['record_id']}")
        worlds.setdefault(parts[1], []).append(unit)
    for world, items in worlds.items():
        items.sort(key=lambda u: int(str(u["record_id"]).split(".")[-1]))
        if len(items) != expected_per_world:
            raise SystemExit(f"{prefix}:{world}: expected {expected_per_world}, got {len(items)}")
    if len(worlds) != 12:
        raise SystemExit(f"{prefix}: expected 12 worlds, got {len(worlds)}")
    return worlds


def collect_units() -> dict[str, list[dict]]:
    catalog = build_catalog()
    by_type = {}
    for kind in EXPECTED:
        rows = [u for u in catalog["units"] if str(u.get("record_id", "")).startswith(kind + ".") and u.get("path") == "name"]
        if len(rows) != EXPECTED[kind]:
            raise SystemExit(f"{kind} inventory drifted: {len(rows)}/{EXPECTED[kind]}")
        by_type[kind] = rows
    if len(WORLD_NAMES) != 12 or len(LOCATION_NAMES) != 120:
        raise SystemExit(f"editorial map drifted: worlds={len(WORLD_NAMES)} locations={len(LOCATION_NAMES)}")

    world_rows = {str(u["record_id"]).split(".")[1]: u for u in by_type["world"]}
    locations = indexed(by_type["location"], "location", 10)
    marks = indexed(by_type["mark"], "mark", 17)
    npcs = indexed(by_type["npc"], "npc", 25)
    endings = indexed(by_type["ending"], "ending", 3)
    result = {locale: [] for locale in TARGETS}

    for world_key, unit in world_rows.items():
        source = str(unit["source"])
        if source not in WORLD_NAMES:
            raise SystemExit(f"unmapped world name: {source}")
        for locale in TARGETS:
            result[locale].append({"record_id": str(unit["record_id"]), "translation": WORLD_NAMES[source][locale]})

    for world_key, rows in locations.items():
        for unit in rows:
            source = str(unit["source"])
            if source not in LOCATION_NAMES:
                raise SystemExit(f"unmapped location name: {source}")
            for locale in TARGETS:
                result[locale].append({"record_id": str(unit["record_id"]), "translation": LOCATION_NAMES[source][locale]})

    for world_key, rows in marks.items():
        locs = locations[world_key]
        for index, unit in enumerate(rows):
            source = str(unit["source"])
            prefix = next((p for p in MARK_PREFIX if source.startswith(p + " de ")), None)
            if prefix is None:
                raise SystemExit(f"unmapped mark prefix: {source}")
            location_source = str(locs[index % 10]["source"])
            if not source.endswith(location_source):
                raise SystemExit(f"mark/location relation drifted: {unit['record_id']} source={source!r} location={location_source!r}")
            for locale in TARGETS:
                result[locale].append({
                    "record_id": str(unit["record_id"]),
                    "translation": f"{MARK_PREFIX[prefix][locale]} — {LOCATION_NAMES[location_source][locale]}",
                })

    for world_key, rows in npcs.items():
        locs = locations[world_key]
        for index, unit in enumerate(rows):
            source = str(unit["source"])
            location_source = str(locs[index % 10]["source"])
            suffix = " de " + location_source
            if not source.endswith(suffix):
                raise SystemExit(f"npc/location relation drifted: {unit['record_id']} source={source!r} location={location_source!r}")
            personal_name = source[:-len(suffix)]
            if not personal_name.strip():
                raise SystemExit(f"empty NPC personal name: {unit['record_id']}")
            for locale in TARGETS:
                result[locale].append({
                    "record_id": str(unit["record_id"]),
                    "translation": f"{personal_name} — {LOCATION_NAMES[location_source][locale]}",
                })

    for world_key, rows in endings.items():
        world_source = str(world_rows[world_key]["source"])
        for unit in rows:
            source = str(unit["source"])
            prefix = next((p for p in ENDING_PREFIX if source.startswith(p + " — ")), None)
            if prefix is None or not source.endswith(world_source):
                raise SystemExit(f"ending/world relation drifted: {unit['record_id']} source={source!r}")
            for locale in TARGETS:
                result[locale].append({
                    "record_id": str(unit["record_id"]),
                    "translation": f"{ENDING_PREFIX[prefix][locale]} — {WORLD_NAMES[world_source][locale]}",
                })
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
        raise SystemExit(f"{locale}: {missing} world/location-derived name translations missing")
    if not check_only:
        path.write_text(json.dumps(overlay, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return added, missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed world/location editorial names and derived mark/NPC/ending names.")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    units = collect_units()
    expected = sum(EXPECTED.values())
    for locale in TARGETS:
        added, missing = apply(locale, units[locale], args.check)
        print(
            "WORLD_LOCATION_DERIVED_LOCALIZATION %s: required=%d added=%d missing_before=%d mode=%s"
            % (locale, expected, added, missing, "check" if args.check else "apply")
        )
    print("WORLD_LOCATION_DERIVED_LOCALIZATION PASS: worlds=12 locations=120 marks=204 npcs=300 endings=36 units_per_target=%d" % expected)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
