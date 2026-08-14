#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from export_localization_catalog import build_catalog
from seed_structured_localization import SENSORY, STAKE, SECRET, RESOURCE
from seed_structured_name_localization import MATERIALS
from seed_world_location_derived_name_localization import LOCATION_NAMES

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "localization"
TARGETS = ("en", "es_419")
EXPECTED = {
    ("character", "name"): 36,
    ("character", "passive"): 36,
    ("character", "personal_question"): 36,
    ("character", "weakness"): 36,
    ("ending", "epilogue"): 36,
    ("location", "premise"): 120,
    ("monster", "counterplay"): 300,
    ("monster", "ecology"): 300,
    ("npc", "objective"): 300,
    ("npc", "pressure"): 300,
    ("npc", "voice"): 300,
    ("pool", "name"): 144,
}
EXPECTED_TOTAL = sum(EXPECTED.values())


def bilingual(raw: str) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for line in raw.strip().splitlines():
        src, en, es = line.split("\t")
        out[src] = {"en": en, "es_419": es}
    return out


CHAR_NAMES = bilingual(r"""
Arquivista	Archivist	Archivista
Repetente	Repeater	Repetidor
Curadora de Ecos	Echo Curator	Curadora de Ecos
Lanceiro Solar	Solar Lancer	Lancero Solar
Caminhante de Sombra	Shadow Walker	Caminante de Sombras
Oráculo do Meio-Dia	Midday Oracle	Oráculo del Mediodía
Chaveiro	Locksmith	Cerrajero
Contrabandista de Portas	Door Smuggler	Contrabandista de Puertas
Magistrada do Limiar	Threshold Magistrate	Magistrada del Umbral
Sineiro Náufrago	Shipwrecked Bellringer	Campanero Náufrago
Corsária de Coral	Coral Corsair	Corsaria de Coral
Vigia de Maré	Tide Watcher	Vigía de Marea
Ferreiro de Guerra	War Smith	Herrero de Guerra
Desertor da Forja	Forge Deserter	Desertor de la Forja
Tecelã de Metal	Metal Weaver	Tejedora de Metal
Penitente Cinzento	Gray Penitent	Penitente Gris
Necrógrafa	Necrographer	Necrógrafa
Sem-Nome	Nameless	Sin Nombre
Rastreador de Nós	Knot Tracker	Rastreador de Nudos
Guardião de Casca	Bark Guardian	Guardián de Corteza
Cantora de Cipós	Vine Singer	Cantora de Enredaderas
Caçadora de Aurora	Aurora Hunter	Cazadora de Aurora
Portador da Brasa	Ember Bearer	Portador de la Brasa
Sonhador de Gelo	Ice Dreamer	Soñador de Hielo
Catador de Ossos	Bone Gatherer	Recolector de Huesos
Peregrina da Sede	Pilgrim of Thirst	Peregrina de la Sed
Paleocaçador	Paleohunter	Paleocazador
Tecelão Fraturado	Fractured Weaver	Tejedor Fracturado
Herdeira do Nó	Heiress of the Knot	Heredera del Nudo
Inacabado	Unfinished	Inacabado
Barqueiro do Reflexo	Ferryman of Reflection	Barquero del Reflejo
Pescadora de Presságios	Omen Fisher	Pescadora de Presagios
Afogado Retornado	Returned Drowned	Ahogado Retornado
Duelista do Abismo	Abyss Duelist	Duelista del Abismo
Engenheira de Pontes	Bridge Engineer	Ingeniera de Puentes
Monge do Vento	Wind Monk	Monje del Viento
""")

