import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SafetyTimerScreen extends StatefulWidget {
  const SafetyTimerScreen({super.key});

  @override
  State<SafetyTimerScreen> createState() => _SafetyTimerScreenState();
}

class _SafetyTimerScreenState extends State<SafetyTimerScreen>
    with SingleTickerProviderStateMixin {
  // ── Colour tokens ─────────────────────────────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _primaryFixed = Color(0xFFFFD8ED);
  static const Color _primaryContainer = Color(0xFF48293D);
  static const Color _surfaceContainer = Color(0xFFF0EDEE);
  static const Color _outlineVariant = Color(0xFFD1C3C9);
  static const Color _error = Color(0xFFBA1A1A);

  // ── Timer State ────────────────────────────────────────────────────
  int _totalSeconds = 30 * 60;
  int _timeLeft = 30 * 60;
  int _selectedMinutes = 30;
  bool _isRunning = false;
  Timer? _timer;

  // ── Custom input ───────────────────────────────────────────────────
  bool _showCustomInput = false;
  final TextEditingController _customController = TextEditingController();

  // ── Pulse animation ────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ── Contacts ───────────────────────────────────────────────────────
  final List<_Contact> _contacts = [
    _Contact(initials: 'AM', name: 'Amara Miller', role: 'Emergency Primary', color: Color(0xFFFFD8ED)),
    _Contact(initials: 'JD', name: 'John Doe', role: 'Close Friend', color: Color(0xFFAACAE8)),
  ];

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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _customController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _selectDuration(int minutes) {
    if (_isRunning) return;
    setState(() {
      _selectedMinutes = minutes;
      _totalSeconds = minutes * 60;
      _timeLeft = minutes * 60;
      _showCustomInput = false;
    });
  }

  void _applyCustomTimer() {
    final val = int.tryParse(_customController.text.trim());
    if (val == null || val < 1 || val > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a value between 1 and 1440 minutes')),
      );
      return;
    }
    _selectDuration(val);
    _customController.clear();
    setState(() => _showCustomInput = false);
  }

  void _startTimer() {
    if (_timeLeft <= 0) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft <= 0) {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _showExpiredDialog();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _timeLeft = _totalSeconds;
    });
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _cardBg,
        title: Row(
          children: const [
            Icon(Icons.crisis_alert_rounded, color: Color(0xFFBA1A1A)),
            SizedBox(width: 8),
            Text('Timer Expired!', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your emergency contacts have been notified with your last known location.',
          style: TextStyle(color: Color(0xFF4E4449), height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _timeLeft = _totalSeconds);
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  double get _progress => _totalSeconds > 0 ? _timeLeft / _totalSeconds : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              _buildHeader(),
              const SizedBox(height: 28),

              // ── Timer Visual ─────────────────────────────────────────
              _buildTimerVisual(),
              const SizedBox(height: 32),

              // ── Duration Selector ────────────────────────────────────
              _buildDurationSelector(),
              const SizedBox(height: 16),

              // ── Custom Input ─────────────────────────────────────────
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildCustomInput(),
                crossFadeState: _showCustomInput
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),

              // ── Info Card ────────────────────────────────────────────
              _buildInfoCard(),
              const SizedBox(height: 24),

              // ── Contacts ─────────────────────────────────────────────
              _buildContactsSection(),
              const SizedBox(height: 32),

              // ── CTA Button ───────────────────────────────────────────
              _buildCTAButton(),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'You can stop or extend the timer anytime',
                  style: TextStyle(fontSize: 11, color: _onSurfaceVariant.withOpacity(0.8)),
                ),
              ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _primaryFixed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '03',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.schedule_rounded, color: _primary, size: 18),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Safety Timer',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _primary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Auto-alerts contacts if you don\'t check in on time.',
          style: TextStyle(fontSize: 14, color: _onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildTimerVisual() {
    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Atmospheric glow
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primary.withOpacity(_isRunning ? 0.07 : 0.04),
                ),
              ),
            ),

            // Progress ring
            SizedBox(
              width: 210,
              height: 210,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 6,
                backgroundColor: _outlineVariant.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isRunning ? _error : _primary,
                ),
                strokeCap: StrokeCap.round,
              ),
            ),

            // Inner content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_rounded,
                  color: _isRunning ? _error : _primary,
                  size: 32,
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(_timeLeft),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: _isRunning ? _error : _primary,
                    letterSpacing: 2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Safety Duration',
                  style: TextStyle(
                    fontSize: 12,
                    color: _onSurfaceVariant,
                    fontWeight: FontWeight.w500,
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
    final options = [
      {'label': '15', 'sub': 'MINS', 'mins': 15},
      {'label': '30', 'sub': 'MINS', 'mins': 30},
      {'label': '1', 'sub': 'HOUR', 'mins': 60},
    ];

    return Row(
      children: [
        ...options.map((o) {
          final mins = o['mins'] as int;
          final selected = _selectedMinutes == mins && !_showCustomInput;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _DurationButton(
                label: o['label'] as String,
                sub: o['sub'] as String,
                selected: selected,
                disabled: _isRunning,
                onTap: () => _selectDuration(mins),
              ),
            ),
          );
        }),
        // Custom button
        Expanded(
          child: _DurationButton(
            label: '—',
            sub: 'CUSTOM',
            icon: Icons.edit_rounded,
            selected: _showCustomInput,
            disabled: _isRunning,
            onTap: () => setState(() => _showCustomInput = !_showCustomInput),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primary.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Duration (minutes)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 14, color: _onSurface),
                    decoration: InputDecoration(
                      hintText: 'e.g. 45',
                      hintStyle: TextStyle(color: _onSurfaceVariant),
                      filled: true,
                      fillColor: _cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _applyCustomTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Set', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _secondaryContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _primary.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your location and emergency message will be broadcasted to your selected contacts automatically if you fail to stop the timer.',
              style: TextStyle(fontSize: 13, color: _onSurfaceVariant, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Contacts to Notify',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _primary),
            ),
            GestureDetector(
              onTap: () {},
              child: Row(
                children: [
                  Icon(Icons.add_rounded, color: _primary, size: 18),
                  const SizedBox(width: 2),
                  Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_contacts.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outlineVariant.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.color),
                  child: Center(
                    child: Text(
                      c.initials,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _onSurface)),
                      Text(c.role, style: const TextStyle(fontSize: 11, color: _onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.check_circle_rounded, color: _primary, size: 22),
              ],
            ),
          ),
        ))),
      ],
    );
  }

  Widget _buildCTAButton() {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 60,
        child: ElevatedButton(
          onPressed: _isRunning ? _stopTimer : _startTimer,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRunning ? _error : _primary,
            elevation: 6,
            shadowColor: (_isRunning ? _error : _primary).withOpacity(0.35),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 26,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                _isRunning ? 'Stop Timer' : 'Start Timer',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Duration Button ──────────────────────────────────────────────────
class _DurationButton extends StatelessWidget {
  final String label;
  final String sub;
  final IconData? icon;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _DurationButton({
    required this.label,
    required this.sub,
    required this.selected,
    required this.disabled,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF301427).withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF301427) : const Color(0xFFD1C3C9),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon != null
                ? Icon(icon, color: const Color(0xFF301427), size: 20)
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: disabled
                          ? const Color(0xFFD1C3C9)
                          : const Color(0xFF301427),
                    ),
                  ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: disabled
                    ? const Color(0xFFD1C3C9)
                    : const Color(0xFF4E4449),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────
class _Contact {
  final String initials;
  final String name;
  final String role;
  final Color color;
  _Contact({required this.initials, required this.name, required this.role, required this.color});
}
