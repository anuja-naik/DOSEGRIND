# DoseGrind Connect

Cross-platform Flutter companion concept for Atomberg Zenova Mixer Grinder: recipe suggestions, manual grinding guides, optional ESP32 BLE telemetry, DEMO/LIVE segregation and local session history.

## Safety boundary

The app does not control the mixer. Operate its original controls manually; never modify original motor electronics, jar detection, safety interlocks or internal wiring. BLE commands are UI/config/status only. Readings, temperature thresholds, recipe amounts and time/knob suggestions are not certified or universal. Keep the app foregrounded for live monitoring.

## Project structure

- `lib/`: modular models, BLE protocol/service, local session history, recipe logic and Flutter screens.
- `assets/recipes.json`: 12 illustrative adjustable recipe suggestions.
- `esp32_firmware/`: new hardware-dependent ESP32 implementation; not a preserved or tested firmware.
- `docs/SETUP.md`: platform setup, exact BLE schema, calibration, safety and troubleshooting.

## Start

Install Flutter 3.24+/Dart 3.5+, create Android/iOS platform scaffolding if absent, then `flutter pub get`, `flutter analyze`, `flutter test`. See `docs/SETUP.md` before connecting hardware.

## Verification disclaimer

No existing firmware, Flutter/Arduino build toolchains or physical devices were available when authored. Neither app nor firmware is claimed compiled, physically tested, electrically validated or fit for manufacturing. PZEM-004T-100A V4.0 compatibility with the referenced PZEM V3.0 library must be independently checked.