THREAT = bilingual(r"""
afogados sem rosto	faceless drowned	ahogados sin rostro
auroras que alteram rotas	auroras that alter routes	auroras que alteran rutas
caldeiras autônomas	autonomous boilers	calderas autónomas
calor que altera memória	heat that alters memory	calor que altera la memoria
cargas mal distribuídas	poorly distributed loads	cargas mal distribuidas
causas chegando depois dos efeitos	causes arriving after their effects	causas que llegan después de los efectos
corredores que se reescrevem	corridors that rewrite themselves	corredores que se reescriben
correntes invertidas	inverted currents	corrientes invertidas
ecos que exigem autoria	echoes that demand authorship	ecos que exigen autoría
escorpiões de sombra	shadow scorpions	escorpiones de sombra
espelhos que roubam a noite	mirrors that steal the night	espejos que roban la noche
esporos que confundem direção	spores that confuse direction	esporas que confunden la dirección
esquecimento progressivo	progressive forgetting	olvido progresivo
estradas que somem da lembrança	roads that vanish from memory	caminos que desaparecen del recuerdo
frio que cristaliza pensamentos	cold that crystallizes thoughts	frío que cristaliza pensamientos
futuros abortados	aborted futures	futuros abortados
futuros vazando em sonhos	futures leaking into dreams	futuros que se filtran en sueños
fósseis que despertam	fossils that awaken	fósiles que despiertan
ilhas que repetem trajetos	islands that repeat routes	islas que repiten trayectos
juramentos presos à madeira	oaths bound to wood	juramentos atados a la madera
leis incompatíveis entre bairros	incompatible laws between districts	leyes incompatibles entre barrios
linhas de produção sem mestre	masterless production lines	líneas de producción sin maestro
marcas apagadas	erased Marks	Marcas borradas
memórias órfãs	orphaned memories	recuerdos huérfanos
metal que se defende	metal that defends itself	metal que se defiende
miragens com peso	mirages with weight	espejismos con peso
máquinas obedecendo ordens mortas	machines obeying dead orders	máquinas que obedecen órdenes muertas
mímicos de passagem	passage mimics	mímicos de paso
nomes negociados	traded names	nombres negociados
paradoxos famintos	hungry paradoxes	paradojas hambrientas
pontes sob tensão	bridges under strain	puentes bajo tensión
portas que trocam destino	doors that change destination	puertas que cambian de destino
predadores de casca	bark predators	depredadores de corteza
predadores de vidro	glass predators	depredadores de vidrio
quedas sem fundo	bottomless falls	caídas sin fondo
rajadas laterais	crosswinds	ráfagas laterales
rasuras predatórias	predatory erasures	borraduras depredadoras
raízes que fecham caminhos	roots that close paths	raíces que cierran caminos
reflexos que agem antes do corpo	reflections that act before the body	reflejos que actúan antes que el cuerpo
regras locais falhando	local rules failing	reglas locales que fallan
ruas que afundam com a maré	streets that sink with the tide	calles que se hunden con la marea
salvados de versões inexistentes	salvage from nonexistent versions	restos rescatados de versiones inexistentes
sede extrema	extreme thirst	sed extrema
sinos que atraem correntes	bells that draw currents	campanas que atraen corrientes
sombras que não obedecem seus donos	shadows that disobey their owners	sombras que no obedecen a sus dueños
tempestades de sal	salt storms	tormentas de sal
tempestades que repetem vozes	storms that repeat voices	tormentas que repiten voces
textos que reescrevem leitores	texts that rewrite readers	textos que reescriben a los lectores
""")

VOICE_STYLE = bilingual(r"""
corrige os próprios detalhes	corrects their own details	corrige sus propios detalles
transforma tudo em histórias alheias	turns everything into other people's stories	convierte todo en historias ajenas
prefere pesos e distâncias	prefers weights and distances	prefiere pesos y distancias
fala com solenidade	speaks solemnly	habla con solemnidad
usa humor seco	uses dry humor	usa humor seco
não promete sem dizer o preço	makes no promise without naming the price	no promete sin decir el precio
evita nomes próprios	avoids proper names	evita nombres propios
fala rápido diante de contradições	speaks quickly when faced with contradictions	habla rápido ante contradicciones
deixa longos silêncios	leaves long silences	deja largos silencios
cita e contesta provérbios	quotes and challenges proverbs	cita y cuestiona proverbios
responde com precisão desconfortável	answers with uncomfortable precision	responde con precisión incómoda
parece casual quando esconde algo	sounds casual when hiding something	parece casual cuando oculta algo
fala como num depoimento	speaks as if giving testimony	habla como en una declaración
usa o ambiente como metáfora	uses the surroundings as a metaphor	usa el entorno como metáfora
muda para o plural ao falar de culpa	switches to the plural when speaking of guilt	cambia al plural al hablar de culpa
evita dizer eu	avoids saying “I”	evita decir «yo»
usa palavras arcaicas	uses archaic words	usa palabras arcaicas
tem voz calorosa e decisões duras	has a warm voice and hard decisions	tiene voz cálida y decisiones duras
se irrita com imprecisão	gets irritated by imprecision	se irrita con la imprecisión
fala do futuro como lembrança	speaks of the future as memory	habla del futuro como recuerdo
mede cada palavra	weighs every word	mide cada palabra
usa comparações concretas	uses concrete comparisons	usa comparaciones concretas
ri quando está nervoso	laughs when nervous	ríe cuando está nervioso
faz perguntas antes de responder	asks questions before answering	hace preguntas antes de responder
fala baixo e nunca repete uma frase	speaks softly and never repeats a sentence	habla bajo y nunca repite una frase
""")

