import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/nearby_place_model.dart';
import '../services/nearby_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ── Color tokens matching existing theme ──────────────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF807479);
  static const Color _chipBg = Color(0xFFF2D9E4);
  static const Color _chipSelectedBg = Color(0xFF301427);
  static const Color _border = Color(0xFFD1C3C9);
  static const Color _emergencyRed = Color(0xFFD32F2F);

  // Category specific accent colors for markers and badges
  static const Color _policeColor = Color(0xFF1D4ED8);
  static const Color _hospitalColor = Color(0xFFDC2626);
  static const Color _pharmacyColor = Color(0xFF059669);
  static const Color _fireColor = Color(0xFFEA580C);

  final NearbyService _nearbyService = NearbyService();
  final MapController _mapController = MapController();
  final Map<String, GlobalKey> _cardKeys = {};

  // State
  bool _isLoading = false;
  String? _errorMessage;
  LocationResultType? _locationErrorType;
  Position? _currentPosition;
  String? _selectedPlaceId;

  String _selectedCategory = 'all';
  static const int _searchRadius = 5000; // 5 km default
  List<NearbyPlaceModel> _places = [];
  String _attribution = 'Data © OpenStreetMap contributors, ODbL 1.0';

  // Category filter definitions
  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': 'All Services', 'icon': Icons.shield_rounded},
    {'key': 'police', 'label': 'Police Stations', 'icon': Icons.local_police_rounded},
    {'key': 'hospital', 'label': 'Hospitals & Medical', 'icon': Icons.medical_services_rounded},
    {'key': 'pharmacy', 'label': 'Pharmacies', 'icon': Icons.local_pharmacy_rounded},
    {'key': 'fire_station', 'label': 'Fire Stations', 'icon': Icons.local_fire_department_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadLocationAndPlaces();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Initial load or full refresh
  Future<void> _loadLocationAndPlaces() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _locationErrorType = null;
      _selectedPlaceId = null;
    });

    final locResult = await _nearbyService.getCurrentLocation();

    if (locResult.type != LocationResultType.success || locResult.position == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _locationErrorType = locResult.type;
        _errorMessage = locResult.errorMessage ?? 'Unable to acquire GPS location.';
      });
      return;
    }

    _currentPosition = locResult.position;
    await _fetchPlacesForCategory(_selectedCategory);
  }

  /// Fetches places for the selected category from the backend
  Future<void> _fetchPlacesForCategory(String categoryKey) async {
    if (_currentPosition == null) {
      await _loadLocationAndPlaces();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedCategory = categoryKey;
      _selectedPlaceId = null;
    });

    final res = await _nearbyService.fetchNearbyPlaces(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      category: categoryKey,
      radius: _searchRadius,
      limit: 25,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final fetchedPlaces = (res['places'] as List<NearbyPlaceModel>?) ?? [];
      setState(() {
        _isLoading = false;
        _places = fetchedPlaces;
        _attribution = res['attribution']?.toString() ?? _attribution;
      });

      // Populate GlobalKeys for scroll tracking
      _cardKeys.clear();
      for (final p in _places) {
        _cardKeys[p.id] = GlobalKey();
      }

      // Auto-fit map viewport to show user position and nearby markers
      _fitMapToMarkers();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['message']?.toString() ?? 'Failed to retrieve nearby services.';
      });
    }
  }

  /// Automatically adjusts camera bounds so user and places are comfortably visible
  void _fitMapToMarkers() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentPosition == null) return;

      try {
        if (_places.isNotEmpty) {
          final points = [
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            ..._places.map((p) => LatLng(p.latitude, p.longitude)),
          ];

          final bounds = LatLngBounds.fromPoints(points);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.only(top: 80, bottom: 220, left: 40, right: 40),
              maxZoom: 16.0,
            ),
          );
        } else {
          _mapController.move(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            14.5,
          );
        }
      } catch (_) {
        // Fallback gracefully if map is not rendered yet
      }
    });
  }

  /// Center camera directly on user position
  void _centerOnUser() {
    if (_currentPosition == null) {
      _loadLocationAndPlaces();
      return;
    }
    _mapController.move(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      15.5,
    );
  }

  /// Handle tap on a place marker
  void _onMarkerTapped(NearbyPlaceModel place) {
    setState(() {
      _selectedPlaceId = place.id;
    });

    _mapController.move(
      LatLng(place.latitude, place.longitude),
      16.0,
    );

    // Scroll corresponding card into view in the sheet
    final targetKey = _cardKeys[place.id];
    if (targetKey?.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }
  }

  /// Handle tap on a place card
  void _onCardTapped(NearbyPlaceModel place) {
    setState(() {
      _selectedPlaceId = place.id;
    });

    _mapController.move(
      LatLng(place.latitude, place.longitude),
      16.0,
    );
  }

  /// One-tap emergency call to 112 (National Emergency Helpline)
  Future<void> _call112() async {
    final Uri uri = Uri.parse('tel:112');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnackBar('Unable to open phone dialer for 112.');
      }
    } catch (_) {
      _showSnackBar('Could not launch dialer.');
    }
  }

  /// Call a specific place phone number (opens dialer, does not place call automatically)
  Future<void> _callPlace(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      _showSnackBar('No valid phone number available for this location.');
      return;
    }
    final Uri uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnackBar('Unable to open phone dialer for $phone.');
      }
    } catch (_) {
      _showSnackBar('Could not launch phone dialer.');
    }
  }

  /// Open navigation / directions in Google Maps or default map app
  Future<void> _openDirections(NearbyPlaceModel place) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showSnackBar('Could not open map navigation application.');
      }
    } catch (_) {
      _showSnackBar('Could not open navigation directions.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'police':
        return _policeColor;
      case 'hospital':
        return _hospitalColor;
      case 'pharmacy':
        return _pharmacyColor;
      case 'fire_station':
        return _fireColor;
      default:
        return _primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // 1. Interactive OpenStreetMap Tile Layer with Markers
          Positioned.fill(
            child: _buildMapWidget(),
          ),

          // 2. Top Header Overlay (Title, Emergency Pill, GPS indicator)
          _buildTopHeaderOverlay(),

          // 3. Floating Map Controls (Re-center & Fit bounds)
          _buildFloatingMapControls(),

          // 4. Draggable Scrollable Bottom Sheet with Place Cards
          Positioned.fill(
            child: _buildDraggableSheet(),
          ),
        ],
      ),
    );
  }

  /// Builds the real interactive OpenStreetMap widget
  Widget _buildMapWidget() {
    final initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(28.6139, 77.2090); // Default fallback: New Delhi

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 14.0,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: (tapPosition, point) {
          if (_selectedPlaceId != null) {
            setState(() {
              _selectedPlaceId = null;
            });
          }
        },
      ),
      children: [
        // Standard OpenStreetMap tiles (free, worldwide coverage, no proprietary API keys required)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ishaa21.nirbhay',
          maxZoom: 19,
        ),
        // Place and User Markers
        MarkerLayer(
          markers: _buildMapMarkers(),
        ),
      ],
    );
  }

  /// Constructs markers for user location and all nearby services
  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[];

    // User Location Marker (Pulsing blue pin)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: _centerOnUser,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                ),
                // Inner solid pin
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Nearby Service Place Markers
    for (final place in _places) {
      final isSelected = _selectedPlaceId == place.id;
      final markerColor = _getCategoryColor(place.category);

      markers.add(
        Marker(
          point: LatLng(place.latitude, place.longitude),
          width: isSelected ? 52 : 38,
          height: isSelected ? 52 : 38,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _onMarkerTapped(place),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected ? markerColor : markerColor.withOpacity(0.92),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.yellowAccent : Colors.white,
                  width: isSelected ? 3.0 : 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? markerColor.withOpacity(0.6) : Colors.black26,
                    blurRadius: isSelected ? 10 : 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  place.categoryIcon,
                  color: Colors.white,
                  size: isSelected ? 24 : 18,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  /// Top header overlay with dark-gradient backdrop for readability over map tiles
  Widget _buildTopHeaderOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.75),
              Colors.black.withOpacity(0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // App Logo / Shield
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Nearby Safety Help',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _currentPosition != null
                            ? 'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                            : 'Acquiring GPS fix...',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                // Live location status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentPosition != null
                        ? const Color(0xFF10B981).withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentPosition != null
                          ? const Color(0xFF10B981)
                          : Colors.orangeAccent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentPosition != null ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                        size: 12,
                        color: _currentPosition != null ? const Color(0xFF10B981) : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentPosition != null ? 'Live GPS' : 'No GPS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _currentPosition != null ? const Color(0xFF10B981) : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Floating map buttons (My Location and Fit View)
  Widget _buildFloatingMapControls() {
    return Positioned(
      top: 100,
      right: 14,
      child: Column(
        children: [
          // Re-center on user
          FloatingActionButton.small(
            heroTag: 'btn_recenter',
            backgroundColor: _cardBg,
            foregroundColor: _primary,
            elevation: 3,
            tooltip: 'My Location',
            onPressed: _centerOnUser,
            child: const Icon(Icons.my_location_rounded, size: 18),
          ),
          const SizedBox(height: 8),
          // Fit all places in view
          FloatingActionButton.small(
            heroTag: 'btn_fit_bounds',
            backgroundColor: _cardBg,
            foregroundColor: _primary,
            elevation: 3,
            tooltip: 'Show All Places',
            onPressed: _fitMapToMarkers,
            child: const Icon(Icons.crop_free_rounded, size: 18),
          ),
          const SizedBox(height: 8),
          // Refresh GPS and Places
          FloatingActionButton.small(
            heroTag: 'btn_refresh',
            backgroundColor: _cardBg,
            foregroundColor: _primary,
            elevation: 3,
            tooltip: 'Refresh Location & Places',
            onPressed: _isLoading ? null : _loadLocationAndPlaces,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  /// Draggable bottom sheet housing places list, Call 112 banner, and category filters
  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.22,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.22, 0.52, 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Prominent Call 112 Option (Always Accessible) ──────────────
              _buildCall112Banner(),
              const SizedBox(height: 14),

              // Category Filter Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nearby Safe Zones',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                  if (!_isLoading && _places.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _chipBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_places.length} found',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Horizontal Category Chips
              _buildCategoryChips(),
              const SizedBox(height: 14),

              // Dynamic Body depending on state
              if (_isLoading)
                _buildLoadingState()
              else if (_locationErrorType != null)
                _buildLocationErrorState()
              else if (_errorMessage != null)
                _buildErrorMessageState()
              else if (_places.isEmpty)
                _buildEmptyState()
              else
                ..._places.map((place) => _buildPlaceCard(place)),

              const SizedBox(height: 20),
              // OpenStreetMap attribution footer
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    _attribution,
                    style: const TextStyle(fontSize: 10, color: _onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Prominent one-tap Call 112 emergency banner
  Widget _buildCall112Banner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _emergencyRed.withOpacity(0.3), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _emergencyRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _emergencyRed.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Immediate Danger? Call 112',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _emergencyRed,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'All-India Emergency Helpline for Police & Medical assistance',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B2121)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _emergencyRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: _call112,
            child: const Text(
              'Call 112',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal category filter chips
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['key'];
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _isLoading
                ? null
                : () {
                    if (!isSelected) {
                      _fetchPlacesForCategory(cat['key'] as String);
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _chipSelectedBg : _chipBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    size: 15,
                    color: isSelected ? Colors.white : const Color(0xFF705D67),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF705D67),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Loading state with spinner and context message
  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: _primary),
            const SizedBox(height: 16),
            Text(
              'Finding nearby ${_getCategoryLabel(_selectedCategory).toLowerCase()}...',
              style: const TextStyle(fontSize: 13, color: _onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// Location error states (permission denied / GPS disabled)
  Widget _buildLocationErrorState() {
    final isPerm = _locationErrorType == LocationResultType.permissionDenied ||
        _locationErrorType == LocationResultType.permissionDeniedForever;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        children: [
          Icon(
            isPerm ? Icons.location_disabled_rounded : Icons.gps_off_rounded,
            size: 48,
            color: Colors.orange.shade700,
          ),
          const SizedBox(height: 12),
          Text(
            isPerm ? 'Location Permission Needed' : 'Device GPS is Turned Off',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Location access is required to discover nearby emergency services.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              if (_locationErrorType == LocationResultType.permissionDeniedForever) {
                await Geolocator.openAppSettings();
              } else if (_locationErrorType == LocationResultType.serviceDisabled) {
                await Geolocator.openLocationSettings();
              }
              _loadLocationAndPlaces();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              _locationErrorType == LocationResultType.permissionDeniedForever
                  ? 'Open App Settings'
                  : 'Enable & Retry',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Error message state with retry
  Widget _buildErrorMessageState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text(
            'Unable to Load Services',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Network error. Please verify your internet connection.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => _fetchPlacesForCategory(_selectedCategory),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Try Again', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Empty state when no places found in radius
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 46, color: _onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No ${_getCategoryLabel(_selectedCategory)} Found Nearby',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'No records found within ${_searchRadius ~/ 1000} km of your location on OpenStreetMap.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_selectedCategory != 'all')
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _fetchPlacesForCategory('all'),
              child: const Text('Show All Nearby Safety Services', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  /// Real place card with name, address, distance, opening status, and Directions/Call buttons
  Widget _buildPlaceCard(NearbyPlaceModel place) {
    final hasPhone = place.phone != null && place.phone!.trim().isNotEmpty;
    final isSelected = _selectedPlaceId == place.id;
    final categoryColor = _getCategoryColor(place.category);

    return InkWell(
      key: _cardKeys[place.id],
      borderRadius: BorderRadius.circular(14),
      onTap: () => _onCardTapped(place),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _chipBg.withOpacity(0.35) : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _primary : _border.withOpacity(0.35),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? _primary.withOpacity(0.08) : Colors.black.withOpacity(0.03),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Category badge, Place Name, Distance & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(place.categoryIcon, color: categoryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            place.distanceFormatted,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _border,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            place.displayStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: place.isVerifiedOpen
                                  ? const Color(0xFF059669)
                                  : _onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Indicator icon when selected
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.location_pin, color: _primary, size: 20),
                  ),
              ],
            ),

            // Row 2: Address (if available)
            if (place.address != null && place.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                place.address!,
                style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Row 3: Phone number display or "Phone number unavailable" label
            const SizedBox(height: 8),
            if (hasPhone)
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 13, color: _primary),
                  const SizedBox(width: 5),
                  Text(
                    place.phone!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.phone_disabled_outlined, size: 13, color: _onSurfaceVariant.withOpacity(0.8)),
                  const SizedBox(width: 5),
                  Text(
                    'Phone number unavailable',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: _onSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // Row 4: Action Buttons (Directions + Call)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () => _openDirections(place),
                    icon: const Icon(Icons.directions_rounded, size: 15),
                    label: const Text('Directions', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                // Call button: Enabled when valid phone exists, disabled with unavailable indicator when missing
                if (hasPhone)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: Color(0xFF807479), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => _callPlace(place.phone!),
                    icon: const Icon(Icons.call_rounded, size: 15),
                    label: const Text(
                      'Call',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Tooltip(
                    message: 'Phone number unavailable',
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _onSurfaceVariant.withOpacity(0.4),
                        side: BorderSide(color: _border.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: null,
                      icon: Icon(
                        Icons.phone_disabled_rounded,
                        size: 15,
                        color: _onSurfaceVariant.withOpacity(0.4),
                      ),
                      label: Text(
                        'Call',
                        style: TextStyle(fontSize: 12, color: _onSurfaceVariant.withOpacity(0.4)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String key) {
    for (final c in _categories) {
      if (c['key'] == key) return c['label'] as String;
    }
    return 'Services';
  }
}
