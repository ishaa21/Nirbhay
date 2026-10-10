import 'package:flutter/material.dart';
import '../models/sos_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/sos_service.dart';
import 'map_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'community_screen.dart';
import 'safety_timer_screen.dart';
import 'fake_call_screen.dart';
import 'live_tracking_screen.dart';
import 'helplines_screen.dart';
import 'safety_tips_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 0;
  // ignore: unused_field
  bool _sosPressing = false;
  late AnimationController _sosAnimController;
  late Animation<double> _sosScaleAnim;

  UserModel? _currentUser;
  SosIncidentModel? _activeSosIncident;
  bool _isActivatingSos = false;
  bool _isLoadingActiveSos = false;

  @override
  void initState() {
    super.initState();
    _sosAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _sosScaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _sosAnimController, curve: Curves.easeInOut),
    );
    _loadUserAndActiveSos();
  }

  Future<void> _loadUserAndActiveSos() async {
    final user = await AuthService().getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
    await _refreshActiveSos();
  }

  Future<void> _refreshActiveSos() async {
    setState(() => _isLoadingActiveSos = true);
    final res = await SosService().getActiveSos();
    if (mounted) {
      setState(() {
        _isLoadingActiveSos = false;
        if (res['success'] == true && res['active'] == true) {
          _activeSosIncident = res['incident'];
        } else {
          _activeSosIncident = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _sosAnimController.dispose();
    super.dispose();
  }

  // ── colour tokens ────────────────────────────────────────────────
  static const Color _bg = Color(0xFFF7F3F5);
  static const Color _cardBg = Colors.white;
  static const Color _sosDark = Color(0xFF2A1020);
  static const Color _accent = Color(0xFF301427);
  static const Color _textPrimary = Color(0xFF1B1B1C);
  static const Color _textSecondary = Color(0xFF6B6570);
  static const Color _navActiveBg = Color(0xFF2A1020);
  static const Color _mapSafe = Color(0xFF7BC67A);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        fontFamily: 'Roboto',
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top App Bar ──────────────────────────────────────
              _buildTopBar(),

              // ── Scrollable Body ──────────────────────────────────
              Expanded(child: _buildBody()),

              // ── Bottom Navigation ────────────────────────────────
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Top Bar
  // ─────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo text
          const Text(
            'NIRBHAY',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              color: Color(0xFF1B1B1C),
            ),
          ),
          // Notification bell
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_outlined,
                  size: 24,
                  color: Color(0xFF1B1B1C),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF301427),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Greeting
  // ─────────────────────────────────────────────────────────────────
  Widget _buildGreeting() {
    final name = _currentUser?.fullName.split(' ').first ?? 'User';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good evening, $name',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: const [
            Icon(Icons.location_on_outlined, size: 14, color: _textSecondary),
            SizedBox(width: 2),
            Expanded(
              child: Text(
                'Near HSR Layout, Bangalore',
                style: TextStyle(fontSize: 13, color: _textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  SOS Button
  // ─────────────────────────────────────────────────────────────────
  Widget _buildSOSButton() {
    return Center(
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _sosPressing = true);
          _sosAnimController.forward();
        },
        onTapUp: (_) {
          setState(() => _sosPressing = false);
          _sosAnimController.reverse();
          _triggerSosActivation();
        },
        onTapCancel: () {
          setState(() => _sosPressing = false);
          _sosAnimController.reverse();
        },
        child: ScaleTransition(
          scale: _sosScaleAnim,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(0.1, -0.2),
                radius: 0.85,
                colors: _activeSosIncident != null
                    ? [const Color(0xFFD32F2F), const Color(0xFF8B0000)]
                    : [const Color(0xFF4A1D30), _sosDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_activeSosIncident != null ? const Color(0xFFD32F2F) : _sosDark).withOpacity(0.35),
                  blurRadius: 32,
                  spreadRadius: 8,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.55),
                  blurRadius: 0,
                  spreadRadius: 14,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isActivatingSos) ...[
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ACTIVATING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ] else ...[
                  Text(
                    _activeSosIncident != null ? 'ACTIVE' : 'SOS',
                    style: TextStyle(
                      fontSize: _activeSosIncident != null ? 26 : 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _activeSosIncident != null ? 'Tap for Options' : 'Tap to Alert',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFBBAFB5),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _triggerSosActivation() async {
    if (_isActivatingSos) return;

    if (_activeSosIncident != null) {
      _showActiveSosModal(_activeSosIncident!);
      return;
    }

    setState(() => _isActivatingSos = true);

    final res = await SosService().createSos();

    if (!mounted) return;
    setState(() => _isActivatingSos = false);

    if (res['success'] == true) {
      final incident = res['incident'] as SosIncidentModel;
      setState(() => _activeSosIncident = incident);
      _showSosSuccessModal(incident, res['notifications']);
    } else if (res['alreadyActive'] == true) {
      final incident = res['incident'] as SosIncidentModel?;
      if (incident != null) {
        setState(() => _activeSosIncident = incident);
        _showActiveSosModal(incident);
      } else {
        _refreshActiveSos();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to trigger SOS alert.'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  void _showSosSuccessModal(SosIncidentModel incident, dynamic notificationSummary) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Color(0xFFD32F2F), size: 28),
            SizedBox(width: 8),
            Text('SOS Emergency Activated', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your emergency alert has been recorded on the Nirbhay safety network.',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Incident ID: ${incident.id.substring(0, 8)}...', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                  const SizedBox(height: 4),
                  Text('Status: ${incident.status}', style: const TextStyle(fontSize: 12, color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    incident.latitude != null 
                        ? 'Location: ${incident.latitude!.toStringAsFixed(4)}, ${incident.longitude!.toStringAsFixed(4)}'
                        : 'Location: Pending/Unavailable',
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleCancel(incident.id);
            },
            child: const Text('Cancel SOS', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A1020)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showActiveSosModal(SosIncidentModel incident) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.shield, color: Color(0xFFD32F2F)),
            SizedBox(width: 8),
            Text('Active SOS Incident', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'An emergency SOS alert triggered at ${incident.activatedAt.toLocal().toString().split('.')[0]} is currently active.',
          style: const TextStyle(color: _textSecondary),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleCancel(incident.id);
            },
            child: const Text('Cancel SOS', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleResolve(incident.id);
            },
            child: const Text('Resolve SOS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResolve(String incidentId) async {
    final res = await SosService().resolveSos(incidentId);
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _activeSosIncident = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS incident marked as RESOLVED. Safety network updated.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to resolve SOS.')),
      );
    }
  }

  Future<void> _handleCancel(String incidentId) async {
    final res = await SosService().cancelSos(incidentId);
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _activeSosIncident = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS incident CANCELLED.'),
          backgroundColor: Color(0xFF424242),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to cancel SOS.')),
      );
    }
  }


  // ─────────────────────────────────────────────────────────────────
  //  Section Label
  // ─────────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: _textSecondary,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Safety Suite Grid
  // ─────────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.timer_outlined,
      'title': 'Safety Timer',
      'subtitle': "Auto-alerts contacts if you don't check in",
      'route': 'safety_timer',
    },
    {
      'icon': Icons.my_location,
      'title': 'Live Tracking',
      'subtitle': 'Real-time sharing',
      'route': 'live_tracking',
    },
    {
      'icon': Icons.phone_disabled_outlined,
      'title': 'Fake Call',
      'subtitle': 'Simulate a call to exit unsafe situations',
      'route': 'fake_call',
    },
    {
      'icon': Icons.support_agent_outlined,
      'title': 'Helplines',
      'subtitle': 'Local emergency contacts',
      'route': 'helplines',
    },
    {
      'icon': Icons.lightbulb_outline,
      'title': 'Safety Tips',
      'subtitle': 'Guides and precautions',
      'route': 'safety_tips',
    },
  ];

  Widget _buildSafetyGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: _features.length,
      itemBuilder: (context, index) {
        final f = _features[index];
        final route = f['route'] as String?;
        return _SafetyCard(
          icon: f['icon'] as IconData,
          title: f['title'] as String,
          subtitle: f['subtitle'] as String,
          onTap: route == null
              ? null
              : () {
                  Widget screen;
                  if (route == 'safety_timer') {
                    screen = const SafetyTimerScreen();
                  } else if (route == 'live_tracking') {
                    screen = const LiveTrackingScreen();
                  } else if (route == 'fake_call') {
                    screen = const FakeCallScreen();
                  } else if (route == 'helplines') {
                    screen = const HelplinesScreen();
                  } else if (route == 'safety_tips') {
                    screen = const SafetyTipsScreen();
                  } else {
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => screen),
                  );
                },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Map Card
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMapCard() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D8DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
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
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCMNpoYuUMwvEnFQqv9iFS7jmGSEAb7Sr7BlZKYtsI4GXDyXhWxc-ZZ6wpIz4Hsw9g9D7oQkcWUR1_fyyZqi5bmrXYbH1nZspCzZBt_J82Z1FCec9qfsAigv9N_c2MQ8QZy6h03WHqoQGoib8DdpQ3xEOythfuxhtKH3lusXv9baA96J8lxzlMeYUJp5c42nRepht63An0WKi1uxLw9Om20cvDTQrjtCR_byMoZnEyO56i5xP6-b8NraOxy0nNdjGqY-YrLTe9rHjQ8',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFFF0EBE8),
                  child: const Center(
                    child: Icon(Icons.map, size: 36, color: Colors.grey),
                  ),
                );
              },
            ),
          ),

          // Safe zone circle
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _mapSafe.withOpacity(0.22),
                border: Border.all(
                  color: _mapSafe.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2056C0),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2056C0).withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Map label top-left
          Positioned(
            top: 8,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'HSR Layout, Bangalore',
                style: TextStyle(fontSize: 10, color: _textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Bottom Navigation
  // ─────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomPadding > 0 ? bottomPadding : 16,
      ),
      child: CurvedNavigationBar(
        currentIndex: _selectedNavIndex,
        activeColor: _navActiveBg,
        icons: const [
          Icons.home_outlined,
          Icons.map_outlined,
          Icons.people_outline,
          Icons.contact_phone_outlined,
          Icons.person_outline,
        ],
        onTap: (index) {
          setState(() {
            _selectedNavIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return const MapScreen();
      case 2:
        return const CommunityScreen();
      case 3:
        return const ContactsScreen();
      case 4:
        return const ProfileScreen();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildActiveSosCard(SosIncidentModel incident) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD32F2F), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ACTIVE SOS EMERGENCY INCIDENT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Activated: ${incident.activatedAt.toLocal().toString().split('.')[0]}',
            style: const TextStyle(fontSize: 12, color: Color(0xFFE0E0E0)),
          ),
          if (incident.latitude != null && incident.longitude != null) ...[
            const SizedBox(height: 2),
            Text(
              'Location: ${incident.latitude!.toStringAsFixed(4)}, ${incident.longitude!.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFBBAFB5)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleResolve(incident.id),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleCancel(incident.id),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Greeting
          _buildGreeting(),

          // Active Emergency Banner (if active SOS incident present)
          if (_activeSosIncident != null)
            _buildActiveSosCard(_activeSosIncident!),

          const SizedBox(height: 28),

          // SOS Button
          _buildSOSButton(),
          const SizedBox(height: 36),

          // Safety Suite
          _buildSectionLabel('SAFETY SUITE'),
          const SizedBox(height: 12),
          _buildSafetyGrid(),
          const SizedBox(height: 32),

          // Currently Safe Area
          _buildSectionLabel('CURRENTLY SAFE AREA'),
          const SizedBox(height: 12),
          _buildMapCard(),
          const SizedBox(height: 90), // Generous padding for floating nav bar
        ],
      ),
    );
  }


}

// ─────────────────────────────────────────────────────────────────
//  Safety Feature Card
// ─────────────────────────────────────────────────────────────────
class _SafetyCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SafetyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  State<_SafetyCard> createState() => _SafetyCardState();
}

