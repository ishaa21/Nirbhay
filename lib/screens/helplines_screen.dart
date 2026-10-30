import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class HelplinesScreen extends StatefulWidget {
  const HelplinesScreen({super.key});

  @override
  State<HelplinesScreen> createState() => _HelplinesScreenState();
}

class _HelplinesScreenState extends State<HelplinesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ── Color Palette ─────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Colors.white;
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSecondaryContainer = Color(0xFF705D67);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _error = Color(0xFFBA1A1A);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _callNumber(String number) async {
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).couldNotLaunchDialerFor(number))),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboardVal(text))),
    );
  }

  void _openWhatsApp(String number, String message) async {
    final Uri url = Uri.parse('https://wa.me/91$number?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _callNumber(number);
    }
  }

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
              AppLocalizations.of(context).translate('helplinesHeading'),
              style: TextStyle(
                fontSize: 12,
                color: _onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: _onSurface),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Location Context & Quick Status Pill
              _buildLocationStatusPill(),
              const SizedBox(height: 12),

              // 2. Search & Filter Bar
              _buildSearchBar(),
              const SizedBox(height: 14),

              // 3. Hardware Rapid Trigger Shortcut Banner
              _buildHardwareShortcutBanner(),
              const SizedBox(height: 16),

              // 4. Apex National Lifeline 112 Super Card
              _buildNational112Card(),
              const SizedBox(height: 20),

              // 5. Rapid Assistance Cards Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('rapidAssistanceCards'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context).translate('autoRecordedLines'),
                    style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Rapid Cards List
              _buildRapidAssistanceGrid(),
              const SizedBox(height: 24),

              // 6. Specialized Directories (Accordions)
              Text(
                AppLocalizations.of(context).translate('specializedDirectories'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).verified247Desk,
                style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              _buildSpecializedDirectories(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Location Context & Status
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildLocationStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.my_location, size: 18, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).delhiNcrActiveDispatch,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 3, backgroundColor: _primary),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).priority1Ready,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _onSecondaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Search & Filter Bar
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).searchHelplineHint,
          hintStyle: const TextStyle(color: _onSurfaceVariant, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: _onSurfaceVariant, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel, color: _onSurfaceVariant, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Hardware Rapid Trigger Shortcut Banner
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHardwareShortcutBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primary,
            child: const Icon(Icons.settings_accessibility, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).volumeButtonSosRapidDial,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primary),
                ),
                Text(
                  AppLocalizations.of(context).volumeButtonSosDesc,
                  style: const TextStyle(fontSize: 11, color: _onSecondaryContainer),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).volumeButtonTriggerEnabled)),
              );
            },
            child: Text(AppLocalizations.of(context).configuredBadge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Apex National Lifeline 112 Super Card
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildNational112Card() {
    if (_searchQuery.isNotEmpty &&
        !'112 national emergency police fire ambulance'.contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _error,
                      child: const Icon(Icons.crisis_alert, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).apexNationalLifeline,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Color(0xFFE7BAD3),
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context).translate('national112'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF48293D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.of(context).etaUnder15s,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFFD8ED)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).unifiedCrisisDesc,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFE7BAD3), height: 1.4),
          ),
          const SizedBox(height: 12),

          // Metadata Badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _BadgeItem(icon: Icons.schedule, text: AppLocalizations.of(context).desk247Priority),
              _BadgeItem(icon: Icons.translate, text: AppLocalizations.of(context).languages22Indian),
              _BadgeItem(icon: Icons.location_on, text: AppLocalizations.of(context).satelliteDispatch),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => _callNumber('112'),
                  icon: const Icon(Icons.phone_in_talk, size: 18),
                  label: Text(AppLocalizations.of(context).call112, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF48293D),
                    foregroundColor: const Color(0xFFFFD8ED),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => _copyToClipboard('112'),
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: Text(AppLocalizations.of(context).copyDial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Rapid Assistance Cards Grid
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildRapidAssistanceGrid() {
    final l10n = AppLocalizations.of(context);
    final List<Map<String, dynamic>> items = [
      {
        'title': l10n.womenHelplineTitle,
        'number': '1091',
        'subtitle': l10n.womenHelplineSub,
        'desc': l10n.womenHelplineDesc,
        'badges': [l10n.badge247Available, l10n.badgeHindiEngRegional, l10n.badgeResponseUnder30s],
        'icon': Icons.female,
      },
      {
        'title': l10n.ncwHelplineTitle,
        'number': '7827170170',
        'subtitle': l10n.ncwHelplineSub,
        'desc': l10n.ncwHelplineDesc,
        'badges': [l10n.badge247Online, l10n.badgeWhatsappSosEnabled, l10n.badgeLegalCounsel],
        'icon': Icons.support_agent,
        'isWhatsapp': true,
      },
      {
        'title': l10n.cyberCrimeTitle,
        'number': '1930',
        'subtitle': l10n.cyberCrimeSub,
        'desc': l10n.cyberCrimeDesc,
        'badges': [l10n.badge247Operation, l10n.badgeEngHindiRegional, l10n.badgeFirFilingGuidance],
        'icon': Icons.security,
      },
      {
        'title': l10n.childlineTitle,
        'number': '1098',
        'subtitle': l10n.childlineSub,
        'desc': l10n.childlineDesc,
        'badges': [l10n.badge247FreeHelpline, l10n.badgePanIndiaSupport, l10n.badgeStrictAnonymity],
        'icon': Icons.family_restroom,
      },
    ];

    final filtered = items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final fullText = '${item['title']} ${item['number']} ${item['subtitle']} ${item['desc']}'.toLowerCase();
      return fullText.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: Text(l10n.noMatchingHelplinesFound, style: const TextStyle(color: _onSurfaceVariant))),
      );
    }

    return Column(
      children: filtered.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRapidCard(
            title: item['title'],
            number: item['number'],
            subtitle: item['subtitle'],
            desc: item['desc'],
            badges: List<String>.from(item['badges']),
            icon: item['icon'],
            isWhatsapp: item['isWhatsapp'] ?? false,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRapidCard({
    required String title,
    required String number,
    required String subtitle,
    required String desc,
    required List<String> badges,
    required IconData icon,
    bool isWhatsapp = false,
  }) {
    return Container(
      width: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _secondaryContainer,
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            number,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: _onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            style: const TextStyle(fontSize: 12.5, color: _onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 10),

          // Badges
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: badges.map((b) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(b, style: const TextStyle(fontSize: 10.5, color: _onSurface)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => _callNumber(number),
                  icon: const Icon(Icons.call, size: 16),
                  label: Text(AppLocalizations.of(context).callNumberVal(number), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              if (isWhatsapp)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _secondaryContainer,
                      foregroundColor: _primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _openWhatsApp(number, 'HELP EMERGENCY'),
                    icon: const Icon(Icons.chat, size: 16),
                    label: Text(AppLocalizations.of(context).whatsAppSos, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0EDEE),
                      foregroundColor: _onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _copyToClipboard(number),
                    icon: const Icon(Icons.content_copy, size: 16),
                    label: Text(AppLocalizations.of(context).copy, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 6. Specialized Directories (Accordions)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSpecializedDirectories() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _buildAccordionGroup(
          title: l10n.mentalHealthCategory,
          subtitle: l10n.mentalHealthCategorySub,
          icon: Icons.psychology,
          children: [
            _buildDirectoryItem(
              title: l10n.kiranHelplineTitle,
              subtitle: l10n.kiranHelplineSub,
              number: '18005990019',
              displayNumber: '1800-599-0019',
            ),
            const SizedBox(height: 8),
            _buildDirectoryItem(
              title: l10n.teleManasTitle,
              subtitle: l10n.teleManasSub,
              number: '14416',
              displayNumber: '14416 / 1800-891-4416',
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildAccordionGroup(
          title: l10n.policeLegalCategory,
          subtitle: l10n.policeLegalCategorySub,
          icon: Icons.local_police,
          children: [
            _buildDirectoryItem(
              title: l10n.delhiPcrTitle,
              subtitle: l10n.delhiPcrSub,
              number: '112',
              displayNumber: '112 / 100',
            ),
            const SizedBox(height: 8),
            _buildDirectoryItem(
              title: l10n.nalsaTitle,
              subtitle: l10n.nalsaSub,
              number: '15100',
              displayNumber: '15100',
            ),
            const SizedBox(height: 8),
            _buildDirectoryItem(
              title: l10n.railwaySecurityTitle,
              subtitle: l10n.railwaySecuritySub,
              number: '139',
              displayNumber: '139',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccordionGroup({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: _secondaryContainer,
          child: Icon(icon, size: 18, color: _primary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: children,
      ),
    );
  }

  Widget _buildDirectoryItem({
    required String title,
    required String subtitle,
    required String number,
    required String displayNumber,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primary),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  displayNumber,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.content_copy, size: 16, color: _primary),
                onPressed: () => _copyToClipboard(number),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.call, size: 16),
                onPressed: () => _callNumber(number),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BadgeItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF48293D).withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 10.5, color: Colors.white)),
        ],
      ),
    );
  }
}
