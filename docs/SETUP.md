# DoseGrind Connect — setup and validation

## Important scope and verification status

This package is a companion app and monitor only. The mixer remains manually operated with its original knob/buttons, electronics and protections. The firmware has no motor, relay, mains, speed or interlock-control output. Do not connect this project to the mixer internals.

**No existing tested ESP32 source was present in the workspace.** `esp32_firmware/src/main.cpp` is a newly written, hardware-dependent starting point, not preserved tested firmware. No Flutter/Arduino toolchain, physical sensors, ESP32 or mixer was available here; compilation, BLE interoperability, electrical safety and physical testing are unverified. Do not deploy until the checks below pass.

## Product context

Target: Atomberg Zenova Mixer Grinder with listed 500 mL chutney/chopper, 1 L multipurpose, and 1.5 L liquidising jars. Product specifications cite 550 W rated motor power, 1800 W maximum input, 28,000 RPM motor speed and three speeds plus pulse. **No per-speed RPM mapping is provided or invented by this app.** App recipes use adjustable, unverified manual starting suggestions and never actuate the knob.

## Flutter app

1. Install Flutter stable (3.24+; Dart 3.5+) and Android/iOS platform toolchains.
2. From the project root, run `flutter pub get`, then `flutter analyze`, `flutter test`.
3. Create platform scaffolding if needed: `flutter create --platforms=android,ios .` (review before overwriting existing project files).
4. Android: allow BLE scan/connect runtime permissions. For Android 12+, declare `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` with `neverForLocation` for scan; for Android 11 and older, add legacy Bluetooth and location permissions with `maxSdkVersion`/runtime rationale per FlutterBluePlus documentation. Test on a physical phone; an emulator may not support BLE.
5. iOS: add `NSBluetoothAlwaysUsageDescription` to `ios/Runner/Info.plist` (e.g. “Connect to your DoseGrind monitoring accessory.”). Check the plugin's current iOS minimum deployment requirement before build.
6. Select Overview → connect to `DOSEGRIND_ESP32`; app scans, discovers exact service UUID, then subscribes to the live characteristic notification stream. Keep the app foregrounded for monitoring. No promise of uninterrupted background monitoring.
7. DEMO toggle is visibly separated and disabled while connected. Demo telemetry is locally generated, labeled and never written to LIVE history or passed through the LIVE parser.

BLE UUIDs (must match firmware and app):

| GATT item | UUID |
|---|---|
| Service | `12345678-1234-1234-1234-123456789000` |
| Live telemetry | `12345678-1234-1234-1234-123456789001` |
| Device status | `12345678-1234-1234-1234-123456789002` |
| Configuration | `12345678-1234-1234-1234-123456789003` |

Live notification is JSON UTF-8, at a nominal 1 Hz from the current firmware:

```json
{"data_mode":"LIVE","timestamp":1700000000,"uptime_ms":10000,"temperature":25.4,"voltage":230.0,"current":0.4,"power":92.0,"energy_wh":12.0,"session_energy_wh":null,"frequency":50.0,"mixer_status":"IDLE","sensor_status":"OK"}
```

Numeric sensor fields can be JSON `null` when absent/failed. Never substitute sample values. App freshness gate: 3 seconds. The phone requests a 247-byte ATT MTU where supported; iOS negotiates MTU itself. Verify notification payload size and characteristic writes on each target OS. `mixer_status` is estimated from measured power above a calibrated threshold; BLE link alone is never ON status. `energy_wh` is derived from PZEM kWh × 1000. `session_energy_wh` remains null pending validated reset/baseline semantics.

Config writes are JSON and strictly allowlisted: `set_oled_page`, `request_status`, `reset_session_energy`, `device_info`, `set_time`, `set_thresholds`. These are UI/status/config only; no motor action is permitted. App currently exposes no user control for mixer behavior.

## ESP32 firmware

1. Confirm your board, supply, PZEM model/revision, OLED I2C address, DS18B20 topology and buzzer driver. The prescribed pins are in code: OLED SDA21/SCL22; DS18B20 DATA4; PZEM UART RX2=GPIO16/TX2=GPIO17; buttons GPIO26/27; buzzer GPIO25.
2. Use appropriate logic-level protection, isolation and enclosure. PZEM mains measurement is hazardous. Follow module documentation and electrical safety practice; do not wire into the mixer or its mains/motor path.
3. Install PlatformIO, open `esp32_firmware/`, run `pio run`, then flash only a compatible ESP32 dev board. **This source has not been compiled here.** Resolve library/API or board differences with a qualified reviewer.
4. The listed `mandulaj/PZEM-004T-v30` library documents V3.0. Its compatibility with the target PZEM-004T-100A V4.0 is **unknown and must be confirmed against actual hardware** before trusting any measurements. Verify baud/protocol, ratio/calibration and valid readings on an isolated test setup.
5. Check DS18B20 readings against a reference. Sensor open/short/disconnect must produce invalid/null readings, not fabricated numbers. Verify `sensor_status` behavior.
6. Calibrate `calibratedPowerThresholdW` with safe measured idle and operating loads. Configure it above idle but below minimum expected operating draw. Confirm session-start and 12 s idle-end behavior on real logs. This is not automatic speed or recipe recognition.
7. Confirm the temperature alert threshold and local buzzer hardware. Current 70°C is a provisional software value, **not a certified limit or appliance protection**. Ensure local alert continues with BLE disconnected. Original mixer protections remain authoritative.
8. From a phone, confirm exact advertised name/UUID, notification updates, all JSON fields, null-on-failure behavior and disconnect/stale behavior. Do not interpret notifications as verified physical measurements until the sensor chain is validated.

## Troubleshooting

- Device not found: verify ESP32 power, BLE advertising/name, phone Bluetooth, permission grant and proximity.
- Connect but no values: inspect GATT UUIDs, subscription/notify flags, payload length and serial logs. Phone foreground is required for this implementation.
- Readings absent: check PZEM serial pins/cross wiring (ESP32 RX16/TX17), module protocol compatibility, common reference where applicable, DS18B20 GPIO4 and sensor status. Do not use expected or demo values as replacements.
- False sessions: recalibrate measured-power threshold and idle timeout from actual readings; BLE connectivity is not session evidence.
- Temperature alarm: treat as awareness only; inspect device and follow mixer manual. Never bypass original protection.
- Android/iOS build or BLE API mismatch: install current FlutterBluePlus release requirements and follow package platform setup; this environment could not run the builds.

## Recipe interpretation

Dataset is `assets/recipes.json` (12 example recipes). Ingredient amounts scale locally; jar size, nominal batch split and interval suggestions are heuristics, not validated appliance performance or official recipes. Confirm compatibility with the supplied mixer manual; respect its marked working fill limits. The app cannot identify selected jar, knob/speed, recipe, or food texture from PZEM data.
