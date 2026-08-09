#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

MECHANICS = [
    "distance_pressure",
    "status_combo",
    "posture_break",
    "defense_cycle",
    "multi_attack",
    "telegraphed_range",
    "resource_drain",
    "intent_trick",
]

ROLE_BUDGET = {
    "predator": (1, 0),
    "controller": (-1, 1),
    "skirmisher": (-2, 0),
    "tank": (5, 3),
    "swarm": (-3, -1),
    "artillery": (-1, 0),
    "attrition": (2, 2),
    "trickster": (0, 1),
}

ELITE_AFFIXES = [
    {"id":"thorned","damage_bonus":1},
    {"id":"plated","starting_guard":2,"posture_bonus":2},
    {"id":"siphoning","vigor_damage":1},
    {"id":"venomous","status":"poison"},
    {"id":"scorching","status":"burning"},
    {"id":"dreadful","status":"fear"},
    {"id":"rootbound","status":"rooted"},
    {"id":"shocking","status":"shock"},
    {"id":"wetborn","status":"wet"},
    {"id":"swift","pressure_bonus":1},
    {"id":"relentless","heavy_bonus":2},
    {"id":"resonant","posture_damage":2},
]

DOMAIN_STATUS = {
    "mata_fio_verde":"rooted",
    "varzea_espelhos":"wet",
    "costa_sinos_afogados":"fear",
    "chapada_sol_oco":"burning",
    "salinas_ossamar":"poison",
    "vertice":"shock",
    "forja_rubra":"burning",
    "mar_cinza":"fear",
    "noite_iscara":"frozen",
    "cidade_mil_portas":"marked",
    "arquivo_ecos":"fear",
    "tear_desfeito":"shock",
}


