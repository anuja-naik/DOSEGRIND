import 'package:flutter_test/flutter_test.dart';
import 'package:dosegrind_connect/models/device_snapshot.dart';
import 'package:dosegrind_connect/services/session_tracker.dart';

DeviceSnapshot snap(DateTime t, {double? power=100, String mode='LIVE'}) => DeviceSnapshot(
  receivedAt:t, temperatureC:30, voltageV:230, currentA:.4, powerW:power,
  energyWh:1, sessionEnergyWh:null, frequencyHz:50, mixerStatus:'RUNNING',
  sensorStatus:'OK', dataMode:mode,
);
void main() {
 test('BLE connection does not start a session; measured power does', () {
   final tracker=LiveSessionTracker(powerThresholdW:20);
   final t=DateTime.utc(2025);
   expect(tracker.isRunning,isFalse);
   tracker.ingest(snap(t,mode:'DEMO'),now:t);
   expect(tracker.isRunning,isFalse);
   tracker.ingest(snap(t),now:t);
   expect(tracker.isRunning,isTrue);
 });
 test('stale or sensor-error readings do not establish activity', () {
   final tracker=LiveSessionTracker(); final t=DateTime.utc(2025);
   expect(tracker.ingest(snap(t.subtract(const Duration(seconds:5))),now:t),isFalse);
   expect(tracker.isRunning,isFalse);
 });
}
