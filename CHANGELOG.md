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
