import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/l10n/app_localizations.dart';
import 'package:nirbhay/models/app_language.dart';
import 'package:nirbhay/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('AppLanguage Model Tests', () {
    test('contains English, Hindi, and Gujarati', () {
      final codes = AppLanguage.supportedLanguages.map((l) => l.code).toList();
      expect(codes, containsAll(['en', 'hi', 'gu']));
      expect(AppLanguage.supportedLanguages.length, 3);
    });

    test('native names are correctly rendered in their native scripts', () {
      final en = AppLanguage.fromCode('en');
      final hi = AppLanguage.fromCode('hi');
      final gu = AppLanguage.fromCode('gu');

      expect(en.nativeName, 'English');
      expect(hi.nativeName, 'हिन्दी');
      expect(gu.nativeName, 'ગુજરાતી');
    });

    test('fromCode handles case sensitivity and invalid fallbacks', () {
      expect(AppLanguage.fromCode('HI').code, 'hi');
      expect(AppLanguage.fromCode('gU').code, 'gu');
      expect(AppLanguage.fromCode('EN').code, 'en');
      expect(AppLanguage.fromCode('invalid_code').code, 'en');
      expect(AppLanguage.fromCode(null).code, 'en');
    });
  });

  group('AppLocalizations Translation Dictionary Tests', () {
    test('English dictionary returns expected phrases', () {
      final l10n = AppLocalizations(const Locale('en', ''));
      expect(l10n.appName, 'Nirbhay');
      expect(l10n.tapForSos, 'TAP FOR SOS');
      expect(l10n.safetyTimer, 'Safety Timer');
      expect(l10n.fakeCall, 'Fake Call');
      expect(l10n.liveJourney, 'Live Journey');
      expect(l10n.emergencyContacts, 'Emergency Contacts');
    });

    test('Hindi dictionary returns Devanagari script strings and keeps Nirbhay in English', () {
      final l10n = AppLocalizations(const Locale('hi', ''));
      expect(l10n.appName, 'Nirbhay');
      expect(l10n.tapForSos, 'SOS के लिए टैप करें');
      expect(l10n.safetyTimer, 'सुरक्षा टाइमर');
      expect(l10n.fakeCall, 'फेक कॉल');
      expect(l10n.liveJourney, 'लाइव यात्रा');
      expect(l10n.emergencyContacts, 'आपातकालीन संपर्क');
      expect(l10n.goodMorning, 'सुप्रभात,');
    });

    test('Gujarati dictionary returns Gujarati script strings and keeps Nirbhay in English', () {
      final l10n = AppLocalizations(const Locale('gu', ''));
      expect(l10n.appName, 'Nirbhay');
      expect(l10n.tapForSos, 'SOS માટે ટેપ કરો');
      expect(l10n.safetyTimer, 'સેફ્ટી ટાઈમર');
      expect(l10n.fakeCall, 'ફેક કોલ');
      expect(l10n.liveJourney, 'લાઇવ મુસાફરી');
      expect(l10n.emergencyContacts, 'કટોકટી સંપર્કો');
      expect(l10n.goodMorning, 'શુભ સવાર,');
    });

    test('fallback to English when key is missing in non-English dictionary', () {
      final l10n = AppLocalizations(const Locale('hi', ''));
      // appName is defined, returns Nirbhay in English
      expect(l10n.translate('appName'), 'Nirbhay');
      // non-existent key returns key itself
      expect(l10n.translate('completely_non_existent_key_xyz'), 'completely_non_existent_key_xyz');
    });
  });

  group('LanguageService & Emergency SMS Templates', () {
    final languageService = LanguageService();

    test('buildLocalizedSosAlertMessage preserves coordinates and URLs', () {
      final now = DateTime(2026, 10, 30, 14, 30);
      const lat = 23.0225;
      const lng = 72.5714;
      const trackUrl = 'https://nirbhay.app/track/sos_987654';

      // English
      final enAlert = languageService.buildLocalizedSosAlertMessage(
        activatedAt: now,
        latitude: lat,
        longitude: lng,
        trackingUrl: trackUrl,
        targetLanguageCode: 'en',
      );
      expect(enAlert, contains('EMERGENCY ALERT: Nirbhay SOS'));
      expect(enAlert, contains('https://maps.google.com/?q=23.0225,72.5714'));
      expect(enAlert, contains(trackUrl));

      // Hindi
      final hiAlert = languageService.buildLocalizedSosAlertMessage(
        activatedAt: now,
        latitude: lat,
        longitude: lng,
        trackingUrl: trackUrl,
        targetLanguageCode: 'hi',
      );
      expect(hiAlert, contains('आपातकालीन अलर्ट: Nirbhay SOS'));
      expect(hiAlert, contains('https://maps.google.com/?q=23.0225,72.5714'));
      expect(hiAlert, contains(trackUrl));
      expect(hiAlert, contains('कृपया तुरंत सहायता करें।'));

      // Gujarati
      final guAlert = languageService.buildLocalizedSosAlertMessage(
        activatedAt: now,
        latitude: lat,
        longitude: lng,
        trackingUrl: trackUrl,
        targetLanguageCode: 'gu',
      );
      expect(guAlert, contains('ઇમરજન્સી એલર્ટ: Nirbhay SOS'));
      expect(guAlert, contains('https://maps.google.com/?q=23.0225,72.5714'));
      expect(guAlert, contains(trackUrl));
      expect(guAlert, contains('કૃપા કરીને તરત જ તપાસ કરો.'));
    });

    test('buildLocalizedSosAlertMessage handles last known location suffix', () {
      final now = DateTime(2026, 10, 30, 14, 30);
      final locTime = DateTime(2026, 10, 30, 14, 25);

      final hiLastKnown = languageService.buildLocalizedSosAlertMessage(
        activatedAt: now,
        latitude: 19.0760,
        longitude: 72.8777,
        isLastKnown: true,
        locationTimestamp: locTime,
        targetLanguageCode: 'hi',
      );
      expect(hiLastKnown, contains('[अंतिम ज्ञात स्थान'));

      final guLastKnown = languageService.buildLocalizedSosAlertMessage(
        activatedAt: now,
        latitude: 19.0760,
        longitude: 72.8777,
        isLastKnown: true,
        locationTimestamp: locTime,
        targetLanguageCode: 'gu',
      );
      expect(guLastKnown, contains('[છેલ્લું જાણીતું સ્થાન'));
    });

    test('buildLocalizedSosResolvedMessage accurately signals user safety', () {
      final enResolved = languageService.buildLocalizedSosResolvedMessage(targetLanguageCode: 'en');
      final hiResolved = languageService.buildLocalizedSosResolvedMessage(targetLanguageCode: 'hi');
      final guResolved = languageService.buildLocalizedSosResolvedMessage(targetLanguageCode: 'gu');

      expect(enResolved, contains('RESOLVED. User is SAFE now.'));
      expect(hiResolved, contains('उपयोगकर्ता अब सुरक्षित है।'));
      expect(guResolved, contains('વપરાશકર્તા હવે સુરક્ષિત છે.'));
    });

    test('buildLocalizedSafetyTimerExpiredMessage prompts verification', () {
      final enTimer = languageService.buildLocalizedSafetyTimerExpiredMessage(
        latitude: 28.6139,
        longitude: 77.2090,
        targetLanguageCode: 'en',
      );
      expect(enTimer, contains('SAFETY ALERT: Nirbhay Safety Timer expired'));
      expect(enTimer, contains('https://maps.google.com/?q=28.6139,77.209'));

      final hiTimer = languageService.buildLocalizedSafetyTimerExpiredMessage(
        latitude: 28.6139,
        longitude: 77.2090,
        targetLanguageCode: 'hi',
      );
      expect(hiTimer, contains('सुरक्षा अलर्ट: Nirbhay सेफ्टी टाइमर'));
      expect(hiTimer, contains('https://maps.google.com/?q=28.6139,77.209'));

      final guTimer = languageService.buildLocalizedSafetyTimerExpiredMessage(
        latitude: 28.6139,
        longitude: 77.2090,
        targetLanguageCode: 'gu',
      );
      expect(guTimer, contains('સુરક્ષા ચેતવણી: Nirbhay સેફ્ટી ટાઈમર'));
      expect(guTimer, contains('https://maps.google.com/?q=28.6139,77.209'));
    });

    test('buildLocalizedJourneyStartedMessage formats destination and URL', () {
      const dest = 'Central Railway Station';
      const url = 'https://nirbhay.app/journey/j_123';

      final enJourney = languageService.buildLocalizedJourneyStartedMessage(
        destination: dest,
        trackingUrl: url,
        targetLanguageCode: 'en',
      );
      expect(enJourney, contains('SAFE JOURNEY: Journey started to Central Railway Station.'));
      expect(enJourney, contains(url));

      final hiJourney = languageService.buildLocalizedJourneyStartedMessage(
        destination: dest,
        trackingUrl: url,
        targetLanguageCode: 'hi',
      );
      expect(hiJourney, contains('सुरक्षित यात्रा: Central Railway Station के लिए यात्रा शुरू हुई।'));
      expect(hiJourney, contains(url));

      final guJourney = languageService.buildLocalizedJourneyStartedMessage(
        destination: dest,
        trackingUrl: url,
        targetLanguageCode: 'gu',
      );
      expect(guJourney, contains('સુરક્ષિત મુસાફરી: Central Railway Station તરફ મુસાફરી શરૂ થઈ.'));
      expect(guJourney, contains(url));
    });
  });

  group('Reactive Multilingual UI Widget Tests', () {
    testWidgets('UI instantly re-renders when language changes without restart', (tester) async {
      final languageService = LanguageService();
      await languageService.setLanguage('en');

      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: languageService.localeNotifier,
          builder: (context, currentLocale, _) {
            return MaterialApp(
              locale: currentLocale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Scaffold(
                    body: Column(
                      children: [
                        Text(l10n.appName),
                        Text(l10n.tapForSos),
                        Text(l10n.safetyTimer),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      );

      // Verify English strings are initially shown
      expect(find.text('Nirbhay'), findsOneWidget);
      expect(find.text('TAP FOR SOS'), findsOneWidget);
      expect(find.text('Safety Timer'), findsOneWidget);

      // Switch to Hindi reactively
      await languageService.setLanguage('hi');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify immediate update to Hindi without restart (Nirbhay stays in English)
      expect(find.text('Nirbhay'), findsOneWidget);
      expect(find.text('SOS के लिए टैप करें'), findsOneWidget);
      expect(find.text('सुरक्षा टाइमर'), findsOneWidget);
      expect(find.text('TAP FOR SOS'), findsNothing);

      // Switch to Gujarati reactively
      await languageService.setLanguage('gu');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify immediate update to Gujarati without restart (Nirbhay stays in English)
      expect(find.text('Nirbhay'), findsOneWidget);
      expect(find.text('SOS માટે ટેપ કરો'), findsOneWidget);
      expect(find.text('સેફ્ટી ટાઈમર'), findsOneWidget);
      expect(find.text('SOS के लिए टैप करें'), findsNothing);
    });
  });
}
