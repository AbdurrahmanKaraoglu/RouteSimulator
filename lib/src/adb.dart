import 'location.dart';

/// A line of `adb devices` output.
class AdbDevice {
  /// Creates a device entry; usually obtained from [parseAdbDevices].
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

/// Picks the emulator to send fixes to, or throws [StateError] with a message to show the user.
///
/// With [requested] (a serial), that device must be listed, be an emulator and be ready. Without it, exactly one
/// ready emulator must be running: the choice is never guessed when several are open, because other apps on them
/// would receive the mock locations too. Real devices are never chosen (`emu geo fix` only works on emulators).
AdbDevice selectEmulator(List<AdbDevice> devices, {String? requested}) {
  final listed = devices.isEmpty ? 'none' : devices.join(', ');
  if (requested != null) {
    final match = devices.where((d) => d.serial == requested).firstOrNull;
    if (match == null) throw StateError('device $requested not found (adb devices: $listed)');
    if (!match.isEmulator) throw StateError('$requested is not an emulator; "emu geo fix" needs an emulator');
    if (!match.isReady) throw StateError('$requested is ${match.state}');
    return match;
  }
  final emulators = devices.where((d) => d.isEmulator && d.isReady).toList();
  if (emulators.isEmpty) throw StateError('no running emulator found (adb devices: $listed)');
  if (emulators.length > 1) {
    throw StateError(
      'several emulators are running (${emulators.map((d) => d.serial).join(', ')}); choose one with --device',
    );
  }
  return emulators.single;
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
