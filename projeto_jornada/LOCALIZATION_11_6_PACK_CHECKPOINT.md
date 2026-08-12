# Veredas da Trama — 11.6 compact localization checkpoint

## Status

11.6 remains **IN PROGRESS**. The launch-scope blocker has been removed, but this checkpoint does not yet certify the roadmap step.

## Current launch scope

- Source/fallback locale: **pt_BR**.
- Current launch locales: **pt_BR + en**.
- `es_419` is preserved as a **deferred locale** for a future language expansion and is not a launch gate in the current scope.
- This is an explicit product-scope decision, not a relaxation of English quality requirements.

## Frozen coverage contract

- Canonical stable records: **5,160**.
- Canonical translatable content units: **18,804**.
- Last fully green English content baseline: **3,074/18,804**.
- Additional family/monster names persisted after that baseline: **396**.
- Compact English delta: **15,334** units.
- Exact English coverage equation: **3,074 + 396 + 15,334 = 18,804**.
- Required UI: **119/119** in both launch locales.
- Mechanical/lore labels: **165/165** in both launch locales.

## English compact pack

`LocalizationService.gd` supports deterministic multipart compact overlays under `res://localization/content_packs/en/*.b64part`.

The canonical branch currently contains ten contiguous English parts (`part_000` through `part_009`) with a combined Base64 length of **133,572 characters**. The stale checkpoint claim that `part_005` had 59,951 bytes is no longer true: the current `part_005` is the expected **16,000 bytes**.

The parts are sorted and concatenated, Base64-decoded, gzip-decompressed and parsed as JSON. Loading remains fail-closed for malformed data and overlay collisions; canonical source records remain the rules/balance authority.

## Gate architecture after scope change

- `localization/manifest.json` is now the authoritative launch-locale list.
- `tools/build_launch_localization_packs.py` derives its non-source targets from that manifest.
- `tools/localization_pack_certification.py` certifies only current launch targets and still requires **18,804/18,804** English coverage, exactly **15,334** pack units, zero collisions, zero unknown keys and token/BBCode parity.
- `tools/localization_quality_gate.py` now merges the compact pack before glossary/token/completeness checks, so the quality gate covers the complete translated corpus rather than only the base overlay.
- `tools/localization_full_linguistic_sanity.py` derives its targets from the launch manifest.
- Godot overflow and iconography/accessibility certification now exercise **pt_BR + en**.

## Resolved blocker

`LOC-116-001` is **resolved** for the current launch contract because:

1. the English physical pack is contiguous and has the certified total Base64 length;
2. Spanish is no longer a launch locale;
3. compiler/certifier target selection is manifest-driven, preventing a deferred locale from remaining an accidental release blocker.

Spanish localization artifacts are intentionally retained for future work.

## CI condition

Recent GitHub Actions jobs continue to terminate before any step with `runner_id=0`. Until a job actually executes, no new workflow result may be called green or red on code merits.

## Remaining 11.6 gates

1. Execute compact-pack certification proving **en=18,804/18,804**, pack **15,334**, collisions/unknown/token errors = 0 on the current HEAD.
2. Execute full-corpus glossary/placeholder/BBCode QA with the compact pack merged.
3. Run localized Godot overflow/render QA for `pt_BR` and `en` across the responsive device matrix.
4. Run iconography/accessibility-label consistency QA for `pt_BR` and `en`.
5. Run final English linguistic sanity review.
6. Run localization regressions on the same clean HEAD.
7. Only then mark **11.6 ✅**.
