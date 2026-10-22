## 0.1.2

* **DOCS (EN):** README lists the author's other packages (11 packages, English and Turkish sections).
* **DOCS (TR):** README'de geliştiricinin diğer paketleri listelendi (11 paket, İngilizce ve Türkçe bölümler).

## 0.1.1

* **EN:**
  * `generate()` uses one timestamp epoch for the whole list when `startTime` is not set (previously each fix read
    the clock separately, so spacing could drift).
  * While waiting at a route point, `heading` keeps the direction of the arriving segment instead of jumping to the
    next one.
  * New `selectEmulator()` in `package:route_simulator/adb.dart`; the emulator CLI uses it (same behaviour, now
    unit-tested).
  * Shorter pubspec description (pub.dev score), documented constructors, LICENSE copyright line fixed.
  * README: "Used together" section (google_maps_polyline, advanced_background_locator, advanced_geofence,
    animated_route_marker); notes on timestamps. Tests: GPX validated with an XML parser, README snippets compiled.
* **TR:**
  * `startTime` verilmediğinde `generate()` tüm liste için tek bir zaman başlangıcı kullanıyor (önceden her konum
    saati ayrı okuyordu, aralıklar kayabiliyordu).
  * Ara noktada beklerken `heading` sonraki segmente atlamıyor, gelinen yönü koruyor.
  * `package:route_simulator/adb.dart` içinde yeni `selectEmulator()`; emülatör CLI'si bunu kullanıyor (davranış
    aynı, artık birim testli).
  * Daha kısa pubspec açıklaması (pub.dev puanı), belgelenmiş kurucular, LICENSE telif satırı düzeltildi.
  * README: "Birlikte kullanım" bölümü ve zaman damgası notları. Testler: GPX bir XML ayrıştırıcıyla doğrulanıyor,
    README örnekleri derleniyor.

## 0.1.0

* First release. / İlk sürüm.
* **EN:** `RouteSimulator` produces a realistic fake location stream along a `SimRoute` built from points or an
  encoded polyline (bundled, dependency-free decoder/encoder).
  * Speed: `SpeedProfile.constant` or `SpeedProfile.realistic` (acceleration, deceleration, slowdown before turns),
    `RouteStop` waits, looping.
  * Realism: seeded, platform-independent GPS noise (`GpsNoise`): horizontal/altitude/speed error, accuracy value,
    multipath jumps, signal-loss windows; heading, speed and altitude fields.
  * Time: real-time broadcast `Stream` with `playbackRate`, `start/pause/resume/stop/seek`; works under
    `fake_async`. Timer-free `locationAt`, `truthAt` and `generate` for tests.
  * Output: `SimulatedLocation.toMap()` with the keys of advanced_background_locator's `LocationDto`, `toGpx`,
    and the `dart run route_simulator:emulator` command that plays a route on an Android emulator with
    `adb emu geo fix` after showing and confirming the target device.
* **TR:** `RouteSimulator`, nokta listesinden ya da kodlanmış polyline'dan (bağımlılıksız çözücü pakette) kurulan
  `SimRoute` boyunca gerçekçi sahte konum akışı üretir.
  * Hız: `SpeedProfile.constant` ya da `SpeedProfile.realistic` (hızlanma, yavaşlama, viraj öncesi yavaşlama),
    `RouteStop` beklemeleri, döngü.
  * Gerçekçilik: seed'li, platformdan bağımsız GPS gürültüsü (`GpsNoise`): yatay/rakım/hız hatası, doğruluk değeri,
    sıçramalar, sinyal kaybı pencereleri; yön, hız ve rakım alanları.
  * Zaman: `playbackRate` ile gerçek zamanlı yayın `Stream`'i, `start/pause/resume/stop/seek`; `fake_async` ile
    çalışır. Testler için zamanlayıcısız `locationAt`, `truthAt` ve `generate`.
  * Çıktı: advanced_background_locator `LocationDto` anahtarlarıyla `SimulatedLocation.toMap()`, `toGpx` ve hedef
    cihazı gösterip onay aldıktan sonra rotayı `adb emu geo fix` ile Android emülatöründe oynatan
    `dart run route_simulator:emulator` komutu.