CRISIS = bilingual(r"""
a Boca do Esquecimento devolva uma versão alterada da história	the Mouth of Forgetting returns an altered version of the story	la Boca del Olvido devuelva una versión alterada de la historia
a Cinza apague mais uma relação ligada ao caso	the Ash erases another relationship tied to the case	la Ceniza borre otra relación vinculada al caso
a Convergência escolha uma versão por falta de resistência	the Convergence chooses a version for lack of resistance	la Convergencia elija una versión por falta de resistencia
a Estação das Doze Soleiras feche o corredor correspondente	the Station of the Twelve Thresholds closes the corresponding corridor	la Estación de los Doce Umbrales cierre el corredor correspondiente
a Miragem Azul mude de posição	the Blue Mirage changes position	el Espejismo Azul cambie de posición
a aurora mostre um futuro incompatível com o plano atual	the aurora shows a future incompatible with the current plan	la aurora muestre un futuro incompatible con el plan actual
a caldeira exija mais energia do que o bairro pode ceder	the boiler demands more energy than the district can spare	la caldera exija más energía de la que el barrio puede ceder
a cisterna entre no próximo ciclo de racionamento	the cistern enters the next rationing cycle	la cisterna entre en el próximo ciclo de racionamiento
a estrada deixe de existir na memória dos viajantes	the road ceases to exist in travelers' memories	el camino deje de existir en la memoria de los viajeros
a fogueira consuma a última brasa estável	the fire consumes the last stable ember	la hoguera consuma la última brasa estable
a linha automática fabrique outra peça sem destinatário	the automated line manufactures another part with no recipient	la línea automática fabrique otra pieza sin destinatario
a maré esconda novamente a rua de Odria	the tide hides Odria's street again	la marea vuelva a ocultar la calle de Odria
a maré invertida devolva ao rio aquilo que acabou de trazer	the inverted tide returns to the river what it just brought	la marea invertida devuelva al río lo que acaba de traer
a ponte entre em ressonância perigosa	the bridge enters dangerous resonance	el puente entre en una resonancia peligrosa
a porta necessária mude de destino	the needed door changes destination	la puerta necesaria cambie de destino
a próxima chuva apague os sinais gravados na casca	the next rain erases the signs carved into the bark	la próxima lluvia borre las señales grabadas en la corteza
a próxima rajada feche o elevador	the next gust shuts down the lift	la próxima ráfaga cierre el elevador
a reserva de água perca salinidade segura	the water reserve loses its safe salinity	la reserva de agua pierda una salinidad segura
a segunda lua mude de fase e altere a rota	the second moon changes phase and alters the route	la segunda luna cambie de fase y altere la ruta
a seiva negra se torne imprópria para uso	the black sap becomes unsafe to use	la savia negra se vuelva impropia para el uso
a sombra útil abandone o bairro	the useful shadow abandons the district	la sombra útil abandone el barrio
a temperatura feche a rota sobre o lago	the temperature closes the route across the lake	la temperatura cierre la ruta sobre el lago
a tempestade corte o acesso aos salvados	the storm cuts off access to the salvage	la tormenta corte el acceso a los restos rescatados
a tempestade de sal apague as marcas da caravana	the salt storm erases the caravan's Marks	la tormenta de sal borre las Marcas de la caravana
a tinta do documento perca a memória que contém	the document's ink loses the memory it contains	la tinta del documento pierda la memoria que contiene
a água suba acima das estacas habitáveis	the water rises above the habitable stakes	el agua suba por encima de las estacas habitables
as raízes fechem a passagem usada pela comunidade	the roots close the passage used by the community	las raíces cierren el paso usado por la comunidad
o Bairro sem Endereço seja novamente reindexado	the District Without an Address is reindexed again	el Barrio sin Dirección vuelva a ser reindexado
o Ferro Vivo se feche em torno da área de extração	the Living Iron closes around the extraction area	el Hierro Vivo se cierre alrededor del área de extracción
o Mar Ausente volte a exercer pressão sobre o terreno	the Absent Sea begins pressing against the land again	el Mar Ausente vuelva a ejercer presión sobre el terreno
o Mosteiro sele outra lembrança antes do depoimento	the Monastery seals another memory before the testimony	el Monasterio selle otro recuerdo antes del testimonio
o Nó Original combine novamente duas possibilidades incompatíveis	the Original Knot combines two incompatible possibilities again	el Nudo Original vuelva a combinar dos posibilidades incompatibles
o Poço das Sete Cordas entre em novo rodízio de acesso	the Well of Seven Ropes enters a new access rotation	el Pozo de las Siete Cuerdas entre en una nueva rotación de acceso
o Tribunal do Limiar altere a regra de passagem	the Threshold Court changes the passage rule	el Tribunal del Umbral cambie la regla de paso
o caminho para Ontem feche sua janela atual	the path to Yesterday closes its current window	el camino hacia Ayer cierre su ventana actual
o canal repita uma decisão que ninguém tomou	the channel repeats a decision nobody made	el canal repita una decisión que nadie tomó
o contrapeso de Avar seja redistribuído para outro bairro	Avar's counterweight is reassigned to another district	el contrapeso de Avar sea redistribuido a otro barrio
o eco tardio revele uma versão contraditória da história	the late echo reveals a contradictory version of the story	el eco tardío revele una versión contradictoria de la historia
o farol passe a iluminar outra rota possível	the lighthouse begins illuminating another possible route	el faro pase a iluminar otra ruta posible
o meio-dia torne impossível cruzar o cânion	midday makes it impossible to cross the canyon	el mediodía vuelva imposible cruzar el cañón
o nome usado por testemunhas seja vendido no Mercado	the name used by witnesses is sold in the Market	el nombre usado por los testigos sea vendido en el Mercado
o obelisco da oitava sombra volte a se alinhar	the obelisk of the eighth shadow aligns again	el obelisco de la octava sombra vuelva a alinearse
o próximo ciclo de têmpera torne a oficina inacessível	the next tempering cycle makes the workshop inaccessible	el próximo ciclo de templado vuelva inaccesible el taller
o próximo silêncio boreal interrompa toda orientação	the next boreal silence disrupts all navigation	el próximo silencio boreal interrumpa toda orientación
o reflexo local assuma uma versão diferente dos fatos	the local reflection adopts a different version of the facts	el reflejo local adopte una versión diferente de los hechos
o sino seguinte altere as correntes do porto	the next bell alters the port currents	la siguiente campana altere las corrientes del puerto
o vento mude a carga segura dos cabos	the wind changes the cables' safe load	el viento cambie la carga segura de los cables
o vidro solar retenha calor suficiente para ferir quem se aproxima	the sun-glass retains enough heat to injure anyone who approaches	el vidrio solar retenga suficiente calor para herir a quien se acerque
o índice vivo mova a referência para outra versão	the living index moves the reference to another version	el índice vivo mueva la referencia a otra versión
os Copistas consolidem uma versão antes da contestação	the Copyists consolidate a version before it can be challenged	los Copistas consoliden una versión antes de la impugnación
os Guardadores cobrem o juramento pendente	the Keepers collect on the outstanding oath	los Guardianes cobren el juramento pendiente
um Eco órfão seja arquivado como se fosse original	an orphaned Echo is archived as if it were original	un Eco huérfano sea archivado como si fuera original
um futuro abortado adquira consistência suficiente para interferir	an aborted future gains enough substance to interfere	un futuro abortado adquiera suficiente consistencia para interferir
uma Rasura alcance o registro que sustenta a investigação	an Erasure reaches the record supporting the investigation	una Borradura alcance el registro que sostiene la investigación
uma Vereda instável mude de posição	an unstable Path changes position	una Senda inestable cambie de posición
uma causa seja removida antes de produzir seu efeito	a cause is removed before producing its effect	una causa sea eliminada antes de producir su efecto
uma chave conceitual expire com a relação que a sustenta	a conceptual key expires with the relationship that sustains it	una llave conceptual expire con la relación que la sostiene
uma memória futura se torne difícil de distinguir do presente	a future memory becomes hard to distinguish from the present	un recuerdo futuro se vuelva difícil de distinguir del presente
uma ordem antiga volte a ser executada pelos Inacabados	an old order is carried out by the Unfinished again	una orden antigua vuelva a ser ejecutada por los Inacabados
uma promessa estrutural vença e retire sustentação da passagem	a structural promise expires and withdraws support from the passage	una promesa estructural venza y retire el soporte del paso
""")

