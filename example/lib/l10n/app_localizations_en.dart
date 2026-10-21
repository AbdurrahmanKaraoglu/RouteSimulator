// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Route Simulator';

  @override
  String get routeTitle => 'Route';

  @override
  String get presetCity => 'City loop';

  @override
  String get presetHighway => 'Highway (polyline)';

  @override
  String routeSummary(String km, int points, String duration) {
    return '$km km · $points points · one lap $duration';
  }

  @override
  String get settingsTitle => 'Simulation';

  @override
  String get profileConstant => 'Constant';

  @override
  String get profileRealistic => 'Realistic';

  @override
  String speedLabel(int speed) {
    return 'Speed: $speed km/h';
  }

  @override
  String noiseLabel(int meters) {
    return 'GPS noise: $meters m';
  }

  @override
  String get signalLoss => 'Signal loss';

  @override
  String get jumps => 'Multipath jumps';

  @override
  String get stopHalfway => 'Stop 20 s halfway';

  @override
  String get loop => 'Loop';

  @override
  String get playback => 'Playback';

  @override
  String get start => 'Start';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get stop => 'Stop';

  @override
  String get stateIdle => 'Ready';

  @override
  String get stateRunning => 'Running';

  @override
  String get statePaused => 'Paused';

  @override
  String get stateFinished => 'Finished';

  @override
  String get liveTitle => 'Live fix';

  @override
  String get speed => 'Speed';

  @override
  String get accuracy => 'Accuracy';

  @override
  String get heading => 'Heading';

  @override
  String get distance => 'Distance';

  @override
  String get lap => 'Lap';

  @override
  String get fixes => 'Fixes';

  @override
  String get noFixYet => 'Press Start to begin the simulation.';

  @override
  String get trackTitle => 'Track';

  @override
  String get trackLegend => 'Grey: route · Blue: simulated fixes · Red: jumps';

  @override
  String get speedChartTitle => 'Speed over time';

  @override
  String get logTitle => 'Recent fixes';

  @override
  String get tagStopped => 'stop';

  @override
  String get tagJump => 'jump';

  @override
  String get exportGpx => 'Export GPX';

  @override
  String gpxDialogTitle(int count) {
    return 'GPX track ($count points)';
  }

  @override
  String get copy => 'Copy';

  @override
  String get close => 'Close';

  @override
  String get copied => 'GPX copied to the clipboard';

  @override
  String seedLabel(int seed) {
    return 'Seed $seed';
  }
}
