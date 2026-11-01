import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dosegrind_connect/models/device_snapshot.dart';

void main() {
  test('accepts LIVE telemetry and parses numeric fields', () {
    final s = DeviceSnapshot.fromLiveJson(utf8.encode(jsonEncode({
      'data_mode':'LIVE','timestamp':1700000000,'uptime_ms':8000,
      'temperature':31.2,'voltage':230,'current':0.5,'power':110,
      'energy_wh':4.2,'session_energy_wh':null,'frequency':50,
      'mixer_status':'RUNNING','sensor_status':'OK',
    })), receivedAt: DateTime.utc(2025));
    expect(s.isLive, isTrue); expect(s.temperatureC, 31.2); expect(s.powerW, 110);
    expect(s.energyWh, 4.2); expect(s.sessionEnergyWh, isNull);
  });
  test('rejects DEMO payload on LIVE parser', () {
    expect(() => DeviceSnapshot.fromLiveJson(utf8.encode('{"data_mode":"DEMO"}')), throwsFormatException);
  });
  test('rejects malformed JSON', () {
    expect(() => DeviceSnapshot.fromLiveJson(utf8.encode('not-json')), throwsFormatException);
  });
  test('non-finite and string measurements are ignored', () {
    final s = DeviceSnapshot.fromLiveJson(utf8.encode('{"data_mode":"LIVE","power":"123","temperature":null}'));
    expect(s.powerW, isNull); expect(s.temperatureC, isNull);
  });
}
