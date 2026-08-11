#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from export_localization_catalog import build_catalog
from seed_structured_localization import SENSORY, STAKE, SECRET
from seed_structured_name_localization import MATERIALS
from seed_world_location_derived_name_localization import WORLD_NAMES, LOCATION_NAMES
from seed_structured_narrative_localization import CHAR_NAMES, THREAT

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
TARGETS = ("en", "es_419")
EXPECTED_RECORDS = 2544
EXPECTED_UNITS = EXPECTED_RECORDS * 5
EVENT_PATHS = {"title", "text", "choices.0.text", "choices.1.text", "choices.2.text"}

CATEGORY = {
    "Exploration": {"en": "Exploration", "es_419": "Exploración"},
    "Resource": {"en": "Resource", "es_419": "Recurso"},
    "Social": {"en": "Social", "es_419": "Social"},
    "Hazard": {"en": "Hazard", "es_419": "Peligro"},
    "Creature": {"en": "Creature", "es_419": "Criatura"},
    "Choice": {"en": "Choice", "es_419": "Decisión"},
    "Knowledge": {"en": "Knowledge", "es_419": "Conocimiento"},
    "Mark": {"en": "Mark", "es_419": "Marca"},
    "Debt": {"en": "Debt", "es_419": "Deuda"},
    "Trade": {"en": "Trade", "es_419": "Comercio"},
    "Route": {"en": "Route", "es_419": "Ruta"},
    "Ritual": {"en": "Ritual", "es_419": "Ritual"},
    "Weather": {"en": "Weather", "es_419": "Clima"},
    "Faction": {"en": "Faction", "es_419": "Facción"},
    "Memory": {"en": "Memory", "es_419": "Memoria"},
    "Moral": {"en": "Moral", "es_419": "Moral"},
    "Callback": {"en": "Callback", "es_419": "Retorno"},
}

LEAD = {
    "Exploration": {"en": "An out-of-place detail forces you to read the surroundings before moving on.", "es_419": "Un detalle fuera de lugar te obliga a leer el entorno antes de avanzar."},
    "Resource": {"en": "There is something useful here, but taking it changes the balance of the place.", "es_419": "Hay algo útil aquí, pero retirarlo altera el equilibrio del lugar."},
    "Social": {"en": "Two people tell incompatible versions of the same event.", "es_419": "Dos personas cuentan versiones incompatibles del mismo suceso."},
    "Hazard": {"en": "The danger does not strike immediately; it worsens with every hesitation.", "es_419": "El peligro no ataca de inmediato; empeora con cada vacilación."},
    "Creature": {"en": "A wounded creature blocks the way and may be fleeing something worse.", "es_419": "Una criatura herida bloquea el camino y quizá huya de algo peor."},
    "Choice": {"en": "A quick solution shifts the cost onto someone who is not present.", "es_419": "Una solución rápida traslada el costo a alguien que no está presente."},
    "Knowledge": {"en": "An inscription contradicts everything said about this place.", "es_419": "Una inscripción contradice todo lo que se decía de este lugar."},
    "Mark": {"en": "Someone—or something—recognizes your earlier decision.", "es_419": "Alguien —o algo— reconoce una decisión que tomaste antes."},
    "Debt": {"en": "An old promise comes due at an inconvenient moment.", "es_419": "Una antigua promesa exige su pago en un momento inoportuno."},
    "Trade": {"en": "A merchant accepts a payment that is not money.", "es_419": "Un comerciante acepta un pago que no es dinero."},
    "Route": {"en": "Two Paths seem to lead to the same destination, but demand different losses.", "es_419": "Dos Sendas parecen llevar al mismo destino, pero exigen pérdidas diferentes."},
    "Ritual": {"en": "A local procedure works, though no one agrees why.", "es_419": "Un procedimiento local funciona, aunque nadie coincide sobre el motivo."},
    "Weather": {"en": "The environment changes predictably only for those who noticed earlier details.", "es_419": "El entorno cambia de forma predecible solo para quien observó los detalles anteriores."},
    "Faction": {"en": "Two factions contest control, though neither can operate the place alone.", "es_419": "Dos facciones disputan el control, aunque ninguna puede operar el lugar por sí sola."},
    "Memory": {"en": "You find proof of a version of yourself that never lived this journey.", "es_419": "Encuentras pruebas de una versión de ti que nunca vivió esta jornada."},
    "Moral": {"en": "The safest alternative is also the one that erases an important truth.", "es_419": "La alternativa más segura también es la que borra una verdad importante."},
    "Callback": {"en": "Something you did several Beats ago finally catches up with you.", "es_419": "Algo que hiciste varias Batidas atrás finalmente te alcanza."},
}

