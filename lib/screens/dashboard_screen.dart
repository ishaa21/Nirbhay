import 'package:flutter/material.dart';
import 'map_screen.dart';

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
                colors: [Color(0xFF4A1D30), _sosDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: _sosDark.withOpacity(0.35),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textSecondary),
            ),
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
        return _buildPlaceholderPage('Community');
      case 3:
        return _buildPlaceholderPage('Contacts');
      case 4:
        return _buildPlaceholderPage('Profile');
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
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
    );
  }

  Widget _buildPlaceholderPage(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            title == 'Community'
                ? Icons.people_outline
                : title == 'Contacts'
                ? Icons.contact_phone_outlined
                : Icons.person_outline,
            size: 48,
            color: const Color(0xFF807479),
          ),
          const SizedBox(height: 12),
          Text(
            '$title Page',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF807479),
            ),
          ),
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
                color: Colors.black.withOpacity(_hovered ? 0.07 : 0.03),
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
