import 'package:flutter/material.dart';

class SafetyTipsScreen extends StatefulWidget {
  const SafetyTipsScreen({super.key});

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen> {
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Colors.white;
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
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
              'Safety Tips & Awareness',
              style: TextStyle(
                fontSize: 12,
                color: _onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Color(0xFFFFD8ED), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Empowerment & Precautions',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Practical, expert-recommended safety protocols for daily commutes, night travel, and public transit.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFFE7BAD3), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Categories
              const Text(
                'Safety Guides',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
              ),
              const SizedBox(height: 12),

              _buildTipCategory(
                title: 'Night Travel & Cab Safety',
                icon: Icons.nightlife,
                tips: [
                  'Always check vehicle registration plate & driver photo matches ride app details before stepping in.',
                  'Enable Nirbhay Live Tracking to auto-share your real-time GPS location with your guardians.',
                  'Sit directly behind the driver to remain out of immediate arm reach in taxis.',
                  'Keep your phone battery above 30% and volume turned up during late-night transit.',
                ],
              ),
              const SizedBox(height: 12),

              _buildTipCategory(
                title: 'Public Transport & Metro Safety',
                icon: Icons.subway,
                tips: [
                  'Locate CISF/Security kiosks and emergency call buttons on Metro platforms.',
                  'Stay in well-lit areas near group commuters or designated women coaches.',
                  'If followed, head towards station station-master desks or active shops immediately.',
                ],
              ),
              const SizedBox(height: 12),

              _buildTipCategory(
                title: 'Digital & Cyber Protection',
                icon: Icons.phonelink_lock,
                tips: [
                  'Never share real-time location on public social media until after leaving a location.',
                  'Report cyber-harassment, morphing, or stalking immediately to 1930 Cyber Cell.',
                  'Use two-factor authentication on all social media and messaging apps.',
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCategory({
    required String title,
    required IconData icon,
    required List<String> tips,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _secondaryContainer,
                child: Icon(icon, size: 18, color: _primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: tips.map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: _primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(fontSize: 12.5, color: _onSurface, height: 1.35),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
