import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
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
          children: [
            const Text(
              'Nirbhay',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
            ),
            Text(
              l10n.safetyTips,
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
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Color(0xFFFFD8ED), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          l10n.empowermentPrecautions,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.empowermentPrecautionsSub,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFE7BAD3), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Categories
              Text(
                l10n.safetyTips,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
              ),
              const SizedBox(height: 12),

              _buildTipCategory(
                title: l10n.tipCatNightTravel,
                icon: Icons.nightlife,
                tips: [
                  l10n.tipNightTravel1,
                  l10n.tipNightTravel2,
                  l10n.tipNightTravel3,
                  l10n.tipNightTravel4,
                ],
              ),
              const SizedBox(height: 12),

              _buildTipCategory(
                title: l10n.tipCatPublicTransit,
                icon: Icons.subway,
                tips: [
                  l10n.tipPublicTransit1,
                  l10n.tipPublicTransit2,
                  l10n.tipPublicTransit3,
                ],
              ),
              const SizedBox(height: 12),

              _buildTipCategory(
                title: l10n.tipCatDigitalCyber,
                icon: Icons.phonelink_lock,
                tips: [
                  l10n.tipDigitalCyber1,
                  l10n.tipDigitalCyber2,
                  l10n.tipDigitalCyber3,
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
