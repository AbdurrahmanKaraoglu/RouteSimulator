// Plays a simulated route on an Android emulator with `adb emu geo fix`.
//
//   dart run route_simulator:emulator --polyline "<encoded>" --speed 50
//   dart run route_simulator:emulator --demo --realistic --rate 5 --device emulator-5554
//
// Run with --help for all options.
import 'dart:async';
import 'dart:io';

import 'package:route_simulator/adb.dart';
import 'package:route_simulator/route_simulator.dart';

const _usage = '''
Plays a simulated route on an Android emulator with "adb emu geo fix".

Route (one of):
  --polyline <encoded>     Google encoded polyline (use --precision 6 for polyline6)
  --points "lat,lng;..."   Points separated by ";" (optionally lat,lng,alt)
  --file <path>            .gpx file (trkpt/rtept), a text file with an encoded polyline,
                           or one "lat,lng[,alt]" per line
  --demo                   Built-in demo route in Istanbul (Kadıköy)

Motion:
  --speed <km/h>           Cruise speed (default 50)
  --realistic              Accelerate, slow down for turns and stops
  --stop <index>:<sec>     Wait at route point <index> (repeatable)
  --loop                   Start over at the end (stop with Ctrl+C)
  --interval <sec>         Simulated seconds between fixes (default 1)
  --rate <x>               Playback speed, 1 = real time (default 1)
  --noise <m>              GPS noise standard deviation in metres (default 0)
  --seed <n>               Noise seed (default 0)

Device:
  -s, --device <serial>    Emulator serial; required when several are running
  --adb <path>             adb executable (default: ANDROID_HOME/platform-tools or PATH)
  -y, --yes                Do not ask for confirmation
  --dry-run                Print the adb commands instead of running them
  -h, --help               Show this help
''';

Future<void> main(List<String> args) async {
  try {
    exitCode = await _run(args);
  } on _UsageException catch (e) {
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln('Run with --help for usage.');
    exitCode = 64;
  }
}

class _UsageException implements Exception {
  _UsageException(this.message);
  final String message;
}

Future<int> _run(List<String> args) async {
  final o = _Options.parse(args);
  if (o.help) {
    stdout.write(_usage);
    return 0;
  }

  final route = _loadRoute(o);
  final simulator = RouteSimulator(
    route: route,
    profile: o.realistic
        ? SpeedProfile.realistic(cruiseSpeed: o.speedKmh / 3.6)
        : SpeedProfile.constant(o.speedKmh / 3.6),
    stops: [for (final s in o.stops) RouteStop.atPoint(s.$1, Duration(milliseconds: (s.$2 * 1000).round()))],
    loop: o.loop,
    noise: o.noise > 0 ? GpsNoise(horizontalError: o.noise, seed: o.seed) : GpsNoise.none,
    interval: Duration(milliseconds: (o.interval * 1000).round()),
    playbackRate: o.rate,
  );

  final adb = o.adb ?? _findAdb();
  String serial;
  if (o.dryRun && o.device == null) {
    serial = 'emulator-XXXX';
  } else {
    serial = await _selectDevice(adb, o.device);
  }

  final lap = simulator.lapDuration;
  stdout
    ..writeln(
      'Route:   ${route.points.length} points, ${(route.length / 1000).toStringAsFixed(2)} km, '
      'one lap ${_format(lap)} simulated${o.loop ? ' (looping)' : ''}',
    )
    ..writeln(
      'Playback: every ${o.interval}s simulated at ${o.rate}x '
      '(≈ ${_format(Duration(microseconds: (lap.inMicroseconds / o.rate).round()))} real time per lap)',
    );

  if (o.dryRun) {
    stdout.writeln('Target device: $serial (dry run — nothing is sent)');
    for (final l in simulator.generate(until: o.loop ? lap : null)) {
      stdout.writeln('$adb ${geoFixArguments(serial, l).join(' ')}');
    }
    return 0;
  }

  final avd = await _avdName(adb, serial);
  stdout.writeln('Target device: $serial${avd == null ? '' : ' (AVD: $avd)'}');
  stdout.writeln('Other apps on this emulator will also receive these mock locations.');
  if (!o.yes) {
    if (!stdin.hasTerminal) {
      stderr.writeln('Not an interactive terminal; pass --yes to confirm sending to $serial.');
      return 1;
    }
    stdout.write('Send locations to $serial? [y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    if (answer != 'y' && answer != 'yes') {
      stdout.writeln('Cancelled.');
      return 1;
    }
  }

  final done = Completer<int>();
  var sent = 0;
  var pending = Future<void>.value();
  final sub = simulator.locations.listen((l) {
    // Serialise the adb calls so fixes arrive in order even when adb is slow.
    pending = pending.then((_) async {
      final r = await Process.run(adb, geoFixArguments(serial, l));
      if (r.exitCode != 0 || '${r.stdout}'.contains('KO')) {
        stderr.writeln('adb failed: ${r.stderr}${r.stdout}'.trim());
        if (!done.isCompleted) done.complete(1);
        return;
      }
      sent++;
      stdout.write(
        '\r${_format(l.elapsed)}  ${l.latitude.toStringAsFixed(6)}, ${l.longitude.toStringAsFixed(6)}  '
        '${(l.speed * 3.6).toStringAsFixed(0).padLeft(3)} km/h  lap ${l.lap + 1}   ',
      );
    });
  });
  final stateSub = simulator.states.listen((s) {
    if (s == SimulatorState.finished) pending.then((_) => done.isCompleted ? null : done.complete(0));
  });
  StreamSubscription<ProcessSignal>? sigint;
  try {
    sigint = ProcessSignal.sigint.watch().listen((_) => done.isCompleted ? null : done.complete(130));
  } on SignalException {
    // Signal watching is not available on every platform.
  }

  simulator.start();
  final code = await done.future;
  simulator.stop();
  await pending;
  await sub.cancel();
  await stateSub.cancel();
  await sigint?.cancel();
  await simulator.dispose();
  stdout.writeln('\nSent $sent locations to $serial.');
  return code;
}

