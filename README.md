# route_simulator

[![pub package](https://img.shields.io/pub/v/route_simulator.svg)](https://pub.dev/packages/route_simulator)

Realistic fake GPS location streams along a route — for testing and demoing location apps at your desk.
Pure Dart with **no runtime dependencies**: works in Flutter apps, on the server, in unit tests and on the web.

*[Türkçe açıklama aşağıda.](#türkçe)*

- **Input:** a list of points or an encoded polyline (Google `polyline5` / OSRM `polyline6`).
- **Motion:** constant speed, or a realistic profile that accelerates, slows down before turns and stops and comes
  to rest at the end; waits at route points; looping.
- **Realism:** seeded GPS noise (metres), accuracy value, occasional multipath jumps, signal-loss windows, altitude,
  heading and speed.
- **Time:** a real-time `Stream` with a playback rate, `start / pause / resume / stop / seek`; works with
  `fake_async`. Timer-free `locationAt` / `generate` for tests.
- **Output:** `SimulatedLocation` whose `toMap()` has the keys of
  [advanced_background_locator](https://pub.dev/packages/advanced_background_locator)'s `LocationDto`, GPX export,
  and a CLI that plays the route on an Android emulator.

## Installation

```yaml
dev_dependencies: # or dependencies, for an in-app demo mode
  route_simulator: ^0.1.1
```

## Quick start

```dart
import 'package:route_simulator/route_simulator.dart';

final simulator = RouteSimulator(
  route: SimRoute.fromEncodedPolyline(encoded), // or SimRoute([GeoPoint(41.0, 29.0), ...])
  profile: const SpeedProfile.realistic(cruiseSpeed: 50 / 3.6), // m/s
  stops: const [RouteStop.atPoint(3, Duration(seconds: 30))], // wait 30 s at point 3
  noise: const GpsNoise(horizontalError: 4, seed: 42, dropoutProbability: 0.02),
  playbackRate: 5, // five times faster than real time
);

simulator.locations.listen((l) {
  print('${l.latitude}, ${l.longitude} ${l.speed} m/s ±${l.accuracy} m');
});
simulator.start(); // later: pause(), resume(), seek(...), stop(), dispose()
```

### Speed profiles and stops

| | `SpeedProfile.constant(speed)` | `SpeedProfile.realistic(cruiseSpeed: …)` |
|---|---|---|
| Start / end | at full speed | from rest / to rest |
| Acceleration | instant | `acceleration` (1.5 m/s²), `deceleration` (2.5 m/s²) |
| Turns | ignored | limited to `cornerSpeed` (5 m/s) at `cornerAngle` (90°) and sharper, proportionally below |
| Stops | halt, wait, continue | brake to 0, wait, accelerate |

`RouteStop.atPoint(index, duration)` waits at a route vertex, `RouteStop.atDistance(metres, duration)` anywhere.
`loop: true` starts over at the end; `SimulatedLocation.lap` counts laps.

### Noise

```dart
const GpsNoise(
  horizontalError: 3,    // σ per axis in metres
  altitudeError: 4,      // σ in metres
  speedError: 0.3,       // σ in m/s, also reported as speedAccuracy
  accuracy: null,        // null: ≈ 1.51 σ (68 % radius, like Android) ±20 %
  jumpProbability: 0.01, // multipath jump of jumpDistance metres
  jumpDistance: 40,
  dropoutProbability: 0.05, // a whole dropoutDuration window has no fix
  dropoutDuration: Duration(seconds: 5),
  seed: 42,
)
```

All randomness comes from a small built-in generator keyed by `seed` and the sample time, so the output is
**identical on every run and every platform**, and does not depend on playback history (`seek` back and you get the
same fixes). Noise-free values are always available through `truthAt`, `SimulatedLocation.distance`, `isStopped`
and `isJump` — handy as the oracle in filter tests.

### Testing

The stream only uses `Timer`, so it runs under [`fake_async`](https://pub.dev/packages/fake_async):

```dart
fakeAsync((async) {
  final got = <SimulatedLocation>[];
  sim.locations.listen(got.add);
  sim.start();
  async.elapse(const Duration(seconds: 10)); // 11 fixes: t = 0 … 10 s
});
```

Or skip timers entirely:

```dart
final all = sim.generate(every: const Duration(milliseconds: 500)); // whole route
final fix = sim.locationAt(const Duration(minutes: 3)); // null during signal loss
```

Pass `startTime` for deterministic timestamps. Without it, a playback is stamped from the moment `start()` is
called (`clock` from `fake_async` is not used — timestamps come from `DateTime.now()`), and `generate()` uses one
epoch for the whole list.

### Feeding your app

```dart
// Same keys as advanced_background_locator's LocationDto:
final dto = LocationDto.fromJson(location.toMap());
```

`toMap()` returns `latitude, longitude, accuracy, altitude, speed, speed_accuracy, heading, time` (ms since epoch,
`double`), `is_mocked` (`true`) and `provider` (`route_simulator`). This package does not depend on
advanced_background_locator.

### GPX export

```dart
final gpx = toGpx(simulator.generate(), name: 'Morning commute');
```

The GPX 1.1 track can be loaded into Android Studio's emulator *Location → Routes*, Xcode, or any GPX viewer.

## Android emulator CLI

```bash
dart run route_simulator:emulator --demo --realistic --rate 5 --device emulator-5554
```

```text
Route:   10 points, 2.07 km, one lap 02:40 simulated
Playback: every 1.0s simulated at 5.0x (≈ 00:32 real time per lap)
Target device: emulator-5554 (AVD: Pixel_8_API_36)
Other apps on this emulator will also receive these mock locations.
Send locations to emulator-5554? [y/N]
```

The command always shows the target device (serial and AVD name) and asks before sending anything. With several
emulators running it refuses to guess: pass `--device emulator-5556`. Real devices are rejected, because
`emu geo fix` only works on emulators. Other inputs: `--points "41.0,29.0;41.01,29.02"`, `--file route.gpx`
(or a text file), `--demo`. `--dry-run` prints the `adb` commands, `--yes` skips the prompt (for scripts), `--help`
lists everything (stops, loop, noise, seed, interval, adb path). Polylines often contain characters such as `|` or
`` ` `` that shells (especially Windows `cmd`) interpret; put them in a file and use `--file route.txt`.

## Used together

route_simulator is part of a small family of packages; none of them depends on another.

| Package | With route_simulator |
|---|---|
| [google_maps_polyline](https://pub.dev/packages/google_maps_polyline) | Fetch a real route, then simulate it: `SimRoute.fromEncodedPolyline(encodedPolyline)` (or `SimRoute(points.map((p) => GeoPoint(p.latitude, p.longitude)))`). |
| [advanced_background_locator](https://pub.dev/packages/advanced_background_locator) | Feed your location callback without moving: `LocationDto.fromJson(location.toMap())`. |
| [advanced_geofence](https://pub.dev/packages/advanced_geofence) | Drive enter/dwell/exit events at your desk (see below). |
| [animated_route_marker](https://pub.dev/packages/animated_route_marker) | Move a map marker with simulated fixes: `controller.jumpTo(LatLng(l.latitude, l.longitude), bearing: l.heading)`. |

Both route_simulator and advanced_geofence export a `GeoPoint`, so import one of them with a prefix:

```dart
import 'package:advanced_geofence/advanced_geofence.dart' as gf;
import 'package:route_simulator/route_simulator.dart';

final engine = gf.GeofenceEngine(
  geofences: [gf.CircleGeofence(id: 'office', center: const gf.GeoPoint(41.0082, 28.9784), radius: 150)],
  // Simulated timestamps may lie in the past or (with playbackRate > 1) in the future.
  options: const gf.GeofenceOptions(maxReadingAge: null),
);

simulator.locations.listen((l) {
  final result = engine.process(gf.GeoPoint(l.latitude, l.longitude, accuracy: l.accuracy, time: l.time));
  for (final event in result.events) print('${event.type.name} ${event.geofenceId}');
});
```

## Why another one? Comparison

Checked on pub.dev on 2026-10-22:

| | route_simulator | gmaps_vehicle_tracker | android_location_mocker / fluttermocklocation |
|---|---|---|---|
| Kind | pure Dart library + CLI | Flutter tracking UI on Google Maps, includes a simulator | Android-only plugins |
| Runtime dependencies | none | Flutter, Google Maps | Flutter |
| Route input | points, polyline5/6 | encoded polyline | one fixed point |
| Speed profile / turns / stops | ✓ | ✓ | – |
| Seeded noise, jumps, signal loss | ✓ (platform-independent) | ✓ | – |
| Virtual clock, `fake_async`, `seek` | ✓ | injectable clock | – |
| GPX export | ✓ | – | – |
| Emulator playback (`adb emu geo fix`) | ✓ | – | system mock provider on device |
| `LocationDto`-compatible map | ✓ | – | – |

Mock-location *detectors* (`trust_location`, `detect_fake_location`, `safe_device`, …) solve the opposite problem.
route_simulator does not install an Android mock-location provider; it feeds your code directly (stream / map) or
the emulator (CLI).

## Design decisions

- **Bundled polyline codec instead of depending on `google_maps_polyline`.** Decoding is ~40 lines; depending on
  google_maps_polyline would pull in `http` and a Directions API client that a simulator never uses. The codec is
  the standard algorithm, so polylines from google_maps_polyline, Directions/Routes API, OSRM or Valhalla work
  as-is.
- **No dependency on advanced_background_locator.** `toMap()` matches `LocationDto`'s keys, so the two packages
  interoperate without either depending on the other.
- **No `dart:io` in the library.** The CLI lives in `bin/`; the pure helpers it uses are in
  `package:route_simulator/adb.dart`.

## Türkçe

Konum uygulamalarını masa başında test etmek ve demo yapmak için bir rota boyunca gerçekçi sahte konum akışı üretir.
Saf Dart'tır ve **çalışma zamanı bağımlılığı yoktur**: Flutter uygulamasında, sunucuda, birim testlerinde ve webde
çalışır.

- **Girdi:** nokta listesi (`SimRoute([GeoPoint(...), ...])`) ya da kodlanmış polyline
  (`SimRoute.fromEncodedPolyline(dize, precision: 5)`; OSRM `polyline6` için `precision: 6`).
- **Hareket:** `SpeedProfile.constant(hız)` sabit hız (m/s); `SpeedProfile.realistic(cruiseSpeed: ...)` duruştan
  hızlanır, virajdan ve duraktan önce yavaşlar, sonda durur. `RouteStop.atPoint(indeks, süre)` ara noktada bekler,
  `loop: true` başa döner (`lap` tur sayısı).
- **Gerçekçilik:** `GpsNoise` ile metre cinsinden gürültü (`horizontalError` eksen başına σ), doğruluk değeri,
  ara sıra sıçrama (`jumpProbability`), sinyal kaybı pencereleri (`dropoutProbability`), rakım, yön ve hız. Tüm
  rastgelelik `seed` ve örnek zamanından türetilir: her çalıştırmada ve her platformda **aynı sonuç**, `seek` sonrası
  da aynı. Gürültüsüz gerçek değer `truthAt` ile alınır.
- **Zaman:** `playbackRate` ile hızlandırılabilen gerçek zamanlı `Stream`; `start / pause / resume / stop / seek`.
  Yalnızca `Timer` kullandığı için `fake_async` ile test edilir; zamanlayıcısız `locationAt` ve `generate` da var.
  Belirlenimli zaman damgaları için `startTime` verin.
- **Çıktı:** `SimulatedLocation.toMap()` advanced_background_locator'ın `LocationDto` anahtarlarıyla birebir aynıdır
  (`LocationDto.fromJson(konum.toMap())`), bağımlılık eklemez. `toGpx(konumlar)` GPX 1.1 izi üretir.
- **Birlikte kullanım:** [google_maps_polyline](https://pub.dev/packages/google_maps_polyline) ile alınan rota
  `SimRoute.fromEncodedPolyline` ile simüle edilir;
  [advanced_background_locator](https://pub.dev/packages/advanced_background_locator) geri çağrısı
  `LocationDto.fromJson(konum.toMap())` ile beslenir; [advanced_geofence](https://pub.dev/packages/advanced_geofence)
  `engine.process(...)` ile giriş/bekleme/çıkış olayları masa başında üretilir (iki paket de `GeoPoint` dışa açtığı
  için birini önekle içe aktarın, `GeofenceOptions(maxReadingAge: null)` kullanın);
  [animated_route_marker](https://pub.dev/packages/animated_route_marker) işaretçisi
  `controller.jumpTo(LatLng(...), bearing: konum.heading)` ile taşınır. Paketler birbirine bağımlı değildir.
- **Emülatör:** `dart run route_simulator:emulator --demo --realistic --rate 5 --device emulator-5554`. Komut hedef
  cihazı (seri numarası ve AVD adı) gösterir ve göndermeden önce onay ister; birden fazla emülatör açıksa `--device`
  ister, gerçek cihazı reddeder. `--dry-run` komutları yalnızca yazdırır, `--yes` onayı atlar, `--help` tüm
  seçenekleri listeler.
- **Fark:** pub.dev'deki mock-location paketleri yalnızca Android'de ve tek sabit noktayla çalışıyor;
  gmaps_vehicle_tracker'ın simülatörü Google Maps arayüzüne bağlı. route_simulator bağımsız, belirlenimli, sanal
  saatli, GPX ve emülatör desteğiyle gelir.
- **Bağımlılık kararı:** polyline çözücü pakete gömülüdür (~40 satır). `google_maps_polyline`'a bağlanmak
  simülatörün hiç kullanmadığı `http` ve Directions istemcisini getirirdi; algoritma standart olduğu için
  google_maps_polyline, Directions/Routes API ve OSRM polyline'ları doğrudan çalışır.

## License / Lisans

MIT — see [LICENSE](LICENSE).
