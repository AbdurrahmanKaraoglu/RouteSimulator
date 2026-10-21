import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:route_simulator/route_simulator.dart';

import 'l10n/app_localizations.dart';

const _brandNavy = Color(0xFF0B2545);
const _brandBlue = Color(0xFF1D4ED8);
const _border = Color(0xFFE2E8F0);
const _muted = Color(0xFF64748B);
const _seed = 42;

void main() {
  runApp(const SimulatorDemoApp());
}

class SimulatorDemoApp extends StatelessWidget {
  const SimulatorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandNavy,
      primary: _brandNavy,
      secondary: _brandBlue,
    );
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: _brandNavy,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: _brandNavy,
            selectedForegroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
      home: const SimulatorScreen(),
    );
  }
}

enum _Preset { city, highway }

/// A loop around Kadıköy, Istanbul, given as points.
final _cityRoute = SimRoute(const [
  GeoPoint(40.99090, 29.02350),
  GeoPoint(40.98960, 29.02540),
  GeoPoint(40.98780, 29.02620),
  GeoPoint(40.98570, 29.02690),
  GeoPoint(40.98400, 29.02810),
  GeoPoint(40.98250, 29.02950),
  GeoPoint(40.98330, 29.03190),
  GeoPoint(40.98520, 29.03250),
  GeoPoint(40.98760, 29.03180),
  GeoPoint(40.98950, 29.02980),
  GeoPoint(40.99090, 29.02350),
]);

