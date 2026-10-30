import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../models/safety_hotspot_model.dart';
import 'community_service.dart';
import 'language_service.dart';
import 'location_update_service.dart';

class ProactiveRouteAlertService {
  static final ProactiveRouteAlertService _instance = ProactiveRouteAlertService._internal();
  factory ProactiveRouteAlertService() => _instance;
  ProactiveRouteAlertService._internal();

  static const String _channelName = 'com.ishaa21.nirbhay/route_alerts';
  static const MethodChannel _platform = MethodChannel(_channelName);

  static const String _keyEnabled = 'nirbhay_route_alerts_enabled';
  static const String _keyDistance = 'nirbhay_route_alerts_distance';
  static const String _keyVibrate = 'nirbhay_route_alerts_vibrate';
  static const String _keySound = 'nirbhay_route_alerts_sound';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // User preference state
  bool _isEnabled = true;
  int _warningDistanceMeters = 500;
  bool _vibrate = true;
  bool _sound = true;

  // Active in-memory alerts
  final ValueNotifier<SafetyHotspotModel?> activeAlertNotifier =
      ValueNotifier<SafetyHotspotModel?>(null);
  final ValueNotifier<List<SafetyHotspotModel>> upcomingAlertsNotifier =
      ValueNotifier<List<SafetyHotspotModel>>([]);

  // State machine for alert deduplication and tier tracking
  // hotspotId -> highest tier alerted ('EARLY', 'APPROACHING', 'INSIDE')
  final Map<String, String> _alertedTiers = {};
  // hotspotId -> last time alerted
  final Map<String, DateTime> _lastAlertTimestamps = {};

  // Cache for hotspots to avoid hitting backend every GPS update
  List<SafetyHotspotModel> _cachedHotspots = [];
  DateTime? _lastHotspotFetchTime;
  Position? _lastEvaluatedPosition;
  VoidCallback? _trackingListener;

  bool get isEnabled => _isEnabled;
  int get warningDistanceMeters => _warningDistanceMeters;
  bool get vibrate => _vibrate;
  bool get sound => _sound;
  Position? get lastEvaluatedPosition => _lastEvaluatedPosition;
  List<SafetyHotspotModel> get cachedHotspots => _cachedHotspots;

