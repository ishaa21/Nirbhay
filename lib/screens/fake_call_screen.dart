import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sos_model.dart';
import '../services/sos_service.dart';
import '../services/location_update_service.dart';
import '../services/fake_call_audio_service.dart';
import '../services/fake_call_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CallerAvatarPreset
// ─────────────────────────────────────────────────────────────────────────────
class CallerAvatarPreset {
  final String label;
  final String defaultName;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String subtitle;

  const CallerAvatarPreset({
    required this.label,
    required this.defaultName,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.subtitle,
  });
}

const List<CallerAvatarPreset> kCallerPresets = [
  CallerAvatarPreset(
    label: 'Mom',
    defaultName: 'Mom',
    icon: Icons.person_rounded,
    bgColor: Color(0xFFFCE4EC),
    iconColor: Color(0xFFC2185B),
    subtitle: 'Mobile',
  ),
  CallerAvatarPreset(
    label: 'Dad',
    defaultName: 'Dad',
    icon: Icons.person_outline_rounded,
    bgColor: Color(0xFFE8EAF6),
    iconColor: Color(0xFF303F9F),
    subtitle: 'Home',
  ),
  CallerAvatarPreset(
    label: 'Boss',
    defaultName: 'Office / Boss',
    icon: Icons.work_outline_rounded,
    bgColor: Color(0xFFECEFF1),
    iconColor: Color(0xFF37474F),
    subtitle: 'Work',
  ),
  CallerAvatarPreset(
    label: 'Police',
    defaultName: 'Police Department',
    icon: Icons.local_police_outlined,
    bgColor: Color(0xFFE3F2FD),
    iconColor: Color(0xFF1565C0),
    subtitle: 'Emergency Service',
  ),
  CallerAvatarPreset(
    label: 'Doctor',
    defaultName: 'Dr. Sharma',
    icon: Icons.medical_services_outlined,
    bgColor: Color(0xFFE0F2F1),
    iconColor: Color(0xFF00796B),
    subtitle: 'Hospital',
  ),
  CallerAvatarPreset(
    label: 'Friend',
    defaultName: 'Priya (Friend)',
    icon: Icons.favorite_outline_rounded,
    bgColor: Color(0xFFEDE7F6),
    iconColor: Color(0xFF673AB7),
    subtitle: 'Mobile',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// FakeCallScreen
// ─────────────────────────────────────────────────────────────────────────────
class FakeCallScreen extends StatefulWidget {
  final String? initialCallerName;
  final String? initialCallerSubtitle;
  final bool autoAccept;
  final bool isFromTrigger;

  const FakeCallScreen({
    super.key,
    this.initialCallerName,
    this.initialCallerSubtitle,
    this.autoAccept = false,
    this.isFromTrigger = false,
  });

  @override
  State<FakeCallScreen> createState() => FakeCallScreenState();
}

class FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
  static const Color _success = Color(0xFF2E7D32);

  // ── State ─────────────────────────────────────────────────────────────────
  late TextEditingController callerNameController;
  int selectedDelaySeconds = 0; // 0 = Immediately, 10, 30, 60
  CallerAvatarPreset selectedPreset = kCallerPresets[0];

  bool isArmed = false;
  int countdownRemainingSeconds = 0;
  DateTime? scheduledFireTime;
  Timer? countdownTimer;

  bool showIncomingOverlay = false;
  bool isCallConnected = false;
  int callDurationSeconds = 0;
  Timer? callDurationTimer;

  // ── Pulse animation for incoming ring ──────────────────────────────────────
  late AnimationController pulseController;
  late Animation<double> pulseAnim;

  // ── Audio & Vibration Ringtone Service ────────────────────────────────────
  double ringtoneVolume = 0.8;
  bool isPreviewPlaying = false;
  Timer? hapticRingerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final initialName = (widget.initialCallerName != null && widget.initialCallerName!.trim().isNotEmpty)
        ? widget.initialCallerName!.trim()
        : selectedPreset.defaultName;
    callerNameController = TextEditingController(text: initialName);

    FakeCallService().onCallTriggered = (callerName, callerSubtitle, isAccepted) {
      if (!mounted) return;
      setState(() {
        callerNameController.text = callerName;
        isArmed = false;
        countdownRemainingSeconds = 0;
      });
      if (isAccepted) {
        _triggerIncomingCall();
        handleAcceptCall();
      } else {
        _triggerIncomingCall();
      }
    };

    FakeCallService().onCallCancelled = () {
      if (!mounted) return;
      handleDeclineOrEndCall();
    };


    if (widget.isFromTrigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.autoAccept) {
          _triggerIncomingCall();
          handleAcceptCall();
        } else {
          _triggerIncomingCall();
        }
      });
    }

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    pulseAnim = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );
    _checkPendingBackgroundTrigger();
  }


  Future<void> _checkPendingBackgroundTrigger() async {
    final info = await FakeCallService().getPendingTrigger();
    if (!mounted) return;
    if (info.hasPendingTrigger) {
      setState(() {
        // Set caller name
        callerNameController.text = info.callerName;
        isArmed = false;
        countdownRemainingSeconds = 0;
      });
      if (info.isAccepted) {
        _triggerIncomingCall();
        handleAcceptCall();
      } else {
        _triggerIncomingCall();
      }
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FakeCallService().onCallTriggered = null;
    FakeCallService().onCallCancelled = null;
    countdownTimer?.cancel();
    callDurationTimer?.cancel();
    hapticRingerTimer?.cancel();
    FakeCallAudioService().stopRingtone();
    FakeCallService().stopRingtone();
    FakeCallService().cancelScheduledFakeCall();
    callerNameController.dispose();
    pulseController.dispose();
    super.dispose();
  }

  // ── App Lifecycle (Requirement 4 & Bug 4) ─────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (showIncomingOverlay && !isCallConnected) {
        FakeCallAudioService().pauseRingtone();
      }
    } else if (state == AppLifecycleState.resumed) {
      _checkPendingBackgroundTrigger();
      if (showIncomingOverlay && !isCallConnected) {
        FakeCallAudioService().resumeRingtone();
      }
      if (isArmed && scheduledFireTime != null) {
        final now = DateTime.now();
        if (now.isAfter(scheduledFireTime!)) {
          // Time elapsed while app was paused or in background
          _triggerIncomingCall();
        } else {
          // Recalculate remaining seconds accurately
          setState(() {
            countdownRemainingSeconds = scheduledFireTime!.difference(now).inSeconds;
          });
        }
      }
    }
  }

  // ── Action Handlers ───────────────────────────────────────────────────────
  @visibleForTesting
  void simulateArmedExpiry() {
    setState(() {
      isArmed = true;
      scheduledFireTime = DateTime.now().subtract(const Duration(seconds: 2));
    });
  }

  Future<void> armFakeCall() async {
    final callerName = callerNameController.text.trim().isNotEmpty
        ? callerNameController.text.trim()
        : selectedPreset.defaultName;

    final avatarIndex = kCallerPresets.indexOf(selectedPreset);

    if (selectedDelaySeconds == 0) {
      await FakeCallService().scheduleFakeCall(
        delaySeconds: 0,
        callerName: callerName,
        callerSubtitle: selectedPreset.subtitle,
        avatarIndex: avatarIndex >= 0 ? avatarIndex : 0,
      );
      _triggerIncomingCall();
      return;
    }

    await FakeCallService().scheduleFakeCall(
      delaySeconds: selectedDelaySeconds,
      callerName: callerName,
      callerSubtitle: selectedPreset.subtitle,
      avatarIndex: avatarIndex >= 0 ? avatarIndex : 0,
    );

    final fireAt = DateTime.now().add(Duration(seconds: selectedDelaySeconds));
    setState(() {
      isArmed = true;
      scheduledFireTime = fireAt;
      countdownRemainingSeconds = selectedDelaySeconds;
    });

    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = scheduledFireTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        _triggerIncomingCall();
      } else {
        setState(() {
          countdownRemainingSeconds = remaining;
        });
      }
    });

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fake call armed! Incoming call in $selectedDelaySeconds seconds.'),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void cancelScheduledCall() {
    countdownTimer?.cancel();
    FakeCallAudioService().stopRingtone();
    FakeCallService().stopRingtone();
    FakeCallService().cancelScheduledFakeCall();
    setState(() {
      isArmed = false;
      scheduledFireTime = null;
      countdownRemainingSeconds = 0;
      isPreviewPlaying = false;
    });
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scheduled fake call cancelled.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _triggerIncomingCall() {
    countdownTimer?.cancel();
    FakeCallService().stopRingtone();
    setState(() {
      isArmed = false;
      scheduledFireTime = null;
      countdownRemainingSeconds = 0;
      showIncomingOverlay = true;
      isCallConnected = false;
      callDurationSeconds = 0;
      isPreviewPlaying = false;
    });

    // Start audible bundled telephone ringtone with configured volume and vibration
    FakeCallAudioService().startRingtone(volume: ringtoneVolume);
  }

  void handleAcceptCall() {
    // Stop ringing immediately upon answering the simulated call
    FakeCallAudioService().stopRingtone();
    FakeCallService().stopRingtone();
    FakeCallService().cancelScheduledFakeCall();
    hapticRingerTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      isCallConnected = true;
      callDurationSeconds = 0;
    });

    callDurationTimer?.cancel();
    callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !showIncomingOverlay) {
        callDurationTimer?.cancel();
        return;
      }
      setState(() {
        callDurationSeconds++;
      });
    });
  }

  void handleDeclineOrEndCall() {
    // Stop ringing immediately upon declining or hanging up
    FakeCallAudioService().stopRingtone();
    FakeCallService().stopRingtone();
    FakeCallService().cancelScheduledFakeCall();
    hapticRingerTimer?.cancel();
    callDurationTimer?.cancel();
    HapticFeedback.lightImpact();
    setState(() {
      showIncomingOverlay = false;
      isCallConnected = false;
      callDurationSeconds = 0;
      isPreviewPlaying = false;
    });

    if (widget.isFromTrigger && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleEmergencyEscalation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: _error, size: 24),
            SizedBox(width: 8),
            Text('Activate Real SOS?', style: TextStyle(color: _error, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will IMMEDIATELY notify your saved emergency contacts with your live location. Use only if in real danger.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Trigger Real SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    handleDeclineOrEndCall();
    final res = await SosService().createSos();
    if (!mounted) return;
    if (res['success'] == true) {
      final incident = res['incident'] as SosIncidentModel?;
      if (incident != null) {
        LocationUpdateService().start(sosId: incident.id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Real SOS Alert Triggered! Contacts notified.'),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Setup Screen
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
                  const SizedBox(height: 16),
                  if (isArmed) ...[
                    _buildArmedCountdownCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildCallerCustomizationCard(),
                  const SizedBox(height: 16),
                  _buildDelaySelector(),
                  const SizedBox(height: 16),
                  _buildRingtoneSettingsCard(),
                  const SizedBox(height: 24),
                  _buildTriggerButton(),
                ],
              ),
            ),
          ),
        ),

        // Simulated Incoming or In-Call Full-Screen Overlay
        if (showIncomingOverlay)
          _buildSimulatedCallOverlay(),
      ],
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
              child: const Text('04', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryContainer)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.phone_callback_rounded, color: _primary, size: 20),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Fake Call Simulator',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _primary, height: 1.2),
        ),
        const SizedBox(height: 4),
        const Text(
          'Simulate a realistic incoming call to discreetly exit unsafe or uncomfortable situations.',
          style: TextStyle(fontSize: 14, color: _onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildArmedCountdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _success.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.ring_volume_rounded, color: _success, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Call Armed: Ringing in ${countdownRemainingSeconds}s',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _success),
                ),
              ),
              IconButton(
                onPressed: cancelScheduledCall,
                icon: const Icon(Icons.close_rounded, color: _error),
                tooltip: 'Cancel Call',
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: selectedDelaySeconds > 0 ? (countdownRemainingSeconds / selectedDelaySeconds) : 0,
            backgroundColor: Colors.white,
            valueColor: const AlwaysStoppedAnimation<Color>(_success),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: cancelScheduledCall,
              style: OutlinedButton.styleFrom(
                foregroundColor: _error,
                side: const BorderSide(color: _error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('CANCEL SCHEDULED CALL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallerCustomizationCard() {
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
          const Text('1. Caller Identity & Avatar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primary)),
          const SizedBox(height: 12),

          // Preset Avatars
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: kCallerPresets.map((preset) {
                final isSelected = selectedPreset.label == preset.label;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedPreset = preset;
                        callerNameController.text = preset.defaultName;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryFixed : _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _primary : _outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: preset.bgColor,
                            child: Icon(preset.icon, color: preset.iconColor, size: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            preset.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? _primary : _onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Custom Caller Name Input
          TextField(
            controller: callerNameController,
            decoration: InputDecoration(
              labelText: 'Caller Name',
              hintText: 'e.g. Mom, Inspector Rao, Boss',
              prefixIcon: Icon(selectedPreset.icon, color: selectedPreset.iconColor),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _outlineVariant)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelaySelector() {
    final delays = [
      (0, 'Now', Icons.bolt_rounded),
      (10, '10 sec', Icons.timer_outlined),
      (30, '30 sec', Icons.schedule_rounded),
      (60, '60 sec', Icons.hourglass_bottom_rounded),
      (300, '5 min', Icons.alarm_rounded),
    ];

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
          const Text('2. Ring Delay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primary)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: delays.map((item) {
                final seconds = item.$1;
                final label = item.$2;
                final icon = item.$3;
                final isSelected = selectedDelaySeconds == seconds;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: isArmed ? null : () => setState(() => selectedDelaySeconds = seconds),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryFixed : _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? _primary : _outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(icon, size: 20, color: isSelected ? _primary : _onSurfaceVariant),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? _primary : _onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingtoneSettingsCard() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('3. Ringtone & Audio', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primary)),
              TextButton.icon(
                onPressed: isArmed
                    ? null
                    : () async {
                        if (isPreviewPlaying) {
                          await FakeCallAudioService().stopRingtone();
                          if (mounted) setState(() => isPreviewPlaying = false);
                        } else {
                          if (mounted) setState(() => isPreviewPlaying = true);
                          await FakeCallAudioService().startRingtone(volume: ringtoneVolume);
                        }
                      },
                icon: Icon(
                  isPreviewPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 18,
                  color: isArmed ? Colors.grey : _primary,
                ),
                label: Text(
                  isPreviewPlaying ? 'Stop' : 'Preview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isArmed ? Colors.grey : _primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: _primaryFixed.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Audible bundled telephone ringtone plays on the media/ringer channel when incoming call triggers.',
            style: TextStyle(fontSize: 12, color: _onSurfaceVariant, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                ringtoneVolume == 0
                    ? Icons.volume_off_rounded
                    : ringtoneVolume < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                color: _primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _primary,
                    inactiveTrackColor: _outlineVariant,
                    thumbColor: _primary,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: ringtoneVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(ringtoneVolume * 100).round()}%',
                    onChanged: isArmed
                        ? null
                        : (val) {
                            setState(() => ringtoneVolume = val);
                            FakeCallAudioService().setVolume(val);
                          },
                  ),
                ),
              ),
              Text(
                '${(ringtoneVolume * 100).round()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildTriggerButton() {
    final String label = selectedDelaySeconds == 0
        ? 'Ring Phone Immediately'
        : (selectedDelaySeconds == 300
            ? 'Arm Call (5 min Delay)'
            : 'Arm Call (${selectedDelaySeconds}s Delay)');

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isArmed ? null : armFakeCall,
        icon: const Icon(Icons.ring_volume_rounded, color: Colors.white, size: 22),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Simulated Incoming / In-Call Full-Screen Overlay
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSimulatedCallOverlay() {
    final callerName = callerNameController.text.trim().isEmpty
        ? selectedPreset.defaultName
        : callerNameController.text.trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        color: const Color(0xFF0F0F11),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Top Bar: Simulated Badge & SOS Shortcut ────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SIMULATED CALL • NIRBHAY',
                        style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Quick Emergency Escalation Pill
                    GestureDetector(
                      onTap: _handleEmergencyEscalation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _error.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('REAL SOS', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Center Content: Caller Avatar & Info ───────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!isCallConnected)
                        ScaleTransition(
                          scale: pulseAnim,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectedPreset.iconColor.withOpacity(0.15),
                            ),
                          ),
                        ),
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: selectedPreset.bgColor,
                        child: Icon(selectedPreset.icon, color: selectedPreset.iconColor, size: 54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    callerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCallConnected
                        ? _formatDuration(callDurationSeconds)
                        : (selectedPreset.subtitle.isNotEmpty ? selectedPreset.subtitle : 'Incoming Call'),
                    style: TextStyle(
                      fontSize: 16,
                      color: isCallConnected ? const Color(0xFF4CAF50) : Colors.white60,
                      fontWeight: isCallConnected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),

              // ── In-Call Controls or Incoming Action Buttons ──────────
              if (isCallConnected)
                _buildConnectedCallControls()
              else
                _buildIncomingCallActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingCallActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Decline Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: handleDeclineOrEndCall,
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF3B30),
                  ),
                  child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 10),
                const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // Accept Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: handleAcceptCall,
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF34C759),
                  ),
                  child: const Icon(Icons.call_rounded, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 10),
                const Text('Accept', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedCallControls() {
    final controls = [
      (Icons.mic_off_rounded, 'Mute'),
      (Icons.dialpad_rounded, 'Keypad'),
      (Icons.volume_up_rounded, 'Speaker'),
      (Icons.add_rounded, 'Add Call'),
      (Icons.videocam_rounded, 'Video'),
      (Icons.contacts_rounded, 'Contacts'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            children: controls.map((c) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                    ),
                    child: Icon(c.$1, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 6),
                  Text(c.$2, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          // End Call Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: handleDeclineOrEndCall,
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF3B30),
                  ),
                  child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 8),
                const Text('End Call', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
