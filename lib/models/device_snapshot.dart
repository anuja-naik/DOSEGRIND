import 'dart:convert';

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.receivedAt,
    required this.mixerStatus,
    required this.sensorStatus,
    required this.dataMode,
    this.temperatureC,
    this.voltageV,
    this.currentA,
    this.powerW,
    this.energyWh,
    this.sessionEnergyWh,
    this.frequencyHz,
    this.deviceEpoch,
    this.uptimeMs,
  });

  final DateTime receivedAt;
  final double? temperatureC;
  final double? voltageV;
  final double? currentA;
  final double? powerW;
  final double? energyWh;
  final double? sessionEnergyWh;
  final double? frequencyHz;
  final String mixerStatus;
  final String sensorStatus;
  final String dataMode;
  final int? deviceEpoch;
  final int? uptimeMs;

  bool get isLive => dataMode == 'LIVE';
  bool get isDemo => dataMode == 'DEMO';

  bool isFreshAt(DateTime now, {Duration maxAge = const Duration(seconds: 3)}) =>
      now.difference(receivedAt) <= maxAge;

  static double? _number(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    return null;
  }

  factory DeviceSnapshot.fromLiveJson(List<int> bytes, {DateTime? receivedAt}) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Live notification must be a JSON object.');
    }
    final mode = (decoded['data_mode'] as String? ?? '').toUpperCase();
    if (mode != 'LIVE') {
      throw const FormatException('Live characteristic did not identify LIVE data.');
    }
    final stamp = decoded['timestamp'];
    return DeviceSnapshot(
      receivedAt: receivedAt ?? DateTime.now(),
      temperatureC: _number(decoded['temperature']),
      voltageV: _number(decoded['voltage']),
      currentA: _number(decoded['current']),
      powerW: _number(decoded['power']),
      energyWh: _number(decoded['energy_wh']),
      sessionEnergyWh: _number(decoded['session_energy_wh']),
      frequencyHz: _number(decoded['frequency']),
      mixerStatus: (decoded['mixer_status'] as String? ?? 'UNKNOWN').toUpperCase(),
      sensorStatus: (decoded['sensor_status'] as String? ?? 'UNKNOWN').toUpperCase(),
      dataMode: 'LIVE',
      deviceEpoch: stamp is num && stamp > 0 ? stamp.toInt() : null,
      uptimeMs: decoded['uptime_ms'] is num ? (decoded['uptime_ms'] as num).toInt() : null,
    );
  }

  factory DeviceSnapshot.demo({
    required DateTime receivedAt,
    required double temperatureC,
    required double powerW,
    required double energyWh,
    required double voltageV,
    required double currentA,
    required String mixerStatus,
  }) => DeviceSnapshot(
        receivedAt: receivedAt,
        temperatureC: temperatureC,
        voltageV: voltageV,
        currentA: currentA,
        powerW: powerW,
        energyWh: energyWh,
        sessionEnergyWh: energyWh,
        frequencyHz: 50,
        mixerStatus: mixerStatus,
        sensorStatus: 'DEMO',
        dataMode: 'DEMO',
      );
}

enum BlePhase { unsupported, bluetoothOff, unauthorized, idle, scanning, connecting, connected, error }

class BleUiState {
  const BleUiState(this.phase, {this.deviceName, this.message});
  final BlePhase phase;
  final String? deviceName;
  final String? message;
  bool get isConnected => phase == BlePhase.connected;
}