/// Göztepe → Bostancı, given as an encoded polyline (e.g. from google_maps_polyline or the Routes API).
final _highwayRoute = SimRoute.fromEncodedPolyline(
  r'okdyF{yjpDjRs{@fOgw@bj@_cBf^w|And@giBnd@_cB',
);

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  _Preset _preset = _Preset.city;
  bool _realistic = true;
  double _speedKmh = 40;
  double _noise = 4;
  bool _signalLoss = false;
  bool _jumps = false;
  bool _stopHalfway = true;
  bool _loop = false;
  double _rate = 5;

  late RouteSimulator _sim;
  bool _hasSim = false;
  StreamSubscription<SimulatedLocation>? _locSub;
  StreamSubscription<SimulatorState>? _stateSub;
  final _fixes = <SimulatedLocation>[];
  int _fixCount = 0;

  SimRoute get _route => _preset == _Preset.city ? _cityRoute : _highwayRoute;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _stateSub?.cancel();
    _sim.dispose();
    super.dispose();
  }

  /// Recreates the simulator after a setting changed.
  void _rebuild() {
    _locSub?.cancel();
    _stateSub?.cancel();
    if (_hasSim) _sim.dispose();
    final route = _route;
    final speed = _speedKmh / 3.6;
    _sim = RouteSimulator(
      route: route,
      profile: _realistic
          ? SpeedProfile.realistic(cruiseSpeed: speed)
          : SpeedProfile.constant(speed),
      stops: _stopHalfway
          ? [
              RouteStop.atDistance(
                route.length / 2,
                const Duration(seconds: 20),
              ),
            ]
          : const [],
      loop: _loop,
      noise: GpsNoise(
        horizontalError: _noise,
        altitudeError: _noise,
        seed: _seed,
        jumpProbability: _jumps ? 0.05 : 0,
        dropoutProbability: _signalLoss ? 0.15 : 0,
      ),
      playbackRate: _rate,
      defaultAltitude: 30,
    );
    _hasSim = true;
    _fixes.clear();
    _fixCount = 0;
    _locSub = _sim.locations.listen((l) {
      setState(() {
        _fixCount++;
        _fixes.add(l);
        if (_fixes.length > 600) _fixes.removeAt(0);
      });
    });
    _stateSub = _sim.states.listen((_) => setState(() {}));
  }

  void _change(VoidCallback update) {
    setState(() {
      update();
      _rebuild();
    });
  }

  Future<void> _exportGpx() async {
    final l = AppLocalizations.of(context);
    final points = _sim.generate(until: _loop ? _sim.lapDuration : null);
    final gpx = toGpx(points, name: l.appTitle);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.gpxDialogTitle(points.length)),
        content: SizedBox(
          width: 520,
          height: 320,
          child: SingleChildScrollView(
            child: SelectableText(
              gpx,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.close),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: Text(l.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: gpx));
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l.copied)));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = [
      _routeCard(l),
      _settingsCard(l),
      _controlsCard(l),
      _liveCard(l),
      _Section(
        title: l.trackTitle,
        subtitle: l.trackLegend,
        child: AspectRatio(
          aspectRatio: 1.4,
          child: CustomPaint(painter: _TrackPainter(_route, _fixes)),
        ),
      ),
      _Section(
        title: l.speedChartTitle,
        child: SizedBox(
          height: 160,
          child: CustomPaint(painter: _SpeedPainter(_fixes, _speedKmh)),
        ),
      ),
      _logCard(l),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            tooltip: l.exportGpx,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportGpx,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 900) {
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => sections[i],
            );
          }
          Widget column(List<Widget> children) => Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => children[i],
            ),
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column(sections.sublist(0, 3)),
              column(sections.sublist(3)),
            ],
          );
        },
      ),
    );
  }

  Widget _routeCard(AppLocalizations l) {
    final km = NumberFormat(
      '0.00',
      Localizations.localeOf(context).toString(),
    ).format(_route.length / 1000);
    return _Section(
      title: l.routeTitle,
      subtitle: l.routeSummary(
        km,
        _route.points.length,
        _formatDuration(_sim.lapDuration),
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_Preset>(
          segments: [
            ButtonSegment(
              value: _Preset.city,
              label: Text(l.presetCity),
              icon: const Icon(Icons.location_city),
            ),
            ButtonSegment(
              value: _Preset.highway,
              label: Text(l.presetHighway),
              icon: const Icon(Icons.route),
            ),
          ],
          selected: {_preset},
          onSelectionChanged: (s) => _change(() => _preset = s.first),
        ),
      ),
    );
  }

  Widget _settingsCard(AppLocalizations l) {
    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(label),
          value: value,
          onChanged: (v) => _change(() => onChanged(v)),
        );

    return _Section(
      title: l.settingsTitle,
      subtitle: l.seedLabel(_seed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l.profileConstant)),
              ButtonSegment(value: true, label: Text(l.profileRealistic)),
            ],
            selected: {_realistic},
            onSelectionChanged: (s) => _change(() => _realistic = s.first),
          ),
          const SizedBox(height: 8),
          Text(l.speedLabel(_speedKmh.round())),
          Slider(
            value: _speedKmh,
            min: 10,
            max: 120,
            divisions: 22,
            label: '${_speedKmh.round()}',
            onChanged: (v) => setState(() => _speedKmh = v),
            onChangeEnd: (v) => _change(() => _speedKmh = v),
          ),
          Text(l.noiseLabel(_noise.round())),
          Slider(
            value: _noise,
            max: 20,
            divisions: 20,
            label: '${_noise.round()}',
            onChanged: (v) => setState(() => _noise = v),
            onChangeEnd: (v) => _change(() => _noise = v),
          ),
          toggle(l.signalLoss, _signalLoss, (v) => _signalLoss = v),
          toggle(l.jumps, _jumps, (v) => _jumps = v),
          toggle(l.stopHalfway, _stopHalfway, (v) => _stopHalfway = v),
          toggle(l.loop, _loop, (v) => _loop = v),
        ],
      ),
    );
  }

  Widget _controlsCard(AppLocalizations l) {
    final state = _sim.state;
    final lap = _sim.lapDuration;
    final elapsed = _sim.elapsed;
    final position = _loop
        ? Duration(
            microseconds:
                elapsed.inMicroseconds % math.max(1, lap.inMicroseconds),
          )
        : elapsed;
    final stateLabel = switch (state) {
      SimulatorState.idle => l.stateIdle,
      SimulatorState.running => l.stateRunning,
      SimulatorState.paused => l.statePaused,
      SimulatorState.finished => l.stateFinished,
    };
    return _Section(
      title: l.playback,
      trailing: Chip(
        label: Text(stateLabel),
        visualDensity: VisualDensity.compact,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1×')),
              ButtonSegment(value: 5, label: Text('5×')),
              ButtonSegment(value: 20, label: Text('20×')),
            ],
            selected: {_rate},
            onSelectionChanged: (s) => setState(() {
              _rate = s.first;
              _sim.playbackRate = _rate; // applied without restarting
            }),
          ),
          Slider(
            value: position.inMilliseconds
                .clamp(0, lap.inMilliseconds)
                .toDouble(),
            max: math.max(1, lap.inMilliseconds).toDouble(),
            onChanged: state == SimulatorState.idle
                ? null
                : (v) => setState(
                    () => _sim.seek(Duration(milliseconds: v.round())),
                  ),
          ),
          Row(
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: _muted),
              ),
              const Spacer(),
              Text(_formatDuration(lap), style: const TextStyle(color: _muted)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (state == SimulatorState.running)
                FilledButton.icon(
                  onPressed: _sim.pause,
                  icon: const Icon(Icons.pause),
                  label: Text(l.pause),
                )
              else if (state == SimulatorState.paused)
                FilledButton.icon(
                  onPressed: _sim.resume,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l.resume),
                )
              else
                FilledButton.icon(
                  onPressed: () {
                    setState(_fixes.clear);
                    _sim.start();
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l.start),
                ),
              OutlinedButton.icon(
                onPressed: state == SimulatorState.idle ? null : _sim.stop,
                icon: const Icon(Icons.stop),
                label: Text(l.stop),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveCard(AppLocalizations l) {
    final last = _fixes.isEmpty ? null : _fixes.last;
    if (last == null) {
      return _Section(
        title: l.liveTitle,
        child: Text(l.noFixYet, style: const TextStyle(color: _muted)),
      );
    }
    final n = NumberFormat('0.0', Localizations.localeOf(context).toString());
    return _Section(
      title: l.liveTitle,
      subtitle:
          '${last.latitude.toStringAsFixed(6)}, ${last.longitude.toStringAsFixed(6)}',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _Stat(l.speed, '${n.format(last.speed * 3.6)} km/h', Icons.speed),
          _Stat(l.accuracy, '±${n.format(last.accuracy)} m', Icons.gps_fixed),
          _Stat(l.heading, '${last.heading.round()}°', Icons.explore_outlined),
          _Stat(l.distance, '${n.format(last.distance)} m', Icons.straighten),
          _Stat(l.lap, '${last.lap + 1}', Icons.repeat),
          _Stat(l.fixes, '$_fixCount', Icons.place_outlined),
        ],
      ),
    );
  }

  Widget _logCard(AppLocalizations l) {
    final recent = _fixes.reversed.take(12).toList();
    return _Section(
      title: l.logTitle,
      child: recent.isEmpty
          ? Text(l.noFixYet, style: const TextStyle(color: _muted))
          : Column(
              children: [
                for (final f in recent)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      _formatDuration(f.elapsed),
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    title: Text(
                      '${f.latitude.toStringAsFixed(6)}, ${f.longitude.toStringAsFixed(6)}',
                    ),
                    subtitle: Text(
                      '${(f.speed * 3.6).toStringAsFixed(1)} km/h · ±${f.accuracy.toStringAsFixed(1)} m',
                    ),
                    trailing: f.isJump
                        ? _Tag(l.tagJump, Colors.red.shade700)
                        : f.isStopped
                        ? _Tag(l.tagStopped, Colors.orange.shade800)
                        : null,
                  ),
              ],
            ),
    );
  }
}

