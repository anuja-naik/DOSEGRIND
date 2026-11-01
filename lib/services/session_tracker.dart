import '../models/device_snapshot.dart';

class LiveSessionTracker {
  LiveSessionTracker({this.powerThresholdW = 20, this.idleTimeout = const Duration(seconds: 12)});
  double powerThresholdW;
  Duration idleTimeout;
  DateTime? _started;
  DateTime? _lastActive;
  double _energyStartWh = 0;
  double _maxPowerW = 0;
  double _powerSum = 0;
  int _powerSamples = 0;
  final List<double> _temperatures = [];
  double get averagePowerW => _powerSamples == 0 ? 0 : _powerSum / _powerSamples;
  bool get isRunning => _started != null;
  DateTime? get startedAt => _started;
  double get maximumPowerW => _maxPowerW;
  List<double> get temperatureTrend => List.unmodifiable(_temperatures);

  // BLE state alone never starts a session. Missing / stale readings do not create one.
  bool ingest(DeviceSnapshot s, {required DateTime now}) {
    if (!s.isLive || !s.isFreshAt(now) || s.sensorStatus == 'ERROR' || s.powerW == null) return false;
    final active = s.powerW! >= powerThresholdW;
    if (active) {
      if (_started == null) { _started = s.receivedAt; _energyStartWh = s.energyWh ?? 0; _maxPowerW = s.powerW!; _temperatures.clear(); }
      _lastActive = s.receivedAt;
      _powerSum += s.powerW!; _powerSamples++;
      if (s.powerW! > _maxPowerW) _maxPowerW = s.powerW!;
      if (s.temperatureC != null) _temperatures.add(s.temperatureC!);
      return false;
    }
    if (_started != null && _lastActive != null && s.receivedAt.difference(_lastActive!) >= idleTimeout) return true;
    return false;
  }
  double energySince(double? currentEnergyWh) => currentEnergyWh == null ? 0 : (currentEnergyWh - _energyStartWh).clamp(0, double.infinity);
  DateTime? finish() { final s = _started; _reset(); return s; }
  void _reset() { _started = null; _lastActive = null; _energyStartWh = 0; _maxPowerW = 0; _powerSum = 0; _powerSamples = 0; _temperatures.clear(); }
}
