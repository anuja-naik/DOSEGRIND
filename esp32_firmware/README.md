# ESP32 monitor firmware (unverified starting point)

This implementation was written from scratch because no tested firmware source existed in the workspace. It has not been compiled or tested on hardware. It is monitor-only and has no mixer motor/mains control. Review `../docs/SETUP.md` before use.

Preserved pin map: OLED SDA21/SCL22; DS18B20 DATA4; PZEM UART RX16/TX17; buttons 26/27; buzzer 25. BLE name and UUIDs are defined in `src/main.cpp` and match the Flutter app. Local temperature alert is provisional, not certified protection. PZEM V3 library versus PZEM-004T-100A V4.0 compatibility remains unverified.