CHOICE_VERBS = {
    "Exploration": ("Examine", "Intervene", "Bypass", "Examinar", "Intervenir", "Rodear"),
    "Resource": ("Preserve", "Extract", "Share", "Preservar", "Extraer", "Compartir"),
    "Social": ("Listen to", "Question", "Record", "Escuchar", "Cuestionar", "Registrar"),
    "Hazard": ("Wait with", "Cross", "Retreat", "Esperar con", "Atravesar", "Retroceder"),
    "Creature": ("Help with", "Follow", "Free", "Ayudar con", "Seguir", "Liberar"),
    "Choice": ("Take on", "Transfer", "Reveal", "Asumir", "Transferir", "Revelar"),
    "Knowledge": ("Read", "Copy", "Keep", "Leer", "Copiar", "Guardar"),
    "Mark": ("Acknowledge", "Deny", "Accept", "Reconocer", "Negar", "Aceptar"),
    "Debt": ("Honor", "Delay", "Pay", "Cumplir", "Aplazar", "Pagar"),
    "Trade": ("Negotiate", "Refuse", "Trade", "Negociar", "Rechazar", "Intercambiar"),
    "Route": ("Compare", "Risk", "Mark", "Comparar", "Arriesgar", "Marcar"),
    "Ritual": ("Perform", "Improvise", "Interrupt", "Ejecutar", "Improvisar", "Interrumpir"),
    "Weather": ("Observe", "Force", "Wait", "Observar", "Forzar", "Esperar"),
    "Faction": ("Mediate", "Favor", "Divide", "Mediar", "Favorecer", "Dividir"),
    "Memory": ("Confront", "Erase", "Anchor", "Confrontar", "Borrar", "Anclar"),
    "Moral": ("Protect", "Hide", "Confess", "Proteger", "Ocultar", "Confesar"),
    "Callback": ("Respond with", "Break through", "Undo", "Responder con", "Romper con", "Deshacer"),
}

SOURCE_LEADS = {
    "Um detalhe fora do lugar obriga você a ler o ambiente antes de avançar.": "Exploration",
    "Há algo útil aqui, mas retirá-lo muda o equilíbrio do lugar.": "Resource",
    "Duas pessoas contam versões incompatíveis do mesmo acontecimento.": "Social",
    "O perigo não ataca de imediato; ele piora a cada hesitação.": "Hazard",
    "Uma criatura ferida ocupa o caminho e talvez esteja fugindo de algo pior.": "Creature",
    "Uma solução rápida transfere o custo para alguém que não está presente.": "Choice",
    "Uma inscrição contradiz tudo o que se dizia sobre este lugar.": "Knowledge",
    "Sua decisão anterior é reconhecida por alguém ou por alguma coisa.": "Mark",
    "Uma promessa antiga cobra retorno em momento inconveniente.": "Debt",
    "Um comerciante aceita um pagamento que não é dinheiro.": "Trade",
    "Duas Veredas parecem levar ao mesmo destino, mas exigem perdas diferentes.": "Route",
    "Um procedimento local funciona, embora ninguém concorde sobre o motivo.": "Ritual",
    "O ambiente muda de modo previsível apenas para quem observou detalhes anteriores.": "Weather",
    "Duas facções disputam controle sem que nenhuma consiga operar o lugar sozinha.": "Faction",
    "Você encontra prova de uma versão de si mesmo que não viveu esta jornada.": "Memory",
    "A alternativa mais segura é também a que apaga uma verdade importante.": "Moral",
    "Algo que você fez várias Batidas atrás finalmente alcança você.": "Callback",
}


def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected object: {path}")
    return value


def norm(value: str) -> str:
    return " ".join(value.strip().casefold().split())


def translated(mapping: dict[str, dict[str, str]], source: str, locale: str) -> str | None:
    row = mapping.get(source)
    if row:
        return row.get(locale)
    wanted = norm(source)
    for key, candidate in mapping.items():
        if norm(key) == wanted:
            return candidate.get(locale)
    return None


def material(source: str, locale: str) -> str | None:
    return translated(MATERIALS, source, locale)


