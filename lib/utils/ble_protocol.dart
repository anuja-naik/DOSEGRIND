class BleProtocol {
  static const deviceName = 'DOSEGRIND_ESP32';
  static const service = '12345678-1234-1234-1234-123456789000';
  static const liveData = '12345678-1234-1234-1234-123456789001';
  static const deviceStatus = '12345678-1234-1234-1234-123456789002';
  static const configuration = '12345678-1234-1234-1234-123456789003';
  static const staleAfter = Duration(seconds: 3);

  // Deliberately excludes every motor/speed/power-control command.
  static const allowedCommands = <String>{
    'set_oled_page',
    'request_status',
    'reset_session_energy',
    'device_info',
    'set_time',
    'set_thresholds',
  };
}
