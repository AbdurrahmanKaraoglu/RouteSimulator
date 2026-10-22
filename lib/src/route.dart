import 'geo.dart';
import 'polyline.dart';

/// A position on a [SimRoute].
class RoutePosition {
  /// Creates a position; produced by [SimRoute.positionAt].
  const RoutePosition({required this.point, required this.heading, required this.distance, required this.segmentIndex});

  /// The point on the route (altitude interpolated when the vertices have one).
  final GeoPoint point;

  /// Direction of travel in degrees, clockwise from north.
  final double heading;

  /// Distance from the start of the route in metres.
  final double distance;

  /// Index of the segment `points[segmentIndex] → points[segmentIndex + 1]`.
  final int segmentIndex;
}

/// An ordered list of points to travel along.
///
/// Consecutive duplicate points are dropped so that every segment has a length.
class SimRoute {
  /// Creates a route from at least two distinct points.
  SimRoute(Iterable<GeoPoint> points) : points = List.unmodifiable(_dedupe(points)) {
    if (this.points.length < 2) {
      throw ArgumentError.value(points, 'points', 'needs at least two distinct points');
    }
    final cumulative = List<double>.filled(this.points.length, 0);
    final headings = List<double>.filled(this.points.length - 1, 0);
    for (var i = 1; i < this.points.length; i++) {
      cumulative[i] = cumulative[i - 1] + distanceBetween(this.points[i - 1], this.points[i]);
      headings[i - 1] = bearingBetween(this.points[i - 1], this.points[i]);
    }
    _cumulative = cumulative;
    _headings = headings;
  }

  /// Creates a route from a Google encoded polyline (see [decodePolyline]).
  factory SimRoute.fromEncodedPolyline(String encoded, {int precision = 5}) =>
      SimRoute(decodePolyline(encoded, precision: precision));

  /// The route vertices.
  final List<GeoPoint> points;

  late final List<double> _cumulative;
  late final List<double> _headings;

  /// Total length in metres.
  double get length => _cumulative.last;

  /// Distance of vertex [index] from the start, in metres.
  double distanceOfPoint(int index) => _cumulative[index];

  /// Heading of segment [index] in degrees.
  double headingOfSegment(int index) => _headings[index];

  /// How sharply the route turns at vertex [index], in degrees (0 = straight on, 180 = U-turn).
  ///
  /// The first and last vertices return 0.
  double turnAngleAt(int index) {
    if (index <= 0 || index >= points.length - 1) return 0;
    return bearingDifference(_headings[index - 1], _headings[index]);
  }

  /// The position [distance] metres from the start. Values outside `[0, length]` are clamped.
  RoutePosition positionAt(double distance) {
    final d = distance.clamp(0.0, length);
    var lo = 0;
    var hi = points.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_cumulative[mid] <= d) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final segLength = _cumulative[lo + 1] - _cumulative[lo];
    final fraction = segLength == 0 ? 0.0 : (d - _cumulative[lo]) / segLength;
    return RoutePosition(
      point: interpolate(points[lo], points[lo + 1], fraction),
      heading: _headings[lo],
      distance: d,
      segmentIndex: lo,
    );
  }

  static List<GeoPoint> _dedupe(Iterable<GeoPoint> input) {
    final out = <GeoPoint>[];
    for (final p in input) {
      if (!p.latitude.isFinite || !p.longitude.isFinite) {
        throw ArgumentError.value(p, 'points', 'contains a non-finite coordinate');
      }
      if (out.isEmpty || distanceBetween(out.last, p) > 1e-3) out.add(p);
    }
    return out;
  }
}
