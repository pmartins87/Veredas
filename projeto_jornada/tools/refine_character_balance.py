#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

# Each Domain deliberately contains one approachable, one intermediate and one
# expert learning curve. Mechanics are curated from the fantasy of the named
# Andarilho rather than inherited from generator position.
KIT = {
    "Rastreador de Nós": ("posture", "range", "balanced", "intermediate", "tracker", "rooted"),
    "Guardião de Casca": ("guard", "counter", "cautious", "approachable", "bulwark", "rooted"),
    "Cantora de Cipós": ("status", "resource", "balanced", "expert", "controller", "rooted"),
    "Barqueiro do Reflexo": ("move", "counter", "balanced", "approachable", "skirmisher", "wet"),
    "Pescadora de Presságios": ("range", "echo", "explorer", "expert", "seer", "fear"),
    "Afogado Retornado": ("heal", "debt", "cautious", "intermediate", "survivor", "wet"),
    "Sineiro Náufrago": ("posture", "echo", "balanced", "intermediate", "resonator", "fear"),
    "Corsária de Coral": ("damage", "mark", "aggressive", "approachable", "raider", "bleeding"),
    "Vigia de Maré": ("guard", "range", "cautious", "expert", "sentinel", "wet"),
    "Lanceiro Solar": ("damage", "range", "aggressive", "approachable", "duelist", "burning"),
    "Caminhante de Sombra": ("counter", "move", "balanced", "intermediate", "skirmisher", "fear"),
    "Oráculo do Meio-Dia": ("mark", "echo", "balanced", "expert", "seer", "burning"),
    "Catador de Ossos": ("guard", "posture", "cautious", "approachable", "bulwark", "bleeding"),
    "Peregrina da Sede": ("heal", "resource", "cautious", "intermediate", "survivor", "poison"),
    "Paleocaçador": ("range", "status", "aggressive", "expert", "hunter", "bleeding"),
    "Duelista do Abismo": ("counter", "damage", "aggressive", "approachable", "duelist", "fear"),
    "Engenheira de Pontes": ("guard", "resource", "balanced", "intermediate", "bulwark", "shock"),
    "Monge do Vento": ("move", "posture", "explorer", "expert", "skirmisher", "rooted"),
    "Ferreiro de Guerra": ("damage", "guard", "aggressive", "approachable", "bruiser", "burning"),
    "Desertor da Forja": ("counter", "resource", "balanced", "intermediate", "reactor", "burning"),
    "Tecelã de Metal": ("status", "mark", "balanced", "expert", "controller", "shock"),
    "Penitente Cinzento": ("guard", "debt", "cautious", "approachable", "survivor", "fear"),
    "Necrógrafa": ("status", "echo", "explorer", "intermediate", "controller", "poison"),
    "Sem-Nome": ("move", "mark", "balanced", "expert", "skirmisher", "fear"),
    "Caçadora de Aurora": ("range", "status", "aggressive", "approachable", "hunter", "shock"),
    "Portador da Brasa": ("damage", "resource", "aggressive", "intermediate", "bruiser", "burning"),
    "Sonhador de Gelo": ("echo", "status", "balanced", "expert", "seer", "frozen"),
    "Chaveiro": ("range", "move", "balanced", "approachable", "skirmisher", "rooted"),
    "Contrabandista de Portas": ("move", "debt", "balanced", "intermediate", "raider", "fear"),
    "Magistrada do Limiar": ("mark", "guard", "cautious", "expert", "sentinel", "rooted"),
    "Arquivista": ("mark", "resource", "balanced", "intermediate", "scholar", "fear"),
    "Repetente": ("echo", "counter", "balanced", "expert", "reactor", "fear"),
    "Curadora de Ecos": ("heal", "echo", "cautious", "approachable", "survivor", "fear"),
    "Tecelão Fraturado": ("resource", "status", "explorer", "expert", "weaver", "shock"),
    "Herdeira do Nó": ("guard", "mark", "balanced", "intermediate", "sentinel", "rooted"),
    "Inacabado": ("damage", "debt", "aggressive", "approachable", "bruiser", "bleeding"),
}

TIER = {
    "approachable": {
        "complexity": 2,
        "health": 18,
        "vigor": 9,
        "posture": 11,
        "guard": 1,
        "resource_max": 5,
        "resource_start": 1,
        "power_bonus": 0,
        "second_cost": 3,
        "forgiveness": 0.82,
        "ceiling": 0.64,
    },
    "intermediate": {
        "complexity": 3,
        "health": 16,
        "vigor": 9,
        "posture": 10,
        "guard": 0,
        "resource_max": 6,
        "resource_start": 1,
        "power_bonus": 1,
        "second_cost": 3,
        "forgiveness": 0.62,
        "ceiling": 0.76,
    },
    "expert": {
        "complexity": 5,
        "health": 15,
        "vigor": 8,
        "posture": 9,
        "guard": 0,
        "resource_max": 7,
        "resource_start": 0,
        "power_bonus": 2,
        "second_cost": 2,
        "forgiveness": 0.42,
        "ceiling": 0.90,
    },
}

