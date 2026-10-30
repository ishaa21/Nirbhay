import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'translations_en.dart';
import 'translations_hi.dart';
import 'translations_gu.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en', ''));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', ''),
    Locale('hi', ''),
    Locale('gu', ''),
  ];

  Map<String, String> get _currentMap {
    switch (locale.languageCode.toLowerCase()) {
      case 'hi':
        return translationsHi;
      case 'gu':
        return translationsGu;
      case 'en':
      default:
        return translationsEn;
    }
  }

  /// General lookup with English fallback.
  String translate(String key) {
    final map = _currentMap;
    if (map.containsKey(key)) {
      return map[key]!;
    }
    // Fallback to English
    if (translationsEn.containsKey(key)) {
      return translationsEn[key]!;
    }
    return key;
  }

  /// Shorthand lookup
  String operator [](String key) => translate(key);

  // Common Getters
  String get appName => translate('appName');
  String get appTagline => translate('appTagline');
  String get staySafe => translate('staySafe');
  String get ok => translate('ok');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get submit => translate('submit');
  String get done => translate('done');
  String get loading => translate('loading');
  String get retry => translate('retry');
  String get error => translate('error');
  String get success => translate('success');
  String get close => translate('close');
  String get back => translate('back');
  String get search => translate('search');
  String get copy => translate('copy');
  String get share => translate('share');
  String get copiedToClipboard => translate('copiedToClipboard');
  String get openInGoogleMaps => translate('openInGoogleMaps');
  String get viewDetails => translate('viewDetails');
  String get permissionRequired => translate('permissionRequired');
  String get enabled => translate('enabled');
  String get disabled => translate('disabled');

  // Navigation
  String get navHome => translate('navHome');
  String get navMap => translate('navMap');
  String get navNearby => translate('navNearby');
  String get navCommunity => translate('navCommunity');
  String get navContacts => translate('navContacts');
  String get navProfile => translate('navProfile');
  String get navSettings => translate('navSettings');

  // Greetings & Status
  String get goodMorning => translate('goodMorning');
  String get goodAfternoon => translate('goodAfternoon');
  String get goodEvening => translate('goodEvening');
  String get defaultUser => translate('defaultUser');
  String get shieldActive => translate('shieldActive');
  String get shieldStandby => translate('shieldStandby');
  String get emergencyShieldActive => translate('emergencyShieldActive');
  String get liveGpsStream => translate('liveGpsStream');
  String get awaitingGpsFix => translate('awaitingGpsFix');
  String get gpsAccuracy => translate('gpsAccuracy');
  String get locationUnavailable => translate('locationUnavailable');

  // SOS
  String get tapForSos => translate('tapForSos');
  String get hold3Seconds => translate('hold3Seconds');
  String get sosHolding => translate('sosHolding');
  String get sosEmergencyActivated => translate('sosEmergencyActivated');
  String get sosAlertDispatched => translate('sosAlertDispatched');
  String get resolveSos => translate('resolveSos');
  String get resolveSosConfirm => translate('resolveSosConfirm');
  String get iAmSafeNow => translate('iAmSafeNow');
  String get cancelSos => translate('cancelSos');
  String get triggeringSos => translate('triggeringSos');
  String get sosCancelled => translate('sosCancelled');
  String get sosResolved => translate('sosResolved');

  // Quick Actions
  String get quickActions => translate('quickActions');
  String get fakeCall => translate('fakeCall');
  String get fakeCallSubtitle => translate('fakeCallSubtitle');
  String get safetyTimer => translate('safetyTimer');
  String get safetyTimerSubtitle => translate('safetyTimerSubtitle');
  String get liveJourney => translate('liveJourney');
  String get liveJourneySubtitle => translate('liveJourneySubtitle');
  String get quickEscape => translate('quickEscape');
  String get quickEscapeSubtitle => translate('quickEscapeSubtitle');
  String get emergencyContacts => translate('emergencyContacts');
  String get nearbyHelp => translate('nearbyHelp');
  String get communityHub => translate('communityHub');
  String get emergencyHelplines => translate('emergencyHelplines');

  // Shake SOS
  String get shakeToSos => translate('shakeToSos');
  String get shakeSensitivity => translate('shakeSensitivity');
  String get shakeCountdownTitle => translate('shakeCountdownTitle');
  String get shakeCountdownMessage => translate('shakeCountdownMessage');
  String get cancelCountdown => translate('cancelCountdown');
  String get testShakeFeature => translate('testShakeFeature');
  String get shakePhoneDetected => translate('shakePhoneDetected');

  // Fake Call
  String get incomingCall => translate('incomingCall');
  String get callerPolice => translate('callerPolice');
  String get callerDad => translate('callerDad');
  String get callerMom => translate('callerMom');
  String get callerFriend => translate('callerFriend');
  String get triggerFakeCall => translate('triggerFakeCall');
  String get scheduleIn15s => translate('scheduleIn15s');
  String get scheduleIn30s => translate('scheduleIn30s');
  String get scheduleIn1m => translate('scheduleIn1m');
  String get scheduleIn5m => translate('scheduleIn5m');
  String get acceptCall => translate('acceptCall');
  String get declineCall => translate('declineCall');
  String get callActive => translate('callActive');
  String get endCall => translate('endCall');

  // Safety Timer
  String get setSafetyTimer => translate('setSafetyTimer');
  String get timerInstruction => translate('timerInstruction');
  String get startTimer => translate('startTimer');
  String get stopTimer => translate('stopTimer');
  String get timerRunning => translate('timerRunning');
  String get customTimer => translate('customTimer');
  String get timerExpiredAlert => translate('timerExpiredAlert');
  String get enterPinToStop => translate('enterPinToStop');
  String get incorrectPin => translate('incorrectPin');

  // Live Journey
  String get startJourney => translate('startJourney');
  String get endJourney => translate('endJourney');
  String get shareJourneyLink => translate('shareJourneyLink');
  String get journeyActive => translate('journeyActive');
  String get destination => translate('destination');
  String get journeyStartedSuccess => translate('journeyStartedSuccess');
  String get journeyEndedSuccess => translate('journeyEndedSuccess');
  String get journeyShieldStandby => translate('journeyShieldStandby');
  String get journeyLovedOnesExplanation => translate('journeyLovedOnesExplanation');

  // Emergency Contacts
  String get addEmergencyContact => translate('addEmergencyContact');
  String get contactName => translate('contactName');
  String get contactPhone => translate('contactPhone');
  String get contactRelation => translate('contactRelation');
  String get noContactsAdded => translate('noContactsAdded');
  String get addAtLeastOneContact => translate('addAtLeastOneContact');
  String get contactAdded => translate('contactAdded');
  String get contactDeleted => translate('contactDeleted');
  String get maxContactsReached => translate('maxContactsReached');

  // Helplines
  String get nationalEmergency => translate('nationalEmergency');
  String get policeHelpline => translate('policeHelpline');
  String get womenHelpline => translate('womenHelpline');
  String get domesticAbuseHelpline => translate('domesticAbuseHelpline');
  String get ambulanceHelpline => translate('ambulanceHelpline');
  String get callNow => translate('callNow');

  // Nearby Help
  String get nearbyServices => translate('nearbyServices');
  String get policeStations => translate('policeStations');
  String get hospitals => translate('hospitals');
  String get pharmacies => translate('pharmacies');
  String get fireStations => translate('fireStations');
  String get findingNearby => translate('findingNearby');
  String get noNearbyPlaces => translate('noNearbyPlaces');

  // Community Hub
  String get communitySafetyFeed => translate('communitySafetyFeed');
  String get safetyAlerts => translate('safetyAlerts');
  String get createReport => translate('createReport');
  String get reportDescription => translate('reportDescription');
  String get category => translate('category');
  String get catSuspiciousActivity => translate('catSuspiciousActivity');
  String get catHarassment => translate('catHarassment');
  String get catUnsafeArea => translate('catUnsafeArea');
  String get catTheft => translate('catTheft');
  String get catRoadSafety => translate('catRoadSafety');
  String get catLostPerson => translate('catLostPerson');
  String get catHelpfulInfo => translate('catHelpfulInfo');
  String get catOther => translate('catOther');
  String get filterAll => translate('filterAll');
  String get filterNearby => translate('filterNearby');
  String get filterMostUpvoted => translate('filterMostUpvoted');
  String get myReports => translate('myReports');
  String get upvote => translate('upvote');
  String get comments => translate('comments');
  String get addComment => translate('addComment');
  String get reportPost => translate('reportPost');
  String get reportPostReason => translate('reportPostReason');

  // Settings & Profile
  String get profile => translate('profile');
  String get settings => translate('settings');
  String get language => translate('language');
  String get selectLanguage => translate('selectLanguage');
  String get languageChangedNotice => translate('languageChangedNotice');
  String get currentLanguage => translate('currentLanguage');
  String get notifications => translate('notifications');
  String get soundAndVibration => translate('soundAndVibration');
  String get privacyPolicy => translate('privacyPolicy');
  String get termsOfService => translate('termsOfService');
  String get logout => translate('logout');
  String get confirmLogout => translate('confirmLogout');
  String get editProfile => translate('editProfile');
  String get fullName => translate('fullName');
  String get emailAddress => translate('emailAddress');
  String get phoneNumber => translate('phoneNumber');
  String get bloodGroup => translate('bloodGroup');

  // Auth
  String get signIn => translate('signIn');
  String get signUp => translate('signUp');
  String get email => translate('email');
  String get password => translate('password');
  String get forgotPassword => translate('forgotPassword');
  String get donNotHaveAccount => translate('donNotHaveAccount');
  String get alreadyHaveAccount => translate('alreadyHaveAccount');
  String get invalidEmail => translate('invalidEmail');
  String get invalidPassword => translate('invalidPassword');
  String get passwordsDoNotMatch => translate('passwordsDoNotMatch');
  String get welcomeBack => translate('welcomeBack');
  String get createAccount => translate('createAccount');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'hi', 'gu'].contains(locale.languageCode.toLowerCase());
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
