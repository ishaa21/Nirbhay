import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../services/sos_service.dart';
import '../services/location_update_service.dart';
import '../services/journey_service.dart';
import '../services/api_config.dart';
import '../models/sos_model.dart';
import '../models/journey_model.dart';
import '../l10n/app_localizations.dart';

class LiveTrackingScreen extends StatefulWidget {

  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  bool _routeDeviationAlarm = true;
  SosIncidentModel? _activeIncident;
  JourneyModel? _activeJourney;
  bool _isLoadingIncident = true;
  bool _isStartingJourney = false;
  Position? _devicePosition;
  Timer? _tickerTimer;
  Timer? _sosHoldTimer;

  @override
  void initState() {
    super.initState();
    _initDeviceLocation();
    _fetchActiveIncident();
    _fetchActiveJourney();
    LocationUpdateService().statusNotifier.addListener(_onTrackingStatusChanged);
    _tickerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initDeviceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }

      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && mounted) {
        setState(() => _devicePosition = cached);
        try {
          _mapController.move(LatLng(cached.latitude, cached.longitude), 15.0);
        } catch (_) {}
      }

      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() => _devicePosition = fresh);
        try {
          _mapController.move(LatLng(fresh.latitude, fresh.longitude), 16.0);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[LiveTrackingScreen] Location acquisition note: $e');
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _sosHoldTimer?.cancel();
    LocationUpdateService().statusNotifier.removeListener(_onTrackingStatusChanged);
    super.dispose();
  }

  double? get _displayLatitude {
    final pos = LocationUpdateService().lastPosition;
    if (pos != null) return pos.latitude;
    if (_activeJourney?.lastKnownLatitude != null) return _activeJourney!.lastKnownLatitude;
    if (_activeIncident?.latitude != null) return _activeIncident!.latitude;
    if (_activeJourney?.startLatitude != null) return _activeJourney!.startLatitude;
    return _devicePosition?.latitude;
  }

  double? get _displayLongitude {
    final pos = LocationUpdateService().lastPosition;
    if (pos != null) return pos.longitude;
    if (_activeJourney?.lastKnownLongitude != null) return _activeJourney!.lastKnownLongitude;
    if (_activeIncident?.longitude != null) return _activeIncident!.longitude;
    if (_activeJourney?.startLongitude != null) return _activeJourney!.startLongitude;
    return _devicePosition?.longitude;
  }

  void _onTrackingStatusChanged() {
    if (mounted) {
      final lat = _displayLatitude;
      final lng = _displayLongitude;
      if (lat != null && lng != null) {
        try {
          _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
        } catch (_) {}
      }
      setState(() {});
    }
  }

  Future<void> _fetchActiveIncident() async {
    setState(() => _isLoadingIncident = true);
    final res = await SosService().getActiveSos();
    if (mounted) {
      setState(() {
        _isLoadingIncident = false;
        if (res['success'] == true && res['active'] == true) {
          _activeIncident = res['incident'];
        } else {
          _activeIncident = null;
        }
      });
      _syncLocationTracking();
    }
  }

  Future<void> _fetchActiveJourney() async {
    final res = await JourneyService().getActiveJourney();
    if (mounted) {
      setState(() {
        if (res['success'] == true && res['active'] == true) {
          _activeJourney = res['journey'] as JourneyModel?;
          if (_activeJourney != null) {
            _routeDeviationAlarm = _activeJourney!.routeDeviationEnabled;
          }
        } else {
          _activeJourney = null;
        }
      });
      _syncLocationTracking();
    }
  }

  void _syncLocationTracking() {
    final sosId = _activeIncident?.id;
    final journeyId = _activeJourney?.id;
    if (sosId != null || journeyId != null) {
      LocationUpdateService().start(sosId: sosId, journeyId: journeyId);
    } else if (LocationUpdateService().isRunning) {
      LocationUpdateService().stop();
    }
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'No fix yet';
    final diffSec = DateTime.now().difference(dt).inSeconds;
    if (diffSec < 5) return 'Updated just now';
    if (diffSec < 60) return 'Updated ${diffSec}s ago';
    final diffMin = diffSec ~/ 60;
    if (diffMin < 60) return 'Updated ${diffMin}m ago';
    return dt.toLocal().toString().split('.')[0].substring(11, 16);
  }

  // ── Color Palette (Matching Nirbhay Design System) ────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Colors.white;
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSecondaryContainer = Color(0xFF705D67);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _tertiaryFixed = Color(0xFFCCE5FF);
  static const Color _onTertiaryFixed = Color(0xFF001E31);
  static const Color _error = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface.withOpacity(0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Nirbhay',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
            ),
            Text(
              'Live Journey Tracking',
              style: TextStyle(
                fontSize: 12,
                color: _onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: _onSurface),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoadingIncident) ...[
                const LinearProgressIndicator(minHeight: 2, color: _primary),
                const SizedBox(height: 8),
              ],
              // 1. Active Safety Status Banner
              _buildStatusBanner(),
              const SizedBox(height: 16),

              // 2. Interactive Map Container with Markers & SOS
              _buildMapContainer(),
              const SizedBox(height: 16),

              // 3. Telemetry & Ride Specs Card
              _buildTelemetryCard(),
              const SizedBox(height: 16),

              // 4. Primary Journey Actions (Share & Stop)
              _buildPrimaryActions(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Active Safety Status Banner
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    final tracking = LocationUpdateService();
    final pos = tracking.lastPosition;
    final lastUpload = tracking.lastSuccessfulUploadTime;
    final isStale = tracking.isStale;
    final state = tracking.state;
    final hasActiveIncident = _activeIncident != null;
    final hasActiveJourney = _activeJourney != null;

    String title = hasActiveIncident
        ? 'Emergency Shield Active'
        : (hasActiveJourney ? 'Journey Shield Active' : 'Journey Shield Standby');
    String subtitle;
    if (state == TrackingState.gpsDisabled) {
      subtitle = 'GPS is disabled. Please enable device location.';
    } else if (state == TrackingState.permissionDenied) {
      subtitle = 'Location permission denied. Please grant permission.';
    } else if (state == TrackingState.authExpired) {
      subtitle = 'Session expired. Please log in again.';
    } else if (isStale && (hasActiveIncident || hasActiveJourney)) {
      subtitle = '⚠️ Location Stale — ${_formatRelativeTime(lastUpload)}';
    } else if ((hasActiveIncident || hasActiveJourney) && pos != null) {
      subtitle = 'Live stream active • ${_formatRelativeTime(lastUpload)}';
    } else if (hasActiveIncident || hasActiveJourney) {
      subtitle = 'Acquiring high-accuracy GPS fix...';
    } else {
      subtitle = 'No active journey or emergency. Tap SOS if in danger.';
    }

    String accuracyText = (hasActiveIncident || hasActiveJourney)
        ? (pos != null ? '±${pos.accuracy.toStringAsFixed(0)}m' : 'Locating')
        : 'Standby';
    if (state == TrackingState.gpsDisabled) {
      accuracyText = 'No GPS';
    } else if (state == TrackingState.permissionDenied) {
      accuracyText = 'No Perm';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: isStale ? Border.all(color: const Color(0xFFD32F2F), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: (isStale ? const Color(0xFFD32F2F) : Colors.black).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Pulsing active dot
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasActiveIncident
                            ? (isStale ? const Color(0xFFD32F2F) : _primary)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isStale ? const Color(0xFFBA1A1A) : _onSurfaceVariant,
                              fontWeight: isStale ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Battery & GPS Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isStale ? const Color(0xFFFFCDD2) : _secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isStale ? Icons.warning_amber_rounded : Icons.gps_fixed,
                      size: 13,
                      color: isStale ? const Color(0xFFBA1A1A) : _onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      accuracyText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isStale ? const Color(0xFFBA1A1A) : _onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Active Guardians Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGuardianPill('Mom', Icons.person, _primary),
                const SizedBox(width: 8),
                _buildGuardianPill('Sister Priya', Icons.person_3, _primary),
                const SizedBox(width: 8),
                _buildGuardianPill('112 Dispatch', Icons.local_police, _onTertiaryFixed, isPolice: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianPill(String name, IconData icon, Color activeColor, {bool isPolice = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPolice ? _tertiaryFixed : const Color(0xFFF0EDEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: activeColor.withOpacity(0.2),
            child: Icon(icon, size: 12, color: activeColor),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isPolice ? FontWeight.bold : FontWeight.w500,
              color: isPolice ? _onTertiaryFixed : _onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.check_circle, size: 14, color: activeColor),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Map Display Container with Floating SOS Trigger
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMapContainer() {
    final tracking = LocationUpdateService();
    final pos = tracking.lastPosition;
    final lastUpload = tracking.lastSuccessfulUploadTime;
    final isStale = tracking.isStale;
    final hasActiveIncident = _activeIncident != null;
    final hasActiveJourney = _activeJourney != null;
    final lat = _displayLatitude;
    final lng = _displayLongitude;

    final String coordText = lat != null && lng != null
        ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
        : ((hasActiveIncident || hasActiveJourney) ? 'Acquiring GPS Fix...' : 'Standby - No Fix');

    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: isStale ? Border.all(color: const Color(0xFFD32F2F), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Real OpenStreetMap Interactive View (always visible)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(lat ?? 28.6139, lng ?? 77.2090),
                initialZoom: (lat != null && lng != null) ? 16.0 : 13.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: ApiConfig.mapRasterTileUrl,
                  userAgentPackageName: ApiConfig.mapUserAgentPackage,
                  maxZoom: 19,
                ),
                if (lat != null && lng != null) ...[
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(lat, lng),
                        radius: (pos != null && pos.accuracy > 0) ? pos.accuracy : 25,
                        useRadiusInMeter: true,
                        color: (isStale ? const Color(0xFFD32F2F) : _primary).withOpacity(0.12),
                        borderColor: isStale ? const Color(0xFFD32F2F) : _primary,
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(lat, lng),
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isStale ? const Color(0xFFD32F2F) : _primary,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: (isStale ? const Color(0xFFD32F2F) : _primary).withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.navigation, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Navigation Waypoint / Staleness Badge Top-Left
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isStale ? const Color(0xFFFFEBEE) : Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                border: isStale ? Border.all(color: const Color(0xFFD32F2F)) : null,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isStale ? const Color(0xFFFFCDD2) : _tertiaryFixed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isStale ? Icons.warning_amber_rounded : Icons.gps_fixed,
                      size: 16,
                      color: isStale ? const Color(0xFFD32F2F) : _onTertiaryFixed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isStale ? 'Location Stale' : (pos != null ? 'Live GPS Stream' : 'Awaiting GPS Fix'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isStale ? const Color(0xFFD32F2F) : _onSurface,
                        ),
                      ),
                      Text(
                        _formatRelativeTime(lastUpload),
                        style: TextStyle(
                          fontSize: 10,
                          color: isStale ? const Color(0xFFBA1A1A) : _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Recenter / Refresh Map Button Top-Right
          Positioned(
            top: 12,
            right: 12,
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.95),
              child: IconButton(
                icon: const Icon(Icons.my_location, color: _primary, size: 20),
                tooltip: 'Recenter on live location',
                onPressed: () {
                  if (lat != null && lng != null) {
                    try {
                      _mapController.move(LatLng(lat, lng), 16.0);
                    } catch (_) {}
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Centered on live position.')),
                    );
                  } else {
                    _initDeviceLocation();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Acquiring current GPS location...')),
                    );
                  }
                  if (_activeIncident != null || _activeJourney != null) {
                    _syncLocationTracking();
                  }
                },
              ),
            ),
          ),

          // Open in Google Maps Button Bottom-Left
          Positioned(
            bottom: 14,
            left: 14,
            child: GestureDetector(
              onTap: _openGoogleMaps,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.map_outlined, size: 16, color: _primary),
                    SizedBox(width: 6),
                    Text(
                      'Google Maps',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Coordinates Badge Bottom-Center
          Positioned(
            bottom: 14,
            left: 140,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: isStale ? Border.all(color: const Color(0xFFD32F2F)) : null,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Text(
                coordText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isStale ? const Color(0xFFD32F2F) : _primary,
                ),
              ),
            ),
          ),

          // Floating SOS Pulse Button Bottom-Right
          Positioned(
            bottom: 14,
            right: 14,
            child: Column(
              children: [
                GestureDetector(
                  onLongPressStart: (_) {
                    _sosHoldTimer?.cancel();
                    _sosHoldTimer = Timer(const Duration(seconds: 2), () {
                      if (mounted) _triggerEmergencySOS();
                    });
                  },
                  onLongPressEnd: (_) => _sosHoldTimer?.cancel(),
                  onLongPressCancel: () => _sosHoldTimer?.cancel(),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _error,
                      boxShadow: [
                        BoxShadow(
                          color: _error.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Hold 2s',
                    style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Telemetry & Ride Specs Card
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTelemetryCard() {
    final tracking = LocationUpdateService();
    final pos = tracking.lastPosition;
    final lastUpload = tracking.lastSuccessfulUploadTime;
    final isStale = tracking.isStale;

    final String paceText = (pos != null && pos.speed >= 0)
        ? '${(pos.speed * 3.6).toStringAsFixed(1)} km/h'
        : '0.0 km/h';
    final String accuracyText = pos != null ? '±${pos.accuracy.toStringAsFixed(0)}m' : '--';
    final String statusText = isStale
        ? 'STALE'
        : (pos != null ? 'LIVE' : 'WAITING');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REAL-TIME TELEMETRY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pos != null
                          ? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'
                          : 'Awaiting Satellite Lock',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    Text(
                      pos != null
                          ? 'Accuracy: ±${pos.accuracy.toStringAsFixed(1)}m • Fix: ${_formatRelativeTime(lastUpload)}'
                          : 'Ensure device GPS is turned on with clear sky view',
                      style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isStale ? const Color(0xFFFFCDD2) : _secondaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isStale ? const Color(0xFFBA1A1A) : _primary,
                      ),
                    ),
                    Text(
                      _formatRelativeTime(lastUpload),
                      style: TextStyle(
                        fontSize: 10,
                        color: isStale ? const Color(0xFFBA1A1A) : _onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Telemetry Badges Grid (3 Stats)
          Row(
            children: [
              Expanded(
                child: _buildTelemetryBadge(
                  icon: Icons.speed,
                  title: paceText,
                  subtitle: 'Speed',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTelemetryBadge(
                  icon: Icons.gps_fixed,
                  title: accuracyText,
                  subtitle: 'GPS Accuracy',
                  isPrimaryText: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTelemetryBadge(
                  icon: Icons.access_time_filled,
                  title: _formatRelativeTime(lastUpload),
                  subtitle: 'Last Sync',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Route Deviation Alarm Toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _secondaryContainer,
                  child: const Icon(Icons.wrong_location, size: 18, color: _onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Route Deviation Alarm',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _onSurface),
                      ),
                      Text(
                        'Alert guardians if drift exceeds 150m',
                        style: TextStyle(fontSize: 11, color: _onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _routeDeviationAlarm,
                  activeColor: Colors.white,
                  activeTrackColor: _primary,
                  onChanged: (val) {
                    setState(() => _routeDeviationAlarm = val);
                    // Persist to backend if a journey is active
                    if (_activeJourney != null) {
                      JourneyService().updateDeviationAlarm(
                        journeyId: _activeJourney!.id,
                        enabled: val,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryBadge({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isPrimaryText = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: _onSecondaryContainer),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isPrimaryText ? _primary : _onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: _onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Primary Journey Action Buttons
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPrimaryActions() {
    final hasActiveSos = _activeIncident != null;
    final hasActiveJourney = _activeJourney != null;

    return Column(
      children: [
        Row(
          children: [
            // Share Live Link
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _shareTrackingLink,
                icon: const Icon(Icons.share, size: 18),
                label: Text(AppLocalizations.of(context).translate('shareLiveLink'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            // Resolve SOS / Stop journey
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasActiveSos
                      ? const Color(0xFF2E7D32)
                      : (hasActiveJourney ? const Color(0xFFBA1A1A) : _secondaryContainer),
                  foregroundColor: (hasActiveSos || hasActiveJourney) ? Colors.white : _onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: hasActiveSos
                    ? _handleResolveActiveSos
                    : (hasActiveJourney ? _showEndJourneyDialog : null),
                icon: Icon(
                  hasActiveSos
                      ? Icons.check_circle_outline
                      : (hasActiveJourney ? Icons.stop_circle_outlined : Icons.lock_reset),
                  size: 18,
                ),
                label: Text(
                  hasActiveSos ? AppLocalizations.of(context).translate('checkIn') : (hasActiveJourney ? AppLocalizations.of(context).translate('endJourneyButton') : 'No Journey'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Start Journey button (only when no journey or SOS active)
        if (!hasActiveSos && !hasActiveJourney)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _secondaryContainer,
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _isStartingJourney ? null : _startJourney,
              icon: _isStartingJourney
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                    )
                  : const Icon(Icons.play_circle_outline, size: 18),
              label: Text(
                _isStartingJourney ? AppLocalizations.of(context).translate('startingTimer') : AppLocalizations.of(context).translate('startJourneyButton'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (hasActiveJourney && !hasActiveSos)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: Color(0xFF2E7D32), size: 10),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Journey active since ${_formatJourneyDuration(_activeJourney!.startedAt)}  •  '  
                    '${_activeJourney!.destination != null ? "To: ${_activeJourney!.destination}" : "No destination set"}',
                    style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatJourneyDuration(DateTime startedAt) {
    final diff = DateTime.now().difference(startedAt);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  Future<void> _startJourney() async {
    setState(() => _isStartingJourney = true);
    final res = await JourneyService().startJourney(
      routeDeviationEnabled: _routeDeviationAlarm,
      forceNew: true,
    );
    if (!mounted) return;
    setState(() => _isStartingJourney = false);

    if (res['success'] == true) {
      final journey = res['journey'] as JourneyModel;
      setState(() => _activeJourney = journey);
      _syncLocationTracking();
      final url = res['trackingUrl'] as String? ?? journey.trackingUrl ?? '';
      if (url.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: url));
      }
      final notif = res['notifications'] as Map<String, dynamic>?;
      final smsNote = notif != null
          ? (notif['status'] == 'NOT_CONFIGURED'
              ? ' SMS gateway not configured on server.'
              : (notif['sentCount'] != null && (notif['sentCount'] as num) + (notif['pendingCount'] as num? ?? 0) > 0
                  ? ' Guardians notified via SMS.'
                  : ''))
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Journey started! Live link${url.isNotEmpty ? ' copied to clipboard' : ' generated'}.$smsNote',
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Offer immediate sharing sheet to send to WhatsApp / SMS
      if (url.isNotEmpty) {
        _showShareModal(url);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to start journey.')),
      );
    }
  }

  Future<void> _openGoogleMaps() async {
    final lat = _displayLatitude;
    final lng = _displayLongitude;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No GPS fix available yet to open in Google Maps.')),
      );
      return;
    }

    final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps.')),
        );
      }
    } catch (e) {
      debugPrint('[LiveTrackingScreen] Error opening maps: $e');
    }
  }

  void _shareTrackingLink() {
    // Prefer journey tracking URL; fall back to SOS tracking URL
    final url = _activeJourney?.trackingUrl ?? _activeIncident?.trackingUrl;
    if (url != null && url.isNotEmpty) {
      _showShareModal(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active journey or SOS. Tap "Start Journey & Share" first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showShareModal(String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Icon(Icons.share_location, color: _primary, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Share Live Journey Tracking',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Anyone with this link can view your live route and safety status in real time.',
                  style: TextStyle(fontSize: 13, color: _onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                // URL display & Copy box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F3F4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E0E3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          url,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _primary,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Live tracking link copied to clipboard!'),
                              backgroundColor: Color(0xFF2E7D32),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 15),
                        label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Quick Share Action buttons
                Row(
                  children: [
                    // WhatsApp
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final msg = Uri.encodeComponent(
                            'I am traveling and sharing my live journey with you for safety via Nirbhay:\n$url',
                          );
                          final waUri = Uri.parse('https://wa.me/?text=$msg');
                          try {
                            await launchUrl(waUri, mode: LaunchMode.externalApplication);
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not launch WhatsApp.')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // SMS
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: const BorderSide(color: _primary),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final msg = Uri.encodeComponent(
                            'I am traveling and sharing my live journey with you for safety via Nirbhay:\n$url',
                          );
                          final smsUri = Uri.parse('sms:?body=$msg');
                          try {
                            await launchUrl(smsUri, mode: LaunchMode.externalApplication);
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not launch SMS.')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: const Text('SMS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Browser preview
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _onSurfaceVariant,
                          side: const BorderSide(color: Color(0xFFD0C5CA)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: const Text('Open', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleResolveActiveSos() async {
    if (_activeIncident == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resolve Emergency SOS?'),
        content: const Text(
          'This will inform your emergency contacts that you are safe now and stop live location tracking.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I am Safe Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final id = _activeIncident!.id;
    final res = await SosService().resolveSos(id);
    if (!mounted) return;

    if (res['success'] == true) {
      LocationUpdateService().stop();
      setState(() => _activeIncident = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS resolved. "User is safe" SMS sent to emergency contacts.'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to resolve SOS.')),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // End Journey Confirmation Dialog
  // ──────────────────────────────────────────────────────────────────────────
  void _showEndJourneyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.stop_circle_outlined, color: Color(0xFFBA1A1A)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'End Live Journey?',
                style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your journey? Live location sharing with guardians will stop.',
          style: TextStyle(fontSize: 14, color: _onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Tracking', style: TextStyle(color: _onSurfaceVariant, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _endActiveJourney();
            },
            child: const Text('End Journey', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _endActiveJourney() async {
    final journeyId = _activeJourney?.id ?? 'active';
    final res = await JourneyService().endJourney(
      journeyId: journeyId,
      reason: 'COMPLETED',
    );
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _activeJourney = null);
      LocationUpdateService().stopJourneyTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journey ended safely. Live tracking stopped.'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await _fetchActiveJourney();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Could not end journey.')),
      );
    }
  }

  Future<void> _triggerEmergencySOS() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activating SOS Emergency Alert...')),
    );

    final res = await SosService().createSos();
    if (!mounted) return;

    if (res['success'] == true) {
      final incident = res['incident'] as SosIncidentModel;
      setState(() => _activeIncident = incident);
      _syncLocationTracking();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning, color: _error),
              SizedBox(width: 8),
              Text('EMERGENCY SOS ACTIVATED', style: TextStyle(color: _error, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            'Emergency alert #${incident.id.substring(0, 8)} has been activated on the network and dispatched to emergency contacts.',
            style: const TextStyle(color: _onSurface),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _error),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else if (res['alreadyActive'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An active SOS emergency incident is already in progress.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to activate SOS emergency alert.')),
      );
    }
  }
}