ROLE_ADJUST = {
    "bulwark": (1, -1, 1, 1),
    "sentinel": (0, 0, 1, 1),
    "survivor": (1, 0, 0, 0),
    "bruiser": (0, 0, 1, 0),
    "duelist": (-1, 1, 0, 0),
    "hunter": (-1, 1, 0, 0),
    "tracker": (0, 1, 0, 0),
    "skirmisher": (-1, 1, -1, 0),
    "raider": (-1, 1, 0, 0),
    "controller": (-1, 1, 0, 0),
    "seer": (-1, 1, -1, 0),
    "resonator": (0, 0, 0, 0),
    "reactor": (0, 0, 1, 0),
    "scholar": (-1, 1, 0, 0),
    "weaver": (-1, 1, -1, 0),
}

BASE_POWER = {
    "damage": 4,
    "posture": 5,
    "guard": 5,
    "heal": 5,
    "move": 2,
    "status": 1,
    "counter": 3,
    "resource": 3,
    "echo": 2,
    "mark": 1,
    "debt": 5,
    "range": 4,
}


def read(name: str):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def write(name: str, rows) -> None:
    (DATA / f"{name}.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def ability_power(mechanic: str, tier: str) -> int:
    bonus = int(TIER[tier]["power_bonus"])
    if mechanic in {"status", "mark"}:
        return int(BASE_POWER[mechanic]) + (1 if tier == "expert" else 0)
    if mechanic == "move":
        return int(BASE_POWER[mechanic]) + (1 if tier == "expert" else 0)
    return int(BASE_POWER[mechanic]) + bonus


def main() -> None:
    characters = read("characters")
    abilities = read("abilities")
    if len(characters) != 36 or len(abilities) != 72:
        raise SystemExit(
            f"Expected 36 characters / 72 abilities, got {len(characters)} / {len(abilities)}"
        )

    by_ability = {row["id"]: row for row in abilities}
    seen_names = {row.get("name", "") for row in characters}
    missing = sorted(set(KIT) - seen_names)
    unknown = sorted(seen_names - set(KIT))
    if missing or unknown:
        raise SystemExit(f"Character balance map mismatch; missing={missing} unknown={unknown}")

    domain_tiers: dict[str, set[str]] = {}
    signatures: set[str] = set()

    for character in characters:
        name = character["name"]
        mech_a, mech_b, recommended, tier, role, status_id = KIT[name]
        profile = TIER[tier]
        dh, dv, dp, dg = ROLE_ADJUST.get(role, (0, 0, 0, 0))

        character["combat_role"] = role
        character["base_health"] = int(profile["health"]) + dh
        character["base_vigor"] = int(profile["vigor"]) + dv
        character["base_posture"] = int(profile["posture"]) + dp
        character["base_guard"] = max(0, int(profile["guard"]) + dg)
        character["resource_max"] = int(profile["resource_max"])
        character["resource_start"] = int(profile["resource_start"])
        character["resource_gain_per_action"] = 1
        character["learning_curve"] = {
            "tier": tier,
            "complexity": int(profile["complexity"]),
            "forgiveness": float(profile["forgiveness"]),
            "ceiling": float(profile["ceiling"]),
            "recommended_policy": recommended,
            "teaching_note": {
                "approachable": "Funciona mesmo com decisões imperfeitas; ensina leitura de intenção antes de exigir combo.",
                "intermediate": "Pede alternância entre ação básica e recurso de assinatura para manter eficiência.",
                "expert": "Troca margem de erro por ferramentas mais eficientes; repetir a mesma resposta reduz o teto real do kit.",
            }[tier],
        }
        character["balance_signature"] = f"{role}:{mech_a}+{mech_b}:{tier}:{character['resource']}"
        signatures.add(character["balance_signature"])
        domain_tiers.setdefault(character["world_id"], set()).add(tier)

        ability_ids = list(character.get("abilities", []))
        if len(ability_ids) != 2:
            raise SystemExit(f"{name} does not have exactly two signature abilities")
        for index, (ability_id, mechanic) in enumerate(zip(ability_ids, (mech_a, mech_b))):
            ability = by_ability[ability_id]
            ability["mechanic"] = mechanic
            ability["power"] = ability_power(mechanic, tier)
            ability["cost"] = 0 if mechanic == "resource" else (2 if index == 0 else int(profile["second_cost"]))
            ability["status_id"] = status_id
            ability["duration"] = 2 + (1 if tier == "expert" else 0)
            ability["learning_tier"] = tier
            ability["combat_role"] = role
            ability["signature"] = (
                f"{mechanic}:p{ability['power']}:c{ability['cost']}:"
                f"{status_id}:{role}:{character['resource']}"
            )

    if len(signatures) != 36:
        raise SystemExit(f"Expected 36 distinct balance signatures, got {len(signatures)}")
    for world_id, tiers in sorted(domain_tiers.items()):
        if tiers != {"approachable", "intermediate", "expert"}:
            raise SystemExit(f"{world_id} learning tiers are incomplete: {sorted(tiers)}")

    write("characters", characters)
    write("abilities", abilities)
    print("CHARACTER_BALANCE_REFINEMENT PASS: 36 curated kits; one learning tier of each kind per Domain")


if __name__ == "__main__":
    main()
