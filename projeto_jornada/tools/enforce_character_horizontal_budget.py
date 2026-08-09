#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARACTERS_PATH = ROOT / "data" / "characters.json"
ABILITIES_PATH = ROOT / "data" / "abilities.json"

# Intentionally narrow corrections derived from controlled Phase 10.2 matrices.
# Each override addresses a measured kit-level outlier; policy-comparison
# confounds and later item-economy effects are handled by their own experiments.
ABILITY_TUNING = {
    "Vigia de Maré": {
        "guard": {"power": 5, "cost": 2},
        "range": {"power": 4, "cost": 3},
    },
    "Peregrina da Sede": {
        "heal": {"power": 4, "cost": 3},
        "resource": {"power": 2, "cost": 0},
    },
    "Barqueiro do Reflexo": {
        "counter": {"power": 4, "cost": 3},
    },
    "Magistrada do Limiar": {
        "guard": {"power": 4, "cost": 2},
    },
    "Portador da Brasa": {
        "damage": {"power": 4, "cost": 1},
    },
    "Tecelã de Metal": {
        "status": {"power": 3, "cost": 2},
    },
}


def _read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def _write(path: Path, rows) -> None:
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    characters = _read(CHARACTERS_PATH)
    abilities = _read(ABILITIES_PATH)
    if len(characters) != 36 or len(abilities) != 72:
        raise SystemExit(
            f"Expected 36 characters / 72 abilities, got {len(characters)} / {len(abilities)}"
        )

    abilities_by_id = {str(row.get("id", "")): row for row in abilities}
    tuned = []
    for character in characters:
        # Horizontal metaprogression contract: unlocking another Andarilho never
        # grants a larger raw health/vigor pool. Learning curves live in posture,
        # guard and signature-resource efficiency instead.
        character["base_health"] = 16
        character["base_vigor"] = 8

        name = str(character.get("name", ""))
        overrides = ABILITY_TUNING.get(name)
        if not overrides:
            continue
        seen_mechanics = set()
        for ability_id in character.get("abilities", []):
            ability = abilities_by_id.get(str(ability_id))
            if not ability:
                raise SystemExit(f"Missing ability {ability_id} for {name}")
            mechanic = str(ability.get("mechanic", ""))
            if mechanic not in overrides:
                continue
            for key, value in overrides[mechanic].items():
                ability[key] = value
            ability["signature"] = (
                f"{mechanic}:p{ability['power']}:c{ability['cost']}:"
                f"{ability.get('status_id', '')}:{ability.get('combat_role', '')}:"
                f"{ability.get('resource', '')}"
            )
            seen_mechanics.add(mechanic)
        if seen_mechanics != set(overrides):
            raise SystemExit(
                f"Tuning map mismatch for {name}: expected {sorted(overrides)}, got {sorted(seen_mechanics)}"
            )
        tuned.append(name)

    if sorted(tuned) != sorted(ABILITY_TUNING):
        raise SystemExit(f"Expected to tune {sorted(ABILITY_TUNING)}, tuned {sorted(tuned)}")

    _write(CHARACTERS_PATH, characters)
    _write(ABILITIES_PATH, abilities)
    print("CHARACTER_HORIZONTAL_BUDGET PASS: all 36 use 16 health / 8 vigor")
    print("CHARACTER_TARGETED_TUNING PASS: %s" % ", ".join(sorted(tuned)))


if __name__ == "__main__":
    main()