COUNTER_MECH = {
    "alcance": {"en": "range", "es_419": "alcance"},
    "estado": {"en": "status", "es_419": "estado"},
    "postura": {"en": "posture", "es_419": "postura"},
    "ritmo": {"en": "rhythm", "es_419": "ritmo"},
    "terreno": {"en": "terrain", "es_419": "terreno"},
}
POOL = {
    "arc": {"en": "arc", "es_419": "arco"},
    "callback": {"en": "callback", "es_419": "retorno"},
    "creature": {"en": "creature", "es_419": "criatura"},
    "exploration": {"en": "exploration", "es_419": "exploración"},
    "faction": {"en": "faction", "es_419": "facción"},
    "hazard": {"en": "hazard", "es_419": "peligro"},
    "knowledge": {"en": "knowledge", "es_419": "conocimiento"},
    "memory": {"en": "memory", "es_419": "memoria"},
    "ritual": {"en": "ritual", "es_419": "ritual"},
    "route": {"en": "route", "es_419": "ruta"},
    "social": {"en": "social", "es_419": "social"},
    "trade": {"en": "trade", "es_419": "comercio"},
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


def resource(source: str, locale: str) -> str | None:
    mapping = RESOURCE.get(locale, {})
    wanted = norm(source)
    for key, value in mapping.items():
        if norm(str(key)) == wanted:
            return str(value)
    return None


def material(source: str, locale: str) -> str | None:
    return translated(MATERIALS, source, locale)


def location(source: str, locale: str) -> str | None:
    return translated(LOCATION_NAMES, source, locale)


def npc_personal_name(source_name: str) -> tuple[str, str] | None:
    candidates = sorted(LOCATION_NAMES, key=len, reverse=True)
    source_cf = source_name.casefold()
    for loc in candidates:
        suffix = " de " + loc.casefold()
        if source_cf.endswith(suffix):
            personal = source_name[: len(source_name) - len(suffix)].strip()
            if personal:
                return personal, loc
    return None


def source_units() -> list[dict[str, Any]]:
    catalog = build_catalog()
    selected: list[dict[str, Any]] = []
    counts: dict[tuple[str, str], int] = {}
    for unit in catalog["units"]:
        key = str(unit.get("key", ""))
        if not key.startswith("content."):
            continue
        record_id = str(unit.get("record_id", ""))
        path = str(unit.get("path", ""))
        kind = record_id.split(".", 1)[0]
        pair = (kind, path)
        if pair not in EXPECTED:
            continue
        counts[pair] = counts.get(pair, 0) + 1
        selected.append(unit)
    if counts != EXPECTED:
        missing = {f"{k[0]}.{k[1]}": (EXPECTED[k], counts.get(k, 0)) for k in EXPECTED if counts.get(k, 0) != EXPECTED[k]}
        raise SystemExit(f"structured narrative inventory drifted: {missing}")
    if len(selected) != EXPECTED_TOTAL:
        raise SystemExit(f"expected {EXPECTED_TOTAL} selected units, got {len(selected)}")
    return selected


def translate_unit(unit: dict[str, Any], locale: str, overlay: dict[str, Any]) -> str | None:
    rid = str(unit["record_id"])
    kind = rid.split(".", 1)[0]
    path = str(unit["path"])
    source = str(unit["source"])

    if kind == "character" and path == "name":
        return translated(CHAR_NAMES, source, locale)

    if kind == "character" and path == "passive":
        m = re.fullmatch(r"(.+) converte (.+) em (.+) quando muda a forma de lidar com (.+)\.", source)
        if not m:
            return None
        char_t = translated(CHAR_NAMES, m.group(1), locale)
        sensory_t = translated(SENSORY, m.group(2), locale)
        resource_t = resource(m.group(3), locale)
        stake_t = translated(STAKE, m.group(4), locale)
        if not all((char_t, sensory_t, resource_t, stake_t)):
            return None
        if locale == "en":
            return f"{char_t} converts {sensory_t} into {resource_t} when changing how they approach the task: {stake_t}."
        return f"{char_t} convierte {sensory_t} en {resource_t} cuando cambia su forma de abordar la tarea: {stake_t}."

    if kind == "character" and path == "personal_question":
        m = re.fullmatch(r"Até onde aceita (.+) quando descobre que (.+)\?", source)
        if not m:
            return None
        stake_t = translated(STAKE, m.group(1), locale)
        secret_t = translated(SECRET, m.group(2), locale)
        if not stake_t or not secret_t:
            return None
        if locale == "en":
            return f"How far will they go to {stake_t} after discovering that {secret_t}?"
        return f"¿Hasta dónde llega su disposición a {stake_t} al descubrir que {secret_t}?"

    if kind == "character" and path == "weakness":
        m = re.fullmatch(r"(.+) perde eficiência quando insiste duas vezes contra (.+)\.", source)
        if not m:
            return None
        char_t = translated(CHAR_NAMES, m.group(1), locale)
        threat_t = translated(THREAT, m.group(2), locale)
        if not char_t or not threat_t:
            return None
        if locale == "en":
            return f"{char_t} loses efficiency when they repeat the same approach twice against {threat_t}."
        return f"{char_t} pierde eficiencia cuando repite dos veces el mismo enfoque contra {threat_t}."

    if kind == "ending" and path == "epilogue":
        m = re.fullmatch(r"A solução escolhe (.+) sabendo que (.+)\.", source)
        if not m:
            return None
        stake_t = translated(STAKE, m.group(1), locale)
        secret_t = translated(SECRET, m.group(2), locale)
        if not stake_t or not secret_t:
            return None
        if locale == "en":
            return f"The solution chooses to {stake_t}, knowing that {secret_t}."
        return f"La solución elige {stake_t}, sabiendo que {secret_t}."

    if kind == "location" and path == "premise":
        m = re.fullmatch(r"(.+) é marcado por (.+) e por (.+)\.", source)
        if not m:
            return None
        loc_t = location(m.group(1), locale)
        material_t = material(m.group(2), locale)
        threat_t = translated(THREAT, m.group(3), locale)
        if not loc_t or not material_t or not threat_t:
            return None
        if locale == "en":
            return f"{loc_t} is marked by {material_t} and by {threat_t}."
        return f"{loc_t} está marcado por {material_t} y por {threat_t}."

    if kind == "monster" and path == "counterplay":
        m = re.fullmatch(r"A janela surge quando (.+) anuncia mudança de comportamento; explore (.+) \((\d+)/25\)\.", source)
        if not m:
            return None
        sensory_t = translated(SENSORY, m.group(1), locale)
        mech_t = translated(COUNTER_MECH, m.group(2), locale)
        if not sensory_t or not mech_t:
            return None
        if locale == "en":
            return f"The opening appears when {sensory_t} signals a behavior change; exploit {mech_t} ({m.group(3)}/25)."
        return f"La apertura aparece cuando {sensory_t} anuncia un cambio de comportamiento; aprovecha {mech_t} ({m.group(3)}/25)."

    if kind == "monster" and path == "ecology":
        m = re.fullmatch(r"(.+) ocupa (.+), onde (.+) oferece abrigo; compete em torno de (.+) e evita (.+)\.", source)
        if not m:
            return None
        current_record = overlay.get(rid, {})
        monster_t = current_record.get("name") if isinstance(current_record, dict) else None
        loc_t = location(m.group(2), locale)
        material_t = material(m.group(3), locale)
        stake_t = translated(STAKE, m.group(4), locale)
        threat_t = translated(THREAT, m.group(5), locale)
        if not all(isinstance(v, str) and v.strip() for v in (monster_t, loc_t, material_t, stake_t, threat_t)):
            return None
        if locale == "en":
            return f"{monster_t} inhabits {loc_t}, where {material_t} provides shelter; its competition centers on the goal to {stake_t}, and it avoids {threat_t}."
        return f"{monster_t} habita {loc_t}, donde {material_t} ofrece refugio; su competencia gira en torno al objetivo de {stake_t} y evita {threat_t}."

    if kind == "npc" and path == "objective":
        m = re.fullmatch(r"(.+) quer (.+) antes que (.+) torne o lugar inviável\.", source)
        if not m:
            return None
        parsed = npc_personal_name(m.group(1))
        stake_t = translated(STAKE, m.group(2), locale)
        threat_t = translated(THREAT, m.group(3), locale)
        if not parsed or not stake_t or not threat_t:
            return None
        personal, source_location = parsed
        loc_t = location(source_location, locale)
        if not loc_t:
            return None
        if locale == "en":
            return f"At {loc_t}, {personal} wants to {stake_t} before the place becomes unlivable because of {threat_t}."
        return f"En {loc_t}, {personal} quiere {stake_t} antes de que el lugar se vuelva inhabitable por {threat_t}."

    if kind == "npc" and path == "pressure":
        m = re.fullmatch(r"Sabe que (.+) e teme perder (.+) se falar\. Em (.+), precisa (.+) antes que (.+)\.", source)
        if not m:
            return None
        secret_t = translated(SECRET, m.group(1), locale)
        material_t = material(m.group(2), locale)
        loc_t = location(m.group(3), locale)
        embedded = m.group(4)
        crisis_t = translated(CRISIS, m.group(5), locale)
        embedded_m = re.fullmatch(r"(.+) quer (.+) antes que (.+) torne o lugar inviável", embedded, flags=re.IGNORECASE)
        if not embedded_m:
            return None
        parsed = npc_personal_name(embedded_m.group(1))
        stake_t = translated(STAKE, embedded_m.group(2), locale)
        threat_t = translated(THREAT, embedded_m.group(3), locale)
        if not parsed or not all((secret_t, material_t, loc_t, crisis_t, stake_t, threat_t)):
            return None
        personal, _ = parsed
        if locale == "en":
            return f"Knows that {secret_t} and fears losing {material_t} if they speak. In {loc_t}, {personal} must {stake_t} before the place becomes unlivable because of {threat_t}, and before {crisis_t}."
        return f"Sabe que {secret_t} y teme perder {material_t} si habla. En {loc_t}, {personal} debe {stake_t} antes de que el lugar se vuelva inhabitable por {threat_t} y antes de que {crisis_t}."

    if kind == "npc" and path == "voice":
        m = re.fullmatch(r"(.+); menciona (.+)\.", source)
        if not m:
            return None
        style_t = translated(VOICE_STYLE, m.group(1), locale)
        sensory_t = translated(SENSORY, m.group(2), locale)
        if not style_t or not sensory_t:
            return None
        if locale == "en":
            return f"{style_t}; mentions {sensory_t}."
        return f"{style_t}; menciona {sensory_t}."

    if kind == "pool" and path == "name":
        return translated(POOL, source, locale)

    return None


def apply(locale: str, units: list[dict[str, Any]], check_only: bool) -> tuple[int, int]:
    path = LOC / "content" / f"{locale}.json"
    overlay = read_object(path)
    missing_before = 0
    added = 0
    untranslated: list[str] = []
    for unit in units:
        rid = str(unit["record_id"])
        field = str(unit["path"])
        record = overlay.get(rid)
        if not isinstance(record, dict):
            record = {}
            if not check_only:
                overlay[rid] = record
        current = record.get(field) if isinstance(record, dict) else None
        if isinstance(current, str) and current.strip():
            continue
        missing_before += 1
        value = translate_unit(unit, locale, overlay)
        if not isinstance(value, str) or not value.strip():
            untranslated.append(f"{rid}.{field}: {unit['source']}")
            continue
        if not check_only:
            record[field] = value
            added += 1
    if untranslated:
        sample = "\n".join(untranslated[:30])
        raise SystemExit(f"{locale}: {len(untranslated)} structured narrative translations unresolved\n{sample}")
    if check_only and missing_before:
        raise SystemExit(f"{locale}: {missing_before} structured narrative translations missing")
    if not check_only:
        path.write_text(json.dumps(overlay, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return added, missing_before


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed deterministic non-event narrative localization for phase 11.6.")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()

    units = source_units()
    for locale in TARGETS:
        added, missing = apply(locale, units, args.check)
        print("STRUCTURED_NARRATIVE_LOCALIZATION %s: required=%d added=%d missing_before=%d mode=%s" % (locale, EXPECTED_TOTAL, added, missing, "check" if args.check else "apply"))
    print("STRUCTURED_NARRATIVE_LOCALIZATION PASS: characters=144 endings=36 locations=120 monsters=600 npcs=900 pools=144 units_per_target=%d" % EXPECTED_TOTAL)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