class _Options {
  String? polyline;
  String? points;
  String? file;
  bool demo = false;
  int precision = 5;
  double speedKmh = 50;
  bool realistic = false;
  final stops = <(int, double)>[];
  bool loop = false;
  double interval = 1;
  double rate = 1;
  double noise = 0;
  int seed = 0;
  String? device;
  String? adb;
  bool yes = false;
  bool dryRun = false;
  bool help = false;

  static _Options parse(List<String> args) {
    final o = _Options();
    var i = 0;
    String value(String name) {
      if (i + 1 >= args.length) throw _UsageException('$name needs a value');
      return args[++i];
    }

    double number(String name, {bool positive = true}) {
      final raw = value(name);
      final v = double.tryParse(raw);
      if (v == null || !v.isFinite || (positive ? v <= 0 : v < 0)) {
        throw _UsageException('$name: invalid number "$raw"');
      }
      return v;
    }

    for (; i < args.length; i++) {
      final a = args[i];
      switch (a) {
        case '--polyline':
          o.polyline = value(a);
        case '--points':
          o.points = value(a);
        case '--file':
          o.file = value(a);
        case '--demo':
          o.demo = true;
        case '--precision':
          o.precision = number(a).toInt();
        case '--speed':
          o.speedKmh = number(a);
        case '--realistic':
          o.realistic = true;
        case '--stop':
          final raw = value(a);
          final parts = raw.split(':');
          final index = parts.length == 2 ? int.tryParse(parts[0]) : null;
          final secs = parts.length == 2 ? double.tryParse(parts[1]) : null;
          if (index == null || secs == null || index < 0 || secs < 0) {
            throw _UsageException('--stop expects <index>:<seconds>, got "$raw"');
          }
          o.stops.add((index, secs));
        case '--loop':
          o.loop = true;
        case '--interval':
          o.interval = number(a);
        case '--rate':
          o.rate = number(a);
        case '--noise':
          o.noise = number(a, positive: false);
        case '--seed':
          final raw = value(a);
          o.seed = int.tryParse(raw) ?? (throw _UsageException('--seed: invalid integer "$raw"'));
        case '-s' || '--device':
          o.device = value(a);
        case '--adb':
          o.adb = value(a);
        case '-y' || '--yes':
          o.yes = true;
        case '--dry-run':
          o.dryRun = true;
        case '-h' || '--help':
          o.help = true;
        default:
          throw _UsageException('unknown option "$a"');
      }
    }
    final sources = [o.polyline, o.points, o.file, if (o.demo) 'demo'].nonNulls.length;
    if (!o.help && sources != 1) throw _UsageException('give exactly one of --polyline, --points, --file, --demo');
    return o;
  }
}

