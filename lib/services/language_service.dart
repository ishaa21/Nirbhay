import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_language.dart';
import 'auth_service.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String storageKey = 'nirbhay_app_language';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _currentLanguageCode = 'en';

  /// ValueNotifier to trigger instant reactive UI rebuilds across the whole app
  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en', ''));

  String get currentLanguageCode => _currentLanguageCode;
  Locale get currentLocale => Locale(_currentLanguageCode, '');
  AppLanguage get currentLanguage => AppLanguage.fromCode(_currentLanguageCode);

  /// Initialize language from persistent local storage
  Future<void> init() async {
    try {
      final savedCode = await _storage.read(key: storageKey);
      if (savedCode != null && savedCode.isNotEmpty) {
        final code = savedCode.toLowerCase().trim();
        if (['en', 'hi', 'gu'].contains(code)) {
          _currentLanguageCode = code;
          localeNotifier.value = Locale(code, '');
          debugPrint('[LanguageService] Loaded persisted language: $code');
          return;
        }
      }
    } catch (e) {
      debugPrint('[LanguageService] Error loading language from storage: $e');
    }
    _currentLanguageCode = 'en';
    localeNotifier.value = const Locale('en', '');
  }

  /// Change active language instantly without app restart
  Future<void> setLanguage(String languageCode) async {
    final code = languageCode.toLowerCase().trim();
    if (!['en', 'hi', 'gu'].contains(code)) return;

    _currentLanguageCode = code;
    localeNotifier.value = Locale(code, '');

    // Persist locally for offline availability
    try {
      await _storage.write(key: storageKey, value: code);
    } catch (e) {
      debugPrint('[LanguageService] Failed to persist language locally: $e');
    }

    // Sync to backend if authenticated
    try {
      final token = await AuthService().getToken();
      if (token != null && token.isNotEmpty) {
        AuthService().updateProfile(preferredLanguage: code).ignore();
      }
    } catch (_) {}
  }

  // --- Localized Emergency SMS Templates ---

  /// Build localized SOS SMS Alert message
  String buildLocalizedSosAlertMessage({
    required DateTime activatedAt,
    double? latitude,
    double? longitude,
    bool isLastKnown = false,
    DateTime? locationTimestamp,
    String? trackingUrl,
    String? targetLanguageCode,
  }) {
    final lang = (targetLanguageCode ?? _currentLanguageCode).toLowerCase();
    final timeStr = activatedAt.toLocal().toString().split('.')[0];

    String locationStr;
    if (latitude != null && longitude != null) {
      final latStr = latitude.toStringAsFixed(4);
      final lngStr = longitude.toStringAsFixed(4);
      final mapsUrl = 'https://maps.google.com/?q=$latitude,$longitude';

      if (lang == 'hi') {
        if (isLastKnown) {
          final locTime = locationTimestamp?.toLocal().toString().split('.')[0] ?? '';
          final timeSuffix = locTime.isNotEmpty ? ' समय: $locTime' : '';
          locationStr = 'स्थान: $mapsUrl ($latStr, $lngStr) [अंतिम ज्ञात स्थान$timeSuffix]';
        } else {
          locationStr = 'स्थान: $mapsUrl ($latStr, $lngStr)';
        }
      } else if (lang == 'gu') {
        if (isLastKnown) {
          final locTime = locationTimestamp?.toLocal().toString().split('.')[0] ?? '';
          final timeSuffix = locTime.isNotEmpty ? ' સમય: $locTime' : '';
          locationStr = 'સ્થાન: $mapsUrl ($latStr, $lngStr) [છેલ્લું જાણીતું સ્થાન$timeSuffix]';
        } else {
          locationStr = 'સ્થાન: $mapsUrl ($latStr, $lngStr)';
        }
      } else {
        if (isLastKnown) {
          final locTime = locationTimestamp?.toLocal().toString().split('.')[0] ?? '';
          final timeSuffix = locTime.isNotEmpty ? ' as of $locTime' : '';
          locationStr = 'Location: $mapsUrl ($latStr, $lngStr) [LAST KNOWN LOCATION$timeSuffix]';
        } else {
          locationStr = 'Location: $mapsUrl ($latStr, $lngStr)';
        }
      }
    } else {
      if (lang == 'hi') {
        locationStr = 'स्थान: अनुपलब्ध';
      } else if (lang == 'gu') {
        locationStr = 'સ્થાન: ઉપલબ્ધ નથી';
      } else {
        locationStr = 'Location: Unavailable';
      }
    }

    String trackingStr = '';
    if (trackingUrl != null && trackingUrl.isNotEmpty) {
      if (lang == 'hi') {
        trackingStr = ' लाइव ट्रैकिंग: $trackingUrl';
      } else if (lang == 'gu') {
        trackingStr = ' લાઇવ ટ્રેકિંગ: $trackingUrl';
      } else {
        trackingStr = ' Live Tracking: $trackingUrl';
      }
    }

    switch (lang) {
      case 'hi':
        return 'आपातकालीन अलर्ट: निर्भय SOS $timeStr पर सक्रिय हुआ। $locationStr.$trackingStr कृपया तुरंत सहायता करें।';
      case 'gu':
        return 'ઇમરજન્સી એલર્ટ: નિર્ભય SOS $timeStr વાગ્યે સક્રિય થયું. $locationStr.$trackingStr કૃપા કરીને તરત જ તપાસ કરો.';
      case 'en':
      default:
        return 'EMERGENCY ALERT: Nirbhay SOS activated at $timeStr. $locationStr.$trackingStr Please check immediately.';
    }
  }

  /// Build localized SOS Resolved SMS message
  String buildLocalizedSosResolvedMessage({String? targetLanguageCode}) {
    final lang = (targetLanguageCode ?? _currentLanguageCode).toLowerCase();
    switch (lang) {
      case 'hi':
        return 'स्थिति अपडेट: निर्भय SOS आपातकालीन अलर्ट समाप्त हो गया है। उपयोगकर्ता अब सुरक्षित है। आगे किसी कार्रवाई की आवश्यकता नहीं है।';
      case 'gu':
        return 'સ્થિતિ અપડેટ: નિર્ભય SOS ઇમરજન્સી એલર્ટ પૂર્ણ થયું છે. વપરાશકર્તા હવે સુરક્ષિત છે. હવે કોઈ પગલાં લેવાની જરૂર નથી.';
      case 'en':
      default:
        return 'STATUS UPDATE: Nirbhay SOS emergency alert has been RESOLVED. User is SAFE now. No further action is required.';
    }
  }

  /// Build localized Safety Timer Expired SMS message
  String buildLocalizedSafetyTimerExpiredMessage({
    double? latitude,
    double? longitude,
    String? targetLanguageCode,
  }) {
    final lang = (targetLanguageCode ?? _currentLanguageCode).toLowerCase();
    String locPart = '';
    if (latitude != null && longitude != null) {
      locPart = ' https://maps.google.com/?q=$latitude,$longitude';
    }

    switch (lang) {
      case 'hi':
        return 'सुरक्षा अलर्ट: निर्भय सेफ्टी टाइमर समाप्त हो गया है और उपयोगकर्ता ने पुष्टि नहीं की है।$locPart कृपया तुरंत उनकी सुरक्षा की पुष्टि करें।';
      case 'gu':
        return 'સુરક્ષા ચેતવણી: નિર્ભય સેફ્ટી ટાઈમર સમાપ્ત થઈ ગયું છે અને વપરાશકર્તાએ પુષ્ટિ કરી નથી.$locPart કૃપા કરીને તરત જ તેમની સુરક્ષા ચકાસો.';
      case 'en':
      default:
        return 'SAFETY ALERT: Nirbhay Safety Timer expired without user check-in.$locPart Please verify their safety immediately.';
    }
  }

  /// Build localized Journey Started SMS message
  String buildLocalizedJourneyStartedMessage({
    required String destination,
    String? trackingUrl,
    String? targetLanguageCode,
  }) {
    final lang = (targetLanguageCode ?? _currentLanguageCode).toLowerCase();
    final trackStr = (trackingUrl != null && trackingUrl.isNotEmpty) ? ' $trackingUrl' : '';

    switch (lang) {
      case 'hi':
        return 'सुरक्षित यात्रा: $destination के लिए यात्रा शुरू हुई। लाइव ट्रैक करें:$trackStr';
      case 'gu':
        return 'સુરક્ષિત મુસાફરી: $destination તરફ મુસાફરી શરૂ થઈ. લાઇવ ટ્રેક કરો:$trackStr';
      case 'en':
      default:
        return 'SAFE JOURNEY: Journey started to $destination. Track live:$trackStr';
    }
  }

  /// Build localized Journey Ended SMS message
  String buildLocalizedJourneyEndedMessage({String? targetLanguageCode}) {
    final lang = (targetLanguageCode ?? _currentLanguageCode).toLowerCase();
    switch (lang) {
      case 'hi':
        return 'सुरक्षित यात्रा: उपयोगकर्ता सुरक्षित रूप से अपने गंतव्य पर पहुँच गया है।';
      case 'gu':
        return 'સુરક્ષિત મુસાફરી: વપરાશકર્તા સુરક્ષિત રીતે ગંતવ્ય પર પહોંચી ગયો છે.';
      case 'en':
      default:
        return 'SAFE JOURNEY: User has arrived safely at destination.';
    }
  }
}
