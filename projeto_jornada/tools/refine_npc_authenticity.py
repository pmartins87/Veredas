#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

DEADLINES = {
    "mata_fio_verde": [
        "as raízes fechem a passagem usada pela comunidade",
        "a próxima chuva apague os sinais gravados na casca",
        "a seiva negra se torne imprópria para uso",
        "os Guardadores cobrem o juramento pendente",
        "uma Vereda instável mude de posição",
    ],
    "varzea_espelhos": [
        "a maré invertida devolva ao rio aquilo que acabou de trazer",
        "o reflexo local assuma uma versão diferente dos fatos",
        "a água suba acima das estacas habitáveis",
        "a segunda lua mude de fase e altere a rota",
        "o canal repita uma decisão que ninguém tomou",
    ],
    "costa_sinos_afogados": [
        "a maré esconda novamente a rua de Odria",
        "o sino seguinte altere as correntes do porto",
        "a tempestade corte o acesso aos salvados",
        "o eco tardio revele uma versão contraditória da história",
        "o farol passe a iluminar outra rota possível",
    ],
    "chapada_sol_oco": [
        "a sombra útil abandone o bairro",
        "o meio-dia torne impossível cruzar o cânion",
        "a cisterna entre no próximo ciclo de racionamento",
        "o obelisco da oitava sombra volte a se alinhar",
        "o vidro solar retenha calor suficiente para ferir quem se aproxima",
    ],
    "salinas_ossamar": [
        "o Poço das Sete Cordas entre em novo rodízio de acesso",
        "a tempestade de sal apague as marcas da caravana",
        "a Miragem Azul mude de posição",
        "a reserva de água perca salinidade segura",
        "o Mar Ausente volte a exercer pressão sobre o terreno",
    ],
    "vertice": [
        "o vento mude a carga segura dos cabos",
        "o contrapeso de Avar seja redistribuído para outro bairro",
        "a ponte entre em ressonância perigosa",
        "a próxima rajada feche o elevador",
        "uma promessa estrutural vença e retire sustentação da passagem",
    ],
    "forja_rubra": [
        "a linha automática fabrique outra peça sem destinatário",
        "o Ferro Vivo se feche em torno da área de extração",
        "a caldeira exija mais energia do que o bairro pode ceder",
        "uma ordem antiga volte a ser executada pelos Inacabados",
        "o próximo ciclo de têmpera torne a oficina inacessível",
    ],
    "mar_cinza": [
        "a Cinza apague mais uma relação ligada ao caso",
        "o nome usado por testemunhas seja vendido no Mercado",
        "a estrada deixe de existir na memória dos viajantes",
        "o Mosteiro sele outra lembrança antes do depoimento",
        "a Boca do Esquecimento devolva uma versão alterada da história",
    ],
    "noite_iscara": [
        "a fogueira consuma a última brasa estável",
        "a aurora mostre um futuro incompatível com o plano atual",
        "a temperatura feche a rota sobre o lago",
        "uma memória futura se torne difícil de distinguir do presente",
        "o próximo silêncio boreal interrompa toda orientação",
    ],
    "cidade_mil_portas": [
        "a porta necessária mude de destino",
        "o Tribunal do Limiar altere a regra de passagem",
        "uma chave conceitual expire com a relação que a sustenta",
        "o Bairro sem Endereço seja novamente reindexado",
        "a Estação das Doze Soleiras feche o corredor correspondente",
    ],
    "arquivo_ecos": [
        "uma Rasura alcance o registro que sustenta a investigação",
        "o índice vivo mova a referência para outra versão",
        "um Eco órfão seja arquivado como se fosse original",
        "a tinta do documento perca a memória que contém",
        "os Copistas consolidem uma versão antes da contestação",
    ],
    "tear_desfeito": [
        "o Nó Original combine novamente duas possibilidades incompatíveis",
        "uma causa seja removida antes de produzir seu efeito",
        "o caminho para Ontem feche sua janela atual",
        "um futuro abortado adquira consistência suficiente para interferir",
        "a Convergência escolha uma versão por falta de resistência",
    ],
}


def load(name):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def save(name, rows):
    (DATA / f"{name}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")


def world_slug(world_id):
    return str(world_id).split(".", 1)[-1]


def main():
    npcs = load("npcs")
    locations = {row["id"]: row for row in load("locations")}
    counters = {}
    for npc in npcs:
        slug = world_slug(npc.get("world_id", ""))
        idx = counters.get(slug, 0)
        counters[slug] = idx + 1
        deadlines = DEADLINES.get(slug, ["a situação mude de forma irreversível"])
        deadline = deadlines[idx % len(deadlines)]
        location = locations.get(npc.get("location_id", ""), {})
        location_name = location.get("name", "a localidade")
        objective = str(npc.get("objective", "resolver a questão pendente")).strip().rstrip(".")
        base = str(npc.get("pressure", "Há pouco tempo para agir")).strip().rstrip(".")
        npc["pressure"] = f"{base}. Em {location_name}, precisa {objective.lower()} antes que {deadline}."
    save("npcs", npcs)
    print(f"refined {len(npcs)} NPC pressures across {len(counters)} domains")


if __name__ == "__main__":
    main()
