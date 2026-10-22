import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/safety_timer_model.dart';
import '../services/safety_timer_service.dart';
import 'signin_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SafetyTimerScreen
//
// Full backend-integrated Safety Timer screen.
//   • Fetches any active timer from the server on load (recovery after restart).
//   • Selectable durations: 5, 15, 30, 60 minutes.
//   • Actions while ACTIVE: Check In (safe), Extend (+5/+15/+30/+60), Cancel.
//   • Server-side expiry detection — countdown is local feedback;
//     authoritative detection runs on the backend cron scheduler.
//   • Pre-expiry notification (haptic, sound, visual urgent banner).
//   • Clear onboarding explaining connectivity & SMS gateway requirements.
//   • Handles offline status, session expiry, and extensions.
// ─────────────────────────────────────────────────────────────────────────────

class SafetyTimerScreen extends StatefulWidget {
  const SafetyTimerScreen({super.key});

  @override
  State<SafetyTimerScreen> createState() => _SafetyTimerScreenState();
}

class _SafetyTimerScreenState extends State<SafetyTimerScreen>
    with SingleTickerProviderStateMixin {
  // ── Color tokens ──────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _primaryFixed = Color(0xFFFFD8ED);
  static const Color _primaryContainer = Color(0xFF48293D);
  static const Color _outlineVariant = Color(0xFFD1C3C9);
  static const Color _error = Color(0xFFBA1A1A);
  static const Color _warningBg = Color(0xFFFFF3CD);
  static const Color _successColor = Color(0xFF2E7D32);
  static const Color _urgentBg = Color(0xFFFFEBEE);

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loadingInitial = true;
  bool _processing = false; // API call in progress
  SafetyTimerModel? _activeTimer;
  int _selectedMinutes = 30;
  int _timeLeftSeconds = 30 * 60;
  Timer? _countdownTimer;
  // Custom timer input handling
  bool _customMode = false;
  final TextEditingController _customController = TextEditingController();
  bool _preExpiryAlertFired = false;

  // ── Pulse animation ───────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ── Config ────────────────────────────────────────────────────────────────
  static const List<int> _durations = [5, 15, 30, 60];
  static const List<int> _extensions = [5, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadActiveTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _customController.dispose();
    super.dispose();
  }

  // ── Backend interactions ──────────────────────────────────────────────────

  Future<void> _loadActiveTimer() async {
    setState(() => _loadingInitial = true);
    final res = await SafetyTimerService().getActiveTimer();
    if (!mounted) return;

    if (res['sessionExpired'] == true) {
      setState(() => _loadingInitial = false);
      _handleSessionExpired();
      return;
    }

    if (res['success'] == true && res['active'] == true) {
      final timer = res['timer'] as SafetyTimerModel;
      final remaining = res['remainingMs'] as int?;
      _setActiveTimer(timer, remaining);
    } else {
      _countdownTimer?.cancel();
      setState(() => _activeTimer = null);
    }
    setState(() => _loadingInitial = false);
  }

  void _setActiveTimer(SafetyTimerModel timer, int? remainingMs) {
    _countdownTimer?.cancel();
    _preExpiryAlertFired = false;
    setState(() {
      _activeTimer = timer;
      _timeLeftSeconds = timer.remainingSeconds(remainingMs);
    });
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timeLeftSeconds > 0) {
          _timeLeftSeconds--;
          // Pre-expiry notification check: 60s remaining
          if (_timeLeftSeconds <= 60 && !_preExpiryAlertFired) {
            _preExpiryAlertFired = true;
            _notifyUserPreExpiry();
          }
        } else {
          _countdownTimer?.cancel();
          _showClientExpiredBanner();
        }
      });
    });
  }

  /// Notify the user when timer is about to expire
  void _notifyUserPreExpiry() {
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  void _showClientExpiredBanner() {
    if (!mounted) return;
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text(
          'Countdown ended. The server will verify check-in status and dispatch emergency SMS to your contacts if no check-in is received.',
          style: TextStyle(color: Color(0xFF5D4037), fontSize: 13),
        ),
        backgroundColor: _warningBg,
        leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD84315)),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              _loadActiveTimer();
            },
            child: const Text('REFRESH', style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              _handleCheckIn();
            },
            child: const Text('I\'M SAFE', style: TextStyle(color: _successColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStart() async {
    // Ensure custom minutes are applied if set
    if (_customMode && _customController.text.isNotEmpty) {
      final customVal = int.tryParse(_customController.text.trim());
      if (customVal != null && customVal > 0) {
        _selectedMinutes = customVal;
        _customMode = false;
      }
    }
    if (_processing) return;
    setState(() => _processing = true);

    final res = await SafetyTimerService().startTimer(_selectedMinutes);
    if (!mounted) return;
    setState(() => _processing = false);

    if (res['sessionExpired'] == true) {
      _handleSessionExpired();
      return;
    }

    if (res['success'] == true) {
      _setActiveTimer(res['timer'] as SafetyTimerModel, null);
      _showSnack('Safety Timer started for $_selectedMinutes minutes.', _primary);
    } else if (res['alreadyActive'] == true) {
      _showSnack('A timer is already active. Refreshing...', Colors.orange.shade800);
      await _loadActiveTimer();
    } else if (res['offline'] == true) {
      _showOfflineDialog(res['message'] as String);
    } else {
      _showSnack(res['message'] ?? 'Failed to start timer.', _error);
    }
  }

  Future<void> _handleCheckIn() async {
    if (_processing || _activeTimer == null) return;
    final confirmed = await _showConfirmDialog(
      title: 'Check In — I Am Safe',
      body: 'This will mark you safe and stop the timer. Your emergency contacts will NOT be alerted.',
      confirmLabel: 'Check In Now',
      confirmColor: _successColor,
    );
    if (!confirmed || !mounted) return;

    setState(() => _processing = true);
    final res = await SafetyTimerService().checkIn(_activeTimer!.id);
    if (!mounted) return;
    setState(() => _processing = false);

    if (res['sessionExpired'] == true) {
      _handleSessionExpired();
      return;
    }

    if (res['success'] == true) {
      _countdownTimer?.cancel();
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      setState(() => _activeTimer = null);
      _showSnack('✅ Checked in successfully. You are marked safe!', _successColor);
    } else if (res['offline'] == true) {
      _showOfflineDialog(res['message'] as String);
    } else {
      _showSnack(res['message'] ?? 'Check-in failed.', _error);
    }
  }

  Future<void> _handleCancel() async {
    if (_processing || _activeTimer == null) return;
    final confirmed = await _showConfirmDialog(
      title: 'Cancel Safety Timer',
      body: 'Are you sure you want to cancel the timer? No emergency alerts will be triggered.',
      confirmLabel: 'Cancel Timer',
      confirmColor: Colors.grey.shade700,
    );
    if (!confirmed || !mounted) return;

    setState(() => _processing = true);
    final res = await SafetyTimerService().cancelTimer(_activeTimer!.id);
    if (!mounted) return;
    setState(() => _processing = false);

    if (res['sessionExpired'] == true) {
      _handleSessionExpired();
      return;
    }

    if (res['success'] == true) {
      _countdownTimer?.cancel();
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      setState(() => _activeTimer = null);
      _showSnack('Safety timer cancelled.', Colors.grey.shade800);
    } else if (res['offline'] == true) {
      _showOfflineDialog(res['message'] as String);
    } else {
      _showSnack(res['message'] ?? 'Cancel failed.', _error);
    }
  }

  Future<void> _handleExtend(int extendMinutes) async {
    if (_processing || _activeTimer == null) return;
    setState(() => _processing = true);
    final res = await SafetyTimerService().extendTimer(_activeTimer!.id, extendMinutes);
    if (!mounted) return;
    setState(() => _processing = false);

    if (res['sessionExpired'] == true) {
      _handleSessionExpired();
      return;
    }

    if (res['success'] == true) {
      final updated = res['timer'] as SafetyTimerModel;
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      _setActiveTimer(updated, null);
      _showSnack('Timer extended by $extendMinutes minutes.', _primary);
    } else if (res['offline'] == true) {
      _showOfflineDialog(res['message'] as String);
    } else {
      _showSnack(res['message'] ?? 'Extend failed.', _error);
    }
  }

  void _handleSessionExpired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Session Expired', style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
        content: const Text(
          'Your login session has expired. Please sign in again to continue managing your Safety Timer.',
          style: TextStyle(color: _onSurfaceVariant, fontSize: 13.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SignInScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showOfflineDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.wifi_off_rounded, color: _error, size: 24),
            SizedBox(width: 8),
            Text('Network Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primary)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, color: _onSurfaceVariant, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showExtendSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Extend Timer Duration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Add more time if your journey or activity is taking longer than expected:',
                style: TextStyle(fontSize: 13, color: _onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: _extensions.map((min) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleExtend(min);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: const BorderSide(color: _primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          '+$min\nmin',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primary, height: 1.2),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: _cardBg,
        title: Text(title, style: const TextStyle(color: _primary, fontWeight: FontWeight.bold)),
        content: Text(body, style: const TextStyle(color: _onSurfaceVariant)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _onSurfaceVariant),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Formatting ────────────────────────────────────────────────────────────

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (_activeTimer == null) return 0;
    final total = _activeTimer!.durationMinutes * 60;
    if (total <= 0) return 0;
    return (_timeLeftSeconds / total).clamp(0.0, 1.0);
  }

  bool get _isRunning => _activeTimer != null && _activeTimer!.isActive;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool warning = _isRunning && _timeLeftSeconds <= 60;

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _surface,
        colorScheme: const ColorScheme.light(
          primary: _primary,
          onPrimary: Colors.white,
          surface: _surface,
          onSurface: _onSurface,
          onSurfaceVariant: _onSurfaceVariant,
          outline: _outlineVariant,
          error: _error,
        ),
        dialogBackgroundColor: _cardBg,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _onSurface,
          displayColor: _primary,
        ),
      ),
      child: Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          child: _loadingInitial
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      if (warning) ...[
                        _buildPreExpiryAlertCard(),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 20),
                      _buildTimerVisual(warning: warning),
                      const SizedBox(height: 28),
                      if (!_isRunning) ...[
                        _buildDurationSelector(),
                        const SizedBox(height: 12),
                        // Custom duration chip
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('custom_duration_button'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: _showCustomTimerDialog,
                            child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: (_selectedMinutes != 5 && _selectedMinutes != 15 && _selectedMinutes != 30 && _selectedMinutes != 60)
                                  ? _primary.withOpacity(0.09)
                                  : _cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (_selectedMinutes != 5 && _selectedMinutes != 15 && _selectedMinutes != 30 && _selectedMinutes != 60)
                                    ? _primary
                                    : _outlineVariant,
                                width: (_selectedMinutes != 5 && _selectedMinutes != 15 && _selectedMinutes != 30 && _selectedMinutes != 60) ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  (_selectedMinutes != 5 && _selectedMinutes != 15 && _selectedMinutes != 30 && _selectedMinutes != 60)
                                      ? Icons.check_circle_rounded
                                      : Icons.tune_rounded,
                                  size: 18,
                                  color: (_selectedMinutes != 5 && _selectedMinutes != 15 && _selectedMinutes != 30 && _selectedMinutes != 60)
                                      ? _primary
                                      : _onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  (_selectedMinutes != 5 && _selectedMinutes != 15 && _selectedMinutes != 30 && _selectedMinutes != 60)
                                      ? 'Custom: $_selectedMinutes MIN (Tap to change)'
                                      : 'Set Custom Duration',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: (_selectedMinutes != 5 && _selectedMinutes != 15 && _selectedMinutes != 30 && _selectedMinutes != 60)
                                        ? _primary
                                        : _onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                        _buildStartButton(),
                      ] else ...[
                        _buildActiveActions(),
                      ],
                      const SizedBox(height: 20),
                      _buildStatusCard(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

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
              child: const Text(
                '03',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryContainer),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.schedule_rounded, color: _primary, size: 18),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Safety Timer',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _primary, height: 1.2),
        ),
        const SizedBox(height: 4),
        const Text(
          'Auto-alerts your emergency contacts if you don\'t check in before time runs out.',
          style: TextStyle(fontSize: 14, color: _onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildPreExpiryAlertCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _urgentBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: _error, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚡ EXPIRING SOON! CHECK IN NOW',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _error, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Less than 1 minute remains! If you do not check in, the server will dispatch an emergency alert to your saved contacts.',
            style: TextStyle(fontSize: 12.5, color: _onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _handleCheckIn,
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  label: const Text('I\'M SAFE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _successColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _showExtendSheet,
                  icon: const Icon(Icons.add_alarm, color: _primary, size: 18),
                  label: const Text('EXTEND', style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildTimerVisual({required bool warning}) {
    final Color progressColor = warning ? _error : (_isRunning ? _successColor : _primary);
    final Color timerTextColor = warning ? _error : _primary;

    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse glow
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: progressColor.withOpacity(_isRunning ? 0.10 : 0.04),
                ),
              ),
            ),
            // Progress ring
            SizedBox(
              width: 210,
              height: 210,
              child: CircularProgressIndicator(
                value: _isRunning ? _progress : (_selectedMinutes > 0 ? 1.0 : 0),
                strokeWidth: 7,
                backgroundColor: _outlineVariant.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                strokeCap: StrokeCap.round,
              ),
            ),
            // Center content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isRunning ? Icons.timer_rounded : Icons.timer_outlined,
                  color: progressColor,
                  size: 32,
                ),
                const SizedBox(height: 6),
                Text(
                  _isRunning
                      ? _formatTime(_timeLeftSeconds)
                      : _formatTime(_selectedMinutes * 60),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: timerTextColor,
                    letterSpacing: 2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isRunning
                      ? (warning ? '⚡ Expiring soon!' : 'Time remaining')
                      : 'Select duration below',
                  style: TextStyle(
                    fontSize: 13,
                    color: warning ? _error : _onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Duration',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _primary),
        ),
        const SizedBox(height: 12),
        Row(
          children: _durations.map((min) {
            final selected = _selectedMinutes == min;
            final label = min < 60 ? '$min\nMIN' : '1\nHOUR';
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMinutes = min),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? _primary.withOpacity(0.09) : _cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? _primary : _outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected ? _primary : _onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: _processing ? null : _handleStart,
        icon: _processing
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
        label: Text(
          _processing ? 'Starting…' : 'Start Timer',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withOpacity(0.85),
          disabledForegroundColor: Colors.white,
          elevation: 6,
          shadowColor: _primary.withOpacity(0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  void _showCustomTimerDialog() async {
    final controller = TextEditingController(
      text: (_selectedMinutes != 5 && _selectedMinutes != 15 && _selectedMinutes != 30 && _selectedMinutes != 60)
          ? '$_selectedMinutes'
          : '',
    );
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: _primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Custom Duration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter timer duration in minutes (1 to 1440 min / 24 hrs):',
              style: TextStyle(fontSize: 13, color: _onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('custom_timer_input'),
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 45',
                hintStyle: TextStyle(color: _onSurfaceVariant.withOpacity(0.5), fontSize: 16),
                suffixText: 'MIN',
                suffixStyle: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Quick presets:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [10, 20, 45, 90, 120].map((mins) {
                return InkWell(
                  onTap: () {
                    controller.text = mins.toString();
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _outlineVariant),
                    ),
                    child: Text(
                      '$mins min',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            style: TextButton.styleFrom(foregroundColor: _onSurfaceVariant),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            key: const Key('custom_timer_set_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1 && val <= 1440) {
                setState(() {
                  _selectedMinutes = val;
                  _timeLeftSeconds = val * 60;
                  _customMode = false;
                });
                Navigator.of(dialogCtx).pop();
                _showSnack('Custom duration set to $val minutes.', _primary);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter a valid duration between 1 and 1440 minutes.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: _error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Set Duration', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveActions() {
    return Column(
      children: [
        // Check In — prominent
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton.icon(
            onPressed: _processing ? null : _handleCheckIn,
            icon: _processing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 24),
            label: Text(
              _processing ? 'Processing…' : 'I\'m Safe — Check In',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _successColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _successColor.withOpacity(0.85),
              disabledForegroundColor: Colors.white,
              elevation: 6,
              shadowColor: _successColor.withOpacity(0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Extend + Cancel row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _processing ? null : _showExtendSheet,
                icon: const Icon(Icons.timer_outlined, color: _primary, size: 20),
                label: const Text('Extend', style: TextStyle(color: _primary, fontWeight: FontWeight.w700, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  backgroundColor: _cardBg,
                  side: const BorderSide(color: _primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _processing ? null : _handleCancel,
                icon: const Icon(Icons.cancel_outlined, color: _error, size: 20),
                label: const Text('Cancel', style: TextStyle(color: _error, fontWeight: FontWeight.w700, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _error,
                  backgroundColor: _cardBg,
                  side: const BorderSide(color: _error, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    if (_activeTimer == null) {
      return const SizedBox.shrink();
    }

    // Active timer status card
    final expiry = _activeTimer!.expiresAt.toLocal();
    final expiryStr =
        '${expiry.hour.toString().padLeft(2, '0')}:${expiry.minute.toString().padLeft(2, '0')}';
    final hasLocation = _activeTimer!.latitude != null && _activeTimer!.longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.timer_rounded, color: _primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Timer Active',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _primary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadActiveTimer,
                child: Icon(Icons.refresh_rounded, color: _primary.withOpacity(0.6), size: 20),
              ),
            ],
          ),
          const Divider(height: 20),
          _statusRow(Icons.schedule_outlined, 'Expires at', expiryStr),
          const SizedBox(height: 6),
          _statusRow(
            Icons.location_on_outlined,
            'Location',
            hasLocation
                ? '${_activeTimer!.latitude!.toStringAsFixed(4)}, ${_activeTimer!.longitude!.toStringAsFixed(4)}'
                : 'Not captured',
          ),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _onSurfaceVariant, size: 16),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: _onSurfaceVariant, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _onSurface),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
