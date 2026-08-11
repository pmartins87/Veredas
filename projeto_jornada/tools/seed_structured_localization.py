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
EXPECTED = {
    "signature": 72,
    "conflict": 180,
    "teaching_note": 36,
    "description": 1116,
    "secret": 120,
    "sensory": 120,
}


def table(raw: str) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for line in raw.strip().splitlines():
        src, en, es = line.split("\t")
        out[src] = {"en": en, "es_419": es}
    return out


SENSORY = table(r"""
ar que dói nos pulmões	air that hurts the lungs	aire que duele en los pulmones
ar seco cortando a garganta	dry air cutting the throat	aire seco que corta la garganta
aurora sem som	soundless aurora	aurora sin sonido
bronze vibrando sob os pés	bronze vibrating underfoot	bronce vibrando bajo los pies
calor de fornalha	furnace heat	calor de horno
cantos duplicados de aves	doubled bird calls	cantos duplicados de aves
cheiro de chuva parada	smell of stagnant rain	olor a lluvia estancada
cheiro de madeira encerada	smell of waxed wood	olor a madera encerada
cheiro de papel queimado	smell of burnt paper	olor a papel quemado
cheiro de terra molhada	smell of wet earth	olor a tierra mojada
cheiro de tinta fresca	smell of fresh ink	olor a tinta fresca
cheiro impossível de maresia	impossible smell of sea spray	olor imposible a brisa marina
cinza nos dentes	ash between the teeth	ceniza entre los dientes
claridade branca ofuscante	blinding white glare	resplandor blanco cegador
cordas vibrando como instrumentos	ropes vibrating like instruments	cuerdas vibrando como instrumentos
eco de fechaduras	echo of locks	eco de cerraduras
espuma fria	cold foam	espuma fría
estalidos de madeira sob tensão	cracking wood under strain	crujidos de madera bajo tensión
frio sem vento	windless cold	frío sin viento
fumaça doce de brasa	sweet ember smoke	humo dulce de brasa
gelo rangendo	creaking ice	hielo crujiendo
gosto de fuligem	taste of soot	sabor a hollín
gosto metálico de seiva	metallic taste of sap	sabor metálico de savia
latão frio	cold brass	latón frío
linhas vibrando no ar	lines vibrating in the air	líneas vibrando en el aire
luz branca sem conforto	comfortless white light	luz blanca sin consuelo
luz com sombra invertida	light with inverted shadows	luz con sombras invertidas
luz verde filtrada	filtered green light	luz verde filtrada
martelos ritmados	rhythmic hammers	martillos rítmicos
metal frio nas mãos	cold metal in the hands	metal frío en las manos
névoa abaixo dos pés	mist below the feet	niebla bajo los pies
passos vindo de corredores inexistentes	footsteps from nonexistent corridors	pasos que vienen de corredores inexistentes
pedra quente nas botas	hot stone beneath the boots	piedra caliente bajo las botas
pena riscando sozinha	quill scratching on its own	pluma escribiendo por sí sola
peso mudando sem movimento	weight shifting without movement	peso que cambia sin movimiento
pó frio de estante	cold shelf dust	polvo frío de estantería
reflexos tremendo sem vento	reflections trembling without wind	reflejos temblando sin viento
sal nos lábios	salt on the lips	sal en los labios
sal queimando a pele	salt burning the skin	sal quemando la piel
silêncio abafado	muffled silence	silencio amortiguado
som chegando atrasado	sound arriving late	sonido que llega tarde
sussurro de páginas	whisper of pages	susurro de páginas
vento cheio de vozes	wind full of voices	viento lleno de voces
vento cheirando a poeira	wind smelling of dust	viento con olor a polvo
vento rasgando o ouvido	wind tearing at the ears	viento que desgarra los oídos
vento seco assobiando em costelas	dry wind whistling through ribs	viento seco silbando entre costillas
água fria nos tornozelos	cold water around the ankles	agua fría alrededor de los tobillos
óleo queimado	burnt oil	aceite quemado
""")

