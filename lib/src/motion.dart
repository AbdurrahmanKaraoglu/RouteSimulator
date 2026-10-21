import 'dart:math' as math;

import 'profile.dart';
import 'route.dart';

/// Noise-free kinematic state at a moment of one lap.
class MotionState {
  const MotionState({required this.distance, required this.speed, required this.isStopped});

  /// Distance from the start of the route in metres.
  final double distance;

  /// Speed in m/s.
  final double speed;

  /// Whether the device is waiting at a [RouteStop].
  final bool isStopped;
}

class _Node {
  _Node(this.s, this.limit, [this.dwell = 0]);
  final double s;
  double limit;
  double dwell;
  double v = 0;
}

class _Segment {
  const _Segment(this.t0, this.dt, this.s0, this.s1, this.v0, this.a, {this.dwell = false});
  final double t0;
  final double dt;
  final double s0;
  final double s1;
  final double v0;
  final double a;
  final bool dwell;
}

/// Time → distance/speed plan for one lap of a route.
///
/// The route is split into short pieces (at most [maxStep] metres for realistic profiles). Each piece is driven
/// with constant acceleration; speeds at the piece ends respect the cruise speed, corner limits, stops and the
/// acceleration/deceleration limits (forward and backward pass).
class MotionPlan {
  MotionPlan._(this._segments, this.duration);

  /// Maximum piece length in metres for realistic profiles.
  static const double maxStep = 5;

  /// Builds the plan. Throws [ArgumentError] for invalid profiles or stops.
  factory MotionPlan(SimRoute route, SpeedProfile profile, List<RouteStop> stops) {
    profile.validate();
    final length = route.length;
    final constant = profile.isConstant;
    final cruise = profile.cruiseSpeed;

    final candidates = <_Node>[
      _Node(0, constant ? cruise : 0),
      _Node(length, constant ? cruise : 0),
      for (var i = 1; i < route.points.length - 1; i++)
        _Node(route.distanceOfPoint(i), constant ? cruise : profile.cornerLimit(route.turnAngleAt(i))),
    ];
    for (final stop in stops) {
      if (stop.duration.isNegative) {
        throw ArgumentError.value(stop.duration, 'stops', 'stop duration must not be negative');
      }
      final index = stop.pointIndex;
      final double d;
      if (index != null) {
        RangeError.checkValidIndex(index, route.points, 'stops');
        d = route.distanceOfPoint(index);
      } else {
        d = stop.distance!;
        if (!(d >= 0 && d <= length)) {
          throw ArgumentError.value(d, 'stops', 'stop distance must be within 0..${route.length}');
        }
      }
      candidates.add(_Node(d, constant ? cruise : 0, stop.duration.inMicroseconds / 1e6));
    }
    candidates.sort((a, b) => a.s.compareTo(b.s));

    final merged = <_Node>[];
    for (final n in candidates) {
      if (merged.isNotEmpty && n.s - merged.last.s < 1e-6) {
        merged.last.limit = math.min(merged.last.limit, n.limit);
        merged.last.dwell += n.dwell;
      } else {
        merged.add(n);
      }
    }

    final nodes = <_Node>[];
    for (var i = 0; i < merged.length; i++) {
      nodes.add(merged[i]);
      if (constant || i == merged.length - 1) continue;
      final gap = merged[i + 1].s - merged[i].s;
      final pieces = (gap / maxStep).ceil();
      for (var k = 1; k < pieces; k++) {
        nodes.add(_Node(merged[i].s + gap * k / pieces, cruise));
      }
    }

    if (constant) {
      for (final n in nodes) {
        n.v = cruise;
      }
    } else {
      nodes.first.v = nodes.first.limit;
      for (var i = 1; i < nodes.length; i++) {
        final d = nodes[i].s - nodes[i - 1].s;
        final reachable = math.sqrt(nodes[i - 1].v * nodes[i - 1].v + 2 * profile.acceleration * d);
        nodes[i].v = math.min(nodes[i].limit, reachable);
      }
      for (var i = nodes.length - 2; i >= 0; i--) {
        final d = nodes[i + 1].s - nodes[i].s;
        final stoppable = math.sqrt(nodes[i + 1].v * nodes[i + 1].v + 2 * profile.deceleration * d);
        nodes[i].v = math.min(nodes[i].v, stoppable);
      }
    }

    final segments = <_Segment>[];
    var t = 0.0;
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      if (n.dwell > 0) {
        segments.add(_Segment(t, n.dwell, n.s, n.s, 0, 0, dwell: true));
        t += n.dwell;
      }
      if (i == nodes.length - 1) break;
      final d = nodes[i + 1].s - n.s;
      final v0 = n.v;
      final v1 = nodes[i + 1].v;
      if (v0 + v1 < 1e-9) {
        // Two stops a hair apart: creep across at the speed the acceleration allows.
        final v = math.max(1e-3, math.min(cruise, math.sqrt(profile.acceleration * d)));
        segments.add(_Segment(t, d / v, n.s, n.s + d, v, 0));
        t += d / v;
        continue;
      }
      final dt = 2 * d / (v0 + v1);
      segments.add(_Segment(t, dt, n.s, n.s + d, v0, (v1 * v1 - v0 * v0) / (2 * d)));
      t += dt;
    }
    return MotionPlan._(segments, t);
  }

  final List<_Segment> _segments;

  /// Duration of one lap in seconds, including stops.
  final double duration;

  /// State [seconds] after the start of the lap (clamped to `[0, duration]`).
  MotionState stateAt(double seconds) {
    if (_segments.isEmpty) return const MotionState(distance: 0, speed: 0, isStopped: false);
    final t = seconds.clamp(0.0, duration);
    var lo = 0;
    var hi = _segments.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_segments[mid].t0 <= t) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final seg = _segments[lo];
    if (seg.dwell && t < seg.t0 + seg.dt) {
      return MotionState(distance: seg.s0, speed: 0, isStopped: true);
    }
    final tau = math.min(t - seg.t0, seg.dt);
    final s = math.min(seg.s1, seg.s0 + seg.v0 * tau + 0.5 * seg.a * tau * tau);
    final v = math.max(0.0, seg.v0 + seg.a * tau);
    return MotionState(distance: s, speed: v, isStopped: false);
  }
}
