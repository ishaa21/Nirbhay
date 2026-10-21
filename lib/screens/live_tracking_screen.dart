import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sos_service.dart';
import '../services/location_update_service.dart';
import '../services/journey_service.dart';
import '../models/sos_model.dart';
import '../models/journey_model.dart';

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
  Timer? _tickerTimer;
  Timer? _sosHoldTimer;

  @override
  void initState() {
    super.initState();
    _fetchActiveIncident();
    _fetchActiveJourney();
    LocationUpdateService().statusNotifier.addListener(_onTrackingStatusChanged);
    _tickerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
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
    return _activeJourney?.startLatitude;
  }

  double? get _displayLongitude {
    final pos = LocationUpdateService().lastPosition;
    if (pos != null) return pos.longitude;
    if (_activeJourney?.lastKnownLongitude != null) return _activeJourney!.lastKnownLongitude;
    if (_activeIncident?.longitude != null) return _activeIncident!.longitude;
    return _activeJourney?.startLongitude;
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
          // Real OpenStreetMap Interactive View
          Positioned.fill(
            child: (lat != null && lng != null)
                ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(lat, lng),
                      initialZoom: 16.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ishaa21.nirbhay',
                        maxZoom: 19,
                      ),
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
                  )
                : Container(
                    color: const Color(0xFFF0EBE8),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2, color: _primary),
                          SizedBox(height: 12),
                          Text(
                            'Acquiring live GPS fix...',
                            style: TextStyle(color: _onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
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
                  }
                  if (_activeIncident != null || _activeJourney != null) {
                    _syncLocationTracking();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Centered on live position.')),
                  );
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
                label: const Text('Share Live Link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                    : (hasActiveJourney ? _showSafetyPinDialog : null),
                icon: Icon(
                  hasActiveSos
                      ? Icons.check_circle_outline
                      : (hasActiveJourney ? Icons.lock_reset : Icons.lock_reset),
                  size: 18,
                ),
                label: Text(
                  hasActiveSos ? 'Resolve (Safe)' : (hasActiveJourney ? 'End Journey' : 'No Journey'),
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
                _isStartingJourney ? 'Starting...' : 'Start Journey & Share',
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
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (res['alreadyActive'] == true) {
      // Refresh to load the existing journey
      await _fetchActiveJourney();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A journey is already active.')),
      );
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
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Live tracking link copied:\n$url'),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active journey or SOS. Tap "Start Journey" to begin sharing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
  // Safety PIN Dialog (End Journey)
  // ──────────────────────────────────────────────────────────────────────────
  void _showSafetyPinDialog() {
    final List<TextEditingController> pinControllers = List.generate(4, (_) => TextEditingController());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.lock, color: _primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'End Journey Safely?',
                style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You have arrived safely. This will end your live tracking session and notify your guardians.',
              style: TextStyle(fontSize: 13, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 44,
                  height: 48,
                  child: TextField(
                    controller: pinControllers[index],
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primary),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF0EDEE),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty && index < 3) {
                        FocusScope.of(ctx).nextFocus();
                      }
                    },
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: _onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (_activeJourney != null) {
                final res = await JourneyService().endJourney(
                  journeyId: _activeJourney!.id,
                  reason: 'COMPLETED',
                );
                if (!mounted) return;
                if (res['success'] == true) {
                  setState(() => _activeJourney = null);
                  LocationUpdateService().stopJourneyTracking();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Journey completed safely. Guardians notified.'),
                      backgroundColor: Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message'] ?? 'Failed to end journey.')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Journey completed safely. Guardians notified.')),
                );
              }
            },
            child: const Text('Confirm & End', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

