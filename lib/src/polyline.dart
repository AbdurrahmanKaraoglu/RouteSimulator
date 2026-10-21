import 'geo.dart';

/// Decodes a Google [encoded polyline](https://developers.google.com/maps/documentation/utilities/polylinealgorithm).
///
/// Use `precision: 6` for polylines from OSRM/Valhalla `polyline6`. Throws [FormatException] for an invalid string.
List<GeoPoint> decodePolyline(String encoded, {int precision = 5}) {
  final factor = _factor(precision);
  final points = <GeoPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  int next() {
    // Arithmetic instead of bit operators: on the web those truncate to 32 bits.
    var result = 0;
    var weight = 1;
    var chunks = 0;
    while (true) {
      if (index >= encoded.length) {
        throw FormatException('Truncated polyline', encoded, index);
      }
      final b = encoded.codeUnitAt(index++) - 63;
      if (b < 0 || b > 63) {
        throw FormatException('Invalid polyline character', encoded, index - 1);
      }
      result += (b % 32) * weight;
      weight *= 32;
      if (b < 32) break;
      if (++chunks > 7) throw FormatException('Polyline value too long', encoded, index);
    }
    return result.isOdd ? -(result ~/ 2) - 1 : result ~/ 2;
  }

  while (index < encoded.length) {
    lat += next();
    lng += next();
    points.add(GeoPoint(lat / factor, lng / factor));
  }
  return points;
}

/// Encodes [points] as a Google encoded polyline. Altitudes are ignored.
String encodePolyline(Iterable<GeoPoint> points, {int precision = 5}) {
  final factor = _factor(precision);
  final out = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;

  void write(int value) {
    var v = value < 0 ? -value * 2 - 1 : value * 2;
    while (v >= 32) {
      out.writeCharCode(32 + v % 32 + 63);
      v ~/= 32;
    }
    out.writeCharCode(v + 63);
  }

  for (final p in points) {
    final lat = (p.latitude * factor).round();
    final lng = (p.longitude * factor).round();
    write(lat - prevLat);
    write(lng - prevLng);
    prevLat = lat;
    prevLng = lng;
  }
  return out.toString();
}

int _factor(int precision) {
  if (precision < 0 || precision > 7) {
    throw ArgumentError.value(precision, 'precision', 'must be between 0 and 7');
  }
  var f = 1;
  for (var i = 0; i < precision; i++) {
    f *= 10;
  }
  return f;
}
