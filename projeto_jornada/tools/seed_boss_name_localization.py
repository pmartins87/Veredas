#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from export_localization_catalog import build_catalog

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
TARGETS = ("en", "es_419")
EXPECTED = 60

BOSS_NAMES = {
    "Rasura-Mãe": {"en": "Mother-Erasure", "es_419": "Rasura-Madre"},
    "Bibliotecário das Mortes": {"en": "Librarian of Deaths", "es_419": "Bibliotecario de las Muertes"},
    "Índice que Lê Pessoas": {"en": "Index That Reads People", "es_419": "Índice que Lee Personas"},
    "Memória sem Autor": {"en": "Memory Without an Author", "es_419": "Memoria sin Autor"},
    "Arquivo que se Defende": {"en": "Archive That Defends Itself", "es_419": "Archivo que se Defiende"},
    "Matilha do Meio-Dia": {"en": "Midday Pack", "es_419": "Manada del Mediodía"},
    "Observatório Vivo": {"en": "Living Observatory", "es_419": "Observatorio Viviente"},
    "Escorpião da Sombra Única": {"en": "Scorpion of the Single Shadow", "es_419": "Escorpión de la Sombra Única"},
    "Homem sem Sombra": {"en": "Shadowless Man", "es_419": "Hombre sin Sombra"},
    "Coração do Sol Oco": {"en": "Heart of the Hollow Sun", "es_419": "Corazón del Sol Hueco"},
    "Juiz da Porta Zero": {"en": "Judge of Door Zero", "es_419": "Juez de la Puerta Cero"},
    "Chave que Escolhe Dono": {"en": "Key That Chooses Its Owner", "es_419": "Llave que Elige Dueño"},
    "Bairro sem Endereço": {"en": "District Without an Address", "es_419": "Barrio sin Dirección"},
    "Mímico das Doze Soleiras": {"en": "Mimic of the Twelve Thresholds", "es_419": "Mímico de los Doce Umbrales"},
    "Cidade que Fecha": {"en": "City That Closes", "es_419": "Ciudad que se Cierra"},
    "Matriarca dos Sinos de Coral": {"en": "Matriarch of the Coral Bells", "es_419": "Matriarca de las Campanas de Coral"},
    "Almirante de Odria Afogada": {"en": "Admiral of Drowned Odria", "es_419": "Almirante de Odria Ahogada"},
    "Tempestade de Asas": {"en": "Storm of Wings", "es_419": "Tormenta de Alas"},
    "Capitão Calcificado": {"en": "Calcified Captain", "es_419": "Capitán Calcificado"},
    "Leviatã Sincrônico": {"en": "Synchronous Leviathan", "es_419": "Leviatán Sincrónico"},
    "Mestre-Matriz Zero": {"en": "Master-Matrix Zero", "es_419": "Maestro-Matriz Cero"},
    "Caldeira que Sonha": {"en": "Dreaming Boiler", "es_419": "Caldera que Sueña"},
    "General Inacabado": {"en": "Unfinished General", "es_419": "General Inacabado"},
    "Sindicato dos Mil Martelos": {"en": "Syndicate of a Thousand Hammers", "es_419": "Sindicato de los Mil Martillos"},
    "Primeiro Fogo": {"en": "First Fire", "es_419": "Primer Fuego"},
    "Rei sem Nome": {"en": "Nameless King", "es_419": "Rey sin Nombre"},
    "Abadessa da Última Memória": {"en": "Abbess of the Last Memory", "es_419": "Abadesa de la Última Memoria"},
    "Farol que Esquece": {"en": "Lighthouse That Forgets", "es_419": "Faro que Olvida"},
    "Cidade Ninguém": {"en": "Nobody City", "es_419": "Ciudad Nadie"},
    "Boca do Esquecimento": {"en": "Maw of Oblivion", "es_419": "Boca del Olvido"},
    "Cerne Faminto": {"en": "Hungry Heartwood", "es_419": "Duramen Hambriento"},
    "Samaúma Juramentada": {"en": "Oathbound Samaúma", "es_419": "Samaúma Juramentada"},
    "Cartógrafo Enraizado": {"en": "Rooted Cartographer", "es_419": "Cartógrafo Enraizado"},
    "Rainha dos Nomes": {"en": "Queen of Names", "es_419": "Reina de los Nombres"},
    "Guardião da Árvore-Nó": {"en": "Guardian of the Knot-Tree", "es_419": "Guardián del Árbol-Nudo"},
    "Urso do Futuro Partido": {"en": "Bear of the Broken Future", "es_419": "Oso del Futuro Roto"},
    "Rainha da Aurora Baixa": {"en": "Queen of the Low Aurora", "es_419": "Reina de la Aurora Baja"},
    "Fogueira que Recorda": {"en": "Fire That Remembers", "es_419": "Hoguera que Recuerda"},
    "Palácio sob o Gelo": {"en": "Palace Beneath the Ice", "es_419": "Palacio bajo el Hielo"},
    "Noite sem Amanhã": {"en": "Night Without Tomorrow", "es_419": "Noche sin Mañana"},
    "Leviatã de Sal": {"en": "Salt Leviathan", "es_419": "Leviatán de Sal"},
    "Guardião das Sete Cordas": {"en": "Guardian of the Seven Ropes", "es_419": "Guardián de las Siete Cuerdas"},
    "Miragem que Bebe": {"en": "Drinking Mirage", "es_419": "Espejismo que Bebe"},
    "Ossário Andante": {"en": "Walking Ossuary", "es_419": "Osario Andante"},
    "Olho do Mar Ausente": {"en": "Eye of the Absent Sea", "es_419": "Ojo del Mar Ausente"},
    "Futuro que Recusou Morrer": {"en": "Future That Refused to Die", "es_419": "Futuro que se Negó a Morir"},
    "Nó Faminto Original": {"en": "Original Hungry Knot", "es_419": "Nudo Hambriento Original"},
    "Tecelão Invertido": {"en": "Inverted Weaver", "es_419": "Tejedor Invertido"},
    "Trono da Convergência": {"en": "Throne of Convergence", "es_419": "Trono de la Convergencia"},
    "Último Fio": {"en": "Last Thread", "es_419": "Último Hilo"},
    "Rei do Reflexo Fundo": {"en": "King of the Deep Reflection", "es_419": "Rey del Reflejo Profundo"},
    "Matriarca das Duas Luas": {"en": "Matriarch of the Two Moons", "es_419": "Matriarca de las Dos Lunas"},
    "Casa que Caminha": {"en": "House That Walks", "es_419": "Casa que Camina"},
    "Afogado sem Primeiro Rosto": {"en": "Drowned One Without a First Face", "es_419": "Ahogado sin Primer Rostro"},
    "Maré que Volta": {"en": "Returning Tide", "es_419": "Marea que Regresa"},
    "Serpe das Mil Pontes": {"en": "Serpent of a Thousand Bridges", "es_419": "Serpiente de los Mil Puentes"},
    "Mestre dos Contrapesos": {"en": "Master of Counterweights", "es_419": "Maestro de los Contrapesos"},
    "Vento com Nome": {"en": "Wind with a Name", "es_419": "Viento con Nombre"},
    "Abismo que Responde": {"en": "Abyss That Answers", "es_419": "Abismo que Responde"},
    "Ponte Juramentada": {"en": "Oathbound Bridge", "es_419": "Puente Juramentado"}
}


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected object: {path}")
    return value


