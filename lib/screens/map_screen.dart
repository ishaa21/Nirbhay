import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  final NearbyService _nearbyService = NearbyService();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  LocationResultType? _locationErrorType;
  Position? _currentPosition;

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

  /// Initial load or full refresh
  Future<void> _loadLocationAndPlaces() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _locationErrorType = null;
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
      setState(() {
        _isLoading = false;
        _places = (res['places'] as List<NearbyPlaceModel>?) ?? [];
        _attribution = res['attribution']?.toString() ?? _attribution;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['message']?.toString() ?? 'Failed to retrieve nearby services.';
      });
    }
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

  /// Call a specific place phone number
  Future<void> _callPlace(String phone) async {
    // Strip non-dialable characters except leading plus
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // 1. Map visual representation with subtle coordinate marker
          _buildMapHeaderVisual(),

          // 2. Floating Action Button: Refresh GPS location
          Positioned(
            bottom: 220,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: _cardBg,
              foregroundColor: _primary,
              elevation: 4,
              tooltip: 'Refresh Location',
              onPressed: _isLoading ? null : _loadLocationAndPlaces,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                    )
                  : const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),

          // 3. Draggable bottom sheet with real places data
          Positioned.fill(
            child: _buildDraggableSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapHeaderVisual() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 260,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF26101F),
                    Color(0xFF3D1B32),
                    Color(0xFF1E0D19),
                  ],
                ),
              ),
              child: CustomPaint(
                painter: _GridPatternPainter(),
              ),
            ),
          ),

          // Header title & location status overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nearby Safety Help',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Verified police stations, hospitals & emergency services',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Active GPS pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentPosition != null ? Icons.location_on : Icons.location_off,
                          size: 13,
                          color: _currentPosition != null ? const Color(0xFF10B981) : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentPosition != null
                              ? 'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                              : 'Acquiring GPS location...',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.38,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.38, 0.68, 0.95],
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
              const SizedBox(height: 16),

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Category icon, Place Name, Distance & Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: place.categoryBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(place.categoryIcon, color: place.categoryIconColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 13,
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

          const SizedBox(height: 12),

          // Row 3: Action Buttons (Directions + Call)
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
              if (hasPhone) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: Color(0xFFF2D9E4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => _callPlace(place.phone!),
                  icon: const Icon(Icons.call_rounded, size: 14),
                  label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
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

/// Custom background painter for subtle map grid design
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