  /// Initialize preferences from secure storage and register tracking listener
  Future<void> init() async {
    try {
      final savedEnabled = await _storage.read(key: _keyEnabled);
      if (savedEnabled != null) {
        _isEnabled = savedEnabled == 'true';
      }

      final savedDist = await _storage.read(key: _keyDistance);
      if (savedDist != null) {
        _warningDistanceMeters = int.tryParse(savedDist) ?? 500;
      }

      final savedVib = await _storage.read(key: _keyVibrate);
      if (savedVib != null) {
        _vibrate = savedVib == 'true';
      }

      final savedSound = await _storage.read(key: _keySound);
      if (savedSound != null) {
        _sound = savedSound == 'true';
      }
    } catch (e) {
      debugPrint('[RouteAlertService] Error loading prefs: $e');
    }

    // Bind to LocationUpdateService to automatically monitor position during journeys
    if (_trackingListener != null) {
      LocationUpdateService().statusNotifier.removeListener(_trackingListener!);
    }
    _trackingListener = () {
      final status = LocationUpdateService().statusNotifier.value;
      if (status.position != null) {
        onLocationUpdated(status.position!);
      }
    };
    LocationUpdateService().statusNotifier.addListener(_trackingListener!);
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!enabled) {
      activeAlertNotifier.value = null;
      upcomingAlertsNotifier.value = [];
      _alertedTiers.clear();
    }
    await _storage.write(key: _keyEnabled, value: enabled.toString());
  }

  Future<void> setWarningDistance(int meters) async {
    _warningDistanceMeters = meters.clamp(200, 1000);
    await _storage.write(key: _keyDistance, value: _warningDistanceMeters.toString());
  }

  Future<void> setVibrate(bool value) async {
    _vibrate = value;
    await _storage.write(key: _keyVibrate, value: value.toString());
  }

  Future<void> setSound(bool value) async {
    _sound = value;
    await _storage.write(key: _keySound, value: value.toString());
  }

  /// Evaluates new GPS position against safety hotspots
  Future<void> onLocationUpdated(Position position, {List<Map<String, double>>? plannedWaypoints}) async {
    if (!_isEnabled) return;

    _lastEvaluatedPosition = position;

    // Refresh hotspot cache if older than 90 seconds or user moved > 1km from last fetch
    final now = DateTime.now();
    final cacheExpired = _lastHotspotFetchTime == null ||
        now.difference(_lastHotspotFetchTime!).inSeconds > 90;

    if (cacheExpired) {
      await _refreshHotspots(position.latitude, position.longitude);
    }

    _evaluateProximityToHotspots(position, plannedWaypoints);
  }

  Future<void> _refreshHotspots(double lat, double lng) async {
    try {
      final res = await CommunityService().getSafetyHotspots(
        latitude: lat,
        longitude: lng,
        radiusKm: 8.0,
      );

      if (res['success'] == true && res['hotspots'] is List<SafetyHotspotModel>) {
        _cachedHotspots = res['hotspots'] as List<SafetyHotspotModel>;
        _lastHotspotFetchTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('[RouteAlertService] Hotspot fetch failed: $e');
    }
  }

  void _evaluateProximityToHotspots(Position position, List<Map<String, double>>? waypoints) {
    if (_cachedHotspots.isEmpty) {
      activeAlertNotifier.value = null;
      upcomingAlertsNotifier.value = [];
      return;
    }

    final upcoming = <SafetyHotspotModel>[];
    SafetyHotspotModel? mostCriticalAlert;
    double closestDistance = double.infinity;

    final now = DateTime.now();

    for (final hotspot in _cachedHotspots) {
      final distMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        hotspot.latitude,
        hotspot.longitude,
      );

      // If user has moved far away (> 700m), clear encounter history so they can be re-alerted next time
      if (distMeters > _warningDistanceMeters + 250) {
        _alertedTiers.remove(hotspot.id);
        _lastAlertTimestamps.remove(hotspot.id);
        continue;
      }

      // Check if within warning horizon
      if (distMeters <= _warningDistanceMeters + hotspot.radiusMeters) {
        upcoming.add(hotspot);

        // Determine current proximity tier
        String currentTier = 'EARLY';
        if (distMeters <= hotspot.radiusMeters + 80) {
          currentTier = 'INSIDE';
        } else if (distMeters <= 220) {
          currentTier = 'APPROACHING';
        }

        // Deduplication & tier progression check
        final lastTier = _alertedTiers[hotspot.id];
        final lastTime = _lastAlertTimestamps[hotspot.id];
        final cooldownElapsed = lastTime == null || now.difference(lastTime).inMinutes >= 15;

        bool shouldNotify = false;
        if (lastTier == null) {
          shouldNotify = true; // First encounter
        } else if (currentTier == 'APPROACHING' && lastTier == 'EARLY') {
          shouldNotify = true; // Upgraded tier
        } else if (currentTier == 'INSIDE' && lastTier != 'INSIDE') {
          shouldNotify = true; // Entered danger zone
        } else if (cooldownElapsed) {
          shouldNotify = true; // Re-alert after cooldown
        }

        if (shouldNotify) {
          _alertedTiers[hotspot.id] = currentTier;
          _lastAlertTimestamps[hotspot.id] = now;
          _dispatchNotification(hotspot, distMeters.round(), currentTier);
        }

        if (distMeters < closestDistance) {
          closestDistance = distMeters;
          mostCriticalAlert = hotspot;
        }
      }
    }

    upcoming.sort((a, b) {
      final da = Geolocator.distanceBetween(position.latitude, position.longitude, a.latitude, a.longitude);
      final db = Geolocator.distanceBetween(position.latitude, position.longitude, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    upcomingAlertsNotifier.value = upcoming;
    activeAlertNotifier.value = mostCriticalAlert;
  }

  /// Dispatches heads-up notification using Android platform channel
  Future<void> _dispatchNotification(
    SafetyHotspotModel hotspot,
    int distanceMeters,
    String tier,
  ) async {
    final lang = LanguageService().currentLanguageCode.toLowerCase();

    String title;
    String body;
    final catName = _formatCategoryName(hotspot.primaryCategory, lang);

    if (lang == 'hi') {
      title = '⚠️ सुरक्षा अलर्ट: आगे संभावित असुरक्षित क्षेत्र';
      if (tier == 'INSIDE') {
        body = 'आप हाल ही में रिपोर्ट किए गए असुरक्षित क्षेत्र में हैं ($catName)। कृपया सतर्क रहें।';
      } else {
        body = 'आप $catName की रिपोर्ट वाले क्षेत्र के करीब पहुंच रहे हैं (~$distanceMeters मी)। कृपया अपने परिवेश के प्रति सचेत रहें।';
      }
    } else if (lang == 'gu') {
      title = '⚠️ સુરક્ષા એલર્ટ: આગળ સંભવિત અસુરક્ષિત વિસ્તાર';
      if (tier == 'INSIDE') {
        body = 'તમે તાજેતરમાં નોંધાયેલ અસુરક્ષિત ક્ષેત્રમાં છો ($catName). કૃપા કરીને સાવચેત રહો.';
      } else {
        body = 'તમે $catName ના અહેવાલવાળા વિસ્તારની નજીક પહોંચી રહ્યા છો (~$distanceMeters મી). કૃપા કરીને સાવચેત રહો.';
      }
    } else {
      title = '⚠️ Safety Alert: Potentially Unsafe Area Ahead';
      if (tier == 'INSIDE') {
        body = 'You are currently inside an area with recent safety reports ($catName). Please remain vigilant.';
      } else {
        body = 'Approaching area with community safety reports ($catName) in ~$distanceMeters m. Please stay alert.';
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _platform.invokeMethod('showSafetyAlert', {
          'title': title,
          'message': body,
          'hotspotId': hotspot.id,
          'latitude': hotspot.latitude,
          'longitude': hotspot.longitude,
          'riskLevel': hotspot.riskLevel.name.toUpperCase(),
          'vibrate': _vibrate,
          'sound': _sound,
        });
      } catch (e) {
        debugPrint('[RouteAlertService] Native notification dispatch error: $e');
      }
    }
  }

  String _formatCategoryName(String rawCategory, String lang) {
    final upper = rawCategory.toUpperCase();
    if (lang == 'hi') {
      switch (upper) {
        case 'HARASSMENT':
          return 'उत्पीड़न / छेड़छाड़';
        case 'UNSAFE_AREA':
          return 'असुरक्षित क्षेत्र';
        case 'SUSPICIOUS_ACTIVITY':
          return 'संदिग्ध गतिविधि';
        case 'THEFT':
          return 'चोरी / छिनैती';
        case 'ROAD_SAFETY':
          return 'सड़क सुरक्षा';
        default:
          return 'सुरक्षा चिंता';
      }
    } else if (lang == 'gu') {
      switch (upper) {
        case 'HARASSMENT':
          return 'હેરાનગતિ / છેડતી';
        case 'UNSAFE_AREA':
          return 'અસુરક્ષિત વિસ્તાર';
        case 'SUSPICIOUS_ACTIVITY':
          return 'શંકાસ્પદ પ્રવૃત્તિ';
        case 'THEFT':
          return 'ચોરી / લૂંટ';
        case 'ROAD_SAFETY':
          return 'માર્ગ સુરક્ષા';
        default:
          return 'સુરક્ષા ચિંતા';
      }
    } else {
      switch (upper) {
        case 'HARASSMENT':
          return 'Harassment';
        case 'UNSAFE_AREA':
          return 'Unsafe Area';
        case 'SUSPICIOUS_ACTIVITY':
          return 'Suspicious Activity';
        case 'THEFT':
          return 'Theft';
        case 'ROAD_SAFETY':
          return 'Road Safety';
        default:
          return 'Safety Concern';
      }
    }
  }

  void dismissActiveAlert() {
    activeAlertNotifier.value = null;
  }

  void dispose() {
    if (_trackingListener != null) {
      LocationUpdateService().statusNotifier.removeListener(_trackingListener!);
      _trackingListener = null;
    }
  }
}