def location(source: str, locale: str) -> str | None:
    return translated(LOCATION_NAMES, source, locale)


def world(source: str, locale: str) -> str | None:
    return translated(WORLD_NAMES, source, locale)


def character(source: str, locale: str) -> str | None:
    return translated(CHAR_NAMES, source, locale)


def event_units() -> list[dict[str, Any]]:
    catalog = build_catalog()
    selected = [u for u in catalog["units"] if str(u.get("record_id", "")).startswith("event.")]
    counts: dict[str, int] = {}
    records: set[str] = set()
    for unit in selected:
        path = str(unit.get("path", ""))
        counts[path] = counts.get(path, 0) + 1
        records.add(str(unit.get("record_id", "")))
    expected_counts = {path: EXPECTED_RECORDS for path in EVENT_PATHS}
    if counts != expected_counts or len(records) != EXPECTED_RECORDS or len(selected) != EXPECTED_UNITS:
        raise SystemExit(f"event localization inventory drifted: records={len(records)} units={len(selected)} counts={counts}")
    return selected


def translate_arc(path: str, source: str, locale: str) -> str | None:
    if path == "title":
        m = re.fullmatch(r"(.+): Fio (\d+)", source)
        if not m:
            return None
        w = world(m.group(1), locale)
        if not w:
            return None
        return f"{w}: {'Thread' if locale == 'en' else 'Hilo'} {m.group(2)}"
    if path == "text":
        m = re.fullmatch(r"(.+) revela que (.+)\. Isso torna impossível tratar (.+) como problema local\.", source)
        if not m:
            return None
        mat = material(m.group(1), locale)
        sec = translated(SECRET, m.group(2), locale)
        stk = translated(STAKE, m.group(3), locale)
        if not mat or not sec or not stk:
            return None
        if locale == "en":
            return f"{mat} reveals that {sec}. This makes it impossible to treat the need to {stk} as a local problem."
        return f"{mat} revela que {sec}. Esto impide tratar como un problema local la necesidad de {stk}."
    fixed = {
        "choices.0.text": {"en": "Record the evidence", "es_419": "Registrar la evidencia"},
        "choices.1.text": {"en": "Share the discovery", "es_419": "Compartir el descubrimiento"},
        "choices.2.text": {"en": "Hide it for now", "es_419": "Ocultarlo por ahora"},
    }
    return fixed.get(path, {}).get(locale)


def translate_transit(path: str, source: str, locale: str) -> str | None:
    if path == "title":
        m = re.fullmatch(r"Consequência em trânsito — (.+)", source)
        if not m:
            return None
        w = world(m.group(1), locale)
        if not w:
            return None
        return f"Transit Consequence — {w}" if locale == "en" else f"Consecuencia en tránsito — {w}"
    if path == "text":
        m = re.fullmatch(r"Uma consequência atravessa a Vereda\. O que começou como tentativa de (.+) agora carrega sinais de que (.+)\.", source)
        if not m:
            return None
        stk = translated(STAKE, m.group(1), locale)
        sec = translated(SECRET, m.group(2), locale)
        if not stk or not sec:
            return None
        if locale == "en":
            return f"A consequence crosses the Path. What began as an attempt to {stk} now carries signs that {sec}."
        return f"Una consecuencia atraviesa la Senda. Lo que comenzó como un intento de {stk} ahora lleva señales de que {sec}."
    fixed = {
        "choices.0.text": {"en": "Face it now", "es_419": "Afrontarla ahora"},
        "choices.1.text": {"en": "Postpone by spending Essence", "es_419": "Aplazarla gastando Esencia"},
        "choices.2.text": {"en": "Turn it into a Mark", "es_419": "Convertirla en Marca"},
    }
    return fixed.get(path, {}).get(locale)