STAKE = table(r"""
aceitar múltiplos futuros	accept multiple futures	aceptar múltiples futuros
assumir um nome alheio	take another's name	asumir un nombre ajeno
concluir uma máquina	finish a machine	terminar una máquina
controlar acesso	control access	controlar el acceso
controlar o Primeiro Fogo	control the First Fire	controlar el Primer Fuego
corrigir um calendário injusto	correct an unjust calendar	corregir un calendario injusto
dar direitos aos Inacabados	grant rights to the Unfinished	dar derechos a los Inacabados
decidir o que merece ser lembrado	decide what deserves to be remembered	decidir qué merece ser recordado
decidir qual versão acreditar	decide which version to believe	decidir qué versión creer
decidir quem controla uma corrente	decide who controls a current	decidir quién controla una corriente
decidir quem pode construir	decide who may build	decidir quién puede construir
decidir quem pode editar um registro	decide who may edit a record	decidir quién puede editar un registro
decidir quem recebe sombra	decide who receives shade	decidir quién recibe sombra
decidir se a noite deve terminar	decide whether the night should end	decidir si la noche debe terminar
decidir se o mar deve retornar	decide whether the sea should return	decidir si el mar debe regresar
desligar uma fábrica	shut down a factory	apagar una fábrica
escolher o que deve convergir	choose what should converge	elegir qué debe converger
escolher qual futuro avisar	choose which future to warn about	elegir qué futuro advertir
escolher uma rota futura	choose a future route	elegir una ruta futura
honrar uma promessa	honor a promise	honrar una promesa
impedir monopólio de rotas	prevent a monopoly on routes	impedir el monopolio de las rutas
impedir que um reflexo substitua alguém	prevent a reflection from replacing someone	impedir que un reflejo sustituya a alguien
impedir uma guerra sem apagar a verdade	stop a war without erasing the truth	impedir una guerra sin borrar la verdad
julgar quem possui uma chave	judge who owns a key	juzgar quién posee una llave
libertar um Eco	free an Echo	liberar un Eco
libertar uma passagem	free a passage	liberar un paso
manter uma comunidade acima da cheia	keep a community above the flood	mantener una comunidad por encima de la crecida
manter uma fogueira	keep a fire burning	mantener una hoguera
manter uma promessa estrutural	keep a structural promise	mantener una promesa estructural
não confundir lembrança com verdade	not confuse memory with truth	no confundir memoria con verdad
não destruir um registro vivo	avoid destroying a living record	no destruir un registro vivo
partilhar água	share water	compartir agua
preservar a noite	preserve the night	preservar la noche
preservar um arquivo fóssil	preserve a fossil archive	preservar un archivo fósil
preservar um naufrágio histórico	preserve a historic shipwreck	preservar un naufragio histórico
preservar uma culpa	preserve a guilt	preservar una culpa
preservar uma memória	preserve a memory	preservar un recuerdo
preservar uma rota	preserve a route	preservar una ruta
reatar sem criar tirania	reconnect without creating tyranny	reconectar sin crear tiranía
recusar um centro	reject a center	rechazar un centro
redistribuir peso	redistribute weight	redistribuir peso
redistribuir água	redistribute water	redistribuir agua
salvar alguém de uma memória futura	save someone from a future memory	salvar a alguien de un recuerdo futuro
salvar um porto	save a port	salvar un puerto
salvar um viajante	save a traveler	salvar a un viajero
salvar uma ponte	save a bridge	salvar un puente
seguir uma miragem verdadeira	follow a true mirage	seguir un espejismo verdadero
usar uma maré impossível	use an impossible tide	usar una marea imposible
""")

