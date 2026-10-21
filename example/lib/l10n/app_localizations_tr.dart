// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Rota Simülatörü';

  @override
  String get routeTitle => 'Rota';

  @override
  String get presetCity => 'Şehir turu';

  @override
  String get presetHighway => 'Otoyol (polyline)';

  @override
  String routeSummary(String km, int points, String duration) {
    return '$km km · $points nokta · bir tur $duration';
  }

  @override
  String get settingsTitle => 'Simülasyon';

  @override
  String get profileConstant => 'Sabit';

  @override
  String get profileRealistic => 'Gerçekçi';

  @override
  String speedLabel(int speed) {
    return 'Hız: $speed km/sa';
  }

  @override
  String noiseLabel(int meters) {
    return 'GPS gürültüsü: $meters m';
  }

  @override
  String get signalLoss => 'Sinyal kaybı';

  @override
  String get jumps => 'Yansıma sıçramaları';

  @override
  String get stopHalfway => 'Yarı yolda 20 sn dur';

  @override
  String get loop => 'Döngü';

  @override
  String get playback => 'Oynatma hızı';

  @override
  String get start => 'Başlat';

  @override
  String get pause => 'Duraklat';

  @override
  String get resume => 'Devam';

  @override
  String get stop => 'Durdur';

  @override
  String get stateIdle => 'Hazır';

  @override
  String get stateRunning => 'Çalışıyor';

  @override
  String get statePaused => 'Duraklatıldı';

  @override
  String get stateFinished => 'Bitti';

  @override
  String get liveTitle => 'Anlık konum';

  @override
  String get speed => 'Hız';

  @override
  String get accuracy => 'Doğruluk';

  @override
  String get heading => 'Yön';

  @override
  String get distance => 'Mesafe';

  @override
  String get lap => 'Tur';

  @override
  String get fixes => 'Konum';

  @override
  String get noFixYet => 'Simülasyonu başlatmak için Başlat\'a dokunun.';

  @override
  String get trackTitle => 'İz';

  @override
  String get trackLegend =>
      'Gri: rota · Mavi: simüle konumlar · Kırmızı: sıçramalar';

  @override
  String get speedChartTitle => 'Zamana göre hız';

  @override
  String get logTitle => 'Son konumlar';

  @override
  String get tagStopped => 'durak';

  @override
  String get tagJump => 'sıçrama';

  @override
  String get exportGpx => 'GPX dışa aktar';

  @override
  String gpxDialogTitle(int count) {
    return 'GPX izi ($count nokta)';
  }

  @override
  String get copy => 'Kopyala';

  @override
  String get close => 'Kapat';

  @override
  String get copied => 'GPX panoya kopyalandı';

  @override
  String seedLabel(int seed) {
    return 'Seed $seed';
  }
}