class _SafetyCardState extends State<_SafetyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap ?? () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFD1B8C5)
                  : const Color(0xFFEDE7EA),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hovered ? 0.07 : 0.03),
                blurRadius: _hovered ? 14 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon at top
              Icon(widget.icon, size: 22, color: const Color(0xFF2A1020)),
              const SizedBox(height: 6),
              // Text block in middle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B6570),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Arrow at bottom-right
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Color(0xFF6B6570),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Curved Navigation Bar Widget
// ─────────────────────────────────────────────────────────────────
class CurvedNavigationBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> icons;
  final Color activeColor;

  const CurvedNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.icons,
    required this.activeColor,
  });

  @override
  State<CurvedNavigationBar> createState() => _CurvedNavigationBarState();
}

class _CurvedNavigationBarState extends State<CurvedNavigationBar> {
  double _prevIndex = 0.0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex.toDouble();
  }

  @override
  void didUpdateWidget(covariant CurvedNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _prevIndex = oldWidget.currentIndex.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    const double topPadding = 20.0;
    const double barHeight = 65.0;
    const double totalHeight = topPadding + barHeight; // 85.0
    const double circleRadius = 26.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double sidePadding = (width * 0.08).clamp(20.0, 28.0);

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: _prevIndex,
            end: widget.currentIndex.toDouble(),
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          builder: (context, animatedIndex, child) {
            // Calculate center X coordinates based on sidePadding
            final double usableWidth = width - 2 * sidePadding;
            final double activeX =
                sidePadding +
                (animatedIndex + 0.5) * (usableWidth / widget.icons.length);

            return SizedBox(
              width: width,
              height: totalHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Painted background with shadow and moving dip
                  CustomPaint(
                    size: Size(width, totalHeight),
                    painter: _NavBarPainter(
                      activeX: activeX,
                      topPadding: topPadding,
                      barHeight: barHeight,
                      dipWidth: 72.0,
                      dipDepth: circleRadius,
                    ),
                  ),

                  // 2. Inactive/Flat Icons
                  Positioned(
                    left: 0,
                    right: 0,
                    top: topPadding,
                    height: barHeight,
                    child: Row(
                      children: [
                        SizedBox(width: sidePadding),
                        ...List.generate(widget.icons.length, (index) {
                          final double dist = (animatedIndex - index).abs();
                          final double opacity = dist.clamp(0.0, 1.0);

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onTap(index),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Opacity(
                                  opacity: opacity,
                                  child: Icon(
                                    widget.icons[index],
                                    size: 24,
                                    color: const Color(0xFF9E8E95),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        SizedBox(width: sidePadding),
                      ],
                    ),
                  ),

                  // 3. Floating/Raised Active Circle containing the active icon
                  Positioned(
                    left: activeX - circleRadius,
                    top: topPadding - circleRadius,
                    child: GestureDetector(
                      onTap: () => widget.onTap(widget.currentIndex),
                      child: Container(
                        width: circleRadius * 2,
                        height: circleRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.activeColor, // Project's active nav bg
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            widget.icons[animatedIndex.round().clamp(
                              0,
                              widget.icons.length - 1,
                            )],
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Curved Navigation Bar Custom Painter
// ─────────────────────────────────────────────────────────────────
class _NavBarPainter extends CustomPainter {
  final double activeX;
  final double topPadding;
  final double barHeight;
  final double dipWidth;
  final double dipDepth;

  _NavBarPainter({
    required this.activeX,
    required this.topPadding,
    required this.barHeight,
    required this.dipWidth,
    required this.dipDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double bottom = size.height;
    const double R = 16.0; // Corner radius of the bar

    final path = Path();
    path.moveTo(R, topPadding);

    final double dipStart = activeX - dipWidth / 2;
    final double dipEnd = activeX + dipWidth / 2;

    // Draw top edge to dip start
    path.lineTo(dipStart, topPadding);

    // Draw dip (left half)
    path.cubicTo(
      dipStart + 14,
      topPadding,
      activeX - 14,
      topPadding + dipDepth,
      activeX,
      topPadding + dipDepth,
    );

    // Draw dip (right half)
    path.cubicTo(
      activeX + 14,
      topPadding + dipDepth,
      dipEnd - 14,
      topPadding,
      dipEnd,
      topPadding,
    );

    // Draw top edge to top-right corner
    path.lineTo(width - R, topPadding);

    // Top-right corner
    path.arcToPoint(
      Offset(width, topPadding + R),
      radius: const Radius.circular(R),
      clockwise: true,
    );

    // Right edge
    path.lineTo(width, bottom - R);

    // Bottom-right corner
    path.arcToPoint(
      Offset(width - R, bottom),
      radius: const Radius.circular(R),
      clockwise: true,
    );

    // Bottom edge
    path.lineTo(R, bottom);

    // Bottom-left corner
    path.arcToPoint(
      Offset(0, bottom - R),
      radius: const Radius.circular(R),
      clockwise: true,
    );

    // Left edge
    path.lineTo(0, topPadding + R);

    // Top-left corner
    path.arcToPoint(
      Offset(R, topPadding),
      radius: const Radius.circular(R),
      clockwise: true,
    );

    path.close();

    // Paint shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.08), 6.0, true);

    // Paint background
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NavBarPainter oldDelegate) {
    return oldDelegate.activeX != activeX ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.dipWidth != dipWidth ||
        oldDelegate.dipDepth != dipDepth;
  }
}
