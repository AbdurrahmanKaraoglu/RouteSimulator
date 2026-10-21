import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Route Simulator'**
  String get appTitle;

  /// No description provided for @routeTitle.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get routeTitle;

  /// No description provided for @presetCity.
  ///
  /// In en, this message translates to:
  /// **'City loop'**
  String get presetCity;

  /// No description provided for @presetHighway.
  ///
  /// In en, this message translates to:
  /// **'Highway (polyline)'**
  String get presetHighway;

  /// No description provided for @routeSummary.
  ///
  /// In en, this message translates to:
  /// **'{km} km · {points} points · one lap {duration}'**
  String routeSummary(String km, int points, String duration);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get settingsTitle;

  /// No description provided for @profileConstant.
  ///
  /// In en, this message translates to:
  /// **'Constant'**
  String get profileConstant;

  /// No description provided for @profileRealistic.
  ///
  /// In en, this message translates to:
  /// **'Realistic'**
  String get profileRealistic;

  /// No description provided for @speedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed: {speed} km/h'**
  String speedLabel(int speed);

  /// No description provided for @noiseLabel.
  ///
  /// In en, this message translates to:
  /// **'GPS noise: {meters} m'**
  String noiseLabel(int meters);

  /// No description provided for @signalLoss.
  ///
  /// In en, this message translates to:
  /// **'Signal loss'**
  String get signalLoss;

  /// No description provided for @jumps.
  ///
  /// In en, this message translates to:
  /// **'Multipath jumps'**
  String get jumps;

  /// No description provided for @stopHalfway.
  ///
  /// In en, this message translates to:
  /// **'Stop 20 s halfway'**
  String get stopHalfway;

  /// No description provided for @loop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get loop;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stateIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get stateIdle;

  /// No description provided for @stateRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get stateRunning;

  /// No description provided for @statePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statePaused;

  /// No description provided for @stateFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get stateFinished;

  /// No description provided for @liveTitle.
  ///
  /// In en, this message translates to:
  /// **'Live fix'**
  String get liveTitle;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @accuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracy;

  /// No description provided for @heading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get heading;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @lap.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get lap;

  /// No description provided for @fixes.
  ///
  /// In en, this message translates to:
  /// **'Fixes'**
  String get fixes;

  /// No description provided for @noFixYet.
  ///
  /// In en, this message translates to:
  /// **'Press Start to begin the simulation.'**
  String get noFixYet;

  /// No description provided for @trackTitle.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get trackTitle;

  /// No description provided for @trackLegend.
  ///
  /// In en, this message translates to:
  /// **'Grey: route · Blue: simulated fixes · Red: jumps'**
  String get trackLegend;

  /// No description provided for @speedChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed over time'**
  String get speedChartTitle;

  /// No description provided for @logTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent fixes'**
  String get logTitle;

  /// No description provided for @tagStopped.
  ///
  /// In en, this message translates to:
  /// **'stop'**
  String get tagStopped;

  /// No description provided for @tagJump.
  ///
  /// In en, this message translates to:
  /// **'jump'**
  String get tagJump;

  /// No description provided for @exportGpx.
  ///
  /// In en, this message translates to:
  /// **'Export GPX'**
  String get exportGpx;

  /// No description provided for @gpxDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'GPX track ({count} points)'**
  String gpxDialogTitle(int count);

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'GPX copied to the clipboard'**
  String get copied;

  /// No description provided for @seedLabel.
  ///
  /// In en, this message translates to:
  /// **'Seed {seed}'**
  String seedLabel(int seed);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
