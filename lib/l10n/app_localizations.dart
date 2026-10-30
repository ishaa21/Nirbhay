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

  // ──────────────────────────────────────────────────────────────────────────
  // Generated Typed Getters (655 keys)
  // ──────────────────────────────────────────────────────────────────────────
  String get acceptCall => translate('acceptCall');
  String get accountAndSecurity => translate('accountAndSecurity');
  String get acquiringLocation => translate('acquiringLocation');
  String get activateRealSosDesc => translate('activateRealSosDesc');
  String get activateRealSosDialogDesc => translate('activateRealSosDialogDesc');
  String get activateRealSosDialogTitle => translate('activateRealSosDialogTitle');
  String get activateRealSosTitle => translate('activateRealSosTitle');
  String get activeSafetyTimer => translate('activeSafetyTimer');
  String get activeSafetyTimerBanner => translate('activeSafetyTimerBanner');
  String get activeSosIncident => translate('activeSosIncident');
  String get addCommentFieldHint => translate('addCommentFieldHint');
  String get addCommentHint => translate('addCommentHint');
  String get addContact => translate('addContact');
  String get addEmergencyContact => translate('addEmergencyContact');
  String get addFirstContact => translate('addFirstContact');
  String get addNew => translate('addNew');
  String get additionalDetailsOptional => translate('additionalDetailsOptional');
  String get agreeTermsPrefix => translate('agreeTermsPrefix');
  String get agreeTermsValidation => translate('agreeTermsValidation');
  String get alertContactDuringEmergencies => translate('alertContactDuringEmergencies');
  String get allServices => translate('allServices');
  String get allServicesTab => translate('allServicesTab');
  String get alreadyHaveAccount => translate('alreadyHaveAccount');
  String get ambulance108 => translate('ambulance108');
  String get ambulance108Sub => translate('ambulance108Sub');
  String get apexNationalLifeline => translate('apexNationalLifeline');
  String get appName => translate('appName');
  String get appTagline => translate('appTagline');
  String get appTheme => translate('appTheme');
  String get appThemeTitle => translate('appThemeTitle');
  String get approximateArea => translate('approximateArea');
  String get armCallDelayBtn => translate('armCallDelayBtn');
  String get attachCoarseGps => translate('attachCoarseGps');
  String get attachCoarseGpsDesc => translate('attachCoarseGpsDesc');
  String get attachCoordinates => translate('attachCoordinates');
  String get autoAlertBadge => translate('autoAlertBadge');
  String get autoAlertDescription => translate('autoAlertDescription');
  String get autoAlertSms => translate('autoAlertSms');
  String get autoRecordedLines => translate('autoRecordedLines');
  String get automaticSosAlert => translate('automaticSosAlert');
  String get automaticWatchdog => translate('automaticWatchdog');
  String get available247 => translate('available247');
  String get awaitingGpsFix => translate('awaitingGpsFix');
  String get back => translate('back');
  String get bloodGroup => translate('bloodGroup');
  String get call => translate('call');
  String get call112 => translate('call112');
  String get callAction => translate('callAction');
  String get callAdd => translate('callAdd');
  String get callContacts => translate('callContacts');
  String get callKeypad => translate('callKeypad');
  String get callMute => translate('callMute');
  String get callNumber => translate('callNumber');
  String get callSpeaker => translate('callSpeaker');
  String get callVideo => translate('callVideo');
  String get callerBoss => translate('callerBoss');
  String get callerDoctor => translate('callerDoctor');
  String get callerDrSharma => translate('callerDrSharma');
  String get callerEmergencyService => translate('callerEmergencyService');
  String get callerFriendPreset => translate('callerFriendPreset');
  String get callerHome => translate('callerHome');
  String get callerHospital => translate('callerHospital');
  String get callerMobile => translate('callerMobile');
  String get callerNameInputHint => translate('callerNameInputHint');
  String get callerNameInputLabel => translate('callerNameInputLabel');
  String get callerNameLabel => translate('callerNameLabel');
  String get callerOfficeBoss => translate('callerOfficeBoss');
  String get callerPoliceDept => translate('callerPoliceDept');
  String get callerPresets => translate('callerPresets');
  String get callerPriyaFriend => translate('callerPriyaFriend');
  String get callerSubtitleLabel => translate('callerSubtitleLabel');
  String get callerWork => translate('callerWork');
  String get cancel => translate('cancel');
  String get cancelCountdown => translate('cancelCountdown');
  String get cancelFailedSnack => translate('cancelFailedSnack');
  String get cancelScheduledCallBtn => translate('cancelScheduledCallBtn');
  String get cancelSos => translate('cancelSos');
  String get cancelTimer => translate('cancelTimer');
  String get cancelTimerConfirmBtn => translate('cancelTimerConfirmBtn');
  String get cancelTimerDialogBody => translate('cancelTimerDialogBody');
  String get cancelTimerDialogTitle => translate('cancelTimerDialogTitle');
  String get catHarassment => translate('catHarassment');
  String get catHelpfulInfo => translate('catHelpfulInfo');
  String get catLostPerson => translate('catLostPerson');
  String get catOther => translate('catOther');
  String get catRoadSafety => translate('catRoadSafety');
  String get catSuspicious => translate('catSuspicious');
  String get catSuspiciousActivity => translate('catSuspiciousActivity');
  String get catTheft => translate('catTheft');
  String get catUnsafeArea => translate('catUnsafeArea');
  String get checkIn => translate('checkIn');
  String get checkInFailedSnack => translate('checkInFailedSnack');
  String get checkInNowBtn => translate('checkInNowBtn');
  String get checkInSafe => translate('checkInSafe');
  String get checkInSafeDialogBody => translate('checkInSafeDialogBody');
  String get checkInSafeDialogTitle => translate('checkInSafeDialogTitle');
  String get checkedInSafeSuccessSnack => translate('checkedInSafeSuccessSnack');
  String get checkedInSuccess => translate('checkedInSuccess');
  String get child1098 => translate('child1098');
  String get child1098Sub => translate('child1098Sub');
  String get childlineDesc => translate('childlineDesc');
  String get childlineSub => translate('childlineSub');
  String get childlineTitle => translate('childlineTitle');
  String get close => translate('close');
  String get comments => translate('comments');
  String get communityAlerts => translate('communityAlerts');
  String get communityDiscussionHeading => translate('communityDiscussionHeading');
  String get communityFeed => translate('communityFeed');
  String get communityHubHeading => translate('communityHubHeading');
  String get communitySubtitle => translate('communitySubtitle');
  String get configuredBadge => translate('configuredBadge');
  String get confirmLogout => translate('confirmLogout');
  String get confirmLogoutBody => translate('confirmLogoutBody');
  String get connectionErrorPullToRefresh => translate('connectionErrorPullToRefresh');
  String get contactAdded => translate('contactAdded');
  String get contactDeleted => translate('contactDeleted');
  String get contactDeletedSuccess => translate('contactDeletedSuccess');
  String get contactName => translate('contactName');
  String get contactPhone => translate('contactPhone');
  String get contactSavedSuccess => translate('contactSavedSuccess');
  String get contactUpdated => translate('contactUpdated');
  String get contactsHeading => translate('contactsHeading');
  String get contactsSubheading => translate('contactsSubheading');
  String get copiedToClipboard => translate('copiedToClipboard');
  String get copy => translate('copy');
  String get copyDial => translate('copyDial');
  String get couldNotObtainLocation => translate('couldNotObtainLocation');
  String get couldNotUpdateVote => translate('couldNotUpdateVote');
  String get countdownEndedVerifyStatus => translate('countdownEndedVerifyStatus');
  String get createAccount => translate('createAccount');
  String get createReport => translate('createReport');
  String get createStrongPasswordHint => translate('createStrongPasswordHint');
  String get currentLanguage => translate('currentLanguage');
  String get customDuration => translate('customDuration');
  String get customTimerTitle => translate('customTimerTitle');
  String get cyberCrimeDesc => translate('cyberCrimeDesc');
  String get cyberCrimeSub => translate('cyberCrimeSub');
  String get cyberCrimeTitle => translate('cyberCrimeTitle');
  String get dangerousIncitement => translate('dangerousIncitement');
  String get declineCall => translate('declineCall');
  String get defaultUser => translate('defaultUser');
  String get delay10s => translate('delay10s');
  String get delay1m => translate('delay1m');
  String get delay30s => translate('delay30s');
  String get delayInstant => translate('delayInstant');
  String get delete => translate('delete');
  String get deleteContactConfirm => translate('deleteContactConfirm');
  String get deleteContactPrompt => translate('deleteContactPrompt');
  String get deleteContactTitle => translate('deleteContactTitle');
  String get deleteReportAction => translate('deleteReportAction');
  String get deleteSafetyReportDesc => translate('deleteSafetyReportDesc');
  String get deleteSafetyReportDialogDesc => translate('deleteSafetyReportDialogDesc');
  String get deleteSafetyReportDialogTitle => translate('deleteSafetyReportDialogTitle');
  String get deleteSafetyReportTitle => translate('deleteSafetyReportTitle');
  String get delhiPcrSub => translate('delhiPcrSub');
  String get delhiPcrTitle => translate('delhiPcrTitle');
  String get descFieldHint => translate('descFieldHint');
  String get descFieldLabel => translate('descFieldLabel');
  String get descMin10Chars => translate('descMin10Chars');
  String get desk247Priority => translate('desk247Priority');
  String get directions => translate('directions');
  String get directionsAction => translate('directionsAction');
  String get disabled => translate('disabled');
  String get discreetExit => translate('discreetExit');
  String get dispatchSosBtn => translate('dispatchSosBtn');
  String get dispatchingText => translate('dispatchingText');
  String get donNotHaveAccount => translate('donNotHaveAccount');
  String get done => translate('done');
  String get dontHaveAccount => translate('dontHaveAccount');
  String get doxxingPhone => translate('doxxingPhone');
  String get driftAlertNotice => translate('driftAlertNotice');
  String get edit => translate('edit');
  String get editContact => translate('editContact');
  String get editEmergencyContact => translate('editEmergencyContact');
  String get editProfile => translate('editProfile');
  String get editReportAction => translate('editReportAction');
  String get email => translate('email');
  String get emailAddress => translate('emailAddress');
  String get emailAddressRequiredValidation => translate('emailAddressRequiredValidation');
  String get emailLabel => translate('emailLabel');
  String get emailRequiredValidation => translate('emailRequiredValidation');
  String get emergencyContacts => translate('emergencyContacts');
  String get emergencyContactsNotified => translate('emergencyContactsNotified');
  String get emergencyContactsTitle => translate('emergencyContactsTitle');
  String get emergencyServiceFallback => translate('emergencyServiceFallback');
  String get emergencyShieldActive => translate('emergencyShieldActive');
  String get empowermentPrecautions => translate('empowermentPrecautions');
  String get empowermentPrecautionsSub => translate('empowermentPrecautionsSub');
  String get enableLocationNearbyAlerts => translate('enableLocationNearbyAlerts');
  String get enabled => translate('enabled');
  String get endCall => translate('endCall');
  String get endJourneyButton => translate('endJourneyButton');
  String get endJourneyDesc => translate('endJourneyDesc');
  String get endJourneyPrompt => translate('endJourneyPrompt');
  String get enterFullNameHint => translate('enterFullNameHint');
  String get enterMinutes => translate('enterMinutes');
  String get enterMinutesHint => translate('enterMinutesHint');
  String get enterMinutesRangePrompt => translate('enterMinutesRangePrompt');
  String get enterPasswordHint => translate('enterPasswordHint');
  String get enterValidEmailValidation => translate('enterValidEmailValidation');
  String get error => translate('error');
  String get errorFetchingContacts => translate('errorFetchingContacts');
  String get etaUnder15s => translate('etaUnder15s');
  String get expiringSoonBadge => translate('expiringSoonBadge');
  String get expiringSoonCheckInNowHeading => translate('expiringSoonCheckInNowHeading');
  String get expiringSoonDesc => translate('expiringSoonDesc');
  String get extendAction => translate('extendAction');
  String get extendFailedSnack => translate('extendFailedSnack');
  String get extendTimer => translate('extendTimer');
  String get extendTimerDurationDesc => translate('extendTimerDurationDesc');
  String get extendTimerDurationTitle => translate('extendTimerDurationTitle');
  String get failedToCancelSos => translate('failedToCancelSos');
  String get failedToDeleteComment => translate('failedToDeleteComment');
  String get failedToDeleteContact => translate('failedToDeleteContact');
  String get failedToDeleteReport => translate('failedToDeleteReport');
  String get failedToLoadSafetyAlerts => translate('failedToLoadSafetyAlerts');
  String get failedToPostComment => translate('failedToPostComment');
  String get failedToResolveSos => translate('failedToResolveSos');
  String get failedToRetrieveNearby => translate('failedToRetrieveNearby');
  String get failedToSaveContact => translate('failedToSaveContact');
  String get failedToStartTimer => translate('failedToStartTimer');
  String get failedToSubmitReport => translate('failedToSubmitReport');
  String get failedToTriggerSosAlert => translate('failedToTriggerSosAlert');
  String get failedToUpdateAlertPref => translate('failedToUpdateAlertPref');
  String get failedToUpdateReport => translate('failedToUpdateReport');
  String get failedToUpdateShakeService => translate('failedToUpdateShakeService');
  String get fakeCall => translate('fakeCall');
  String get fakeCallDisclaimer => translate('fakeCallDisclaimer');
  String get fakeCallHeading => translate('fakeCallHeading');
  String get fakeCallSub => translate('fakeCallSub');
  String get fakeCallSubtitle => translate('fakeCallSubtitle');
  String get feedEmptyDesc => translate('feedEmptyDesc');
  String get filterLatest => translate('filterLatest');
  String get filterLocating => translate('filterLocating');
  String get filterMostUpvoted => translate('filterMostUpvoted');
  String get filterNearby => translate('filterNearby');
  String get fireStation => translate('fireStation');
  String get fireStationType => translate('fireStationType');
  String get fireStationsTab => translate('fireStationsTab');
  String get forgotPassword => translate('forgotPassword');
  String get fullName => translate('fullName');
  String get fullNameAsterisk => translate('fullNameAsterisk');
  String get fullNameHint => translate('fullNameHint');
  String get fullNameLabel => translate('fullNameLabel');
  String get fullNameRequiredValidation => translate('fullNameRequiredValidation');
  String get goBackBtn => translate('goBackBtn');
  String get goodAfternoon => translate('goodAfternoon');
  String get goodEvening => translate('goodEvening');
  String get goodMorning => translate('goodMorning');
  String get googleBrandName => translate('googleBrandName');
  String get gotItBtn => translate('gotItBtn');
  String get gpsAccuracy => translate('gpsAccuracy');
  String get gpsDisabled => translate('gpsDisabled');
  String get gpsDisabledSubtitle => translate('gpsDisabledSubtitle');
  String get gpsTurnedOff => translate('gpsTurnedOff');
  String get groceryListContent => translate('groceryListContent');
  String get groceryListTitle => translate('groceryListTitle');
  String get guardianTracking => translate('guardianTracking');
  String get harassmentAbusive => translate('harassmentAbusive');
  String get helpAndSupport => translate('helpAndSupport');
  String get helpAndSupportDesc => translate('helpAndSupportDesc');
  String get helpAndSupportSubtitle => translate('helpAndSupportSubtitle');
  String get helpAndSupportTitle => translate('helpAndSupportTitle');
  String get helplines => translate('helplines');
  String get helplinesHeading => translate('helplinesHeading');
  String get helplinesSub => translate('helplinesSub');
  String get hold3Seconds => translate('hold3Seconds');
  String get hospital => translate('hospital');
  String get hospitalClinicType => translate('hospitalClinicType');
  String get hospitalsTab => translate('hospitalsTab');
  String get hoursUnavailable => translate('hoursUnavailable');
  String get iAmSafeBtn => translate('iAmSafeBtn');
  String get iAmSafeNow => translate('iAmSafeNow');
  String get inaccurateInfo => translate('inaccurateInfo');
  String get incidentCategoryHeading => translate('incidentCategoryHeading');
  String get incidentId => translate('incidentId');
  String get incidentIdLabel => translate('incidentIdLabel');
  String get incomingCall => translate('incomingCall');
  String get invalidEmail => translate('invalidEmail');
  String get invalidMinutes => translate('invalidMinutes');
  String get invalidPassword => translate('invalidPassword');
  String get journeyActiveSince => translate('journeyActiveSince');
  String get journeyEndedSafely => translate('journeyEndedSafely');
  String get journeyEndedSuccess => translate('journeyEndedSuccess');
  String get journeyShieldActive => translate('journeyShieldActive');
  String get journeyShieldStandby => translate('journeyShieldStandby');
  String get justNow => translate('justNow');
  String get keepTracking => translate('keepTracking');
  String get keypad => translate('keypad');
  String get kiranHelplineSub => translate('kiranHelplineSub');
  String get kiranHelplineTitle => translate('kiranHelplineTitle');
  String get kmAway => translate('kmAway');
  String get language => translate('language');
  String get languageChangedConfirm => translate('languageChangedConfirm');
  String get languageChangedNotice => translate('languageChangedNotice');
  String get languageSelectionSubtitle => translate('languageSelectionSubtitle');
  String get languageSelectionTitle => translate('languageSelectionTitle');
  String get languages22Indian => translate('languages22Indian');
  String get lastKnownPrefix => translate('lastKnownPrefix');
  String get lastSync => translate('lastSync');
  String get launchFakeCall => translate('launchFakeCall');
  String get liveGpsStream => translate('liveGpsStream');
  String get liveJourney => translate('liveJourney');
  String get liveJourneyHeading => translate('liveJourneyHeading');
  String get liveJourneySub => translate('liveJourneySub');
  String get liveJourneyTracking => translate('liveJourneyTracking');
  String get liveLocationSharing => translate('liveLocationSharing');
  String get liveLocationSharingSub => translate('liveLocationSharingSub');
  String get loading => translate('loading');
  String get locationDetailsHint => translate('locationDetailsHint');
  String get locationDetailsLabel => translate('locationDetailsLabel');
  String get locationPermProximitySort => translate('locationPermProximitySort');
  String get locationPermSubtitle => translate('locationPermSubtitle');
  String get locationPermissionDenied => translate('locationPermissionDenied');
  String get locationPermissionNeeded => translate('locationPermissionNeeded');
  String get locationUnavailable => translate('locationUnavailable');
  String get logOutTitle => translate('logOutTitle');
  String get logout => translate('logout');
  String get logoutConfirm => translate('logoutConfirm');
  String get logoutConfirmTitle => translate('logoutConfirmTitle');
  String get manageCircleOfSafety => translate('manageCircleOfSafety');
  String get meetingAgendaContent => translate('meetingAgendaContent');
  String get meetingAgendaTitle => translate('meetingAgendaTitle');
  String get mentalHealthCategory => translate('mentalHealthCategory');
  String get mentalHealthCategorySub => translate('mentalHealthCategorySub');
  String get min5 => translate('min5');
  String get mins => translate('mins');
  String get minutesInputLabel => translate('minutesInputLabel');
  String get mute => translate('mute');
  String get myReports => translate('myReports');
  String get myReportsEmptyDesc => translate('myReportsEmptyDesc');
  String get nalsaSub => translate('nalsaSub');
  String get nalsaTitle => translate('nalsaTitle');
  String get nameRequired => translate('nameRequired');
  String get national112 => translate('national112');
  String get national112Sub => translate('national112Sub');
  String get navActions => translate('navActions');
  String get navCommunity => translate('navCommunity');
  String get navContacts => translate('navContacts');
  String get navExplore => translate('navExplore');
  String get navHome => translate('navHome');
  String get navMap => translate('navMap');
  String get navNearby => translate('navNearby');
  String get navProfile => translate('navProfile');
  String get navSettings => translate('navSettings');
  String get navVault => translate('navVault');
  String get ncwHelplineDesc => translate('ncwHelplineDesc');
  String get ncwHelplineSub => translate('ncwHelplineSub');
  String get ncwHelplineTitle => translate('ncwHelplineTitle');
  String get nearbyAlerts => translate('nearbyAlerts');
  String get nearbyFallback => translate('nearbyFallback');
  String get nearbyHelpTitle => translate('nearbyHelpTitle');
  String get nearbyServices => translate('nearbyServices');
  String get networkRequiredHeading => translate('networkRequiredHeading');
  String get nirbhayAppHeading => translate('nirbhayAppHeading');
  String get nirbhayMemberFallback => translate('nirbhayMemberFallback');
  String get noAlertsInCategory => translate('noAlertsInCategory');
  String get noCommentsYetDesc => translate('noCommentsYetDesc');
  String get noContactsDesc => translate('noContactsDesc');
  String get noContactsDescription => translate('noContactsDescription');
  String get noContactsTitle => translate('noContactsTitle');
  String get noEmergencyContactsYet => translate('noEmergencyContactsYet');
  String get noFixYet => translate('noFixYet');
  String get noMatchingHelplines => translate('noMatchingHelplines');
  String get noMatchingHelplinesFound => translate('noMatchingHelplinesFound');
  String get noPlacesFound => translate('noPlacesFound');
  String get noReportsYet => translate('noReportsYet');
  String get notifications => translate('notifications');
  String get notificationsDesc => translate('notificationsDesc');
  String get notificationsSettingsSubtitle => translate('notificationsSettingsSubtitle');
  String get notificationsSettingsTitle => translate('notificationsSettingsTitle');
  String get offlineAvailableNotice => translate('offlineAvailableNotice');
  String get offlineLanguageNotice => translate('offlineLanguageNotice');
  String get ok => translate('ok');
  String get open247 => translate('open247');
  String get openDecoyDisguise => translate('openDecoyDisguise');
  String get openInGoogleMaps => translate('openInGoogleMaps');
  String get openNow => translate('openNow');
  String get openSafetyTimer => translate('openSafetyTimer');
  String get orContinueWithDivider => translate('orContinueWithDivider');
  String get orSignUpWithDivider => translate('orSignUpWithDivider');
  String get password => translate('password');
  String get passwordLabel => translate('passwordLabel');
  String get passwordLength => translate('passwordLength');
  String get passwordMin6CharsValidation => translate('passwordMin6CharsValidation');
  String get passwordRequiredValidation => translate('passwordRequiredValidation');
  String get passwordsDoNotMatch => translate('passwordsDoNotMatch');
  String get permissionRequired => translate('permissionRequired');
  String get personalInfo => translate('personalInfo');
  String get personalInfoDesc => translate('personalInfoDesc');
  String get personalInfoSub => translate('personalInfoSub');
  String get personalInfoSubtitle => translate('personalInfoSubtitle');
  String get personalInfoTitle => translate('personalInfoTitle');
  String get pharmaciesTab => translate('pharmaciesTab');
  String get pharmacy => translate('pharmacy');
  String get pharmacyType => translate('pharmacyType');
  String get phoneInvalid => translate('phoneInvalid');
  String get phoneLabel => translate('phoneLabel');
  String get phoneNumber => translate('phoneNumber');
  String get phoneNumberAsterisk => translate('phoneNumberAsterisk');
  String get phoneNumberHint => translate('phoneNumberHint');
  String get phoneNumberRequiredValidation => translate('phoneNumberRequiredValidation');
  String get phoneUnavailable => translate('phoneUnavailable');
  String get pleaseEnterContactName => translate('pleaseEnterContactName');
  String get pleaseEnterPhoneNumber => translate('pleaseEnterPhoneNumber');
  String get pleaseEnterValidPhoneNumber => translate('pleaseEnterValidPhoneNumber');
  String get police => translate('police');
  String get police100 => translate('police100');
  String get police100Sub => translate('police100Sub');
  String get policeLegalCategory => translate('policeLegalCategory');
  String get policeLegalCategorySub => translate('policeLegalCategorySub');
  String get policeStationType => translate('policeStationType');
  String get policeStationsTab => translate('policeStationsTab');
  String get postButton => translate('postButton');
  String get postSafetyAlertTitle => translate('postSafetyAlertTitle');
  String get postSafetyReportBtn => translate('postSafetyReportBtn');
  String get preferences => translate('preferences');
  String get previewBrowser => translate('previewBrowser');
  String get previewRingtoneLabel => translate('previewRingtoneLabel');
  String get priority1Ready => translate('priority1Ready');
  String get privacyPolicy => translate('privacyPolicy');
  String get processingProgress => translate('processingProgress');
  String get profile => translate('profile');
  String get profileHeading => translate('profileHeading');
  String get publishReportBtn => translate('publishReportBtn');
  String get quickActions => translate('quickActions');
  String get quickEscape => translate('quickEscape');
  String get quickEscapeSubtitle => translate('quickEscapeSubtitle');
  String get quickNotesTitle => translate('quickNotesTitle');
  String get quickPresetsLabel => translate('quickPresetsLabel');
  String get quickSosEscalate => translate('quickSosEscalate');
  String get quickSosEscalatePrompt => translate('quickSosEscalatePrompt');
  String get railway139 => translate('railway139');
  String get railway139Sub => translate('railway139Sub');
  String get railwaySecuritySub => translate('railwaySecuritySub');
  String get railwaySecurityTitle => translate('railwaySecurityTitle');
  String get rapidAssistanceCards => translate('rapidAssistanceCards');
  String get realEmergencyOnly => translate('realEmergencyOnly');
  String get realSosAlertTriggeredNotif => translate('realSosAlertTriggeredNotif');
  String get realSosBadge => translate('realSosBadge');
  String get realSosWarningText => translate('realSosWarningText');
  String get reasonDangerous => translate('reasonDangerous');
  String get reasonDoxxing => translate('reasonDoxxing');
  String get reasonHarassment => translate('reasonHarassment');
  String get reasonInaccurate => translate('reasonInaccurate');
  String get reasonSpam => translate('reasonSpam');
  String get refreshTooltip => translate('refreshTooltip');
  String get registrationFailedDefault => translate('registrationFailedDefault');
  String get relationship => translate('relationship');
  String get relationshipHint => translate('relationshipHint');
  String get relationshipOptional => translate('relationshipOptional');
  String get reportDeletedSuccess => translate('reportDeletedSuccess');
  String get reportDescLabel => translate('reportDescLabel');
  String get reportInappropriate => translate('reportInappropriate');
  String get reportInappropriateAction => translate('reportInappropriateAction');
  String get reportInappropriateContent => translate('reportInappropriateContent');
  String get reportInappropriateDialogDesc => translate('reportInappropriateDialogDesc');
  String get reportInappropriateDialogTitle => translate('reportInappropriateDialogTitle');
  String get reportReceivedNotice => translate('reportReceivedNotice');
  String get reportSafetyConcern => translate('reportSafetyConcern');
  String get reportSafetyConcernSub => translate('reportSafetyConcernSub');
  String get reportSubmitted => translate('reportSubmitted');
  String get reportTitleLabel => translate('reportTitleLabel');
  String get reportUpdatedSuccess => translate('reportUpdatedSuccess');
  String get resolveSosDesc => translate('resolveSosDesc');
  String get resolveSosPrompt => translate('resolveSosPrompt');
  String get resolvingProgress => translate('resolvingProgress');
  String get retry => translate('retry');
  String get returnToNirbhayTooltip => translate('returnToNirbhayTooltip');
  String get ringPhoneImmediately => translate('ringPhoneImmediately');
  String get ringtoneAndAudio => translate('ringtoneAndAudio');
  String get ringtoneChannelExplanation => translate('ringtoneChannelExplanation');
  String get routeDeviationAlarm => translate('routeDeviationAlarm');
  String get runningTimerStatus => translate('runningTimerStatus');
  String get safeZoneType => translate('safeZoneType');
  String get safetyAlertPublishedSuccess => translate('safetyAlertPublishedSuccess');
  String get safetyScore => translate('safetyScore');
  String get safetyScoreDesc => translate('safetyScoreDesc');
  String get safetyScoreExplanation => translate('safetyScoreExplanation');
  String get safetyScoreLabel => translate('safetyScoreLabel');
  String get safetySettings => translate('safetySettings');
  String get safetySettingsDesc => translate('safetySettingsDesc');
  String get safetySettingsSub => translate('safetySettingsSub');
  String get safetySettingsTitle => translate('safetySettingsTitle');
  String get safetyTimer => translate('safetyTimer');
  String get safetyTimerCancelledSnack => translate('safetyTimerCancelledSnack');
  String get safetyTimerExpiringSoon => translate('safetyTimerExpiringSoon');
  String get safetyTimerExpiringSoonBanner => translate('safetyTimerExpiringSoonBanner');
  String get safetyTimerHeading => translate('safetyTimerHeading');
  String get safetyTimerSub => translate('safetyTimerSub');
  String get safetyTimerSubtitle => translate('safetyTimerSubtitle');
  String get safetyTimerWatchdog => translate('safetyTimerWatchdog');
  String get safetyTips => translate('safetyTips');
  String get safetyTipsHeading => translate('safetyTipsHeading');
  String get safetyTipsHeroDesc => translate('safetyTipsHeroDesc');
  String get safetyTipsSub => translate('safetyTipsSub');
  String get satelliteDispatch => translate('satelliteDispatch');
  String get save => translate('save');
  String get saveChangesBtn => translate('saveChangesBtn');
  String get saveContact => translate('saveContact');
  String get scheduleFakeCall => translate('scheduleFakeCall');
  String get scheduledFakeCallCancelled => translate('scheduledFakeCallCancelled');
  String get search => translate('search');
  String get searchHelplineHint => translate('searchHelplineHint');
  String get sec10 => translate('sec10');
  String get sec30 => translate('sec30');
  String get sec60 => translate('sec60');
  String get secondsCap => translate('secondsCap');
  String get selectCategory => translate('selectCategory');
  String get selectDuration => translate('selectDuration');
  String get selectDurationBelow => translate('selectDurationBelow');
  String get selectLanguage => translate('selectLanguage');
  String get sessionExpiredDialogBody => translate('sessionExpiredDialogBody');
  String get sessionExpiredDialogTitle => translate('sessionExpiredDialogTitle');
  String get sessionExpiredSubtitle => translate('sessionExpiredSubtitle');
  String get setCustomDurationPrompt => translate('setCustomDurationPrompt');
  String get setDurationButton => translate('setDurationButton');
  String get settings => translate('settings');
  String get shakeBackgroundDesc => translate('shakeBackgroundDesc');
  String get shakeBackgroundLock => translate('shakeBackgroundLock');
  String get shakeCancelled => translate('shakeCancelled');
  String get shakeCountdownWarning => translate('shakeCountdownWarning');
  String get shakeDetected => translate('shakeDetected');
  String get shakePhoneDetected => translate('shakePhoneDetected');
  String get shakeSensitivity => translate('shakeSensitivity');
  String get shakeSensitivityTitle => translate('shakeSensitivityTitle');
  String get shakeSosBgDisabled => translate('shakeSosBgDisabled');
  String get shakeSosBgEnabled => translate('shakeSosBgEnabled');
  String get shakeSosCancelledNoAlerts => translate('shakeSosCancelledNoAlerts');
  String get shakeSosDescription => translate('shakeSosDescription');
  String get shakeSosDetectionTitle => translate('shakeSosDetectionTitle');
  String get shakeToTriggerSos => translate('shakeToTriggerSos');
  String get shakeTriggerDisabled => translate('shakeTriggerDisabled');
  String get shakeTriggerEnabled => translate('shakeTriggerEnabled');
  String get share => translate('share');
  String get shareLiveLink => translate('shareLiveLink');
  String get shareLiveLinkGuardians => translate('shareLiveLinkGuardians');
  String get shareLiveLocation => translate('shareLiveLocation');
  String get shareLiveTrackingLinkGuardians => translate('shareLiveTrackingLinkGuardians');
  String get shareModalSubtitle => translate('shareModalSubtitle');
  String get shareModalTitle => translate('shareModalTitle');
  String get shareSms => translate('shareSms');
  String get shareWhatsApp => translate('shareWhatsApp');
  String get whatsApp => translate('shareWhatsApp');
  String get shieldActive => translate('shieldActive');
  String get shieldStandby => translate('shieldStandby');
  String get showAllServices => translate('showAllServices');
  String get signIn => translate('signIn');
  String get signInFailedDefault => translate('signInFailedDefault');
  String get signInTitle => translate('signInTitle');
  String get signInWelcomeSubtitle => translate('signInWelcomeSubtitle');
  String get signUp => translate('signUp');
  String get signUpTitle => translate('signUpTitle');
  String get signUpWelcomeSubtitle => translate('signUpWelcomeSubtitle');
  String get simulateFakeCall => translate('simulateFakeCall');
  String get simulateFakeCallSub => translate('simulateFakeCallSub');
  String get simulatedCallNirbhayBadge => translate('simulatedCallNirbhayBadge');
  String get smsAlertPrefix => translate('smsAlertPrefix');
  String get smsAlertSuffix => translate('smsAlertSuffix');
  String get smsJourneyEndedPrefix => translate('smsJourneyEndedPrefix');
  String get smsJourneyStartedPrefix => translate('smsJourneyStartedPrefix');
  String get smsLastKnownLocationPrefix => translate('smsLastKnownLocationPrefix');
  String get smsLiveTrackingPrefix => translate('smsLiveTrackingPrefix');
  String get smsLocationPrefix => translate('smsLocationPrefix');
  String get smsResolvedBody => translate('smsResolvedBody');
  String get smsTimerExpiredBody => translate('smsTimerExpiredBody');
  String get sosActivatingIn => translate('sosActivatingIn');
  String get sosAlertDispatched => translate('sosAlertDispatched');
  String get sosDispatchedAt => translate('sosDispatchedAt');
  String get sosDispatchedLiveLocNotif => translate('sosDispatchedLiveLocNotif');
  String get sosEmergencyActivated => translate('sosEmergencyActivated');
  String get sosEmergencyActivatedTitle => translate('sosEmergencyActivatedTitle');
  String get sosEmergencyRecordedNetwork => translate('sosEmergencyRecordedNetwork');
  String get sosHolding => translate('sosHolding');
  String get sosIncidentCancelled => translate('sosIncidentCancelled');
  String get sosLocationPending => translate('sosLocationPending');
  String get sosResolvedSafe => translate('sosResolvedSafe');
  String get soundAndVibration => translate('soundAndVibration');
  String get spamAdvertising => translate('spamAdvertising');
  String get speaker => translate('speaker');
  String get specializedDirectories => translate('specializedDirectories');
  String get speed => translate('speed');
  String get startJourneyButton => translate('startJourneyButton');
  String get startTimerButton => translate('startTimerButton');
  String get startingTimer => translate('startingTimer');
  String get status => translate('status');
  String get statusLabel => translate('statusLabel');
  String get staySafe => translate('staySafe');
  String get stopRingtonePreview => translate('stopRingtonePreview');
  String get submit => translate('submit');
  String get submitReport => translate('submitReport');
  String get submitReportButton => translate('submitReportButton');
  String get success => translate('success');
  String get tapForSos => translate('tapForSos');
  String get tapLockToReturn => translate('tapLockToReturn');
  String get teleManasSub => translate('teleManasSub');
  String get teleManasTitle => translate('teleManasTitle');
  String get telemetryHeader => translate('telemetryHeader');
  String get termsOfService => translate('termsOfService');
  String get termsText => translate('termsText');
  String get themeDark => translate('themeDark');
  String get themeLight => translate('themeLight');
  String get timeRemainingClock => translate('timeRemainingClock');
  String get timeRemainingLabel => translate('timeRemainingLabel');
  String get timerAlreadyActive => translate('timerAlreadyActive');
  String get timerAlreadyActiveRefreshing => translate('timerAlreadyActiveRefreshing');
  String get timerCancelledSuccess => translate('timerCancelledSuccess');
  String get timerExtendedSuccess => translate('timerExtendedSuccess');
  String get timerStatusActive => translate('timerStatusActive');
  String get timerStatusExpired => translate('timerStatusExpired');
  String get tipCatDigitalCyber => translate('tipCatDigitalCyber');
  String get tipCatNightTravel => translate('tipCatNightTravel');
  String get tipCatPublicTransit => translate('tipCatPublicTransit');
  String get tipDigitalCyber1 => translate('tipDigitalCyber1');
  String get tipDigitalCyber2 => translate('tipDigitalCyber2');
  String get tipDigitalCyber3 => translate('tipDigitalCyber3');
  String get tipDigitalSafety => translate('tipDigitalSafety');
  String get tipNightTravel => translate('tipNightTravel');
  String get tipNightTravel1 => translate('tipNightTravel1');
  String get tipNightTravel2 => translate('tipNightTravel2');
  String get tipNightTravel3 => translate('tipNightTravel3');
  String get tipNightTravel4 => translate('tipNightTravel4');
  String get tipPublicTransit => translate('tipPublicTransit');
  String get tipPublicTransit1 => translate('tipPublicTransit1');
  String get tipPublicTransit2 => translate('tipPublicTransit2');
  String get tipPublicTransit3 => translate('tipPublicTransit3');
  String get titleDescRequired => translate('titleDescRequired');
  String get titleFieldHint => translate('titleFieldHint');
  String get titleFieldLabel => translate('titleFieldLabel');
  String get titleMin3Chars => translate('titleMin3Chars');
  String get trackingLinkCopied => translate('trackingLinkCopied');
  String get triggerDelay => translate('triggerDelay');
  String get triggerRealEmergencySos => translate('triggerRealEmergencySos');
  String get triggerRealSosBtn => translate('triggerRealSosBtn');
  String get unableToAcquireGps => translate('unableToAcquireGps');
  String get unableToLoadContacts => translate('unableToLoadContacts');
  String get unifiedCrisisDesc => translate('unifiedCrisisDesc');
  String get updateContact => translate('updateContact');
  String get updatedJustNow => translate('updatedJustNow');
  String get upvote => translate('upvote');
  String get validMinutesRangeError => translate('validMinutesRangeError');
  String get verified247Desk => translate('verified247Desk');
  String get version => translate('version');
  String get versionInfo => translate('versionInfo');
  String get versionText => translate('versionText');
  String get viewDetails => translate('viewDetails');
  String get volumeButtonSosDesc => translate('volumeButtonSosDesc');
  String get volumeButtonSosRapidDial => translate('volumeButtonSosRapidDial');
  String get volumeButtonTriggerEnabled => translate('volumeButtonTriggerEnabled');
  String get welcomeBack => translate('welcomeBack');
  String get whatsAppSos => translate('whatsAppSos');
  String get women1091 => translate('women1091');
  String get women1091Sub => translate('women1091Sub');
  String get womenHelplineDesc => translate('womenHelplineDesc');
  String get womenHelplineSub => translate('womenHelplineSub');
  String get womenHelplineTitle => translate('womenHelplineTitle');
  String get active => translate('active');
  String get activeSosIncidentBanner => translate('activeSosIncidentBanner');
  String get liveJourneySubtitle => translate('liveJourneySubtitle');
  String get localEmergencyContacts => translate('localEmergencyContacts');
  String get location => translate('location');
  String get safetyTipsSubtitle => translate('safetyTipsSubtitle');
  String get triggeringSos => translate('triggeringSos');
  String get view => translate('view');
  String get catAll => translate('catAll');
  String get liveGps => translate('liveGps');
  String get openAppSettings => translate('openAppSettings');
  String get enableAndRetry => translate('enableAndRetry');
  String get locationRequiredNearbyServices => translate('locationRequiredNearbyServices');
  String get locationPermissionNeededTitle => translate('locationPermissionNeededTitle');
  String get deviceGpsTurnedOffTitle => translate('deviceGpsTurnedOffTitle');
  String get myLocation => translate('myLocation');
  String get showAllPlaces => translate('showAllPlaces');
  String get refreshLocationAndPlaces => translate('refreshLocationAndPlaces');
  String get deleteSafetyReportPrompt => translate('deleteSafetyReportPrompt');
  String get deleteSafetyReportConfirm => translate('deleteSafetyReportConfirm');
  String get deleteReport => translate('deleteReport');
  String get postSafetyReport => translate('postSafetyReport');
  String get shareLiveJourneyTracking => translate('shareLiveJourneyTracking');
  String get realTimeTelemetry => translate('realTimeTelemetry');
  String get awaitingSatelliteLock => translate('awaitingSatelliteLock');
  String get ensureGpsClearSky => translate('ensureGpsClearSky');
  String get sosResolvedSafeSms => translate('sosResolvedSafeSms');
  String get endJourneyTitle => translate('endJourneyTitle');
  String get endJourneyAction => translate('endJourneyAction');
  String get imSafeNow => translate('imSafeNow');
  String get noJourney => translate('noJourney');
  String get recenterLiveLocation => translate('recenterLiveLocation');
  String get refresh => translate('refresh');
  String get connectionErrorPullRefresh => translate('connectionErrorPullRefresh');

  // ──────────────────────────────────────────────────────────────────────────
  // Parameterized Helpers
  // ──────────────────────────────────────────────────────────────────────────

  String liveJourneySharingSmsVal(String url) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'मैं यात्रा कर रही हूँ और सुरक्षा के लिए Nirbhay के माध्यम से आपके साथ अपनी लाइव यात्रा साझा कर रही हूँ:\n$url';
    if (lang == 'gu') return 'હું મુસાફરી કરી રહી છું અને સુરક્ષા માટે Nirbhay દ્વારા તમારી સાથે મારી લાઇવ મુસાફરી શેર કરી રહી છું:\n$url';
    return 'I am traveling and sharing my live journey with you for safety via Nirbhay:\n$url';
  }

  String incidentIdVal(String id) {
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'घटना आईडी: $shortId...';
    if (lang == 'gu') return 'ઘટના ID: $shortId...';
    return 'Incident ID: $shortId...';
  }

  String statusWithVal(String status) {
    final lang = locale.languageCode.toLowerCase();
    String s = status.toUpperCase();
    if (s == 'ACTIVE') {
      if (lang == 'hi') return 'स्थिति: सक्रिय';
      if (lang == 'gu') return 'સ્થિતિ: સક્રિય';
      return 'Status: ACTIVE';
    }
    if (s == 'RESOLVED') {
      if (lang == 'hi') return 'स्थिति: हल हो गया';
      if (lang == 'gu') return 'સ્થિતિ: પૂર્ણ થયું';
      return 'Status: RESOLVED';
    }
    if (s == 'CANCELLED') {
      if (lang == 'hi') return 'स्थिति: रद्द';
      if (lang == 'gu') return 'સ્થિતિ: રદ';
      return 'Status: CANCELLED';
    }
    if (lang == 'hi') return 'स्थिति: $status';
    if (lang == 'gu') return 'સ્થિતિ: $status';
    return 'Status: $status';
  }

  String sosActivePromptVal(String time) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return '$time पर सक्रिय हुआ आपातकालीन SOS अलर्ट वर्तमान में सक्रिय है।';
    if (lang == 'gu') return '$time વાગ્યે સક્રિય થયેલ કટોકટી SOS ચેતવણી હાલમાં સક્રિય છે.';
    return 'An emergency SOS alert triggered at $time is currently active.';
  }

  String deleteContactConfirmVal(String name) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'क्या आप वाकई "$name" को अपने आपातकालीन संपर्कों से हटाना चाहते हैं?';
    if (lang == 'gu') return 'શું તમે ખરેખર "$name" ને તમારા કટોકટી સંપર્કોમાંથી દૂર કરવા માંગો છો?';
    return 'Are you sure you want to remove "$name" from your emergency contacts?';
  }

  String reportedByAuthor(String author) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return '$author द्वारा रिपोर्ट किया गया';
    if (lang == 'gu') return '$author દ્વારા જાણ કરવામાં આવી';
    return 'Reported by $author';
  }

  String upvotesCountVal(int count) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return '$count समर्थन';
    if (lang == 'gu') return '$count સમર્થન';
    return '$count upvotes';
  }

  String timeAgoVal(Duration diff) {
    final lang = locale.languageCode.toLowerCase();
    if (diff.inSeconds < 60) {
      return justNow;
    }
    if (diff.inMinutes < 60) {
      if (lang == 'hi') return '${diff.inMinutes} मिनट पहले';
      if (lang == 'gu') return '${diff.inMinutes} મિનિટ પહેલાં';
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      if (lang == 'hi') return '${diff.inHours} घंटे पहले';
      if (lang == 'gu') return '${diff.inHours} કલાક પહેલાં';
      return '${diff.inHours}h ago';
    }
    if (lang == 'hi') return '${diff.inDays} दिन पहले';
    if (lang == 'gu') return '${diff.inDays} દિવસ પહેલાં';
    return '${diff.inDays}d ago';
  }

  String distanceAwayVal(double km, {String? locationName}) {
    final distStr = km.toStringAsFixed(1);
    final lang = locale.languageCode.toLowerCase();
    String suffix = 'km away';
    if (lang == 'hi') suffix = 'किमी दूर';
    if (lang == 'gu') suffix = 'કિમી દૂર';

    if (locationName != null && locationName.isNotEmpty) {
      return '$locationName ($distStr $suffix)';
    }
    return '$distStr $suffix';
  }

  String fakeCallArmedVal(int seconds) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'फेक कॉल तैयार! $seconds सेकंड में इनकमिंग कॉल आएगी।';
    if (lang == 'gu') return 'ફેક કોલ સેટ! $seconds સેકન્ડમાં ઇનકમિંગ કોલ આવશે.';
    return 'Fake call armed! Incoming call in $seconds seconds.';
  }

  String callArmedRingingVal(int seconds) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'कॉल तैयार: $seconds सेकंड में रिंग होगी';
    if (lang == 'gu') return 'કોલ સેટ: $seconds સેકન્ડમાં રિંગ થશે';
    return 'Call Armed: Ringing in ${seconds}s';
  }

  String armCallDelayVal(int seconds) {
    final lang = locale.languageCode.toLowerCase();
    if (seconds == 0) {
      return ringPhoneImmediately;
    }
    if (seconds == 300) {
      if (lang == 'hi') return 'कॉल सेट करें (5 मिनट देरी)';
      if (lang == 'gu') return 'કોલ સેટ કરો (5 મિનિટ વિલંબ)';
      return 'Arm Call (5 min Delay)';
    }
    if (lang == 'hi') return 'कॉल सेट करें ($seconds से. देरी)';
    if (lang == 'gu') return 'કોલ સેટ કરો ($seconds સે. વિલંબ)';
    return 'Arm Call (${seconds}s Delay)';
  }

  String timerStartedVal(int minutes) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return '$minutes मिनट के लिए सेफ्टी टाइमर शुरू हुआ।';
    if (lang == 'gu') return '$minutes મિનિટ માટે સેફ્ટી ટાઈમર શરૂ થયું.';
    return 'Safety Timer started for $minutes minutes.';
  }

  String timerExtendedVal(int minutes) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'टाइमर $minutes मिनट बढ़ाया गया।';
    if (lang == 'gu') return 'ટાઈમર $minutes મિનિટ લંબાવવામાં આવ્યું.';
    return 'Timer extended by $minutes minutes.';
  }

  String customDurationSetVal(int val) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'कस्टम अवधि $val मिनट पर सेट की गई।';
    if (lang == 'gu') return 'કસ્ટમ સમયગાળો $val મિનિટ પર સેટ થયો.';
    return 'Custom duration set to $val minutes.';
  }

  String customDurationBtnLabel(int min) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'कस्टम: $min मिनट (बदलने के लिए टैप करें)';
    if (lang == 'gu') return 'કસ્ટમ: $min મિનિટ (બદલવા માટે ટેપ કરો)';
    return 'Custom: $min MIN (Tap to change)';
  }

  String autoAlertsAtTimeVal(DateTime expiresAt) {
    final h = expiresAt.toLocal().hour.toString().padLeft(2, '0');
    final m = expiresAt.toLocal().minute.toString().padLeft(2, '0');
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'यदि $h:$m तक चेक-इन नहीं किया तो संपर्कों को स्वतः अलर्ट करेगा';
    if (lang == 'gu') return 'જો $h:$m સુધીમાં ચેક-ઇન ન થાય તો સંપર્કોને આપમેળે ચેતવણી આપશે';
    return 'Auto-alerts contacts if not checked in by $h:$m';
  }

  String welcomeUser(String name) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'सफलतापूर्वक साइन इन किया! वापस स्वागत है, $name।';
    if (lang == 'gu') return 'સફળતાપૂર્વક સાઇન ઇન થયા! સ્વાગત છે, $name.';
    return 'Signed in successfully! Welcome back, $name.';
  }

  String welcomeUserAccount(String name) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'hi') return 'खाता सफलतापूर्वक बनाया गया! निर्भय में आपका स्वागत है, $name।';
    if (lang == 'gu') return 'ખાતું સફળતાપૂર્વક બનાવવામાં આવ્યું! નિર્ભયમાં સ્વાગત છે, $name.';
    return 'Account created successfully! Welcome to Nirbhay, $name.';
  }

  String themeSwitchedVal(String theme) {
    final lang = locale.languageCode.toLowerCase();
    String t = theme == 'Light' ? themeLight : themeDark;
    if (lang == 'hi') return 'थीम बदलकर $t मोड कर दी गई';
    if (lang == 'gu') return 'થીમ બદલીને $t મોડ કરવામાં આવી';
    return 'Theme switched to $theme mode';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Category & Place Localizers
  // ──────────────────────────────────────────────────────────────────────────

  String localizeCategory(String? key) {
    if (key == null) return catOther;
    switch (key.toUpperCase()) {
      case 'SUSPICIOUS_ACTIVITY':
        return catSuspiciousActivity;
      case 'HARASSMENT':
        return catHarassment;
      case 'UNSAFE_AREA':
        return catUnsafeArea;
      case 'THEFT':
        return catTheft;
      case 'ROAD_SAFETY':
        return catRoadSafety;
      case 'LOST_PERSON':
        return catLostPerson;
      case 'HELPFUL_INFO':
        return catHelpfulInfo;
      case 'OTHER':
      default:
        return catOther;
    }
  }

  String localizePlaceType(String? type) {
    if (type == null) return emergencyServiceFallback;
    switch (type.toLowerCase()) {
      case 'police':
        return policeStationType;
      case 'hospital':
      case 'clinic':
        return hospitalClinicType;
      case 'pharmacy':
        return pharmacyType;
      case 'fire_station':
        return fireStationType;
      case 'safe_zone':
        return safeZoneType;
      default:
        return emergencyServiceFallback;
    }
  }

  String localizeHoursStatus(bool? isOpen, String? hours) {
    if (isOpen == true) return openNow;
    if (hours != null && hours.toLowerCase().contains('24/7')) return open247;
    return hoursUnavailable;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // New Multilingual Getters & Parametric Helpers
  // ──────────────────────────────────────────────────────────────────────────
  String get emailAddressPlaceholder => translate('emailAddressPlaceholder');
  String get phoneNumberPlaceholder => translate('phoneNumberPlaceholder');
  String get andWord => translate('andWord');
  String get termsOfServiceShort => translate('termsOfServiceShort');
  String get privacyPolicyShort => translate('privacyPolicyShort');
  String get groceryListItems => translate('groceryListItems');
  String get meetingAgendaItems => translate('meetingAgendaItems');
  String get callerMom => translate('callerMom');
  String get callerDad => translate('callerDad');
  String get callerPolice => translate('callerPolice');
  String get expiringSoonCheckInNow => translate('expiringSoonCheckInNow');
  String get timerActive => translate('timerActive');
  String get nearbySafetyHelp => translate('nearbySafetyHelp');
  String get cached => translate('cached');
  String get immediateDangerCall112 => translate('immediateDangerCall112');
  String get allIndiaHelplinePoliceMedical => translate('allIndiaHelplinePoliceMedical');
  String get centeredOnLivePosition => translate('centeredOnLivePosition');
  String get acquiringGpsFix => translate('acquiringGpsFix');
  String get googleMaps => translate('googleMaps');
  String get sos => translate('sos');
  String get hold2s => translate('hold2s');
  String get alertGuardiansDrift => translate('alertGuardiansDrift');
  String get journeyStartedLiveLink => translate('journeyStartedLiveLink');
  String get noGpsFixToOpenMap => translate('noGpsFixToOpenMap');
  String get couldNotLaunchGoogleMaps => translate('couldNotLaunchGoogleMaps');
  String get noActiveJourneyOrSos => translate('noActiveJourneyOrSos');
  String get couldNotLaunchWhatsApp => translate('couldNotLaunchWhatsApp');
  String get couldNotLaunchSms => translate('couldNotLaunchSms');
  String get open => translate('open');
  String get resolveJourneyDesc => translate('resolveJourneyDesc');
  String get activatingSosAlert => translate('activatingSosAlert');
  String get activeSosAlreadyInProgress => translate('activeSosAlreadyInProgress');
  String get category => translate('category');
  String get accidentalShakeCancelHint => translate('accidentalShakeCancelHint');
  String get imSafeCheckIn => translate('imSafeCheckIn');
  String get delhiNcrActiveDispatch => translate('delhiNcrActiveDispatch');
  String get sensitivityLow => translate('sensitivityLow');
  String get sensitivityDefault => translate('sensitivityDefault');
  String get sensitivityHigh => translate('sensitivityHigh');
  String get lightMode => translate('lightMode');
  String get darkMode => translate('darkMode');
  String get badge247Available => translate('badge247Available');
  String get badgeHindiEngRegional => translate('badgeHindiEngRegional');
  String get badgeResponseUnder30s => translate('badgeResponseUnder30s');
  String get badge247Online => translate('badge247Online');
  String get badgeWhatsappSosEnabled => translate('badgeWhatsappSosEnabled');
  String get badgeLegalCounsel => translate('badgeLegalCounsel');
  String get badge247Operation => translate('badge247Operation');
  String get badgeEngHindiRegional => translate('badgeEngHindiRegional');
  String get badgeFirFilingGuidance => translate('badgeFirFilingGuidance');
  String get badge247FreeHelpline => translate('badge247FreeHelpline');
  String get badgePanIndiaSupport => translate('badgePanIndiaSupport');
  String get badgeStrictAnonymity => translate('badgeStrictAnonymity');

  String accountCreatedSuccessfullyWelcome(String name) =>
      translate('accountCreatedSuccessfullyWelcome').replaceAll('{name}', name);

  String signedInSuccessfullyWelcome(String name) =>
      translate('signedInSuccessfullyWelcome').replaceAll('{name}', name);

  String themeSwitchedMode(String theme) =>
      translate('themeSwitchedMode').replaceAll('{theme}', theme);

  String fakeCallArmedInSeconds(int sec) =>
      translate('fakeCallArmedInSeconds').replaceAll('{sec}', sec.toString());

  String callArmedRingingIn(int sec) =>
      translate('callArmedRingingIn').replaceAll('{sec}', sec.toString());

  String couldNotLaunchDialerFor(String number) =>
      translate('couldNotLaunchDialerFor').replaceAll('{number}', number);

  String copiedToClipboardVal(String text) =>
      translate('copiedToClipboardText').replaceAll('{text}', text);

  String callNumberVal(String number) =>
      translate('callSpecificNumber').replaceAll('{number}', number);

  String minutesShort(int mins) =>
      translate('minutesShort').replaceAll('{mins}', mins.toString());

  String addMinutesShort(int mins) =>
      translate('addMinutesShort').replaceAll('{mins}', mins.toString());

  String placesFoundCount(int count) =>
      translate('placesFoundCount').replaceAll('{count}', count.toString());

  String findingNearbyCategory(String category) =>
      translate('findingNearbyCategory').replaceAll('{category}', category);

  String noCategoryFoundNearby(String category) =>
      translate('noCategoryFoundNearby').replaceAll('{category}', category);

  String noRecordsFoundWithinRadius(int km) =>
      translate('noRecordsFoundWithinRadius').replaceAll('{km}', km.toString());

  String journeyActiveSinceDuration(String duration) =>
      translate('journeyActiveSinceDuration').replaceAll('{duration}', duration);

  String sosDispatchedNetworkMessage(String id) =>
      translate('sosDispatchedNetworkMessage').replaceAll('{id}', id);

  String couldNotObtainLocationErr(String err) =>
      translate('couldNotObtainLocationErr').replaceAll('{err}', err);

  String upvotesCountSuffix(int count) =>
      translate('upvotesCountSuffix').replaceAll('{count}', count.toString());

  // ──────────────────────────────────────────────────────────────────────────
  // Backend & Service Message Localizer
  // Intercepts backend responses & service error strings to guarantee
  // that user sees 100% localized messages matching active language.
  // ──────────────────────────────────────────────────────────────────────────

  String localizeBackendMessage(String? raw, {String? fallback}) {
    if (raw == null || raw.trim().isEmpty) {
      return fallback ?? '';
    }
    final s = raw.trim();
    final lower = s.toLowerCase();
    final lang = locale.languageCode.toLowerCase();

    // If string already contains non-Latin characters (Hindi or Gujarati script), return it as is!
    final hasIndic = s.runes.any((r) => (r >= 0x0900 && r <= 0x097F) || (r >= 0x0A80 && r <= 0x0AFF));
    if (hasIndic) {
      return s;
    }

    // Check specific known patterns
    if (lower.contains('not authenticated') || lower.contains('please log in') || lower.contains('please sign in')) {
      if (lang == 'hi') return 'प्रमाणीकृत नहीं। कृपया लॉग इन करें।';
      if (lang == 'gu') return 'પ્રમાણિત નથી. કૃપા કરીને લોગ ઇન કરો.';
      return 'Not authenticated. Please log in.';
    }

    if (lower.contains('session expired') || lower.contains('session has expired')) {
      if (lang == 'hi') return 'सत्र समाप्त हो गया है। कृपया पुनः साइन इन करें।';
      if (lang == 'gu') return 'સત્ર સમાપ્ત થઈ ગયું છે. કૃપા કરીને ફરીથી સાઇન ઇન કરો.';
      return 'Your session has expired. Please sign in again.';
    }

    if (lower.contains('timed out') || lower.contains('timeout')) {
      if (lang == 'hi') return 'अनुरोध समय समाप्त। कृपया पुनः प्रयास करें।';
      if (lang == 'gu') return 'વિનંતીનો સમય સમાપ્ત થયો. કૃપા કરીને ફરી પ્રયાસ કરો.';
      return 'Request timed out. Please try again.';
    }

    if (lower.contains('no internet') || lower.contains('device is currently offline') || lower.contains('offline: unable')) {
      if (lang == 'hi') return 'कोई इंटरनेट कनेक्शन नहीं है।';
      if (lang == 'gu') return 'કોઈ ઇન્ટરનેટ કનેક્શન નથી.';
      return 'No internet connection.';
    }

    if (lower.contains('connection error') || lower.contains('network error') || lower.contains('unable to reach backend')) {
      if (lang == 'hi') return 'कनेक्शन त्रुटि। कृपया अपना इंटरनेट जांचें।';
      if (lang == 'gu') return 'કનેક્શન ભૂલ. કૃપા કરીને તમારું ઇન્ટરનેટ તપાસો.';
      return 'Connection error. Please check your network.';
    }

    if (lower.contains('contact added successfully')) {
      return contactSavedSuccess;
    }
    if (lower.contains('contact updated successfully')) {
      return contactSavedSuccess;
    }
    if (lower.contains('contact deleted successfully')) {
      return contactDeletedSuccess;
    }
    if (lower.contains('failed to add contact') || lower.contains('failed to save contact')) {
      return failedToSaveContact;
    }
    if (lower.contains('failed to delete contact')) {
      return failedToDeleteContact;
    }
    if (lower.contains('failed to load contacts') || lower.contains('failed to load emergency contacts')) {
      return unableToLoadContacts;
    }
    if (lower.contains('failed to update alert preference')) {
      return failedToUpdateAlertPref;
    }

    if (lower.contains('already in progress') || lower.contains('active sos incident is already')) {
      if (lang == 'hi') return 'एक सक्रिय SOS घटना पहले से जारी है।';
      if (lang == 'gu') return 'સક્રિય SOS ઘટના પહેલેથી જ ચાલુ છે.';
      return 'An active SOS incident is already in progress.';
    }

    if (lower.contains('sos alert activated offline')) {
      if (lang == 'hi') return 'SOS अलर्ट ऑफ़लाइन सक्रिय हुआ। संपर्कों को आपातकालीन एसएमएस भेजा गया।';
      if (lang == 'gu') return 'SOS ચેતવણી ઑફલાઇન સક્રિય થઈ. સંપર્કોને કટોકટી SMS મોકલવામાં આવ્યો.';
      return 'SOS alert activated offline. Emergency SMS sent to contacts.';
    }

    if (lower.contains('sos incident activated') || lower.contains('sos alert dispatched')) {
      return sosAlertDispatched;
    }

    if (lower.contains('sos resolved safe') || lower.contains('sos resolved')) {
      return sosResolvedSafe;
    }

    if (lower.contains('sos incident cancelled') || lower.contains('sos cancelled')) {
      return sosIncidentCancelled;
    }

    if (lower.contains('failed to trigger sos')) {
      return failedToTriggerSosAlert;
    }

    if (lower.contains('failed to resolve sos')) {
      return failedToResolveSos;
    }

    if (lower.contains('failed to cancel sos')) {
      return failedToCancelSos;
    }

    if (lower.contains('safety timer started')) {
      if (lang == 'hi') return 'सेफ्टी टाइमर शुरू हो गया।';
      if (lang == 'gu') return 'સેફ્ટી ટાઈમર શરૂ થયું.';
      return 'Safety timer started.';
    }

    if (lower.contains('checked in successfully')) {
      return checkedInSafeSuccessSnack;
    }

    if (lower.contains('check-in failed')) {
      return checkInFailedSnack;
    }

    if (lower.contains('safety timer cancelled')) {
      return safetyTimerCancelledSnack;
    }

    if (lower.contains('failed to start timer')) {
      return failedToStartTimer;
    }

    if (lower.contains('timer extended')) {
      if (lang == 'hi') return 'टाइमर बढ़ा दिया गया।';
      if (lang == 'gu') return 'ટાઈમર લંબાવવામાં આવ્યું.';
      return 'Timer extended successfully.';
    }

    if (lower.contains('report deleted successfully')) {
      return reportDeletedSuccess;
    }

    if (lower.contains('report updated successfully')) {
      return reportUpdatedSuccess;
    }

    if (lower.contains('safety alert published')) {
      return safetyAlertPublishedSuccess;
    }

    if (lower.contains('failed to delete report')) {
      return failedToDeleteReport;
    }

    if (lower.contains('failed to submit report')) {
      return failedToSubmitReport;
    }

    if (lower.contains('failed to update report')) {
      return failedToUpdateReport;
    }

    if (lower.contains('failed to load safety alerts')) {
      return failedToLoadSafetyAlerts;
    }

    if (lower.contains('failed to post comment')) {
      return failedToPostComment;
    }

    if (lower.contains('failed to delete comment')) {
      return failedToDeleteComment;
    }

    if (lower.contains('invalid credentials') || lower.contains('invalid email or password')) {
      if (lang == 'hi') return 'अमान्य ईमेल या पासवर्ड। कृपया पुनः प्रयास करें।';
      if (lang == 'gu') return 'અમાન્ય ઇમેઇલ અથવા પાસવર્ડ. કૃપા કરીને ફરી પ્રયાસ કરો.';
      return 'Invalid email or password. Please try again.';
    }

    if (lower.contains('user already exists') || lower.contains('email already in use')) {
      if (lang == 'hi') return 'यह ईमेल पहले से पंजीकृत है।';
      if (lang == 'gu') return 'આ ઇમેઇલ પહેલેથી જ નોંધાયેલ છે.';
      return 'Email is already registered.';
    }

    if (lower.contains('sign in failed') || lower.contains('signin failed')) {
      return signInFailedDefault;
    }

    if (lower.contains('registration failed')) {
      return registrationFailedDefault;
    }

    if (lower.contains('could not obtain location') || lower.contains('unable to acquire gps')) {
      return unableToAcquireGps;
    }

    if (lower.contains('location permission')) {
      return locationPermissionDenied;
    }

    if (lower.contains('gps is turned off') || lower.contains('gps is disabled')) {
      return gpsDisabled;
    }

    if (lower.contains('journey ended')) {
      return journeyEndedSuccess;
    }

    // Fallback if provided, else if in non-English mode, return a localized generic message
    if (fallback != null) return fallback;

    if (lang == 'hi') {
      return 'अनुरोध संसाधित करने में त्रुटि। कृपया पुनः प्रयास करें।';
    } else if (lang == 'gu') {
      return 'વિનંતી પર પ્રક્રિયા કરવામાં ભૂલ. કૃપા કરીને ફરી પ્રયાસ કરો.';
    }
    return s;
  }

  String get delayNow => translate('delayNow');
  String get delay60s => translate('delay60s');
  String get delay5min => translate('delay5min');
  String get osmCooldownNotice => translate('osmCooldownNotice');
  String get allIndiaEmergencyHelplineShort => translate('allIndiaEmergencyHelplineShort');
  String get publicRateLimitReached => translate('publicRateLimitReached');
  String get unableToLoadServices => translate('unableToLoadServices');
  String get networkErrorVerifyConnection => translate('networkErrorVerifyConnection');
  String get retryNow => translate('retryNow');
  String get tryAgain => translate('tryAgain');
  String get refreshUpper => translate('refreshUpper');
  String get imSafeUpper => translate('imSafeUpper');
  String get unitMin => translate('unitMin');
  String get unitHour => translate('unitHour');
  String get enterTimerDurationHint => translate('enterTimerDurationHint');
  String get lessThanOneMinRemains => translate('lessThanOneMinRemains');
  String get liveTrackingLinkCopied => translate('liveTrackingLinkCopied');
  String get noDestinationSet => translate('noDestinationSet');
  String get liveStreamActive => translate('liveStreamActive');
  String get locationStale => translate('locationStale');
  String get noActiveJourneyOrEmergency => translate('noActiveJourneyOrEmergency');
  String get locating => translate('locating');
  String get standby => translate('standby');
  String get noPerm => translate('noPerm');
  String get noGps => translate('noGps');
  String get enterTitleAtLeast3Chars => translate('enterTitleAtLeast3Chars');
  String get describeConcernAtLeast10Chars => translate('describeConcernAtLeast10Chars');
  String get locationDetailsOptional => translate('locationDetailsOptional');
  String get locationDetailsPlaceholder => translate('locationDetailsPlaceholder');
  String get titlePlaceholder => translate('titlePlaceholder');
  String get descriptionPlaceholder => translate('descriptionPlaceholder');
  String get attachGpsCoordinates => translate('attachGpsCoordinates');
  String get attachGpsCoordinatesDesc => translate('attachGpsCoordinatesDesc');
  String get titleAndDescRequired => translate('titleAndDescRequired');
  String get shakeCountdownMessage => translate('shakeCountdownMessage');
  String get seconds => translate('seconds');
  String get to => translate('to');
  String customDurationSetToMinutes(int val) => translate('customDurationSetToMinutes').replaceAll('{val}', val.toString());

  String get title => translate('title');
  String get description => translate('description');
  String get incidentCategory => translate('incidentCategory');
  String get editReport => translate('editReport');
  String get saveChanges => translate('saveChanges');
  String get safetyHeatmap => translate('safetyHeatmap');
  String get heatmapLayer => translate('heatmapLayer');
  String get showHeatmap => translate('showHeatmap');
  String get hideHeatmap => translate('hideHeatmap');
  String get hotspotRiskHigh => translate('hotspotRiskHigh');
  String get hotspotRiskModerate => translate('hotspotRiskModerate');
  String get hotspotRiskLow => translate('hotspotRiskLow');
  String get hotspotVerified => translate('hotspotVerified');
  String get hotspotCommunityReported => translate('hotspotCommunityReported');
  String get hotspotDisputed => translate('hotspotDisputed');
  String get hotspotDisclaimer => translate('hotspotDisclaimer');
  String hotspotReportsCount(int count) => translate('hotspotReportsCount').replaceAll('{count}', count.toString());
  String hotspotAuthorsCount(int count) => translate('hotspotAuthorsCount').replaceAll('{count}', count.toString());
  String hotspotLatestReport(String time) => translate('hotspotLatestReport').replaceAll('{time}', time);
  String get hotspotFeedbackTitle => translate('hotspotFeedbackTitle');
  String get stillPresent => translate('stillPresent');
  String get markResolved => translate('markResolved');
  String get markInaccurate => translate('markInaccurate');
  String get feedbackSubmitted => translate('feedbackSubmitted');
  String get feedbackError => translate('feedbackError');
  String get filterSafetyReports => translate('filterSafetyReports');
  String get allSafetyCategories => translate('allSafetyCategories');
  String get proactiveRouteAlertTitle => translate('proactiveRouteAlertTitle');
  String proactiveRouteAlertApproaching(int dist) => translate('proactiveRouteAlertApproaching').replaceAll('{dist}', dist.toString());
  String get proactiveRouteAlertInside => translate('proactiveRouteAlertInside');
  String get safetyAlertSettings => translate('safetyAlertSettings');
  String get enableRouteAlerts => translate('enableRouteAlerts');
  String get enableRouteAlertsDesc => translate('enableRouteAlertsDesc');
  String get alertWarningDistance => translate('alertWarningDistance');
  String get alertVibrate => translate('alertVibrate');
  String get alertSound => translate('alertSound');
  String get viewOriginalReport => translate('viewOriginalReport');
  String get dismiss => translate('dismiss');
  String safetyTimerStartedForMinutes(int minutes) => translate('safetyTimerStartedForMinutes').replaceAll('{mins}', minutes.toString());
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