SECRET = table(r"""
Odria possui mais de uma história	Odria has more than one history	Odria tiene más de una historia
Porta Zero abre para lugares sem coordenada	Door Zero opens onto places without coordinates	Puerta Cero se abre a lugares sin coordenadas
a Boca devolve histórias modificadas	the Mouth returns altered stories	la Boca devuelve historias alteradas
a Cinza preserva algumas verdades ao apagá-las de todos	the Ash preserves some truths by erasing them from everyone	la Ceniza preserva algunas verdades al borrarlas de todos
a Galeria registra mortes alternativas	the Gallery records alternative deaths	la Galería registra muertes alternativas
a Ruptura pode ter sido contenção	the Rupture may have been containment	la Ruptura puede haber sido una contención
a aurora registra futuros descartados	the aurora records discarded futures	la aurora registra futuros descartados
a casa se apoia em outra versão do terreno	the house rests on another version of the ground	la casa se apoya en otra versión del terreno
a cidade possui mais portas do que paredes	the city has more doors than walls	la ciudad tiene más puertas que paredes
a oitava sombra não consta dos calendários	the eighth shadow does not appear on the calendars	la octava sombra no figura en los calendarios
a seiva vem de algo que não é árvore	the sap comes from something that is not a tree	la savia proviene de algo que no es un árbol
algo esquecido pode continuar causando efeitos	something forgotten can keep causing effects	algo olvidado puede seguir causando efectos
algumas chaves são relações e não objetos	some keys are relationships, not objects	algunas llaves son relaciones y no objetos
algumas estruturas são sustentadas por promessas	some structures are held up by promises	algunas estructuras se sostienen mediante promesas
algumas memórias ainda não aconteceram	some memories have not happened yet	algunos recuerdos todavía no han ocurrido
algumas páginas lembram jornadas que nunca ocorreram	some pages remember journeys that never happened	algunas páginas recuerdan jornadas que nunca ocurrieron
algumas versões do mundo recusam convergir	some versions of the world refuse to converge	algunas versiones del mundo se niegan a converger
alguns bairros compram sombra de outros	some districts buy shade from others	algunos barrios compran sombra a otros
alguns reflexos lembram escolhas recusadas	some reflections remember rejected choices	algunos reflejos recuerdan elecciones rechazadas
fósseis guardam inscrições	fossils hold inscriptions	los fósiles guardan inscripciones
nomes carregam dívidas	names carry debts	los nombres cargan deudas
nomes podem ser cultivados	names can be cultivated	los nombres pueden cultivarse
o Arquivo talvez tenha provocado a Poda	the Archive may have caused the Pruning	el Archivo puede haber provocado la Poda
o Nó Original não é necessariamente o primeiro	the Original Knot is not necessarily the first	el Nudo Original no es necesariamente el primero
o Primeiro Fogo lembra quem o acendeu	the First Fire remembers who lit it	el Primer Fuego recuerda quién lo encendió
o Sol Ausente pode ser uma escolha	the Absent Sun may be a choice	el Sol Ausente puede ser una elección
o Sol Oco já teve outra trajetória	the Hollow Sun once followed another path	el Sol Hueco tuvo otra trayectoria
o Tear responde a Marcas de jornadas anteriores	the Loom responds to Marks from previous journeys	el Telar responde a Marcas de jornadas anteriores
o abismo contém uma cidade	the abyss contains a city	el abismo contiene una ciudad
o farol ilumina destinos	the lighthouse illuminates destinies	el faro ilumina destinos
o oceano talvez ainda pressione o mundo	the ocean may still be pressing against the world	el océano quizá todavía presione el mundo
o vento repete cálculos	the wind repeats calculations	el viento repite cálculos
objetos chegam antes de serem perdidos	objects arrive before they are lost	los objetos llegan antes de perderse
objetos molhados surgem no deserto	wet objects appear in the desert	objetos mojados aparecen en el desierto
ordens vêm de pessoas mortas	orders come from dead people	las órdenes vienen de personas muertas
os obeliscos sustentam privilégios antigos	the obelisks uphold ancient privileges	los obeliscos sostienen privilegios antiguos
peças descartadas retornam melhores	discarded parts return improved	las piezas descartadas regresan mejoradas
sons chegam antes de sua causa	sounds arrive before their cause	los sonidos llegan antes que su causa
um endereço pode ser roubado	an address can be stolen	una dirección puede ser robada
um mapa cresce conforme a confiança muda	a map grows as trust changes	un mapa crece a medida que cambia la confianza
um índice pode apagar alguém	an index can erase someone	un índice puede borrar a alguien
uma badalada desapareceu na noite da Ruptura	a chime disappeared on the night of the Rupture	una campanada desapareció la noche de la Ruptura
uma fogueira queima lembranças em vez de lenha	a fire burns memories instead of wood	una hoguera quema recuerdos en lugar de leña
uma gota nunca cai	a drop never falls	una gota nunca cae
uma máquina aponta para o Tear	a machine points toward the Loom	una máquina apunta hacia el Telar
uma ponte projeta pilar que não existe	a bridge casts a pillar that does not exist	un puente proyecta un pilar que no existe
uma promessa esquecida sustenta a passagem	a forgotten promise holds the passage together	una promesa olvidada sostiene el paso
uma segunda lua só existe no reflexo	a second moon exists only in the reflection	una segunda luna solo existe en el reflejo
""")

