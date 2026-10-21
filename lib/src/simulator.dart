import 'dart:async';
import 'dart:math' as math;

import 'geo.dart';
import 'location.dart';
import 'motion.dart';
import 'noise.dart';
import 'profile.dart';
import 'route.dart';

/// Playback state of a [RouteSimulator].
enum SimulatorState {
  /// Not started, or stopped with [RouteSimulator.stop].
  idle,

  /// Emitting locations.
  running,

  /// Paused with [RouteSimulator.pause].
  paused,

  /// Reached the end of a non-looping route.
  finished,
}

const _saltHorizontal = 1;
const _saltAltitude = 2;
const _saltSpeed = 3;
const _saltJump = 4;
const _saltDropout = 5;
const _saltAccuracy = 6;

/// Produces a realistic fake location stream along a [SimRoute].
///
/// Time is simulated: every [interval] of simulated time one location is emitted, and the timer fires every
/// `interval / playbackRate` of real time. Because only [Timer] is used, the stream works under `fake_async`.
/// For tests and offline use, [locationAt] and [generate] compute locations without any timer.
class RouteSimulator {
  /// Creates a simulator. Throws [ArgumentError] for invalid settings.
  RouteSimulator({
    required this.route,
    this.profile = const SpeedProfile.constant(13.9),
    List<RouteStop> stops = const [],
    this.loop = false,
    this.noise = GpsNoise.none,
    this.interval = const Duration(seconds: 1),
    double playbackRate = 1,
    this.startTime,
    this.defaultAltitude = 0,
    this.provider = 'route_simulator',
  }) : stops = List.unmodifiable(stops),
       _plan = MotionPlan(route, profile, stops) {
    noise.validate();
    if (interval <= Duration.zero) throw ArgumentError.value(interval, 'interval', 'must be positive');
    _checkRate(playbackRate);
    _playbackRate = playbackRate;
  }

  /// Route to travel along.
  final SimRoute route;

  /// Speed profile.
  final SpeedProfile profile;

  /// Waits along the route.
  final List<RouteStop> stops;

  /// Whether to start over at the beginning after the end.
  final bool loop;

  /// GPS error model.
  final GpsNoise noise;

  /// Simulated time between two locations.
  final Duration interval;

  /// Time of the first location. When `null`, [start] uses the current time.
  final DateTime? startTime;

  /// Altitude in metres used when the route points have none.
  final double defaultAltitude;

  /// Value of [SimulatedLocation.provider].
  final String provider;

  final MotionPlan _plan;
  late double _playbackRate;
  final _controller = StreamController<SimulatedLocation>.broadcast();
  final _stateController = StreamController<SimulatorState>.broadcast();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  SimulatorState _state = SimulatorState.idle;
  DateTime? _epoch;

  /// Length of the route in metres.
  double get length => route.length;

  /// Duration of one lap, including stops.
  Duration get lapDuration => Duration(microseconds: (_plan.duration * 1e6).round());

  /// Simulated time since the start.
  Duration get elapsed => _elapsed;

  /// Current playback state.
  SimulatorState get state => _state;

  /// Broadcast stream of locations. Listen before calling [start].
  Stream<SimulatedLocation> get locations => _controller.stream;

  /// Broadcast stream of state changes.
  Stream<SimulatorState> get states => _stateController.stream;

  /// Simulated seconds per real second (1 = real time, 10 = ten times faster).
  double get playbackRate => _playbackRate;

  set playbackRate(double value) {
    _checkRate(value);
    _playbackRate = value;
    if (_state == SimulatorState.running) _schedule();
  }

  /// Starts emitting from the beginning. The first location is emitted right away.
  ///
  /// Calling it while running or paused restarts the simulation.
  void start() {
    _ensureOpen();
    _epoch = startTime ?? DateTime.now();
    _elapsed = Duration.zero;
    _setState(SimulatorState.running);
    _emit();
    _schedule();
  }

  /// Pauses emission. Simulated time does not advance while paused.
  void pause() {
    if (_state != SimulatorState.running) return;
    _timer?.cancel();
    _setState(SimulatorState.paused);
  }

  /// Continues after [pause].
  void resume() {
    if (_state != SimulatorState.paused) return;
    _setState(SimulatorState.running);
    _schedule();
  }

  /// Stops and rewinds to the start.
  void stop() {
    _timer?.cancel();
    _elapsed = Duration.zero;
    if (_state != SimulatorState.idle) _setState(SimulatorState.idle);
  }

  /// Jumps to [position] of simulated time. While running, a location for the new position is emitted right away.
  ///
  /// Without [loop] the position is clamped to [lapDuration]; seeking a finished simulation to an earlier time
  /// pauses it there.
  void seek(Duration position) {
    _ensureOpen();
    var p = position.isNegative ? Duration.zero : position;
    if (!loop && p > lapDuration) p = lapDuration;
    _elapsed = p;
    if (_state == SimulatorState.finished && p < lapDuration) _setState(SimulatorState.paused);
    if (_state == SimulatorState.running) {
      _emit();
      if (!loop && p >= lapDuration) {
        _finish();
      } else {
        _schedule();
      }
    }
  }

