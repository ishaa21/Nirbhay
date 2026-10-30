import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/shake_sos_service.dart';
import '../l10n/app_localizations.dart';

/// Full-screen emergency countdown overlay shown when a phone shake is detected.
///
/// Provides a visible 15-second countdown with an authoritative "CANCEL SOS" button.
/// If cancelled, no SOS incident is created and no emergency messages are sent.
class ShakeCountdownDialog extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback? onCancelled;
  final VoidCallback? onExpired;

  const ShakeCountdownDialog({
    super.key,
    this.initialSeconds = 15,
    this.onCancelled,
    this.onExpired,
  });

  /// Helper to display the countdown dialog across any active screen context.
  static Future<void> show(BuildContext context, {int initialSeconds = 15}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => ShakeCountdownDialog(initialSeconds: initialSeconds),
    );
  }

  @override
  State<ShakeCountdownDialog> createState() => _ShakeCountdownDialogState();
}

class _ShakeCountdownDialogState extends State<ShakeCountdownDialog>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _localTimer;
  StreamSubscription<ShakeSosEvent>? _eventSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial warning vibration
    HapticFeedback.vibrate();

    // Listen to native countdown events & remote cancellations
    _eventSubscription = ShakeSosService().shakeEvents.listen((event) {
      if (!mounted) return;
      if (event.type == ShakeSosEventType.countdownTick) {
        setState(() {
          _remainingSeconds = event.remainingSeconds;
        });
        HapticFeedback.selectionClick();
      } else if (event.type == ShakeSosEventType.countdownCancelled) {
        _handleCancelledLocally();
      } else if (event.type == ShakeSosEventType.countdownExpired) {
        _handleExpiredLocally();
      }
    });

    // Local fallback tick in case EventChannel ticks lag
    _localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
        HapticFeedback.selectionClick();
      } else {
        timer.cancel();
        _handleExpiredLocally();
      }
    });
  }

  @override
  void dispose() {
    _localTimer?.cancel();
    _eventSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  bool _isDismissed = false;

  Future<void> _handleCancelPressed() async {
    if (_isCancelling || _isDismissed) return;
    setState(() => _isCancelling = true);

    _localTimer?.cancel();
    await ShakeSosService().cancelCountdown();
    _handleCancelledLocally();
  }

  void _handleCancelledLocally() {
    if (_isDismissed) return;
    _isDismissed = true;
    _localTimer?.cancel();
    widget.onCancelled?.call();
    if (mounted) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Shake SOS cancelled. No alerts were sent.'),
          backgroundColor: Color(0xFF424242),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleExpiredLocally() {
    if (_isDismissed) return;
    _isDismissed = true;
    _localTimer?.cancel();
    widget.onExpired?.call();
    if (mounted) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_remainingSeconds / 15.0).clamp(0.0, 1.0);

    return PopScope(
      canPop: false, // Prevent accidental back-button dismissal without authoritative cancel
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E0A16),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD32F2F), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD32F2F).withOpacity(0.4),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon & Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).shakePhoneDetected,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).shakeCountdownMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD1C3C9), fontSize: 13),
              ),
              const SizedBox(height: 28),

              // Pulsing Circular Countdown Timer
              ScaleTransition(
                scale: _pulseAnimation,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_remainingSeconds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'SECONDS',
                          style: TextStyle(
                            color: Color(0xFFFF8A80),
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Prominent Cancel SOS Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF388E3C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                  ),
                  onPressed: _isCancelling ? null : _handleCancelPressed,
                  icon: _isCancelling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cancel_outlined, size: 24),
                  label: Text(
                    _isCancelling ? AppLocalizations.of(context).loading : AppLocalizations.of(context).cancelCountdown,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Accidental shake? Tap Cancel above or from the notification bar to abort.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8C7E85), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
