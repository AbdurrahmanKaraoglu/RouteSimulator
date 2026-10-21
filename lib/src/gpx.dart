import 'location.dart';

/// Writes [locations] as a GPX 1.1 track (`<trk>` with one `<trkseg>`).
///
/// Each point has latitude, longitude, `<ele>` and a UTC `<time>`; the result opens in tools such as GPX viewers,
/// Android Studio's emulator location panel or Xcode's location simulation.
String toGpx(
  Iterable<SimulatedLocation> locations, {
  String name = 'route_simulator',
  String creator = 'route_simulator',
}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="${_escape(creator)}" xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">',
    )
    ..writeln('  <trk>')
    ..writeln('    <name>${_escape(name)}</name>')
    ..writeln('    <trkseg>');
  for (final l in locations) {
    b
      ..writeln('      <trkpt lat="${l.latitude.toStringAsFixed(7)}" lon="${l.longitude.toStringAsFixed(7)}">')
      ..writeln('        <ele>${l.altitude.toStringAsFixed(1)}</ele>')
      ..writeln('        <time>${l.time.toUtc().toIso8601String()}</time>')
      ..writeln('      </trkpt>');
  }
  b
    ..writeln('    </trkseg>')
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return b.toString();
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