TEACHING = table(r"""
Funciona mesmo com decisões imperfeitas; ensina leitura de intenção antes de exigir combo.	Works even with imperfect decisions; it teaches Intent reading before demanding combos.	Funciona incluso con decisiones imperfectas; enseña a leer la Intención antes de exigir combos.
Pede alternância entre ação básica e recurso de assinatura para manter eficiência.	Requires alternating between basic actions and the signature resource to stay efficient.	Exige alternar entre acciones básicas y el recurso distintivo para mantener la eficiencia.
Troca margem de erro por ferramentas mais eficientes; repetir a mesma resposta reduz o teto real do kit.	Trades margin for error for more efficient tools; repeating the same response lowers the kit's true ceiling.	Cambia margen de error por herramientas más eficientes; repetir la misma respuesta reduce el techo real del kit.
""")

MECHANIC = {
    "en": {"counter": "Counter", "damage": "Damage", "debt": "Debt", "echo": "Echo", "guard": "Guard", "heal": "Heal", "mark": "Mark", "move": "Move", "posture": "Posture", "range": "Range", "resource": "Resource", "status": "Status"},
    "es_419": {"counter": "Contraataque", "damage": "Daño", "debt": "Deuda", "echo": "Eco", "guard": "Guardia", "heal": "Curación", "mark": "Marca", "move": "Movimiento", "posture": "Postura", "range": "Alcance", "resource": "Recurso", "status": "Estado"},
}
STATUS = {
    "en": {"bleeding": "Bleeding", "burning": "Burning", "fear": "Fear", "frozen": "Frozen", "poison": "Poison", "rooted": "Rooted", "shock": "Shock", "wet": "Wet"},
    "es_419": {"bleeding": "Sangrado", "burning": "Ardiendo", "fear": "Miedo", "frozen": "Congelado", "poison": "Veneno", "rooted": "Enraizado", "shock": "Choque", "wet": "Mojado"},
}
ROLE = {
    "en": {"bruiser": "Bruiser", "bulwark": "Bulwark", "controller": "Controller", "duelist": "Duelist", "hunter": "Hunter", "raider": "Raider", "reactor": "Reactor", "resonator": "Resonator", "scholar": "Scholar", "seer": "Seer", "sentinel": "Sentinel", "skirmisher": "Skirmisher", "survivor": "Survivor", "tracker": "Tracker", "weaver": "Weaver"},
    "es_419": {"bruiser": "Peleador", "bulwark": "Baluarte", "controller": "Controlador", "duelist": "Duelista", "hunter": "Cazador", "raider": "Asaltante", "reactor": "Reactivo", "resonator": "Resonador", "scholar": "Erudito", "seer": "Vidente", "sentinel": "Centinela", "skirmisher": "Hostigador", "survivor": "Superviviente", "tracker": "Rastreador", "weaver": "Tejedor"},
}
RESOURCE = {
    "en": {"Acorde": "Chord", "Atalho": "Shortcut", "Ausência": "Absence", "Brasa": "Ember", "Brilho": "Glow", "Calor": "Heat", "Calor da Forja": "Forge Heat", "Chave": "Key", "Cinza": "Ash", "Claridade": "Clarity", "Deserção": "Desertion", "Eco": "Echo", "Epitáfio": "Epitaph", "Fratura": "Fracture", "Fôlego Afogado": "Drowned Breath", "Herança": "Inheritance", "Impulso": "Impulse", "Jurisdição": "Jurisdiction", "Maré": "Tide", "Memória": "Memory", "Mutação": "Mutation", "Ossos": "Bones", "Presságio": "Omen", "Reflexo": "Reflection", "Remendo": "Mend", "Ressonância": "Resonance", "Saque": "Plunder", "Sede": "Thirst", "Seiva": "Sap", "Sombra": "Shadow", "Sonho": "Dream", "Sopro": "Breath", "Tensão": "Tension", "Tensão de Cabo": "Cable Tension", "Trama Metálica": "Metal Weave", "Vestígio": "Vestige"},
    "es_419": {"Acorde": "Acorde", "Atalho": "Atajo", "Ausência": "Ausencia", "Brasa": "Brasa", "Brilho": "Brillo", "Calor": "Calor", "Calor da Forja": "Calor de la Forja", "Chave": "Llave", "Cinza": "Ceniza", "Claridade": "Claridad", "Deserção": "Deserción", "Eco": "Eco", "Epitáfio": "Epitafio", "Fratura": "Fractura", "Fôlego Afogado": "Aliento Ahogado", "Herança": "Herencia", "Impulso": "Impulso", "Jurisdição": "Jurisdicción", "Maré": "Marea", "Memória": "Memoria", "Mutação": "Mutación", "Ossos": "Huesos", "Presságio": "Presagio", "Reflexo": "Reflejo", "Remendo": "Remiendo", "Ressonância": "Resonancia", "Saque": "Saqueo", "Sede": "Sed", "Seiva": "Savia", "Sombra": "Sombra", "Sonho": "Sueño", "Sopro": "Soplo", "Tensão": "Tensión", "Tensão de Cabo": "Tensión de Cable", "Trama Metálica": "Trama Metálica", "Vestígio": "Vestigio"},
}


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"expected object: {path}")
    return value


