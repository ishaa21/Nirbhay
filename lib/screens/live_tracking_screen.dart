import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  bool _routeDeviationAlarm = true;

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
              const SizedBox(height: 20),

              // 5. Safe Spots En Route
              _buildSafeSpotsSection(),
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
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Pulsing active dot
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Journey Shield Active',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '3 Guardians actively monitoring',
                            style: TextStyle(
                              fontSize: 12,
                              color: _onSurfaceVariant,
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
                  color: _secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.bolt, size: 14, color: _onSecondaryContainer),
                    SizedBox(width: 2),
                    Text(
                      '92%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _onSecondaryContainer,
                      ),
                    ),
                    Text(' • ', style: TextStyle(color: _onSecondaryContainer)),
                    Icon(Icons.gps_fixed, size: 13, color: _onSecondaryContainer),
                    SizedBox(width: 2),
                    Text(
                      'High',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _onSecondaryContainer,
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
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
          // Real map background image
          Positioned.fill(
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBgT-QSXwxNMNWdY-dwA2SNQwlc9OuGdo4VbnQQz2A4UiCuQqZmgsN_risUzWC9aEfYLtwSiy4rs-lZdZbTrp1crrEMQtUq-iMwysdgufazeKM3buHzJlRUuaweuNVIAWiwVjvi00P-uKpbVfzMcSCEUSr0vHIcb7L3Mz1hl0ITRu2XBg5SWeBFmDYCav6aSUaetODng-hAQnAhoA031DDJ1wizkkdy312MIWvEiD5n5LjI6krWzAXSmw',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFF0EBE8),
                child: const Center(child: Icon(Icons.map, size: 48, color: Colors.grey)),
              ),
            ),
          ),

          // Ambient Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    _primary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Navigation Waypoint Badge Top-Left
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _tertiaryFixed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.turn_sharp_right, size: 16, color: _onTertiaryFixed),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'In 240m on Barakhamba Rd',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _onSurface),
                      ),
                      Text(
                        'Optimal safety route locked',
                        style: TextStyle(fontSize: 10, color: _onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Recenter Map Button Top-Right
          Positioned(
            top: 12,
            right: 12,
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.95),
              child: IconButton(
                icon: const Icon(Icons.my_location, color: _primary, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Map centered on live position')),
                  );
                },
              ),
            ),
          ),

          // Live User Marker (Center)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.navigation, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Connaught Place',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primary),
                  ),
                ),
              ],
            ),
          ),

          // Destination Tag Bottom-Left
          Positioned(
            bottom: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.pin_drop, size: 16, color: _primary),
                  SizedBox(width: 4),
                  Text(
                    'Green Park Metro Stn',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary),
                  ),
                ],
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
                  onLongPress: () => _triggerEmergencySOS(),
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
          // Destination & ETA Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'DESTINATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Green Park Metro Station',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    Text(
                      'Gate No. 2, Ring Road Exit',
                      style: TextStyle(fontSize: 13, color: _onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _secondaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: const [
                    Text(
                      '18 min',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    Text(
                      'ETA 8:42 PM',
                      style: TextStyle(fontSize: 11, color: _onSecondaryContainer),
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
                  title: '24 km/h',
                  subtitle: 'Cab Pace',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTelemetryBadge(
                  icon: Icons.directions_car,
                  title: 'DL 1ZB 4291',
                  subtitle: 'Silver WagonR',
                  isPrimaryText: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTelemetryBadge(
                  icon: Icons.alt_route,
                  title: '5.2 km',
                  subtitle: 'Remaining',
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
                        'Notify guardians if route drifts >150m',
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
              fontSize: 13,
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
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Live link copied to clipboard: https://nirbhay.app/live/tr-9281a')),
              );
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Live Link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _secondaryContainer,
              foregroundColor: _onSecondaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => _showSafetyPinDialog(),
            icon: const Icon(Icons.lock_reset, size: 18),
            label: const Text('Stop (PIN)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Safe Spots En Route Section
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSafeSpotsSection() {
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
            children: [
              Row(
                children: const [
                  Icon(Icons.verified_user, color: _primary, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Safe Spots En Route',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _tertiaryFixed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '3 Nearby',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _onTertiaryFixed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pre-vetted emergency shelters with 24/7 security along your active corridor.',
            style: TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
          const SizedBox(height: 14),

          // Spot 1: Pink Booth
          _buildSafeSpotCard(
            title: 'Pink Police Booth #14',
            subtitle: 'Barakhamba Crossing • 450m ahead',
            icon: Icons.verified_user,
            iconBg: _secondaryContainer,
            actionIcon: Icons.call,
            onAction: () async {
              final url = Uri.parse('tel:112');
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
          ),
          const SizedBox(height: 10),

          // Spot 2: Pharmacy
          _buildSafeSpotCard(
            title: 'Apollo 24/7 Pharmacy',
            subtitle: 'Well-lit safe sanctuary • 1.1 km',
            icon: Icons.local_pharmacy,
            iconBg: _tertiaryFixed,
            actionIcon: Icons.directions,
            onAction: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rerouting to Apollo 24/7 Pharmacy')),
              );
            },
          ),
          const SizedBox(height: 10),

          // Spot 3: CISF Metro Security Kiosk
          _buildSafeSpotCard(
            title: 'CISF Metro Security Kiosk',
            subtitle: 'Gate 3, AIIMS station • 3.4 km',
            icon: Icons.subway,
            iconBg: _secondaryContainer,
            actionIcon: Icons.notifications_active,
            onAction: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Station Marshals notified of your arrival')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSafeSpotCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required IconData actionIcon,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primary),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onAction,
            style: IconButton.styleFrom(
              backgroundColor: _secondaryContainer,
              foregroundColor: _primary,
            ),
            icon: Icon(actionIcon, size: 18),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Safety PIN Dialog
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
            Text('Enter Safety PIN', style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 4-digit secret PIN to verify arrival and safely conclude journey sharing.',
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
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Journey completed safely. Guardians notified.')),
              );
            },
            child: const Text('Confirm & End', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _triggerEmergencySOS() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning, color: _error),
            SizedBox(width: 8),
            Text('EMERGENCY SOS', style: TextStyle(color: _error, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'High priority alert sent to 112 Command Center and all designated guardians with your live location.',
          style: TextStyle(color: _onSurface),
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
  }
}