  /// Stops the simulator and closes its streams.
  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
    await _stateController.close();
  }

  /// Noise-free location at [elapsed] simulated time.
  SimulatedLocation truthAt(Duration elapsed) => _build(elapsed, withNoise: false)!;

  /// Location at [elapsed] simulated time, or `null` when it falls into a simulated signal loss.
  ///
  /// The result depends only on the settings and [elapsed], never on playback history.
  SimulatedLocation? locationAt(Duration elapsed) => _build(elapsed, withNoise: true);

  /// All locations from the start every [every] (default [interval]) of simulated time, skipping signal losses.
  ///
  /// Without [loop] it covers one lap including the final position; with [loop], [until] is required.
  List<SimulatedLocation> generate({Duration? every, Duration? until}) {
    final step = every ?? interval;
    if (step <= Duration.zero) throw ArgumentError.value(step, 'every', 'must be positive');
    if (loop && until == null) throw ArgumentError.notNull('until');
    final end = until ?? lapDuration;
    final out = <SimulatedLocation>[];
    var t = Duration.zero;
    while (true) {
      final reachedEnd = t >= end;
      final loc = locationAt(reachedEnd ? end : t);
      if (loc != null) out.add(loc);
      if (reachedEnd) break;
      t += step;
    }
    return out;
  }

  void _schedule() {
    _timer?.cancel();
    final period = Duration(microseconds: math.max(1, (interval.inMicroseconds / _playbackRate).round()));
    _timer = Timer.periodic(period, (_) => _tick());
  }

  void _tick() {
    _elapsed += interval;
    if (!loop && _elapsed >= lapDuration) {
      _elapsed = lapDuration;
      _emit();
      _finish();
      return;
    }
    _emit();
  }

  void _finish() {
    _timer?.cancel();
    _setState(SimulatorState.finished);
  }

  void _emit() {
    final loc = locationAt(_elapsed);
    if (loc != null && !_controller.isClosed) _controller.add(loc);
  }

  void _setState(SimulatorState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  void _ensureOpen() {
    if (_controller.isClosed) throw StateError('RouteSimulator has been disposed');
  }

  static void _checkRate(double rate) {
    if (!(rate > 0) || !rate.isFinite) throw ArgumentError.value(rate, 'playbackRate', 'must be positive');
  }

  SimulatedLocation? _build(Duration elapsed, {required bool withNoise}) {
    final total = elapsed.isNegative ? 0 : elapsed.inMicroseconds;
    final lapMicros = math.max(1, lapDuration.inMicroseconds);
    var lap = 0;
    var local = total;
    if (loop) {
      lap = total ~/ lapMicros;
      local = total % lapMicros;
    } else if (local > lapMicros) {
      local = lapMicros;
    }

    final key = total ~/ 1000; // noise is keyed by elapsed milliseconds
    final n = noise;
    if (withNoise && n.dropoutProbability > 0) {
      final window = total ~/ n.dropoutDuration.inMicroseconds;
      if (NoiseRandom(n.seed, window, _saltDropout).nextDouble() < n.dropoutProbability) return null;
    }

    final motion = _plan.stateAt(local / 1e6);
    final pos = route.positionAt(motion.distance);
    var point = pos.point;
    var altitude = point.altitude ?? defaultAltitude;
    var speed = motion.speed;
    var accuracy = 1.0;
    var isJump = false;

    if (withNoise && !n.isNone) {
      final h = NoiseRandom(n.seed, key, _saltHorizontal);
      final north = h.nextGaussian() * n.horizontalError;
      final east = h.nextGaussian() * n.horizontalError;
      var offset = math.sqrt(north * north + east * east);
      var bearing = math.atan2(east, north) * 180 / math.pi;
      if (n.jumpProbability > 0) {
        final j = NoiseRandom(n.seed, key, _saltJump);
        if (j.nextDouble() < n.jumpProbability) {
          isJump = true;
          final jb = j.nextDouble() * 2 * math.pi;
          final jn = north + math.cos(jb) * n.jumpDistance;
          final je = east + math.sin(jb) * n.jumpDistance;
          offset = math.sqrt(jn * jn + je * je);
          bearing = math.atan2(je, jn) * 180 / math.pi;
        }
      }
      if (offset > 0) point = offsetPoint(point, offset, bearing);
      altitude += NoiseRandom(n.seed, key, _saltAltitude).nextGaussian() * n.altitudeError;
      speed = math.max(0, speed + NoiseRandom(n.seed, key, _saltSpeed).nextGaussian() * n.speedError);
      final base = n.accuracy ?? math.max(1.0, 1.51 * n.horizontalError);
      accuracy = n.accuracy ?? base * (0.8 + 0.4 * NoiseRandom(n.seed, key, _saltAccuracy).nextDouble());
    } else if (withNoise && n.accuracy != null) {
      accuracy = n.accuracy!;
    }

    final epoch = _epoch ?? startTime ?? DateTime.now();
    return SimulatedLocation(
      latitude: point.latitude,
      longitude: point.longitude,
      accuracy: accuracy,
      altitude: altitude,
      speed: speed,
      speedAccuracy: withNoise ? n.speedError : 0,
      heading: pos.heading,
      time: epoch.add(Duration(microseconds: total)),
      provider: provider,
      elapsed: Duration(microseconds: total),
      distance: motion.distance,
      lap: lap,
      isStopped: motion.isStopped,
      isJump: isJump,
    );
  }
}

/// Convenience: a [GeoPoint] for [location].
extension SimulatedLocationPoint on SimulatedLocation {
  /// The fix as a [GeoPoint] including altitude.
  GeoPoint get point => GeoPoint(latitude, longitude, altitude: altitude);
}
