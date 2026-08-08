# Android export — Veredas da Trama

## Current Phase 8 policy

The Android configuration is deliberately split into two presets:

1. **Android Debug APK** — arm64 + x86_64. Used for CI, local installation and emulator/device compatibility work. It may use the standard Godot debug signing flow.
2. **Android Play AAB (Unsigned CI Template)** — arm64-only, Gradle/AAB prepared for Google Play. Final signing identity and final application ID remain Phase 12.2 concerns.

Current provisional application ID: `com.veredasdatrama.preview`.

## Secrets

Release keystore paths, aliases and passwords must never be committed. The AAB preset keeps release credential fields empty. When production signing is introduced, CI secrets/environment variables must provide them at build time.

## Export exclusions

Source-resolution art, tools, tests and documentation are excluded from Android packages. Final mobile derivatives are generated in `assets/art/mobile` by `tools/prepare_mobile_assets.py` and audited by `tools/audit_mobile_assets.py`.

## Release architecture

Play-oriented output is arm64. Debug APK also includes x86_64 so the same package can be exercised in common Android emulator environments during 8.9.

## Completion gates

- 8.7 requires both presets and security/architecture validation.
- 8.8 requires CI to physically produce an Android APK artifact.
- 8.9 requires compatibility testing across Android environments.
- 8.10 requires an installable, launchable, playable and resumable Android package; merely exporting a file is not sufficient.