def read(name: str):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def write(name: str, rows) -> None:
    (DATA / f"{name}.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def clamp(value: int, low: int, high: int) -> int:
    return max(low, min(high, value))


def distinct_phase_mechanics(candidates: list[str]) -> list[str]:
    """Keep the generated identity while guaranteeing three behavioral phases."""
    chosen: list[str] = []
    for candidate in candidates:
        index = MECHANICS.index(candidate)
        for offset in range(len(MECHANICS)):
            mechanic = MECHANICS[(index + offset) % len(MECHANICS)]
            if mechanic not in chosen:
                chosen.append(mechanic)
                break
    return chosen


def main() -> None:
    worlds = read("worlds")
    families = read("families")
    monsters = read("monsters")
    bosses = read("bosses")
    if len(worlds) != 12 or len(families) != 96 or len(monsters) != 300 or len(bosses) != 60:
        raise SystemExit(
            f"Unexpected enemy catalog sizes worlds={len(worlds)} families={len(families)} monsters={len(monsters)} bosses={len(bosses)}"
        )

    world_order = {row["id"]: index for index, row in enumerate(worlds)}
    family_role = {row["id"]: row.get("role", "predator") for row in families}
    local_monster_index: defaultdict[str, int] = defaultdict(int)
    elite_counts: Counter[str] = Counter()
    affix_counts: Counter[str] = Counter()

    for monster in monsters:
        world_id = str(monster.get("world_id", ""))
        domain_id = world_id.removeprefix("world.")
        wi = world_order.get(world_id, 0)
        local_index = local_monster_index[world_id]
        local_monster_index[world_id] += 1
        tier = local_index // 5
        role = str(family_role.get(monster.get("family_id", ""), "predator"))
        hp_adjust, posture_adjust = ROLE_BUDGET.get(role, (0, 0))
        elite = local_index % 5 == 4

        base_hp = 11 + tier * 2 + hp_adjust
        base_posture = 7 + tier + posture_adjust
        monster["encounter_tier"] = tier + 1
        monster["rank"] = "elite" if elite else "normal"
        # Elites retain a clear encounter premium, but one point less raw HP
        # prevents rare guard/recovery cycles from crossing the 80-round gate.
        monster["hp"] = clamp(base_hp + (4 + tier if elite else 0), 8, 30)
        monster["posture"] = clamp(base_posture + (3 if elite else 0), 5, 18)
        monster["mechanic"] = MECHANICS[local_index % len(MECHANICS)]
        monster["domain_status"] = DOMAIN_STATUS.get(domain_id, "fear")
        monster["starting_guard"] = 0
        monster["damage_bonus"] = 0
        monster["threat_rating"] = round(
            monster["hp"] * 0.08 + monster["posture"] * 0.07 + tier * 0.35 + (1.1 if elite else 0.0),
            3,
        )

        if elite:
            elite_slot = local_index // 5
            affix = dict(ELITE_AFFIXES[(wi * 5 + elite_slot) % len(ELITE_AFFIXES)])
            monster["elite_affix"] = affix["id"]
            monster["elite_affix_data"] = affix
            monster["starting_guard"] = int(affix.get("starting_guard", 0))
            monster["posture"] = clamp(monster["posture"] + int(affix.get("posture_bonus", 0)), 5, 20)
            monster["damage_bonus"] = int(affix.get("damage_bonus", 0))
            elite_counts[world_id] += 1
            affix_counts[affix["id"]] += 1
        else:
            monster["elite_affix"] = ""
            monster["elite_affix_data"] = {}

    local_boss_index: defaultdict[str, int] = defaultdict(int)
    boss_signatures: Counter[str] = Counter()
    for boss in bosses:
        world_id = str(boss.get("world_id", ""))
        domain_id = world_id.removeprefix("world.")
        wi = world_order.get(world_id, 0)
        bi = local_boss_index[world_id]
        local_boss_index[world_id] += 1
        tier = bi + 1
        boss["boss_tier"] = tier
        boss["rank"] = "subboss" if tier <= 3 else "boss"
        boss["hp"] = 28 + tier * 2
        boss["posture"] = 14 + tier
        boss["starting_guard"] = 1 if tier >= 4 else 0
        boss["domain_status"] = DOMAIN_STATUS.get(domain_id, "fear")
        boss["mechanic"] = MECHANICS[(wi + bi * 2) % len(MECHANICS)]
        boss["damage_bonus"] = 0
        phase_mechanics = distinct_phase_mechanics([
            MECHANICS[(wi + bi) % 8],
            MECHANICS[(wi * 3 + bi * 2 + 1) % 8],
            MECHANICS[(wi * 5 + bi * 3 + 2) % 8],
        ])
        phases = [
            {
                "threshold":1.0,
                "name":"Leitura",
                "mechanic":phase_mechanics[0],
                "damage_bonus":0,
                "guard_bonus":0,
                "status":boss["domain_status"],
            },
            {
                "threshold":0.60,
                "name":"Ruptura",
                "mechanic":phase_mechanics[1],
                "damage_bonus":0,
                "guard_bonus":1 if tier >= 2 else 0,
                "status":boss["domain_status"],
            },
            {
                "threshold":0.25,
                "name":"Consequência",
                "mechanic":phase_mechanics[2],
                "damage_bonus":1,
                "guard_bonus":1,
                "status":boss["domain_status"],
            },
        ]
        boss["phases"] = phases
        phase_signature = ">".join(phase_mechanics)
        boss["combat_signature"] = f"t{tier}:{phase_signature}:{boss['domain_status']}"
        boss["threat_rating"] = round(
            boss["hp"] * 0.08 + boss["posture"] * 0.08 + tier * 0.65,
            3,
        )
        boss_signatures[boss["combat_signature"]] += 1

    for world_id in world_order:
        if local_monster_index[world_id] != 25:
            raise SystemExit(f"{world_id} has {local_monster_index[world_id]} monsters instead of 25")
        if elite_counts[world_id] != 5:
            raise SystemExit(f"{world_id} has {elite_counts[world_id]} elites instead of 5")
        if local_boss_index[world_id] != 5:
            raise SystemExit(f"{world_id} has {local_boss_index[world_id]} bosses/subbosses instead of 5")
    if len(affix_counts) != 12 or min(affix_counts.values()) < 4:
        raise SystemExit(f"Elite affix coverage invalid: {dict(sorted(affix_counts.items()))}")
    if len(boss_signatures) < 48:
        raise SystemExit(f"Boss combat signatures insufficiently diverse: {len(boss_signatures)}")

    write("monsters", monsters)
    write("bosses", bosses)
    print("ENEMY_BALANCE_REFINEMENT PASS: 240 normal + 60 elite monsters; 12 functional elite affixes; 60 phased bosses/subbosses")
    print(f"ENEMY_BALANCE boss_signatures={len(boss_signatures)} affixes={dict(sorted(affix_counts.items()))}")


if __name__ == "__main__":
    main()