def translate_personal(path: str, source: str, locale: str) -> str | None:
    if path == "title":
        m = re.fullmatch(r"(.+) — Capítulo (\d+)", source)
        if not m:
            return None
        ch = character(m.group(1), locale)
        if not ch:
            return None
        return f"{ch} — {'Chapter' if locale == 'en' else 'Capítulo'} {m.group(2)}"
    if path == "text":
        m = re.fullmatch(r"(.+) confronta (.+) enquanto (.+) torna sua pergunta pessoal impossível de evitar: Até onde aceita (.+) quando descobre que (.+)\?", source)
        if not m:
            return None
        ch = character(m.group(1), locale)
        sec1 = translated(SECRET, m.group(2), locale)
        sen = translated(SENSORY, m.group(3), locale)
        stk = translated(STAKE, m.group(4), locale)
        sec2 = translated(SECRET, m.group(5), locale)
        if not all((ch, sec1, sen, stk, sec2)):
            return None
        if locale == "en":
            return f"{ch} confronts the fact that {sec1} while {sen} makes their personal question impossible to avoid: how far will they go to {stk} after discovering that {sec2}?"
        return f"{ch} afronta el hecho de que {sec1} mientras {sen} vuelve imposible evitar su pregunta personal: ¿hasta dónde llega su disposición a {stk} al descubrir que {sec2}?"
    if path == "choices.0.text":
        m = re.fullmatch(r"Assumir que (.+) também é sua responsabilidade", source)
        if not m:
            return None
        stk = translated(STAKE, m.group(1), locale)
        if not stk:
            return None
        return f"Accept that {stk} is also their responsibility" if locale == "en" else f"Asumir que {stk} también es su responsabilidad"
    if path == "choices.1.text":
        m = re.fullmatch(r"Rejeitar que (.+) defina seu caminho", source)
        if not m:
            return None
        sec = translated(SECRET, m.group(1), locale)
        if not sec:
            return None
        return f"Reject the idea that {sec} should define their path" if locale == "en" else f"Rechazar que {sec} defina su camino"
    if path == "choices.2.text" and source == "Procurar outra testemunha":
        return "Look for another witness" if locale == "en" else "Buscar otro testigo"
    return None


def parse_location_text(source: str) -> tuple[str, str, str, str, str, str] | None:
    for source_lead, category in SOURCE_LEADS.items():
        prefix = source_lead + " Em "
        if not source.startswith(prefix):
            continue
        rest = source[len(prefix):]
        m = re.fullmatch(r"(.+), (.+); (.+) mostra sinais de que (.+)\. O detalhe decisivo: (.+)\. Você terá de escolher como (.+)\.", rest)
        if not m:
            return None
        return category, m.group(1), m.group(2), m.group(3), m.group(4), m.group(5) + "\0" + m.group(6)
    return None


def translate_location_event(path: str, source: str, locale: str) -> str | None:
    if path == "title":
        m = re.fullmatch(r"(.+) — ([A-Za-z]+)", source)
        if not m or m.group(2) not in CATEGORY:
            return None
        loc = location(m.group(1), locale)
        return f"{loc} — {CATEGORY[m.group(2)][locale]}" if loc else None
    if path == "text":
        parsed = parse_location_text(source)
        if not parsed:
            return None
        category, loc_src, sensory_src, material_src, threat_src, tail = parsed
        secret_src, stake_src = tail.split("\0", 1)
        loc = location(loc_src, locale)
        sen = translated(SENSORY, sensory_src, locale)
        mat = material(material_src, locale)
        thr = translated(THREAT, threat_src, locale)
        sec = translated(SECRET, secret_src, locale)
        stk = translated(STAKE, stake_src, locale)
        if not all((loc, sen, mat, thr, sec, stk)):
            return None
        lead = LEAD[category][locale]
        if locale == "en":
            return f"{lead} In {loc}, {sen}; {mat} shows signs of {thr}. The decisive detail: {sec}. You will have to choose how to {stk}."
        return f"{lead} En {loc}, {sen}; {mat} muestra señales de {thr}. El detalle decisivo: {sec}. Tendrás que elegir cómo {stk}."
    if path == "choices.0.text":
        source_map = {"Examinar":"Exploration","Preservar":"Resource","Ouvir":"Social","Esperar":"Hazard","Ajudar":"Creature","Assumir":"Choice","Ler":"Knowledge","Reconhecer":"Mark","Cumprir":"Debt","Negociar":"Trade","Comparar":"Route","Executar":"Ritual","Observar":"Weather","Mediar":"Faction","Confrontar":"Memory","Proteger":"Moral","Responder":"Callback"}
        category = None
        material_src = ""
        for source_verb, candidate in source_map.items():
            prefix, suffix = source_verb + " ", " antes de decidir"
            if source.startswith(prefix) and source.endswith(suffix):
                category = candidate
                material_src = source[len(prefix):-len(suffix)]
                break
        if not category or not material_src:
            return None
        mat = material(material_src, locale)
        if not mat:
            return None
        verbs = CHOICE_VERBS[category]
        verb = verbs[0] if locale == "en" else verbs[3]
        return f"{verb} {mat} {'before deciding' if locale == 'en' else 'antes de decidir'}"
    if path == "choices.1.text":
        m = re.fullmatch(r"(.+) apesar de (.+)", source)
        if not m:
            return None
        source_map = {"Intervir":"Exploration","Extrair":"Resource","Questionar":"Social","Atravessar":"Hazard","Seguir":"Creature","Transferir":"Choice","Copiar":"Knowledge","Negar":"Mark","Adiar":"Debt","Recusar":"Trade","Arriscar":"Route","Improvisar":"Ritual","Forçar":"Weather","Favorecer":"Faction","Apagar":"Memory","Ocultar":"Moral","Romper":"Callback"}
        category = source_map.get(m.group(1))
        thr = translated(THREAT, m.group(2), locale)
        if not category or not thr:
            return None
        verbs = CHOICE_VERBS[category]
        return f"{verbs[1] if locale == 'en' else verbs[4]} {'despite' if locale == 'en' else 'a pesar de'} {thr}"
    if path == "choices.2.text":
        m = re.fullmatch(r"(.+) e aceitar que (.+) ficará para depois", source)
        if not m:
            return None
        source_map = {"Contornar":"Exploration","Partilhar":"Resource","Registrar":"Social","Recuar":"Hazard","Libertar":"Creature","Revelar":"Choice","Guardar":"Knowledge","Aceitar":"Mark","Pagar":"Debt","Trocar":"Trade","Marcar":"Route","Interromper":"Ritual","Aguardar":"Weather","Dividir":"Faction","Ancorar":"Memory","Confessar":"Moral","Desfazer":"Callback"}
        category = source_map.get(m.group(1))
        stk = translated(STAKE, m.group(2), locale)
        if not category or not stk:
            return None
        verbs = CHOICE_VERBS[category]
        verb = verbs[2] if locale == "en" else verbs[5]
        if locale == "en":
            return f"{verb} and accept that the need to {stk} will have to wait"
        return f"{verb} y aceptar que la necesidad de {stk} tendrá que esperar"
    return None


