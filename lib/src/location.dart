/// A simulated GPS fix.
///
/// The first ten fields mirror `LocationDto` of
/// [advanced_background_locator](https://pub.dev/packages/advanced_background_locator); [toMap] produces the same
/// keys, so `LocationDto.fromJson(location.toMap())` works without this package depending on it.
class SimulatedLocation {
  const SimulatedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.speed,
    required this.speedAccuracy,
    required this.heading,
    required this.time,
    this.isMocked = true,
    this.provider = 'route_simulator',
    required this.elapsed,
    required this.distance,
    required this.lap,
    this.isStopped = false,
    this.isJump = false,
  });

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// Estimated horizontal accuracy (68% radius) in metres.
  final double accuracy;

  /// Altitude in metres.
  final double altitude;

  /// Speed in m/s.
  final double speed;

  /// Estimated speed accuracy in m/s.
  final double speedAccuracy;

  /// Direction of travel in degrees, clockwise from north.
  final double heading;

  /// Timestamp of the fix.
  final DateTime time;

  /// Always `true` unless overridden: this fix did not come from a real receiver.
  final bool isMocked;

  /// Provider name, `route_simulator` by default.
  final String provider;

  /// Simulated time since the start of the simulation (all laps).
  final Duration elapsed;

  /// Noise-free distance along the route in metres, within the current lap.
  final double distance;

  /// Zero-based lap number (always 0 without looping).
  final int lap;

  /// Whether the device is waiting at a stop.
  final bool isStopped;

  /// Whether this fix is a simulated multipath jump.
  final bool isJump;

  /// The fix as a map with the keys of advanced_background_locator's `LocationDto`.
  ///
  /// `time` is milliseconds since epoch as a `double`, as in `LocationDto`.
  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'altitude': altitude,
    'speed': speed,
    'speed_accuracy': speedAccuracy,
    'heading': heading,
    'time': time.millisecondsSinceEpoch.toDouble(),
    'is_mocked': isMocked,
    'provider': provider,
  };

  @override
  String toString() =>
      'SimulatedLocation(${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}, '
      'speed: ${speed.toStringAsFixed(2)}, heading: ${heading.toStringAsFixed(1)}, elapsed: $elapsed)';
}
