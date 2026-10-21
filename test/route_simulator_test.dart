import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:route_simulator/adb.dart';
import 'package:route_simulator/route_simulator.dart';
import 'package:test/test.dart';

/// ~1 km due north along the meridian, then ~1 km due east.
final _lShape = SimRoute(const [GeoPoint(41, 29), GeoPoint(41.009, 29), GeoPoint(41.009, 29.0119)]);

final _start = DateTime.utc(2026, 10, 22, 8);

void main() {
  group('geo', () {
    test('haversine distance Istanbul → Ankara', () {
      final d = distanceBetween(const GeoPoint(41.0082, 28.9784), const GeoPoint(39.9334, 32.8597));
      expect(d / 1000, closeTo(350.0, 1.5));
    });

    test('one degree of latitude ≈ 111.2 km', () {
      expect(distanceBetween(const GeoPoint(0, 0), const GeoPoint(1, 0)), closeTo(111195, 1));
    });

    test('bearings', () {
      expect(bearingBetween(const GeoPoint(41, 29), const GeoPoint(42, 29)), closeTo(0, 1e-9));
      expect(bearingBetween(const GeoPoint(0, 0), const GeoPoint(0, 1)), closeTo(90, 1e-9));
      expect(bearingBetween(const GeoPoint(41, 29), const GeoPoint(40, 29)), closeTo(180, 1e-9));
      expect(bearingDifference(350, 10), 20);
    });

    test('offsetPoint moves the requested distance', () {
      const o = GeoPoint(41, 29);
      for (final b in [0.0, 45.0, 135.0, 270.0]) {
        final p = offsetPoint(o, 25, b);
        expect(distanceBetween(o, p), closeTo(25, 1e-6));
        expect(bearingDifference(bearingBetween(o, p), b), lessThan(1e-3));
      }
    });
  });

  group('polyline', () {
    test('decodes the Google reference polyline', () {
      final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(pts, const [GeoPoint(38.5, -120.2), GeoPoint(40.7, -120.95), GeoPoint(43.252, -126.453)]);
    });

    test('encode is the inverse of decode', () {
      expect(
        encodePolyline(const [GeoPoint(38.5, -120.2), GeoPoint(40.7, -120.95), GeoPoint(43.252, -126.453)]),
        '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      );
      final pts = [for (var i = 0; i < 20; i++) GeoPoint(41 + i * 0.000123, 29 - i * 0.000456)];
      final back = decodePolyline(encodePolyline(pts, precision: 6), precision: 6);
      for (var i = 0; i < pts.length; i++) {
        expect(back[i].latitude, closeTo(pts[i].latitude, 1e-6));
        expect(back[i].longitude, closeTo(pts[i].longitude, 1e-6));
      }
    });

    test('invalid strings throw FormatException', () {
      expect(() => decodePolyline('_p~iF~ps|U_'), throwsFormatException);
      expect(() => decodePolyline('ab cd'), throwsFormatException);
    });
  });

  group('SimRoute', () {
    test('length, positions and turn angle', () {
      expect(_lShape.length, closeTo(1000.75 + 998.6, 2));
      final mid = _lShape.positionAt(500);
      expect(mid.point.longitude, 29);
      expect(mid.heading, closeTo(0, 1e-9));
      expect(_lShape.turnAngleAt(1), closeTo(90, 0.1));
      expect(_lShape.positionAt(-5).distance, 0);
      expect(_lShape.positionAt(1e9).point.latitude, closeTo(41.009, 1e-12));
    });

    test('drops duplicates and rejects too short routes', () {
      expect(SimRoute(const [GeoPoint(1, 1), GeoPoint(1, 1), GeoPoint(1, 2)]).points, hasLength(2));
      expect(() => SimRoute(const [GeoPoint(1, 1), GeoPoint(1, 1)]), throwsArgumentError);
      expect(SimRoute.fromEncodedPolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@').points, hasLength(3));
    });

    test('interpolates altitude', () {
      final r = SimRoute(const [GeoPoint(0, 0, altitude: 100), GeoPoint(0.01, 0, altitude: 200)]);
      expect(r.positionAt(r.length / 2).point.altitude, closeTo(150, 1e-9));
    });
  });

  group('motion', () {
    test('constant speed: duration = length / speed', () {
      final sim = RouteSimulator(route: _lShape, profile: const SpeedProfile.constant(10));
      expect(sim.lapDuration.inMicroseconds / 1e6, closeTo(_lShape.length / 10, 1e-6));
      final l = sim.truthAt(const Duration(seconds: 50));
      expect(l.distance, closeTo(500, 1e-6));
      expect(l.speed, 10);
      expect(l.heading, closeTo(0, 1e-9));
    });

    test('constant speed with a stop adds exactly the wait', () {
      final sim = RouteSimulator(
        route: _lShape,
        profile: const SpeedProfile.constant(10),
        stops: const [RouteStop.atPoint(1, Duration(seconds: 30))],
      );
      final travel = _lShape.length / 10;
      expect(sim.lapDuration.inMicroseconds / 1e6, closeTo(travel + 30, 1e-6));
      final arrive = _lShape.distanceOfPoint(1) / 10;
      final waiting = sim.truthAt(Duration(milliseconds: ((arrive + 15) * 1000).round()));
      expect(waiting.isStopped, isTrue);
      expect(waiting.speed, 0);
      expect(waiting.distance, closeTo(_lShape.distanceOfPoint(1), 1e-6));
      final after = sim.truthAt(Duration(microseconds: ((arrive + 40) * 1e6).round()));
      expect(after.distance, closeTo(_lShape.distanceOfPoint(1) + 100, 1e-3));
    });

    test('realistic profile respects speed, acceleration and corner limits', () {
      const profile = SpeedProfile.realistic(cruiseSpeed: 15, acceleration: 2, deceleration: 3, cornerSpeed: 5);
      final sim = RouteSimulator(route: _lShape, profile: profile);
      final samples = sim.generate(every: const Duration(milliseconds: 100));
      expect(samples.first.speed, 0);
      expect(samples.last.speed, closeTo(0, 1e-6));
      expect(samples.last.distance, closeTo(_lShape.length, 1e-6));
      expect(samples.map((s) => s.speed).reduce(math.max), closeTo(15, 1e-9));
      for (var i = 1; i < samples.length; i++) {
        final a = (samples[i].speed - samples[i - 1].speed) / 0.1;
        expect(a, lessThanOrEqualTo(2 + 1e-6));
        expect(a, greaterThanOrEqualTo(-3 - 1e-6));
        expect(samples[i].distance, greaterThanOrEqualTo(samples[i - 1].distance - 1e-9));
      }
      final corner = _lShape.distanceOfPoint(1);
      final atCorner = samples.reduce((a, b) => (a.distance - corner).abs() < (b.distance - corner).abs() ? a : b);
      expect(atCorner.speed, lessThan(5.5));
      // Slower than constant cruise because of acceleration and the corner.
      expect(sim.lapDuration.inMilliseconds / 1000, greaterThan(_lShape.length / 15 + 5));
    });

    test('realistic stops come to rest', () {
      final sim = RouteSimulator(
        route: _lShape,
        profile: const SpeedProfile.realistic(cruiseSpeed: 12),
        stops: const [RouteStop.atDistance(600, Duration(seconds: 20))],
      );
      final stopped = sim.generate().where((l) => l.isStopped).toList();
      expect(stopped.length, inInclusiveRange(19, 21));
      expect(stopped.every((l) => (l.distance - 600).abs() < 1e-6 && l.speed == 0), isTrue);
    });

    test('loop wraps around and counts laps', () {
      final sim = RouteSimulator(route: _lShape, profile: const SpeedProfile.constant(20), loop: true);
      final lap = sim.lapDuration;
      final l = sim.truthAt(lap * 2 + const Duration(seconds: 10));
      expect(l.lap, 2);
      expect(l.distance, closeTo(200, 1e-3));
      expect(() => sim.generate(), throwsArgumentError);
      expect(sim.generate(until: lap * 3), isNotEmpty);
    });

    test('invalid settings throw', () {
      expect(() => RouteSimulator(route: _lShape, profile: const SpeedProfile.constant(0)), throwsArgumentError);
      expect(
        () => RouteSimulator(route: _lShape, stops: const [RouteStop.atPoint(9, Duration(seconds: 1))]),
        throwsRangeError,
      );
      expect(() => RouteSimulator(route: _lShape, noise: const GpsNoise(jumpProbability: 2)), throwsArgumentError);
      expect(() => RouteSimulator(route: _lShape, playbackRate: 0), throwsArgumentError);
    });
  });

  group('noise', () {
    RouteSimulator make(GpsNoise noise, {bool loop = false}) => RouteSimulator(
      route: _lShape,
      profile: const SpeedProfile.constant(1),
      noise: noise,
      startTime: _start,
      loop: loop,
    );

    test('same seed → identical output, different seed → different', () {
      final a = make(const GpsNoise(seed: 7)).generate();
      final b = make(const GpsNoise(seed: 7)).generate();
      final c = make(const GpsNoise(seed: 8)).generate();
      expect([for (final l in a) l.toMap()], [for (final l in b) l.toMap()]);
      expect(a[10].latitude, isNot(c[10].latitude));
    });

    test('golden values are identical on every platform (run with -p vm,chrome)', () {
      final sim = RouteSimulator(
        route: SimRoute(const [GeoPoint(41, 29), GeoPoint(41.009, 29)]),
        profile: const SpeedProfile.constant(1),
        noise: const GpsNoise(seed: 7, jumpProbability: 0.3, dropoutProbability: 0.3),
        startTime: DateTime.utc(2026),
      );
      final a = sim.locationAt(const Duration(seconds: 10))!;
      expect(a.latitude, closeTo(40.99995864665118, 1e-12));
      expect(a.longitude, closeTo(28.999567447050936, 1e-12));
      expect(a.accuracy, closeTo(5.435447958922014, 1e-12));
      expect(a.isJump, isTrue);
      expect(sim.locationAt(const Duration(seconds: 77)), isNull);
      final b = sim.locationAt(const Duration(seconds: 400))!;
      expect(b.latitude, closeTo(41.003538696581494, 1e-12));
      expect(b.longitude, closeTo(29.0000183806128, 1e-12));
      expect(b.isJump, isFalse);
    });

    test('result does not depend on playback history', () {
      final sim = make(const GpsNoise(seed: 3));
      final direct = sim.locationAt(const Duration(seconds: 321))!;
      sim.generate();
      expect(sim.locationAt(const Duration(seconds: 321))!.toMap(), direct.toMap());
    });

    test('horizontal error has zero mean and the requested sigma', () {
      final sim = make(const GpsNoise(horizontalError: 5, seed: 42));
      final north = <double>[];
      final east = <double>[];
      for (var s = 0; s < 1900; s++) {
        final t = Duration(seconds: s);
        final truth = sim.truthAt(t);
        final noisy = sim.locationAt(t)!;
        final d = distanceBetween(truth.point, noisy.point);
        final b = bearingBetween(truth.point, noisy.point) * math.pi / 180;
        north.add(d * math.cos(b));
        east.add(d * math.sin(b));
      }
      for (final axis in [north, east]) {
        final mean = axis.reduce((a, b) => a + b) / axis.length;
        final sd = math.sqrt(axis.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / axis.length);
        expect(mean.abs(), lessThan(0.5));
        expect(sd, closeTo(5, 0.4));
      }
      final acc = sim.generate().map((l) => l.accuracy);
      expect(acc.reduce(math.min), greaterThanOrEqualTo(0.8 * 7.55 - 1e-9));
      expect(acc.reduce(math.max), lessThanOrEqualTo(1.2 * 7.55 + 1e-9));
    });

    test('jumps and dropouts follow their probabilities', () {
      final sim = make(
        const GpsNoise(
          horizontalError: 0,
          seed: 1,
          jumpProbability: 0.05,
          jumpDistance: 50,
          dropoutProbability: 0.2,
          dropoutDuration: Duration(seconds: 10),
        ),
        loop: true,
      );
      final total = 20000;
      var dropped = 0;
      var jumps = 0;
      for (var s = 0; s < total; s++) {
        final l = sim.locationAt(Duration(seconds: s));
        if (l == null) {
          dropped++;
        } else if (l.isJump) {
          jumps++;
          expect(distanceBetween(sim.truthAt(Duration(seconds: s)).point, l.point), closeTo(50, 1e-3));
        }
      }
      expect(dropped / total, closeTo(0.2, 0.03));
      expect(jumps / (total - dropped), closeTo(0.05, 0.01));
      // Dropouts come in whole windows.
      expect(dropped % 10, 0);
    });
  });

  group('output', () {
    test('toMap matches LocationDto keys and types', () {
      final l = RouteSimulator(route: _lShape, startTime: _start).locationAt(const Duration(seconds: 3))!;
      final m = l.toMap();
      expect(m.keys.toSet(), {
        'latitude',
        'longitude',
        'accuracy',
        'altitude',
        'speed',
        'speed_accuracy',
        'heading',
        'time',
        'is_mocked',
        'provider',
      });
      expect(m['time'], _start.add(const Duration(seconds: 3)).millisecondsSinceEpoch.toDouble());
      expect(m['is_mocked'], isTrue);
      expect(m['provider'], 'route_simulator');
      for (final k in ['latitude', 'longitude', 'accuracy', 'altitude', 'speed', 'speed_accuracy', 'heading']) {
        expect(m[k], isA<double>(), reason: k);
      }
    });

    test('GPX export', () {
      final sim = RouteSimulator(route: _lShape, profile: const SpeedProfile.constant(50), startTime: _start);
      final locations = sim.generate();
      final gpx = toGpx(locations, name: 'A & B');
      expect(RegExp('<trkpt ').allMatches(gpx).length, locations.length);
      expect(gpx, contains('<name>A &amp; B</name>'));
      expect(gpx, contains('<time>2026-10-22T08:00:00.000Z</time>'));
      expect(gpx, contains('lat="41.0000000" lon="29.0000000"'));
      expect(gpx.trim(), endsWith('</gpx>'));
    });

    test('adb helpers', () {
      final devices = parseAdbDevices(
        'List of devices attached\r\nemulator-5570\tdevice\r\nR58M123\tdevice\r\nemulator-5556\toffline\r\n\r\n',
      );
      expect(devices.map((d) => d.serial), ['emulator-5570', 'R58M123', 'emulator-5556']);
      expect(devices.where((d) => d.isEmulator && d.isReady).single.serial, 'emulator-5570');
      final l = RouteSimulator(route: _lShape).truthAt(Duration.zero);
      expect(geoFixArguments('emulator-5570', l), [
        '-s',
        'emulator-5570',
        'emu',
        'geo',
        'fix',
        '29.0000000',
        '41.0000000',
        '0.0',
      ]);
    });
  });

  group('stream', () {
    test('real-time stream, pause, resume, seek and finish under fake_async', () {
      fakeAsync((async) {
        final sim = RouteSimulator(route: _lShape, profile: const SpeedProfile.constant(100), startTime: _start);
        final got = <SimulatedLocation>[];
        final states = <SimulatorState>[];
        sim.locations.listen(got.add);
        sim.states.listen(states.add);

        sim.start();
        async.elapse(const Duration(seconds: 5));
        expect(got.map((l) => l.elapsed.inSeconds), [0, 1, 2, 3, 4, 5]);
        expect(got[5].time, _start.add(const Duration(seconds: 5)));

        sim.pause();
        async.elapse(const Duration(seconds: 10));
        expect(got, hasLength(6));

        sim.resume();
        async.elapse(const Duration(seconds: 1));
        expect(got.last.elapsed, const Duration(seconds: 6));

        sim.seek(const Duration(seconds: 15));
        async.flushMicrotasks();
        expect(got.last.elapsed, const Duration(seconds: 15));

        async.elapse(const Duration(seconds: 30));
        expect(sim.state, SimulatorState.finished);
        expect(got.last.elapsed, sim.lapDuration);
        expect(got.last.distance, closeTo(_lShape.length, 1e-6));

        sim.stop();
        expect(sim.elapsed, Duration.zero);
        async.flushMicrotasks();
        expect(states, [
          SimulatorState.running,
          SimulatorState.paused,
          SimulatorState.running,
          SimulatorState.finished,
          SimulatorState.idle,
        ]);
        sim.dispose();
      });
    });

    test('playbackRate speeds up simulated time', () {
      fakeAsync((async) {
        final sim = RouteSimulator(
          route: _lShape,
          profile: const SpeedProfile.constant(1),
          playbackRate: 10,
          startTime: _start,
        );
        final got = <SimulatedLocation>[];
        sim.locations.listen(got.add);
        sim.start();
        async.elapse(const Duration(seconds: 2));
        expect(got.last.elapsed, const Duration(seconds: 20));
        sim.playbackRate = 50;
        async.elapse(const Duration(seconds: 1));
        expect(got.last.elapsed, const Duration(seconds: 70));
        sim.dispose();
      });
    });

    test('dropouts produce gaps in the stream', () {
      fakeAsync((async) {
        final sim = RouteSimulator(
          route: _lShape,
          profile: const SpeedProfile.constant(1),
          noise: const GpsNoise(dropoutProbability: 0.5, dropoutDuration: Duration(seconds: 5), seed: 9),
          startTime: _start,
        );
        final got = <SimulatedLocation>[];
        sim.locations.listen(got.add);
        sim.start();
        async.elapse(const Duration(seconds: 199));
        expect(got.length, lessThan(160));
        expect(got.length, greaterThan(40));
        sim.dispose();
      });
    });
  });
}
