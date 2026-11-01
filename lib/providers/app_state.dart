import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_snapshot.dart';
import '../models/grinding_session.dart';
import '../services/session_tracker.dart';
import '../services/ble_service.dart';
import '../services/history_service.dart';
import '../services/recipe_service.dart';

final appStateProvider = ChangeNotifierProvider<AppState>((ref) => AppState());

class AppState extends ChangeNotifier {
  final ble = DoseBleService();
  final recipes = RecipeService();
  final historyService = HistoryService();
  final sessionTracker = LiveSessionTracker();
  List<dynamic> recipeList = [];
  List<dynamic> sessions = [];
  DeviceSnapshot? snapshot;
  BleUiState bleState = const BleUiState(BlePhase.idle);
  bool demoMode = false;
  double powerThresholdW = 20;
  int idleTimeoutSeconds = 12;
  Timer? _demoTimer;
  int _demoTick = 0;
  StreamSubscription? _liveSub;
  StreamSubscription? _stateSub;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    powerThresholdW = prefs.getDouble('dosegrind.power_threshold_w') ?? 20;
    idleTimeoutSeconds = prefs.getInt('dosegrind.idle_timeout_seconds') ?? 12;
    sessionTracker.powerThresholdW = powerThresholdW;
    sessionTracker.idleTimeout = Duration(seconds: idleTimeoutSeconds);
    recipeList = await recipes.loadAll();
    sessions = await historyService.load();
    _liveSub = ble.telemetry.listen((s) {
      snapshot = s;
      final ended = sessionTracker.ingest(s, now: DateTime.now());
      if (ended) {
        final started = sessionTracker.startedAt;
        final endedAt = s.receivedAt;
        final energy = sessionTracker.energySince(s.energyWh);
        final maxPower = sessionTracker.maximumPowerW;
        final averagePower = sessionTracker.averagePowerW;
        final trend = sessionTracker.temperatureTrend;
        final originalStart = sessionTracker.finish();
        final startAt = started ?? originalStart;
        if (startAt != null) {
          final record = GrindingSession(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            startedAt: startAt,
            endedAt: endedAt,
            jar: 'Unspecified', sourceMode: 'LIVE',
            durationSeconds: endedAt.difference(startAt).inSeconds,
            energyWh: energy, averagePowerW: averagePower,
            maximumPowerW: maxPower,
            temperatureC: trend.isEmpty ? null : trend.last,
            temperatureTrendC: trend, texture: 'unrated',
          );
          historyService.save(record).then((_) => refreshHistory());
        }
      }
      notifyListeners();
    });
    _stateSub = ble.states.listen((s) { bleState = s; notifyListeners(); });
    notifyListeners();
  }
  Future<void> connect() => ble.connect();
  Future<void> disconnect() => ble.disconnect();
  Future<void> configureSessionDetection(double thresholdW, int idleSeconds) async {
    powerThresholdW = thresholdW.clamp(1, 2000).toDouble();
    idleTimeoutSeconds = idleSeconds.clamp(3, 120);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dosegrind.power_threshold_w', powerThresholdW);
    await prefs.setInt('dosegrind.idle_timeout_seconds', idleTimeoutSeconds);
    sessionTracker.powerThresholdW = powerThresholdW;
    sessionTracker.idleTimeout = Duration(seconds: idleTimeoutSeconds);
    if (bleState.isConnected) {
      await ble.sendUiCommand('set_thresholds', args: {
        'power_threshold_w': powerThresholdW,
        'idle_timeout_ms': idleTimeoutSeconds * 1000,
      });
    }
    notifyListeners();
  }
  void setDemo(bool enabled) {
    demoMode = enabled;
    _demoTimer?.cancel();
    if (enabled) {
      _demoTick = 0;
      void update() {
        _demoTick++;
        final wave = (_demoTick % 12) / 12;
        snapshot = DeviceSnapshot.demo(receivedAt: DateTime.now(), temperatureC: 28 + wave * 3.2,
          powerW: _demoTick % 20 < 14 ? 115 + wave * 38 : 4,
          energyWh: _demoTick * 0.013, voltageV: 230, currentA: 0.48 + wave * 0.1,
          mixerStatus: _demoTick % 20 < 14 ? 'RUNNING' : 'IDLE');
        notifyListeners();
      }
      update(); _demoTimer = Timer.periodic(const Duration(seconds: 1), (_) => update());
    } else { snapshot = null; }
    notifyListeners();
  }
  Future<void> refreshHistory() async { sessions = await historyService.load(); notifyListeners(); }
  @override
  void dispose() { _demoTimer?.cancel(); _liveSub?.cancel(); _stateSub?.cancel(); ble.dispose(); super.dispose(); }
}