def collect_units() -> dict[str, list[dict]]:
    catalog = build_catalog()
    result = {locale: [] for locale in TARGETS}
    count = 0
    seen: set[str] = set()
    for unit in catalog["units"]:
        record_id = str(unit.get("record_id", ""))
        path = str(unit.get("path", ""))
        if not record_id.startswith("boss.") or path != "name":
            continue
        source = str(unit.get("source", ""))
        if source not in BOSS_NAMES:
            raise SystemExit(f"unmapped boss name: {record_id}:{source}")
        if source in seen:
            raise SystemExit(f"duplicate boss source name: {source}")
        seen.add(source)
        count += 1
        for locale in TARGETS:
            result[locale].append({
                "record_id": record_id,
                "path": path,
                "source": source,
                "translation": BOSS_NAMES[source][locale],
            })
    if count != EXPECTED or len(BOSS_NAMES) != EXPECTED:
        raise SystemExit(f"boss name inventory drifted: catalog={count} map={len(BOSS_NAMES)} expected={EXPECTED}")
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
        raise SystemExit(f"{locale}: {missing} boss name translations missing")
    if not check_only:
        path.write_text(json.dumps(overlay, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return added, missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed editorially curated boss-name translations.")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    units = collect_units()
    for locale in TARGETS:
        added, missing = apply(locale, units[locale], args.check)
        print(
            "BOSS_NAME_LOCALIZATION %s: required=%d added=%d missing_before=%d mode=%s"
            % (locale, EXPECTED, added, missing, "check" if args.check else "apply")
        )
    print("BOSS_NAME_LOCALIZATION PASS: curated_names=%d" % EXPECTED)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
