import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_snapshot.dart';
import '../utils/ble_protocol.dart';

T? _firstOrNull<T>(Iterable<T> values) => values.isEmpty ? null : values.first;

class DoseBleService {
  final _state = StreamController<BleUiState>.broadcast();
  final _telemetry = StreamController<DeviceSnapshot>.broadcast();
  Stream<BleUiState> get states => _state.stream;
  Stream<DeviceSnapshot> get telemetry => _telemetry.stream;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _config;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  bool _disposed = false;
  BleUiState current = const BleUiState(BlePhase.idle);

  void _emit(BleUiState s) { current = s; if (!_disposed) _state.add(s); }

  Future<void> connect() async {
    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) { _emit(const BleUiState(BlePhase.unsupported, message: 'Bluetooth LE is not supported on this phone.')); return; }
      final bt = await FlutterBluePlus.adapterState.first;
      if (bt != BluetoothAdapterState.on) { _emit(BleUiState(BlePhase.bluetoothOff, message: 'Turn on Bluetooth to connect.')); return; }
      if (await Permission.bluetoothScan.request().isDenied || await Permission.bluetoothConnect.request().isDenied) {
        _emit(const BleUiState(BlePhase.unauthorized, message: 'Bluetooth permission is required.')); return;
      }
      _emit(const BleUiState(BlePhase.scanning, message: 'Looking for DOSEGRIND_ESP32…'));
      final found = Completer<BluetoothDevice>();
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName == BleProtocol.deviceName && !found.isCompleted) found.complete(r.device);
        }
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12), withNames: [BleProtocol.deviceName]);
      BluetoothDevice device;
      try { device = await found.future.timeout(const Duration(seconds: 13)); }
      on TimeoutException { await FlutterBluePlus.stopScan(); _emit(const BleUiState(BlePhase.idle, message: 'No DoseGrind device found. Check power and try again.')); return; }
      await FlutterBluePlus.stopScan();
      _emit(const BleUiState(BlePhase.connecting, message: 'Connecting…'));
      _device = device;
      await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 12));
      try { await device.requestMtu(247); } catch (_) { /* iOS negotiates MTU itself; verify payload size on each target. */ }
      _connectionSub = device.connectionState.listen((s) { if (s == BluetoothConnectionState.disconnected) { _config = null; _emit(const BleUiState(BlePhase.idle, message: 'Device disconnected. Live values are now stale.')); } });
      final services = await device.discoverServices();
      final service = _firstOrNull(services.where((s) => s.uuid.str.toLowerCase() == BleProtocol.service));
      if (service == null) throw StateError('DoseGrind BLE service not found.');
      final live = _firstOrNull(service.characteristics.where((c) => c.uuid.str.toLowerCase() == BleProtocol.liveData));
      _config = _firstOrNull(service.characteristics.where((c) => c.uuid.str.toLowerCase() == BleProtocol.configuration));
      if (live == null) throw StateError('Live data characteristic not found.');
      await live.setNotifyValue(true);
      await _notifySub?.cancel();
      _notifySub = live.onValueReceived.listen((bytes) {
        try { _telemetry.add(DeviceSnapshot.fromLiveJson(bytes)); }
        on FormatException { /* malformed/non-LIVE notifications are rejected */ }
      });
      _emit(BleUiState(BlePhase.connected, deviceName: device.platformName));
    } catch (e) {
      _emit(BleUiState(BlePhase.error, message: 'Connection failed: $e'));
      await disconnect();
    }
  }

  Future<void> sendUiCommand(String command, {Map<String, Object?> args = const {}}) async {
    if (!BleProtocol.allowedCommands.contains(command)) throw ArgumentError('Command is not allowed for this companion app.');
    final characteristic = _config;
    if (characteristic == null || !current.isConnected) throw StateError('Connect to DoseGrind first.');
    final payload = <String, Object?>{'command': command, ...args};
    await characteristic.write(utf8.encode(jsonEncode(payload)), withoutResponse: false);
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel(); _notifySub = null;
    await _connectionSub?.cancel(); _connectionSub = null;
    final d = _device; _device = null; _config = null;
    if (d != null) { try { await d.disconnect(); } catch (_) {} }
    _emit(const BleUiState(BlePhase.idle));
  }

  Future<void> dispose() async {
    _disposed = true; await disconnect(); await _scanSub?.cancel();
    await _state.close(); await _telemetry.close();
  }
}
