import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sos_model.dart';
import '../services/sos_service.dart';
import '../services/location_update_service.dart';
import 'fake_call_screen.dart';
import 'safety_timer_screen.dart';
import 'live_tracking_screen.dart';
import '../l10n/app_localizations.dart';

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
          children: [
            const Icon(Icons.warning_rounded, color: _error, size: 26),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).activateRealSosDialogTitle, style: const TextStyle(color: _error, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).activateRealSosDialogDesc,
          style: const TextStyle(fontSize: 13.5, color: _onSurfaceVariant, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel.toUpperCase(), style: const TextStyle(color: _onSurfaceVariant, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).dispatchSosBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        LocationUpdateService().start(sosId: incident.id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).sosDispatchedLiveLocNotif),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).localizeBackendMessage(res['message'], fallback: AppLocalizations.of(context).failedToTriggerSosAlert)),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

              // ── Quick Action 1: Fake Call ─────────────────────────────
              _buildActionCard(
                title: l10n.translate('simulateFakeCall'),
                subtitle: l10n.translate('simulateFakeCallSub'),
                badge: l10n.translate('discreetExit'),
                badgeColor: const Color(0xFF1976D2),
                icon: Icons.phone_callback_rounded,
                iconBg: const Color(0xFFE3F2FD),
                buttonLabel: l10n.translate('launchFakeCall'),
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
                title: l10n.safetyTimer,
                subtitle: l10n.translate('safetyTimerWatchdog'),
                badge: l10n.translate('automaticWatchdog'),
                badgeColor: const Color(0xFF7B1FA2),
                icon: Icons.timer_outlined,
                iconBg: const Color(0xFFF3E5F5),
                buttonLabel: l10n.translate('openSafetyTimer'),
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
                title: l10n.translate('liveLocationSharing'),
                subtitle: l10n.translate('liveLocationSharingSub'),
                badge: l10n.translate('guardianTracking'),
                badgeColor: _success,
                icon: Icons.my_location_rounded,
                iconBg: const Color(0xFFE8F5E9),
                buttonLabel: l10n.translate('shareLiveLocation'),
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
        Text(
          AppLocalizations.of(context).quickEscape,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _primary, height: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context).quickEscapeSubtitle,
          style: TextStyle(fontSize: 14, color: _onSurfaceVariant, height: 1.4),
        ),
      ],
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
            children: [
              const Icon(Icons.warning_amber_rounded, color: _error, size: 22),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).translate('realEmergencyOnly'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _error, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('realSosWarningText'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF4A148C), height: 1.35),
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
                _isActivatingSos ? AppLocalizations.of(context).translate('dispatchingText') : AppLocalizations.of(context).translate('triggerRealEmergencySos'),
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
        label: Text(AppLocalizations.of(context).translate('openDecoyDisguise'), style: TextStyle(fontSize: 12.5, color: _onSurfaceVariant)),
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
        title: Text(AppLocalizations.of(context).quickNotesTitle, style: const TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_open_rounded, color: Colors.black54),
            tooltip: AppLocalizations.of(context).returnToNirbhayTooltip,
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
                children: [
                  Text(AppLocalizations.of(context).groceryListTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(AppLocalizations.of(context).groceryListItems, style: const TextStyle(fontSize: 13, height: 1.4)),
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
                children: [
                  Text(AppLocalizations.of(context).meetingAgendaTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(AppLocalizations.of(context).meetingAgendaItems, style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                AppLocalizations.of(context).tapLockToReturn,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