def translate_unit(unit: dict[str, Any], locale: str) -> str | None:
    rid, path, source = str(unit["record_id"]), str(unit["path"]), str(unit["source"])
    parts = rid.split(".")
    if len(parts) >= 3 and parts[1] == "personal":
        return translate_personal(path, source, locale)
    if len(parts) == 3 and parts[2] == "transit_consequence":
        return translate_transit(path, source, locale)
    if len(parts) == 4 and parts[2] == "arc":
        return translate_arc(path, source, locale)
    if len(parts) == 4 and parts[2].startswith("loc"):
        return translate_location_event(path, source, locale)
    return None


def apply(locale: str, units: list[dict[str, Any]], check_only: bool) -> tuple[int, int]:
    path = LOC / "content" / f"{locale}.json"
    overlay = read_object(path)
    missing_before = 0
    added = 0
    unresolved: list[str] = []
    for unit in units:
        rid, field = str(unit["record_id"]), str(unit["path"])
        record = overlay.get(rid)
        if not isinstance(record, dict):
            record = {}
            if not check_only:
                overlay[rid] = record
        current = record.get(field) if isinstance(record, dict) else None
        if isinstance(current, str) and current.strip():
            continue
        missing_before += 1
        value = translate_unit(unit, locale)
        if not isinstance(value, str) or not value.strip():
            unresolved.append(f"{rid}.{field}: {unit['source']}")
            continue
        if not check_only:
            record[field] = value
            added += 1
    if unresolved:
        raise SystemExit(f"{locale}: {len(unresolved)} event translations unresolved\n" + "\n".join(unresolved[:50]))
    if check_only and missing_before:
        raise SystemExit(f"{locale}: {missing_before} event translations missing")
    if not check_only:
        path.write_text(json.dumps(overlay, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return added, missing_before


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed deterministic localization for all phase-11.6 event text.")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    units = event_units()
    for locale in TARGETS:
        added, missing = apply(locale, units, args.check)
        print("EVENT_LOCALIZATION %s: required=%d added=%d missing_before=%d mode=%s" % (locale, EXPECTED_UNITS, added, missing, "check" if args.check else "apply"))
    print("EVENT_LOCALIZATION PASS: records=%d units_per_target=%d" % (EXPECTED_RECORDS, EXPECTED_UNITS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
