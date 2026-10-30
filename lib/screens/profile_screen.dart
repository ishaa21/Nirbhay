import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/shake_sos_service.dart';
import 'signin_screen.dart';
import '../services/language_service.dart';
import '../l10n/app_localizations.dart';
import 'language_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── Color tokens matching design spec ─────────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSecondaryContainer = Color(0xFF705D67);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _outline = Color(0xFF807479);
  static const Color _outlineVariant = Color(0xFFD1C3C9);
  static const Color _cardBorder = Color(0x1A301427); // 10% Old Burgundy

  late AnimationController _badgeAnimController;
  late Animation<double> _badgeScaleAnim;

  String _currentTheme = 'Light';
  UserModel? _userProfile;

  @override
  void initState() {
    super.initState();
    _badgeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _badgeScaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _badgeAnimController,
        curve: Curves.elasticOut,
      ),
    );
    _badgeAnimController.forward();

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await AuthService().getCurrentUser() ?? await AuthService().getProfile();
    if (mounted) {
      setState(() {
        _userProfile = user;
      });
    }
  }

  @override
  void dispose() {
    _badgeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Profile Header Card ─────────────────────────────
                _buildProfileHeaderCard(),
                const SizedBox(height: 24),

                // ── Menu Sections ───────────────────────────────────
                _buildAccountAndSecuritySection(),
                const SizedBox(height: 16),
                _buildPreferencesSection(),
                const SizedBox(height: 32),

                // ── Logout Button & Version Info ────────────────────
                _buildLogoutSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials() {
    final name = _userProfile?.fullName.trim();
    if (name == null || name.isEmpty) return 'NB';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  // ─────────────────────────────────────────────────────────────────
  //  Profile Header Card
  // ─────────────────────────────────────────────────────────────────
  Widget _buildProfileHeaderCard() {
    const avatarUrl =
        'https://lh3.googleusercontent.com/aida-public/AB6AXuC1gTtHcDK78C3-ZZgaE7SN70-WJ1jkIXBzT4jT5Wlpl7EhAPzzTvin9YBJdc9cfk0sQxTaNPcuPMq5fFogJG-WeZbDk-WIq9xhoBOWgju5RUikE1_Ho4RyqtMv6rQI2A58Z0UXytrlcWt3y0cxTHOsCWVa_OFfbeuiXSAmkarlwGIzOkB1qDELJK_aJJniSSZl4pYxsKS8hW4iySp6DxE72Wq-qMBzg-XrzGQKybXousMRhYRQGHIyfrYeBKDFrwoqpKoPK05ULtpA';

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar with badge
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _secondaryContainer, width: 4),
                ),
                child: ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: _secondaryContainer,
                        child: Center(
                          child: Text(
                            _getInitials(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: _secondaryContainer,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Verified badge bottom-right
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // User Name
          Text(
            _userProfile?.fullName ?? 'Ananya Sharma',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _onSurface,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),

          // Email / Member Info
          Text(
            _userProfile?.email ?? 'ananya.sharma@example.com',
            style: const TextStyle(
              fontSize: 14,
              color: _onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Safety Score Badge
          ScaleTransition(
            scale: _badgeScaleAnim,
            child: GestureDetector(
              onTap: () {
                _badgeAnimController.forward(from: 0.0);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).safetyScoreDesc),
                    backgroundColor: _primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _secondaryContainer,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: _primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _onSecondaryContainer,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                        children: [
                          TextSpan(text: 'Safety Score: '),
                          TextSpan(
                            text: '98/100',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Account & Security Section
  // ─────────────────────────────────────────────────────────────────
  Widget _buildAccountAndSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            AppLocalizations.of(context).accountAndSecurity,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _primary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                _buildMenuItemTile(
                  icon: Icons.person_outline_rounded,
                  title: AppLocalizations.of(context).personalInfo,
                  onTap: () => _showMenuBottomSheet(AppLocalizations.of(context).personalInfo, AppLocalizations.of(context).personalInfoDesc),
                  showDivider: true,
                ),
                _buildMenuItemTile(
                  icon: Icons.gpp_maybe_outlined,
                  title: AppLocalizations.of(context).safetySettings,
                  onTap: () => _showSafetySettingsBottomSheet(),
                  showDivider: true,
                ),
                _buildMenuItemTile(
                  icon: Icons.notifications_active_outlined,
                  title: AppLocalizations.of(context).notifications,
                  onTap: () => _showMenuBottomSheet(AppLocalizations.of(context).notifications, AppLocalizations.of(context).notificationsDesc),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Preferences Section
  // ─────────────────────────────────────────────────────────────────
  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            AppLocalizations.of(context).preferences.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _primary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                _buildMenuItemTile(
                  icon: Icons.language_rounded,
                  title: '${AppLocalizations.of(context).language} / भाषा / ભાષા',
                  trailingText: LanguageService().currentLanguage.nativeName,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LanguageSelectionScreen(),
                      ),
                    );
                  },
                  showDivider: true,
                ),
                _buildMenuItemTile(
                  icon: Icons.palette_outlined,
                  title: AppLocalizations.of(context).appTheme,
                  trailingText: _currentTheme == 'Light' ? AppLocalizations.of(context).lightMode : AppLocalizations.of(context).darkMode,
                  onTap: () {
                    setState(() {
                      _currentTheme = _currentTheme == 'Light' ? 'Dark' : 'Light';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).themeSwitchedMode(_currentTheme == 'Light' ? AppLocalizations.of(context).lightMode : AppLocalizations.of(context).darkMode)),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  showDivider: true,
                ),
                _buildMenuItemTile(
                  icon: Icons.help_center_outlined,
                  title: AppLocalizations.of(context).helpAndSupport,
                  onTap: () => _showMenuBottomSheet(AppLocalizations.of(context).helpAndSupport, AppLocalizations.of(context).helpAndSupportSubtitle),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Menu Item Tile Helper
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMenuItemTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailingText,
    required bool showDivider,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _secondaryContainer.withOpacity(0.4),
        child: Container(
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0x1AD1C3C9),
                      width: 1,
                    ),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Icon with circular container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _secondaryContainer.withOpacity(0.5),
                ),
                child: Icon(
                  icon,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _onSurface,
                  ),
                ),
              ),

              // Trailing text if present
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _outline,
                  ),
                ),
                const SizedBox(width: 4),
              ],

              // Chevron Icon
              const Icon(
                Icons.chevron_right_rounded,
                color: _outline,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Logout Section
  // ─────────────────────────────────────────────────────────────────
  Widget _buildLogoutSection() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _confirmLogout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: _primary.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, size: 22),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).logout,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context).nirbhayAppHeading,
          style: const TextStyle(
            fontSize: 11,
            color: _outline,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AppLocalizations.of(context).versionText,
          style: const TextStyle(
            fontSize: 11,
            color: _outlineVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Actions & Modal Sheet Helpers
  // ─────────────────────────────────────────────────────────────────
  void _showSafetySettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        bool isShakeEnabled = false;
        String sensitivity = 'DEFAULT';
        bool isLoading = true;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (isLoading) {
              ShakeSosService().isServiceEnabled().then((enabled) {
                if (ctx.mounted) {
                  setSheetState(() {
                    isShakeEnabled = enabled;
                    isLoading = false;
                  });
                }
              });
            }


            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.gpp_maybe_outlined, color: _primary, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context).safetySettings,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vibration, color: _primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).shakeSosDetectionTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _onSurface,
                                    ),
                                  ),
                                  Text(
                                    AppLocalizations.of(context).shakeBackgroundLock,
                                    style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Switch(
                                    value: isShakeEnabled,
                                    activeColor: _primary,
                                    onChanged: (val) async {
                                      setSheetState(() => isLoading = true);
                                      if (val) {
                                        await ShakeSosService().requestNotificationPermission();
                                      }
                                      final ok = val
                                          ? await ShakeSosService().startShakeService()
                                          : await ShakeSosService().stopShakeService();
                                      if (ctx.mounted) {
                                        setSheetState(() {
                                          isLoading = false;
                                          if (ok) isShakeEnabled = val;
                                        });
                                      }
                                    },
                                  ),
                          ],
                        ),
                        if (isShakeEnabled) ...[
                          const Divider(height: 24),
                          Text(
                            AppLocalizations.of(context).shakeSensitivity,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _onSurface),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: ['LOW', 'DEFAULT', 'HIGH'].map((lvl) {
                              final isSelected = sensitivity == lvl;
                              final label = lvl == 'LOW'
                                  ? AppLocalizations.of(context).sensitivityLow
                                  : (lvl == 'HIGH'
                                      ? AppLocalizations.of(context).sensitivityHigh
                                      : AppLocalizations.of(context).sensitivityDefault);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(label, style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : _onSurfaceVariant,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  )),
                                  selected: isSelected,
                                  selectedColor: _primary,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setSheetState(() => sensitivity = lvl);
                                      ShakeSosService().setSensitivity(lvl);
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppLocalizations.of(context).done, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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


  void _showMenuBottomSheet(String title, String description) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 15,
                  color: _onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context).gotItBtn, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppLocalizations.of(context).logOutTitle, style: const TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          content: Text(AppLocalizations.of(context).confirmLogout),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel, style: const TextStyle(color: _onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                // Clear JWT token from secure storage
                await AuthService().logout();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                );
              },
              child: Text(AppLocalizations.of(context).logOutTitle, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