String _formatDuration(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _brandNavy,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(color: _muted),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _brandBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

/// Plots the route and the fixes in a local equirectangular projection (no map needed).
class _TrackPainter extends CustomPainter {
  _TrackPainter(this.route, this.fixes) : _count = fixes.length;
  final SimRoute route;
  final List<SimulatedLocation> fixes;
  final int _count;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = route.points;
    var minLat = pts.map((p) => p.latitude).reduce(math.min);
    var maxLat = pts.map((p) => p.latitude).reduce(math.max);
    var minLng = pts.map((p) => p.longitude).reduce(math.min);
    var maxLng = pts.map((p) => p.longitude).reduce(math.max);
    final pad = 0.08 * math.max(maxLat - minLat, maxLng - minLng);
    minLat -= pad;
    maxLat += pad;
    minLng -= pad;
    maxLng += pad;
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = (maxLng - minLng) * kx;
    final h = maxLat - minLat;
    final scale = math.min(size.width / w, size.height / h);
    final ox = (size.width - w * scale) / 2;
    final oy = (size.height - h * scale) / 2;
    Offset project(double lat, double lng) =>
        Offset(ox + (lng - minLng) * kx * scale, oy + (maxLat - lat) * scale);

    final routePath = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = project(pts[i].latitude, pts[i].longitude);
      i == 0 ? routePath.moveTo(o.dx, o.dy) : routePath.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      routePath,
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final dot = Paint()..color = _brandBlue.withValues(alpha: 0.55);
    final jump = Paint()..color = Colors.red.shade600;
    for (final f in fixes) {
      canvas.drawCircle(
        project(f.latitude, f.longitude),
        f.isJump ? 4 : 2.5,
        f.isJump ? jump : dot,
      );
    }
    if (fixes.isNotEmpty) {
      final last = project(fixes.last.latitude, fixes.last.longitude);
      canvas.drawCircle(last, 9, Paint()..color = Colors.white);
      canvas.drawCircle(last, 7, Paint()..color = _brandNavy);
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.route != route || old._count != _count || fixes.isNotEmpty;
}

/// Speed (km/h) of the recent fixes as a line chart.
class _SpeedPainter extends CustomPainter {
  _SpeedPainter(this.fixes, this.cruiseKmh);
  final List<SimulatedLocation> fixes;
  final double cruiseKmh;

  @override
  void paint(Canvas canvas, Size size) {
    final maxKmh = math.max(cruiseKmh * 1.25, 10);
    final grid = Paint()
      ..color = _border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final cruiseY = size.height * (1 - cruiseKmh / maxKmh);
    canvas.drawLine(
      Offset(0, cruiseY),
      Offset(size.width, cruiseY),
      Paint()
        ..color = _brandNavy.withValues(alpha: 0.35)
        ..strokeWidth = 1.5,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '${cruiseKmh.round()} km/h',
        style: const TextStyle(fontSize: 10, color: _muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(4, math.max(0, cruiseY - tp.height - 2)));

    final recent = fixes.length > 120
        ? fixes.sublist(fixes.length - 120)
        : fixes;
    if (recent.length < 2) return;
    final path = Path();
    for (var i = 0; i < recent.length; i++) {
      final x = size.width * i / 119;
      final y =
          size.height * (1 - (recent[i].speed * 3.6 / maxKmh).clamp(0.0, 1.0));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _brandBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SpeedPainter old) => true;
}