SimRoute _loadRoute(_Options o) {
  try {
    if (o.demo) return SimRoute(_demoRoute);
    if (o.polyline != null) return SimRoute.fromEncodedPolyline(o.polyline!, precision: o.precision);
    if (o.points != null) return SimRoute(_parsePoints(o.points!.split(';')));
    final file = File(o.file!);
    if (!file.existsSync()) throw _UsageException('file not found: ${o.file}');
    final text = file.readAsStringSync();
    if (text.contains('<gpx')) {
      final pts = RegExp(r'<(?:trkpt|rtept)\s+([^>]*)>').allMatches(text).map((m) {
        final attrs = m.group(1)!;
        final lat = RegExp(r'lat="([^"]+)"').firstMatch(attrs)?.group(1);
        final lon = RegExp(r'lon="([^"]+)"').firstMatch(attrs)?.group(1);
        return GeoPoint(double.parse(lat!), double.parse(lon!));
      }).toList();
      return SimRoute(pts);
    }
    final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length == 1 && !lines.single.contains(',')) {
      return SimRoute.fromEncodedPolyline(lines.single, precision: o.precision);
    }
    return SimRoute(_parsePoints(lines));
  } on _UsageException {
    rethrow;
  } on FormatException catch (e) {
    throw _UsageException('invalid route: ${e.message}');
  } on ArgumentError catch (e) {
    throw _UsageException('invalid route: ${e.message}');
  } on TypeError {
    throw _UsageException('invalid route file');
  }
}

List<GeoPoint> _parsePoints(Iterable<String> items) => [
  for (final item in items.map((s) => s.trim()).where((s) => s.isNotEmpty))
    () {
      final p = item.split(',').map((s) => double.parse(s.trim())).toList();
      if (p.length < 2) throw FormatException('expected lat,lng', item);
      return GeoPoint(p[0], p[1], altitude: p.length > 2 ? p[2] : null);
    }(),
];

String _findAdb() {
  final exe = Platform.isWindows ? 'adb.exe' : 'adb';
  for (final env in ['ANDROID_HOME', 'ANDROID_SDK_ROOT']) {
    final root = Platform.environment[env];
    if (root == null || root.isEmpty) continue;
    final candidate = File('$root${Platform.pathSeparator}platform-tools${Platform.pathSeparator}$exe');
    if (candidate.existsSync()) return candidate.path;
  }
  return 'adb';
}

Future<String> _selectDevice(String adb, String? requested) async {
  final ProcessResult r;
  try {
    r = await Process.run(adb, ['devices']);
  } on ProcessException catch (e) {
    throw _UsageException('could not run adb ($adb): ${e.message}. Use --adb <path>.');
  }
  final devices = parseAdbDevices('${r.stdout}');
  final emulators = devices.where((d) => d.isEmulator && d.isReady).toList();
  if (requested != null) {
    final match = devices.where((d) => d.serial == requested).firstOrNull;
    if (match == null) throw _UsageException('device $requested not found. Connected: ${devices.join(', ')}');
    if (!match.isEmulator) throw _UsageException('$requested is not an emulator; "emu geo fix" needs an emulator');
    if (!match.isReady) throw _UsageException('$requested is ${match.state}');
    return requested;
  }
  if (emulators.isEmpty) throw _UsageException('no running emulator found (adb devices: ${devices.join(', ')})');
  if (emulators.length > 1) {
    throw _UsageException(
      'several emulators are running (${emulators.map((d) => d.serial).join(', ')}); '
      'choose one with --device',
    );
  }
  return emulators.single.serial;
}

Future<String?> _avdName(String adb, String serial) async {
  try {
    final r = await Process.run(adb, ['-s', serial, 'emu', 'avd', 'name']);
    final first = '${r.stdout}'.split(RegExp(r'\r?\n')).map((l) => l.trim()).firstOrNull;
    return first == null || first.isEmpty || first == 'OK' ? null : first;
  } on ProcessException {
    return null;
  }
}

String _format(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

// Kadıköy pier → Moda → Bahariye, Istanbul.
const _demoRoute = [
  GeoPoint(40.99090, 29.02350),
  GeoPoint(40.98960, 29.02540),
  GeoPoint(40.98780, 29.02620),
  GeoPoint(40.98570, 29.02690),
  GeoPoint(40.98400, 29.02810),
  GeoPoint(40.98250, 29.02950),
  GeoPoint(40.98330, 29.03190),
  GeoPoint(40.98520, 29.03250),
  GeoPoint(40.98760, 29.03180),
  GeoPoint(40.98950, 29.02980),
];
