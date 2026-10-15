import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sos_model.dart';
import '../services/sos_service.dart';
import '../services/location_update_service.dart';
import 'fake_call_screen.dart';
import 'safety_timer_screen.dart';
import 'live_tracking_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuickEscapeScreen
//
// A high-stress, discreet escape hub:
//   • 1-Tap Trigger for Fake Call (discreet exit from uncomfortable situations).
//   • Fast shortcut to Safety Timer (cloud-persisted watchdog).
//   • Fast shortcut to Live Location Sharing.
//   • Explicitly DISTINCT Emergency SOS action with confirmation guard
//     to prevent accidental alerts (Requirement 7).
//   • Decoy / Disguise view for instant privacy.
// ─────────────────────────────────────────────────────────────────────────────

class QuickEscapeScreen extends StatefulWidget {
  const QuickEscapeScreen({super.key});

  @override
  State<QuickEscapeScreen> createState() => _QuickEscapeScreenState();
}

class _QuickEscapeScreenState extends State<QuickEscapeScreen> {
  // ── Color tokens ──────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _outlineVariant = Color(0xFFD1C3C9);
  static const Color _error = Color(0xFFBA1A1A);
  static const Color _primaryFixed = Color(0xFFFFD8ED);
  static const Color _primaryContainer = Color(0xFF48293D);
  static const Color _success = Color(0xFF2E7D32);

  bool _isActivatingSos = false;
  bool _showDecoyView = false;

  Future<void> _handleEmergencySos() async {
    // Show explicit confirmation dialog to keep real SOS distinct from simulated actions
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: _error, size: 26),
            SizedBox(width: 8),
            Text('Activate Real SOS?', style: TextStyle(color: _error, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'This will trigger a REAL emergency alert and dispatch SMS with your GPS location to all your emergency contacts.\n\n(If you only need a pretext to leave, use the simulated Fake Call instead.)',
          style: TextStyle(fontSize: 13.5, color: _onSurfaceVariant, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: _onSurfaceVariant, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DISPATCH SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActivatingSos = true);
    HapticFeedback.heavyImpact();

    final res = await SosService().createSos();
    if (!mounted) return;
    setState(() => _isActivatingSos = false);

    if (res['success'] == true) {
      final incident = res['incident'] as SosIncidentModel?;
      if (incident != null) {
        LocationUpdateService().start(incident.id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 SOS Alert Dispatched! Contacts notified with live location.'),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to trigger SOS alert.'),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showDecoyView) {
      return _buildDecoyScreen();
    }

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildStealthBanner(),
              const SizedBox(height: 20),

              // ── Quick Action 1: Fake Call ─────────────────────────────
              _buildActionCard(
                title: 'Simulate Fake Call',
                subtitle: 'Ring your phone immediately or in 10s with a realistic caller screen to excuse yourself.',
                badge: 'DISCREET EXIT',
                badgeColor: const Color(0xFF1976D2),
                icon: Icons.phone_callback_rounded,
                iconBg: const Color(0xFFE3F2FD),
                buttonLabel: 'Launch Fake Call',
                buttonColor: _primary,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FakeCallScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),

              // ── Quick Action 2: Safety Timer ──────────────────────────
              _buildActionCard(
                title: 'Safety Timer',
                subtitle: 'Cloud watchdog counts down (5-60 min) and alerts guardians automatically if you don\'t check in.',
                badge: 'AUTOMATIC WATCHDOG',
                badgeColor: const Color(0xFF7B1FA2),
                icon: Icons.timer_outlined,
                iconBg: const Color(0xFFF3E5F5),
                buttonLabel: 'Open Safety Timer',
                buttonColor: _primary,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SafetyTimerScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),

              // ── Quick Action 3: Live Location Sharing ─────────────────
              _buildActionCard(
                title: 'Live Location Sharing',
                subtitle: 'Share a secure web tracking link with your trusted emergency contacts.',
                badge: 'GUARDIAN TRACKING',
                badgeColor: _success,
                icon: Icons.my_location_rounded,
                iconBg: const Color(0xFFE8F5E9),
                buttonLabel: 'Share Live Location',
                buttonColor: _primary,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LiveTrackingScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Real Emergency SOS (Kept Distinct per Requirement 7) ──
              _buildDistinctSosSection(),
              const SizedBox(height: 20),

              // ── Decoy Mode ────────────────────────────────────────────
              _buildDecoyButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 20),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _primaryFixed, borderRadius: BorderRadius.circular(6)),
              child: const Text('05', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryContainer)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.exit_to_app_rounded, color: _primary, size: 20),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Quick Escape Hub',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _primary, height: 1.2),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fast-access tools to discreetly exit uncomfortable situations or initiate protection.',
          style: TextStyle(fontSize: 14, color: _onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildStealthBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, color: Color(0xFFF57F17), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fake Call is 100% simulated and will NOT notify contacts or authorities. Real emergency alerts are strictly kept in the separate SOS section below.',
              style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.35, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconBg,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: _primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _onSurface)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(fontSize: 12.5, color: _onSurfaceVariant, height: 1.35)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(buttonLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistinctSosSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _error.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: _error, size: 22),
              SizedBox(width: 8),
              Text(
                'REAL EMERGENCY ONLY',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _error, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'If you are in actual danger, use Real SOS. This dispatches SMS alerts with your real-time GPS location to your saved guardians.',
            style: TextStyle(fontSize: 12, color: Color(0xFF4A148C), height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isActivatingSos ? null : _handleEmergencySos,
              icon: _isActivatingSos
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.sos_rounded, color: Colors.white, size: 24),
              label: Text(
                _isActivatingSos ? 'Dispatching...' : 'TRIGGER REAL EMERGENCY SOS',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecoyButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () => setState(() => _showDecoyView = true),
        icon: const Icon(Icons.visibility_off_outlined, size: 18, color: _onSurfaceVariant),
        label: const Text('Open Decoy Disguise Screen (Hide App)', style: TextStyle(fontSize: 12.5, color: _onSurfaceVariant)),
      ),
    );
  }

  // ── Decoy Screen (Innocent Notes App Disguise) ────────────────────────────
  Widget _buildDecoyScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Quick Notes', style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_open_rounded, color: Colors.black54),
            tooltip: 'Return to Nirbhay',
            onPressed: () => setState(() => _showDecoyView = false),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Grocery List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 6),
                  Text('• Milk, Eggs, Bread\n• Green tea\n• Apples & Bananas\n• Almonds', style: TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Meeting Agenda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 6),
                  Text('• Review project timeline\n• Q4 design budget review\n• Client presentation at 4 PM', style: TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                'Tap the lock icon in the top right to return to safety suite.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
