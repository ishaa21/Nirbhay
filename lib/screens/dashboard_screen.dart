import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 0;
  bool _sosPressing = false;
  late AnimationController _sosAnimController;
  late Animation<double> _sosScaleAnim;

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
    final theme = Theme.of(context);

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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Greeting
                      _buildGreeting(),
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

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
          Text(
            'NIRBHAY',
            style: const TextStyle(
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
                icon: const Icon(Icons.notifications_outlined,
                    size: 24, color: Color(0xFF1B1B1C)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Good evening, Ananya',
          style: TextStyle(
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
            Text(
              'Near HSR Layout, Bangalore',
              style: TextStyle(fontSize: 13, color: _textSecondary),
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
          _showSOSDialog();
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
              gradient: const RadialGradient(
                center: Alignment(0.1, -0.2),
                radius: 0.85,
                colors: [Color(0xFF4A1D30), Color(0xFF2A1020)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2A1020).withOpacity(0.35),
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
              children: const [
                Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Hold for 3s',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBBAFB5),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('SOS Alert', style: TextStyle(color: _textPrimary)),
        content: const Text(
          'This will alert your emergency contacts. In a real scenario, hold for 3 seconds to confirm.',
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
    },
    {
      'icon': Icons.my_location,
      'title': 'Live Tracking',
      'subtitle': 'Real-time sharing',
    },
    {
      'icon': Icons.phone_disabled_outlined,
      'title': 'Fake Call',
      'subtitle': 'Simulate a call to exit unsafe situations',
    },
    {
      'icon': Icons.support_agent_outlined,
      'title': 'Helplines',
      'subtitle': 'Local emergency contacts',
    },
    {
      'icon': Icons.security_outlined,
      'title': 'Shield Mode',
      'subtitle': 'High-alert security',
    },
    {
      'icon': Icons.lightbulb_outline,
      'title': 'Safety Tips',
      'subtitle': 'Guides and precautions',
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
        return _SafetyCard(
          icon: f['icon'] as IconData,
          title: f['title'] as String,
          subtitle: f['subtitle'] as String,
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
          // Simulated map background using a grid pattern
          CustomPaint(
            size: const Size(double.infinity, 160),
            painter: _MapPainter(),
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
                    color: _mapSafe.withOpacity(0.5), width: 1.5),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
  static const List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home_outlined, 'label': 'Home'},
    {'icon': Icons.map_outlined, 'label': 'Map'},
    {'icon': Icons.people_outline, 'label': 'Community'},
    {'icon': Icons.contacts_outlined, 'label': 'Contacts'},
    {'icon': Icons.person_outline, 'label': 'Profile'},
  ];

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: const Color(0xFFE5DFE2), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (index) {
          final isSelected = index == _selectedNavIndex;
          final item = _navItems[index];
          return GestureDetector(
            onTap: () => setState(() => _selectedNavIndex = index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? _navActiveBg
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 22,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF9E8E95),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF9E8E95),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
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

  const _SafetyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
        onTap: () {},
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
                color: Colors.black
                    .withOpacity(_hovered ? 0.07 : 0.03),
                blurRadius: _hovered ? 14 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon at top
              Icon(widget.icon, size: 22, color: const Color(0xFF2A1020)),
              // Text block in middle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1B1C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B6570),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Arrow at bottom-right
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward,
                    size: 16, color: Color(0xFF6B6570)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Map Painter  (draws a simple street-map-style background)
// ─────────────────────────────────────────────────────────────────
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF0EBE8);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    final minorPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Horizontal roads
    for (double y = 20; y < size.height; y += 38) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }
    // Vertical roads
    for (double x = 20; x < size.width; x += 55) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    // Minor diagonals
    canvas.drawLine(
        const Offset(0, 40), Offset(size.width * 0.5, size.height * 0.4),
        minorPaint);
    canvas.drawLine(
        Offset(size.width * 0.6, 0),
        Offset(size.width, size.height * 0.7),
        minorPaint);

    // Water-like blob (park/lake)
    final waterPaint = Paint()
      ..color = const Color(0xFFB3D9F5).withOpacity(0.6);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.75, size.height * 0.65),
          width: 60,
          height: 38),
      waterPaint,
    );

    // Green area
    final greenPaint = Paint()
      ..color = const Color(0xFFC8E6C9).withOpacity(0.5);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.28, size.height * 0.45),
          width: 70,
          height: 50),
      greenPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
