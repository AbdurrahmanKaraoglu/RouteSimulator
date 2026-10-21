/// How fast the simulated device moves along the route.
class SpeedProfile {
  /// Moves at [speed] m/s the whole way, with no acceleration phase.
  ///
  /// Stops are instantaneous: the device halts at the stop, waits and continues at [speed].
  const SpeedProfile.constant(double speed)
    : cruiseSpeed = speed,
      acceleration = double.infinity,
      deceleration = double.infinity,
      cornerSpeed = null,
      cornerAngle = 90;

  /// Accelerates from rest, cruises at [cruiseSpeed] m/s, slows down before turns and stops and comes to rest at
  /// the end.
  ///
  /// At a turn of [cornerAngle] degrees or more the speed is limited to [cornerSpeed]; gentler turns are limited
  /// proportionally (a 45° turn with the defaults allows halfway between cruise and corner speed). Turns under 10°
  /// are ignored. Pass `cornerSpeed: null` to disable corner slowdown.
  const SpeedProfile.realistic({
    required this.cruiseSpeed,
    this.acceleration = 1.5,
    this.deceleration = 2.5,
    this.cornerSpeed = 5,
    this.cornerAngle = 90,
  });

  /// Target speed in m/s.
  final double cruiseSpeed;

  /// Maximum acceleration in m/s². [double.infinity] for [SpeedProfile.constant].
  final double acceleration;

  /// Maximum deceleration (as a positive number) in m/s².
  final double deceleration;

  /// Speed limit in m/s at sharp turns, or `null` for no corner slowdown.
  final double? cornerSpeed;

  /// Turn angle in degrees at which [cornerSpeed] fully applies.
  final double cornerAngle;

  /// Whether this is a [SpeedProfile.constant] profile.
  bool get isConstant => acceleration.isInfinite && deceleration.isInfinite;

  /// Speed limit in m/s at a vertex where the route turns by [turnAngle] degrees.
  double cornerLimit(double turnAngle) {
    final corner = cornerSpeed;
    if (corner == null || turnAngle < 10 || corner >= cruiseSpeed) return cruiseSpeed;
    final f = (turnAngle / cornerAngle).clamp(0.0, 1.0);
    return cruiseSpeed - (cruiseSpeed - corner) * f;
  }

  /// Throws [ArgumentError] when a value is out of range.
  void validate() {
    if (!(cruiseSpeed > 0) || !cruiseSpeed.isFinite) {
      throw ArgumentError.value(cruiseSpeed, 'cruiseSpeed', 'must be a positive finite speed');
    }
    if (!(acceleration > 0)) throw ArgumentError.value(acceleration, 'acceleration', 'must be positive');
    if (!(deceleration > 0)) throw ArgumentError.value(deceleration, 'deceleration', 'must be positive');
    final corner = cornerSpeed;
    if (corner != null && !(corner > 0)) throw ArgumentError.value(corner, 'cornerSpeed', 'must be positive');
    if (!(cornerAngle > 0)) throw ArgumentError.value(cornerAngle, 'cornerAngle', 'must be positive');
  }
}

/// A wait of [duration] at a point of the route.
class RouteStop {
  /// Stops at route vertex [pointIndex] (an index into `SimRoute.points`).
  const RouteStop.atPoint(int this.pointIndex, this.duration) : distance = null;

  /// Stops [distance] metres from the start of the route.
  const RouteStop.atDistance(double this.distance, this.duration) : pointIndex = null;

  /// The vertex index, for [RouteStop.atPoint].
  final int? pointIndex;

  /// The distance from the start, for [RouteStop.atDistance].
  final double? distance;

  /// How long to wait.
  final Duration duration;
}
