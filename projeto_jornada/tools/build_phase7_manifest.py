#!/usr/bin/env python3
"""Build the canonical Phase 7 art manifest for Veredas da Trama.

The manifest is deliberately data-first: final illustrations can be produced in any
approved tool, but every required asset has a stable ID, path and delivery contract.
No external reference title or third-party visual identity is part of this source.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "manifests" / "phase7_art_manifest.json"

DOMAINS = [
    ("mata_fio_verde", "Mata do Fio Verde"),
    ("varzea_espelhos", "Várzea dos Espelhos"),
    ("costa_sinos_afogados", "Costa dos Sinos Afogados"),
    ("chapada_sol_oco", "Chapada do Sol Oco"),
    ("salinas_ossamar", "Salinas de Ossamar"),
    ("vertice", "Vértice"),
    ("forja_rubra", "Forja Rubra"),
    ("mar_cinza", "Mar de Cinza"),
    ("noite_iscara", "Noite de Iscara"),
    ("cidade_mil_portas", "Cidade das Mil Portas"),
    ("arquivo_ecos", "Arquivo dos Ecos"),
    ("tear_desfeito", "Tear Desfeito"),
]

CHARACTERS = [
    ("rastreador_nos", "Rastreador de Nós", "mata_fio_verde"),
    ("guardiao_casca", "Guardião de Casca", "mata_fio_verde"),
    ("cantora_cipos", "Cantora de Cipós", "mata_fio_verde"),
    ("barqueiro_reflexo", "Barqueiro do Reflexo", "varzea_espelhos"),
    ("pescadora_pressagios", "Pescadora de Presságios", "varzea_espelhos"),
    ("afogado_retornado", "Afogado Retornado", "varzea_espelhos"),
    ("sineiro_naufrago", "Sineiro Náufrago", "costa_sinos_afogados"),
    ("corsaria_coral", "Corsária de Coral", "costa_sinos_afogados"),
    ("vigia_mare", "Vigia de Maré", "costa_sinos_afogados"),
    ("lanceiro_solar", "Lanceiro Solar", "chapada_sol_oco"),
    ("caminhante_sombra", "Caminhante de Sombra", "chapada_sol_oco"),
    ("oraculo_meio_dia", "Oráculo do Meio-Dia", "chapada_sol_oco"),
    ("catador_ossos", "Catador de Ossos", "salinas_ossamar"),
    ("peregrina_sede", "Peregrina da Sede", "salinas_ossamar"),
    ("paleocacador", "Paleocaçador", "salinas_ossamar"),
    ("duelista_abismo", "Duelista do Abismo", "vertice"),
    ("engenheira_pontes", "Engenheira de Pontes", "vertice"),
    ("monge_vento", "Monge do Vento", "vertice"),
    ("ferreiro_guerra", "Ferreiro de Guerra", "forja_rubra"),
    ("desertor_forja", "Desertor da Forja", "forja_rubra"),
    ("tecela_metal", "Tecelã de Metal", "forja_rubra"),
    ("penitente_cinzento", "Penitente Cinzento", "mar_cinza"),
    ("necrografa", "Necrógrafa", "mar_cinza"),
    ("sem_nome", "Sem-Nome", "mar_cinza"),
    ("cacadora_aurora", "Caçadora de Aurora", "noite_iscara"),
    ("portador_brasa", "Portador da Brasa", "noite_iscara"),
    ("sonhador_gelo", "Sonhador de Gelo", "noite_iscara"),
    ("chaveiro", "Chaveiro", "cidade_mil_portas"),
    ("contrabandista_portas", "Contrabandista de Portas", "cidade_mil_portas"),
    ("magistrada_limiar", "Magistrada do Limiar", "cidade_mil_portas"),
    ("arquivista", "Arquivista", "arquivo_ecos"),
    ("repetente", "Repetente", "arquivo_ecos"),
    ("curadora_ecos", "Curadora de Ecos", "arquivo_ecos"),
    ("tecelao_fraturado", "Tecelão Fraturado", "tear_desfeito"),
    ("herdeira_no", "Herdeira do Nó", "tear_desfeito"),
    ("inacabado", "Inacabado", "tear_desfeito"),
]

TACTICAL_ROLES = [
    "predator", "controller", "skirmisher", "tank",
    "swarm", "artillery", "attrition", "trickster",
]

SYSTEM_ICONS = [
    "health", "vigor", "posture", "guard", "attack", "precision",
    "distance", "movement", "inventory", "character", "journal", "map",
    "mark", "debt", "echo", "thread", "route", "consequence",
    "item_weapon", "item_armor", "item_tool", "item_talisman",
    "item_consumable", "item_key", "currency", "essence",
    "provisions", "load", "merchant", "boss", "elite", "warning",
]


def asset(asset_id: str, kind: str, path: str, *, label: str = "", domain: str = "",
          dimensions: str = "", variants: int = 1, status: str = "required") -> dict:
    return {
        "id": asset_id,
        "kind": kind,
        "label": label,
        "domain": domain,
        "path": path,
        "dimensions": dimensions,
        "variants": variants,
        "status": status,
        "style_contract": "hand_inked_book_game_original",
    }


def build() -> dict:
    assets: list[dict] = []

    for domain_id, domain_name in DOMAINS:
        assets.append(asset(
            f"art.domain.{domain_id}.key",
            "domain_key_art",
            f"assets/art/domains/{domain_id}/key.webp",
            label=domain_name,
            domain=domain_id,
            dimensions="1536x1024",
        ))
        for idx in range(1, 11):
            assets.append(asset(
                f"art.location.{domain_id}.{idx:02d}",
                "location_illustration",
                f"assets/art/domains/{domain_id}/locations/{idx:02d}.webp",
                label=f"{domain_name} — localidade {idx:02d}",
                domain=domain_id,
                dimensions="1280x768",
            ))

    for char_id, char_name, domain_id in CHARACTERS:
        assets.append(asset(
            f"art.character.{char_id}.portrait",
            "character_portrait",
            f"assets/art/characters/{char_id}/portrait.webp",
            label=char_name,
            domain=domain_id,
            dimensions="1024x1536",
        ))
        assets.append(asset(
            f"art.character.{char_id}.figure",
            "character_full_figure",
            f"assets/art/characters/{char_id}/figure.webp",
            label=char_name,
            domain=domain_id,
            dimensions="1024x1536",
        ))
        assets.append(asset(
            f"art.character.{char_id}.silhouette",
            "character_silhouette",
            f"assets/art/characters/{char_id}/silhouette.webp",
            label=char_name,
            domain=domain_id,
            dimensions="768x1024",
        ))

    for domain_id, domain_name in DOMAINS:
        for role in TACTICAL_ROLES:
            assets.append(asset(
                f"art.family.{domain_id}.{role}",
                "monster_family_master",
                f"assets/art/monsters/families/{domain_id}/{role}.webp",
                label=f"{domain_name} — {role}",
                domain=domain_id,
                dimensions="1024x1024",
                variants=3,
            ))
        for idx in range(1, 6):
            assets.append(asset(
                f"art.boss.{domain_id}.{idx:02d}",
                "boss_master",
                f"assets/art/bosses/{domain_id}/{idx:02d}.webp",
                label=f"{domain_name} — chefe {idx:02d}",
                domain=domain_id,
                dimensions="1536x1536",
                variants=3,
            ))

    for icon_id in SYSTEM_ICONS:
        assets.append(asset(
            f"icon.system.{icon_id}",
            "system_icon",
            f"assets/icons/system/{icon_id}.svg",
            label=icon_id,
            dimensions="64x64 vector",
        ))

    # Mark glyph families are vector systems, not one-off raster pictures.
    for category in ["acao", "vinculo", "conhecimento", "condicao", "mundo", "eco"]:
        for idx in range(1, 9):
            assets.append(asset(
                f"icon.mark.{category}.{idx:02d}",
                "mark_glyph",
                f"assets/icons/marks/{category}/{idx:02d}.svg",
                label=f"Marca {category} {idx:02d}",
                dimensions="96x96 vector",
            ))

    return {
        "schema_version": 1,
        "product": "Veredas da Trama",
        "counts": {
            "domain_key_art": 12,
            "location_illustration": 120,
            "character_portrait": 36,
            "character_full_figure": 36,
            "character_silhouette": 36,
            "monster_family_master": 96,
            "boss_master": 60,
            "system_icon": len(SYSTEM_ICONS),
            "mark_glyph": 48,
        },
        "assets": assets,
    }


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = build()
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(data['assets'])} asset contracts")


if __name__ == "__main__":
    main()
