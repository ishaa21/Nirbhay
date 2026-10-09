import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin {
  // ── Colour tokens ─────────────────────────────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _primaryFixed = Color(0xFFFFD8ED);
  static const Color _primaryContainer = Color(0xFF48293D);
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSecondaryContainer = Color(0xFF705D67);
  static const Color _surfaceContainer = Color(0xFFF0EDEE);
  static const Color _outlineVariant = Color(0xFFD1C3C9);

  // ── State ──────────────────────────────────────────────────────────
  String _selectedSchedule = 'Immediately';
  String _selectedCaller = 'Mom';
  bool _showToast = false;
  bool _showIncomingCall = false;
  Timer? _scheduleTimer;
  Timer? _toastTimer;

  // ── Pulse animation ────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final List<String> _callerNames = ['Mom', 'Boss', 'Pizza Delivery', 'Private Number'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    _toastTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _deployFakeCall() {
    // Show toast
    setState(() => _showToast = true);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showToast = false);
    });

    // Schedule the call
    final delay = _selectedSchedule == 'Immediately'
        ? const Duration(seconds: 1)
        : _selectedSchedule == 'In 5 Minutes'
            ? const Duration(minutes: 5)
            : const Duration(seconds: 1);

    _scheduleTimer?.cancel();
    _scheduleTimer = Timer(delay, () {
      if (mounted) {
        setState(() => _showIncomingCall = true);
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _dismissCall() {
    setState(() => _showIncomingCall = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Main Screen ──────────────────────────────────────────────
        Scaffold(
          backgroundColor: _surface,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSetupGrid(),
                  const SizedBox(height: 24),
                  _buildPreviewSection(),
                  const SizedBox(height: 20),
                  _buildStealthHint(),
                  const SizedBox(height: 28),
                  _buildDeployButton(),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'The call will appear exactly like a real system notification.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: _onSurfaceVariant.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Toast ────────────────────────────────────────────────────
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            offset: _showToast ? Offset.zero : const Offset(0, -2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showToast ? 1 : 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _onSurface,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Call Armed: $_selectedSchedule',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Incoming Call Overlay ────────────────────────────────────
        if (_showIncomingCall)
          _IncomingCallOverlay(
            callerName: _selectedCaller,
            pulseAnim: _pulseAnim,
            onDecline: _dismissCall,
            onAccept: _dismissCall,
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _primaryFixed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '04',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryContainer),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.phone_callback_rounded, color: _primary, size: 18),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Fake Call Generator',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _primary, height: 1.2),
        ),
        const SizedBox(height: 6),
        const Text(
          'Simulates an incoming call to help you exit uncomfortable or unsafe situations discreetly.',
          style: TextStyle(fontSize: 14, color: _onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSetupGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Schedule Card ─────────────────────────────────────────────
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _outlineVariant.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Schedule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primary)),
                const SizedBox(height: 12),
                ...[
                  ('Immediately', Icons.bolt_rounded),
                  ('In 5 Minutes', Icons.timer_outlined),
                  ('Custom Time', Icons.edit_calendar_outlined),
                ].map((item) {
                  final isSelected = _selectedSchedule == item.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSchedule = item.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary.withOpacity(0.08) : _surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? _primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.$1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? _primary : _onSurfaceVariant,
                              ),
                            ),
                            Icon(item.$2, size: 16, color: isSelected ? _primary : _onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ── Identity Card ─────────────────────────────────────────────
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _outlineVariant.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Identity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primary)),
                const SizedBox(height: 12),
                Text('Caller Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: _surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _outlineVariant.withOpacity(0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCaller,
                      isExpanded: true,
                      items: _callerNames.map((name) {
                        return DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCaller = val!),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Caller Voice', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Voice recording coming soon'), behavior: SnackBarBehavior.floating),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mic_rounded, size: 16, color: _onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text('Record', style: TextStyle(fontSize: 12, color: _onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.play_circle_rounded, color: _onSecondaryContainer, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Preview Screen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _primary)),
            const SizedBox(width: 6),
            Icon(Icons.visibility_outlined, size: 16, color: _onSurfaceVariant.withOpacity(0.6)),
          ],
        ),
        const SizedBox(height: 16),
        Center(child: _buildPhoneMockup()),
      ],
    );
  }

  Widget _buildPhoneMockup() {
    return Container(
      width: 200,
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF3A3A3C), width: 6),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Notch
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 80,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          // Incoming call content
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1C1C1E),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Caller info
                  Padding(
                    padding: const EdgeInsets.only(top: 36),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ScaleTransition(
                              scale: _pulseAnim,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                            ),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF3A3A3C),
                              ),
                              child: const Icon(Icons.person_rounded, color: Colors.white70, size: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedCaller,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text('Mobile', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Buttons
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFF3B30),
                              ),
                              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 6),
                            const Text('Decline', style: TextStyle(color: Colors.white54, fontSize: 9)),
                          ],
                        ),
                        Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF34C759),
                              ),
                              child: const Icon(Icons.call_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 6),
                            const Text('Accept', style: TextStyle(color: Colors.white54, fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStealthHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryContainer.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stealth Activation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primary)),
                const SizedBox(height: 4),
                Text(
                  'You can trigger a "Private Number" fake call by triple-pressing your power button or shaking your phone 3 times.',
                  style: TextStyle(fontSize: 12, color: _onSurfaceVariant, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeployButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _deployFakeCall,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          elevation: 6,
          shadowColor: _primary.withOpacity(0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.bolt_rounded, size: 24, color: Colors.white),
            SizedBox(width: 10),
            Text('Deploy Fake Call', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Incoming Call Full-Screen Overlay
// ─────────────────────────────────────────────────────────────────
class _IncomingCallOverlay extends StatefulWidget {
  final String callerName;
  final Animation<double> pulseAnim;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  const _IncomingCallOverlay({
    required this.callerName,
    required this.pulseAnim,
    required this.onDecline,
    required this.onAccept,
  });

  @override
  State<_IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<_IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _entryAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(_entryAnim),
      child: Material(
        color: Colors.transparent,
        child: Container(
          color: const Color(0xFF1C1C1E),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ── Caller Info ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      const Text('Incoming Call', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ScaleTransition(
                            scale: widget.pulseAnim,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF3A3A3C),
                            ),
                            child: const Icon(Icons.person_rounded, color: Colors.white70, size: 52),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.callerName,
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text('Mobile', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),

                // ── Action Buttons ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CallButton(
                        icon: Icons.call_end_rounded,
                        label: 'Decline',
                        color: const Color(0xFFFF3B30),
                        onTap: widget.onDecline,
                      ),
                      _CallButton(
                        icon: Icons.call_rounded,
                        label: 'Accept',
                        color: const Color(0xFF34C759),
                        onTap: widget.onAccept,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