def translate_signature(source: str, locale: str) -> str | None:
    parts = source.split(":")
    if len(parts) != 6:
        return None
    mechanic, power, cost, status, role, resource = parts
    if not power.startswith("p") or not cost.startswith("c"):
        return None
    try:
        mechanic_t = MECHANIC[locale][mechanic]
        status_t = STATUS[locale][status]
        role_t = ROLE[locale][role]
        resource_t = RESOURCE[locale][resource]
    except KeyError:
        return None
    if locale == "en":
        return f"{mechanic_t} · Power {power[1:]} · Cost {cost[1:]} · {status_t} · {role_t} · {resource_t}"
    return f"{mechanic_t} · Potencia {power[1:]} · Costo {cost[1:]} · {status_t} · {role_t} · {resource_t}"


def translate(source: str, field: str, locale: str) -> str | None:
    if field == "sensory":
        return SENSORY.get(source, {}).get(locale)
    if field == "secret":
        return SECRET.get(source, {}).get(locale)
    if field == "teaching_note":
        return TEACHING.get(source, {}).get(locale)
    if field == "signature":
        return translate_signature(source, locale)
    if field == "description":
        match = re.fullmatch(r"Carrega sinais de (.+) e foi adaptado para (.+)\.", source)
        if not match:
            return None
        sensory = SENSORY.get(match.group(1), {}).get(locale)
        stake = STAKE.get(match.group(2), {}).get(locale)
        if not sensory or not stake:
            return None
        if locale == "en":
            return f"Carries signs of {sensory} and was adapted to {stake}."
        return f"Muestra señales de {sensory} y fue adaptado para {stake}."
    if field == "conflict":
        if source in STAKE:
            return STAKE[source].get(locale)
        match = re.fullmatch(r"Decidir como (.+) sem ignorar que (.+)\.", source)
        if not match:
            return None
        stake = STAKE.get(match.group(1), {}).get(locale)
        secret = SECRET.get(match.group(2), {}).get(locale)
        if not stake or not secret:
            return None
        if locale == "en":
            return f"Decide how to {stake} without ignoring that {secret}."
        return f"Decidir cómo {stake} sin ignorar que {secret}."
    return None


def structured_units() -> dict[str, list[dict]]:
    catalog = build_catalog()
    result = {locale: [] for locale in TARGETS}
    source_counts: dict[str, int] = {}
    for unit in catalog["units"]:
        key = str(unit.get("key", ""))
        if not key.startswith("content."):
            continue
        path = str(unit.get("path", ""))
        field = path.split(".")[-1]
        if field not in EXPECTED:
            continue
        source = str(unit.get("source", ""))
        source_counts[field] = source_counts.get(field, 0) + 1
        for locale in TARGETS:
            translated = translate(source, field, locale)
            if not translated:
                raise SystemExit(f"untranslated structured unit: {locale}:{key}:{source}")
            result[locale].append({
                "key": key,
                "record_id": str(unit.get("record_id", "")),
                "path": path,
                "source": source,
                "translation": translated,
                "field": field,
            })
    if source_counts != EXPECTED:
        raise SystemExit(f"structured source counts drifted: expected={EXPECTED} actual={source_counts}")
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
        raise SystemExit(f"{locale}: {missing} structured translations missing")
    if not check_only:
        path.write_text(json.dumps(overlay, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return added, missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed deterministic localization for strictly structured presentation fields.")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true", help="Add missing structured translations to target overlays without overwriting manual translations.")
    mode.add_argument("--check", action="store_true", help="Fail if any structured translation is missing from target overlays.")
    args = parser.parse_args()

    units = structured_units()
    for locale in TARGETS:
        added, missing = apply(locale, units[locale], args.check)
        print(
            "STRUCTURED_LOCALIZATION %s: required=%d added=%d missing_before=%d mode=%s"
            % (locale, len(units[locale]), added, missing, "check" if args.check else "apply")
        )
    print("STRUCTURED_LOCALIZATION PASS: fields=%s units_per_target=%d" % (",".join(EXPECTED.keys()), sum(EXPECTED.values())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
