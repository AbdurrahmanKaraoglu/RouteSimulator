import 'package:fake_async/fake_async.dart';
import 'package:route_simulator/adb.dart';
import 'package:route_simulator/route_simulator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

final _route = SimRoute(const [GeoPoint(41, 29), GeoPoint(41.009, 29), GeoPoint(41.009, 29.0119)]);

void main() {
  group('GPX', () {
    test('is well-formed GPX 1.1 with one trkpt per location', () {
      final sim = RouteSimulator(
        route: _route,
        profile: const SpeedProfile.constant(30),
        noise: const GpsNoise(seed: 1),
        startTime: DateTime.utc(2026, 10, 22, 8),
      );
      final locations = sim.generate();
      final doc = XmlDocument.parse(toGpx(locations, name: 'Tom & "Jerry" <test>', creator: 'a<b'));
      final gpx = doc.rootElement;
      expect(gpx.name.local, 'gpx');
      expect(gpx.getAttribute('version'), '1.1');
      expect(gpx.name.namespaceUri, 'http://www.topografix.com/GPX/1/1');
      expect(gpx.getAttribute('creator'), 'a<b');
      expect(gpx.findAllElements('name').single.innerText, 'Tom & "Jerry" <test>');

      final points = gpx.findAllElements('trkpt').toList();
      expect(points, hasLength(locations.length));
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        expect(double.parse(p.getAttribute('lat')!), closeTo(locations[i].latitude, 1e-7));
        expect(double.parse(p.getAttribute('lon')!), closeTo(locations[i].longitude, 1e-7));
        // GPX 1.1 requires <ele> before <time>.
        expect(p.childElements.map((e) => e.name.local), ['ele', 'time']);
        expect(DateTime.parse(p.getElement('time')!.innerText), locations[i].time);
      }
    });

    test('empty input still produces a valid document', () {
      final doc = XmlDocument.parse(toGpx(const []));
      expect(doc.rootElement.findAllElements('trkseg'), hasLength(1));
      expect(doc.rootElement.findAllElements('trkpt'), isEmpty);
    });
  });

  group('selectEmulator', () {
    final devices = parseAdbDevices(
      'List of devices attached\n'
      'emulator-5554\tdevice\n'
      'emulator-5556\toffline\n'
      'R58M123\tdevice\n',
    );

    test('picks the only ready emulator', () {
      expect(selectEmulator(devices).serial, 'emulator-5554');
    });

    test('refuses to guess between several emulators', () {
      final two = [...devices, const AdbDevice('emulator-5570', 'device')];
      expect(
        () => selectEmulator(two),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('--device'))),
      );
      expect(selectEmulator(two, requested: 'emulator-5570').serial, 'emulator-5570');
    });

    test('validates a requested device', () {
      expect(() => selectEmulator(devices, requested: 'R58M123'), throwsStateError);
      expect(() => selectEmulator(devices, requested: 'emulator-5556'), throwsStateError);
      expect(() => selectEmulator(devices, requested: 'emulator-9999'), throwsStateError);
    });

    test('no emulator', () {
      expect(() => selectEmulator(const [AdbDevice('R58M123', 'device')]), throwsStateError);
      expect(() => selectEmulator(const []), throwsStateError);
    });
  });

  group('timestamps and heading', () {
    test('generate without startTime uses one evenly spaced epoch', () {
      final list = RouteSimulator(route: _route, profile: const SpeedProfile.constant(50)).generate();
      for (var i = 1; i < list.length - 1; i++) {
        expect(list[i].time.difference(list[i - 1].time), const Duration(seconds: 1));
      }
    });

    test('start fixes the epoch for the playback (fake_async clock)', () {
      fakeAsync((async) {
        final sim = RouteSimulator(route: _route, profile: const SpeedProfile.constant(50));
        final got = <SimulatedLocation>[];
        sim.locations.listen(got.add);
        sim.start();
        async.elapse(const Duration(seconds: 3));
        expect(got.map((l) => l.time.difference(got.first.time).inSeconds), [0, 1, 2, 3]);
        sim.dispose();
      });
    });

    test('keeps the arriving heading while waiting at a vertex', () {
      final sim = RouteSimulator(
        route: _route,
        profile: const SpeedProfile.constant(10),
        stops: const [RouteStop.atPoint(1, Duration(seconds: 30))],
      );
      final arrive = _route.distanceOfPoint(1) / 10;
      final waiting = sim.truthAt(Duration(seconds: arrive.ceil() + 5));
      expect(waiting.isStopped, isTrue);
      expect(waiting.heading, closeTo(0, 1e-6)); // still facing north
      final after = sim.truthAt(Duration(seconds: arrive.ceil() + 40));
      expect(after.heading, closeTo(90, 0.1)); // now heading east
    });
  });

  group('README examples', () {
    test('quick start and noise snippets run with the current API', () {
      fakeAsync((async) {
        final encoded = encodePolyline(_route.points);
        final simulator = RouteSimulator(
          route: SimRoute.fromEncodedPolyline(encoded),
          profile: const SpeedProfile.realistic(cruiseSpeed: 50 / 3.6),
          stops: const [RouteStop.atPoint(1, Duration(seconds: 30))],
          noise: const GpsNoise(horizontalError: 4, seed: 42, dropoutProbability: 0.02),
          playbackRate: 5,
        );
        final got = <SimulatedLocation>[];
        simulator.locations.listen(got.add);
        simulator.start();
        async.elapse(const Duration(seconds: 2));
        expect(got.length, greaterThan(5));
        simulator
          ..pause()
          ..resume()
          ..seek(const Duration(minutes: 1))
          ..stop();
        simulator.dispose();

        const noise = GpsNoise(
          horizontalError: 3,
          altitudeError: 4,
          speedError: 0.3,
          accuracy: null,
          jumpProbability: 0.01,
          jumpDistance: 40,
          dropoutProbability: 0.05,
          dropoutDuration: Duration(seconds: 5),
          seed: 42,
        );
        final sim = RouteSimulator(route: _route, noise: noise);
        expect(sim.generate(every: const Duration(milliseconds: 500)), isNotEmpty);
        sim.locationAt(const Duration(minutes: 3));
        expect(toGpx(sim.generate(), name: 'Morning commute'), contains('Morning commute'));
      });
    });
  });
}
