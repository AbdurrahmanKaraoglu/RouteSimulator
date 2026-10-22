import 'dart:math' as math;

/// Mean Earth radius in metres (IUGG).
const double earthRadius = 6371008.8;

/// A geographic coordinate with an optional altitude in metres.
class GeoPoint {
  /// Creates a point from [latitude] and [longitude] in degrees and an optional [altitude] in metres.
  const GeoPoint(this.latitude, this.longitude, {this.altitude});

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// Altitude in metres above sea level, if known.
  final double? altitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude && other.altitude == altitude;

  @override
  int get hashCode => Object.hash(latitude, longitude, altitude);

  @override
  String toString() =>
      altitude == null ? 'GeoPoint($latitude, $longitude)' : 'GeoPoint($latitude, $longitude, altitude: $altitude)';
}

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;

/// Great-circle distance between [a] and [b] in metres (haversine).
double distanceBetween(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// Initial bearing from [a] to [b] in degrees, clockwise from north, in `[0, 360)`.
double bearingBetween(GeoPoint a, GeoPoint b) {
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Point at [fraction] (0..1) of the way from [a] to [b].
///
/// Linear in latitude/longitude, which is accurate for the short segments of a road route.
GeoPoint interpolate(GeoPoint a, GeoPoint b, double fraction) {
  final altA = a.altitude;
  final altB = b.altitude;
  return GeoPoint(
    a.latitude + (b.latitude - a.latitude) * fraction,
    a.longitude + (b.longitude - a.longitude) * fraction,
    altitude: altA != null && altB != null ? altA + (altB - altA) * fraction : altA ?? altB,
  );
}

/// The point [distance] metres from [origin] in direction [bearing] (degrees).
GeoPoint offsetPoint(GeoPoint origin, double distance, double bearing) {
  final angular = distance / earthRadius;
  final theta = _rad(bearing);
  final lat1 = _rad(origin.latitude);
  final lng1 = _rad(origin.longitude);
  final lat2 = math.asin(math.sin(lat1) * math.cos(angular) + math.cos(lat1) * math.sin(angular) * math.cos(theta));
  final lng2 =
      lng1 +
      math.atan2(
        math.sin(theta) * math.sin(angular) * math.cos(lat1),
        math.cos(angular) - math.sin(lat1) * math.sin(lat2),
      );
  return GeoPoint(_deg(lat2), (_deg(lng2) + 540) % 360 - 180, altitude: origin.altitude);
}

/// Smallest absolute difference between two bearings, in `[0, 180]`.
double bearingDifference(double a, double b) {
  final d = ((b - a) % 360 + 360) % 360;
  return d > 180 ? 360 - d : d;
}
