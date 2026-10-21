import 'location.dart';

/// A line of `adb devices` output.
class AdbDevice {
  const AdbDevice(this.serial, this.state);

  /// Device serial, e.g. `emulator-5554`.
  final String serial;

  /// Connection state, e.g. `device`, `offline`, `unauthorized`.
  final String state;

  /// Whether this is an Android emulator (only emulators accept `emu geo fix`).
  bool get isEmulator => serial.startsWith('emulator-');

  /// Whether the device is connected and usable.
  bool get isReady => state == 'device';

  @override
  String toString() => '$serial ($state)';
}

/// Parses the output of `adb devices`.
List<AdbDevice> parseAdbDevices(String output) {
  final devices = <AdbDevice>[];
  for (final raw in output.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('List of devices') || line.startsWith('*')) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length >= 2) devices.add(AdbDevice(parts[0], parts[1]));
  }
  return devices;
}

/// Arguments for `adb -s <serial> emu geo fix <longitude> <latitude> <altitude>`.
///
/// Note the emulator console takes **longitude first**.
List<String> geoFixArguments(String serial, SimulatedLocation location) => [
  '-s',
  serial,
  'emu',
  'geo',
  'fix',
  location.longitude.toStringAsFixed(7),
  location.latitude.toStringAsFixed(7),
  location.altitude.toStringAsFixed(1),
];
