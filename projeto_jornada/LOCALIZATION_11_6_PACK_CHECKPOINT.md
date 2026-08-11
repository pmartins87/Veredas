# Veredas da Trama — 11.6 compact localization checkpoint

## Status

11.6 remains **IN PROGRESS**. This checkpoint does not certify the roadmap step.

## Frozen coverage contract

- Canonical stable records: **5,160**.
- Canonical translatable content units: **18,804**.
- Last fully green content baseline: **3,074/18,804** per target.
- Additional family/monster names persisted after that baseline: **396** per target.
- Remaining translation delta compiled and locally validated: **15,334** per target.
- Exact coverage equation: **3,074 + 396 + 15,334 = 18,804**.
- Required UI: **119/119** per launch locale.
- Mechanical/lore labels: **165/165** per launch locale.

## Compact pack architecture

`LocalizationService.gd` supports deterministic multipart compact overlays under:

- `res://localization/content_packs/en/*.b64part`
- `res://localization/content_packs/es_419/*.b64part`

Parts are sorted and concatenated, Base64-decoded, gzip-decompressed and parsed as JSON. Loading is fail-closed for malformed data and overlay collisions; canonical source records remain the rules/balance authority.

## Physical persistence at this checkpoint

### English

The complete locally validated English delta has been split into ten contiguous repository parts (`part_000` through `part_009`) with an expected combined Base64 length of **133,572 characters**. Individual writes were persisted on `projeto-jornada-snapshots`; a missing `part_005` discovered during the remote directory check was explicitly restored before this checkpoint.

### Spanish (Latin America)

The complete locally validated Spanish delta exists as a reproducible compiler output with **15,334 units**, reference Base64 length **139,648 characters** and nine 16k-or-smaller parts. It is **not recorded here as physically persisted in GitHub yet**. Do not infer remote completeness from the local build.

## Reproducibility and certification

Permanent source now includes:

- `tools/build_launch_localization_packs.py` — rebuilds both target deltas from deterministic editorial translators while restoring protected base catalogs before exit;
- `tools/localization_pack_certification.py` — requires 18,804/18,804 content coverage per target, exactly 15,334 pack units, zero base/pack collisions, zero unknown keys and token/BBCode parity;
- `.github/workflows/veredas-localization-pack.yml` — read-only pack certification + Godot architecture regression;
- `.github/workflows/veredas-116-pack-build.yml` — reproducible write pipeline that rebuilds, certifies, proves reproducibility and persists only compact packs;
- `localization/content_packs/manifest.json` — frozen coverage/packing contract.

The compiler also injects the recovered editorial material mapping `musgo luminoso` -> `Luminous Moss` / `Musgo Luminoso` in memory for compatibility with the recovered narrative translator revision; translator source and canonical content are not mutated by this compatibility bridge.

## CI condition

Recent GitHub Actions jobs across unrelated workflows have terminated before any step with no runner assigned. Until a job actually executes, no new workflow in this checkpoint may be called green or red on code merits.

## Remaining 11.6 gates

1. Persist/certify the complete Spanish compact pack in the branch.
2. Obtain an executed pack certification proving **18,804/18,804** in `en` and `es_419` on the same HEAD.
3. Run glossary/placeholder/BBCode QA over the complete translated corpus.
4. Run localized Godot overflow/render QA across the responsive device matrix.
5. Run iconography/accessibility-label consistency QA.
6. Run linguistic review and regressions on the same clean HEAD.
7. Only then mark **11.6 ✅**.
