import 'package:flutter/material.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  // ── Color tokens matching design spec ─────────────────────────────
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _primaryFixed = Color(0xFFFFD8ED);
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSecondaryContainer = Color(0xFF705D67);
  static const Color _errorContainer = Color(0xFFFFDAD6);
  static const Color _onErrorContainer = Color(0xFF93000A);
  static const Color _surfaceContainerHighest = Color(0xFFE4E2E3);
  static const Color _cardBorder = Color(0x1A301427);

  // ── Alert item data state ──────────────────────────────────────────
  late List<_AlertData> _alerts;

  @override
  void initState() {
    super.initState();
    _alerts = [
      _AlertData(
        icon: Icons.electric_bolt_rounded,
        iconBg: _primaryFixed,
        iconColor: _primary,
        title: 'Street Light Malfunction',
        location: 'Near 4th Street Crossing',
        timeAgo: '2 mins ago',
        description:
            'Area is very dark, visibility less than 5 meters. Recommend taking the alternate route via 5th Ave.',
        author: 'By Rahul M.',
        verifiedCount: 12,
        isVerifiedByMe: false,
      ),
      _AlertData(
        icon: Icons.groups_rounded,
        iconBg: _secondaryContainer,
        iconColor: _onSecondaryContainer,
        title: 'Crowd Update',
        location: 'Grand Central Entrance',
        timeAgo: '15 mins ago',
        description:
            'Unexpectedly large gathering near the North exit. Police presence noted, but movement is very slow.',
        author: 'By Sarah K.',
        verifiedCount: 45,
        isVerifiedByMe: false,
      ),
      _AlertData(
        icon: Icons.visibility_rounded,
        iconBg: _errorContainer,
        iconColor: _onErrorContainer,
        title: 'Suspicious Activity',
        location: 'Rear Alley - Market St.',
        timeAgo: '28 mins ago',
        description:
            'Three individuals loitering near residential gates. Reported to local guard. Avoid the alleyway.',
        author: 'By Anonymous',
        verifiedCount: 8,
        isVerifiedByMe: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: Stack(
        children: [
          // ── Scrollable Body Content ─────────────────────────────
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 768), // max-w-3xl
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero Header ───────────────────────────────────
                    _buildHeroHeader(),
                    const SizedBox(height: 24),

                    // ── Report Incident CTA Button ────────────────────
                    _buildReportIncidentCTA(),
                    const SizedBox(height: 32),

                    // ── Area Safety Reports Section ──────────────────
                    _buildAreaSafetyReports(),
                    const SizedBox(height: 32),

                    // ── Recent Alerts Feed Section ────────────────────
                    _buildRecentAlertsFeed(),
                  ],
                ),
              ),
            ),
          ),

          // ── Floating SOS Button ─────────────────────────────────
          Positioned(
            right: 20,
            bottom: 24,
            child: _buildSOSFloatingButton(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Hero Header
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Community Hub',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _primary,
            height: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Real-time safety insights from people nearby. Stay informed, stay safe together.',
          style: TextStyle(
            fontSize: 16,
            color: _onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Report Incident CTA Button
  // ─────────────────────────────────────────────────────────────────
  Widget _buildReportIncidentCTA() {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: _showReportIncidentDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: _primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.campaign_rounded, size: 26),
            SizedBox(width: 12),
            Text(
              'Report Incident',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Area Safety Reports Section
  // ─────────────────────────────────────────────────────────────────
  Widget _buildAreaSafetyReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Area Safety Reports',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening interactive safety heatmap...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'View Map',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Scrollable Cards
        SizedBox(
          height: 165,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildAreaReportCard(
                title: 'Central Park',
                lastUpdated: 'Last updated 12m ago',
                riskLevel: 'High Risk',
                riskBg: _errorContainer,
                riskTextColor: _onErrorContainer,
                mapUrl:
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuASMI1rxXYZqKiVRFhTqWxKK9p-YIR3KimYIkPbHTd2PERFvCeEP8MMh8gr-dAW7rNSqGDTcyD-dzBKEjejor_aQx-P3YVOeIS366r6uEjcKeLwb_447IA5PkGqQ9pla2RBb-taUTlTcsQdYK5tv0AanxqHCWrBUMQRPSnU-JiGQ1_egp4BDWqlPlYkV91fqaNUPhwOkig1IfWqwdFFWq64xkeNYScPyS1lBVJoSZEsN2TubReSQNlFE4yiUp9EEeGlI2Y26TaZ1sTu',
              ),
              const SizedBox(width: 16),
              _buildAreaReportCard(
                title: 'Metro Plaza',
                lastUpdated: 'Last updated 45m ago',
                riskLevel: 'Moderate',
                riskBg: _secondaryContainer,
                riskTextColor: _onSecondaryContainer,
                mapUrl:
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuASJiFpSu0VmkrvzKwkTIPmtCfJk_YebPG9D6Hf9eDGtLPXli70AiAfGfpKjwv4wsZKlCDmOqde-XHZAdfNCnraJJRUF-6-ojawcot7Gn4vsByJkUEdpMBDIknHMbLsAXqiE8TLxzvZ5yJwxPbb1bUSeZ7_VD2wnQV3JLiIxk7OCUPtw4xz9K9Tp-bDznZ6rBot_TA1c6G1aKh5TzQ3gOIKA5l7109mgrXXvPIKRkYCWAfOBkCrCaNDRMmRH9q0qnNJIlnPKhjDgGng',
              ),
              const SizedBox(width: 16),
              _buildAreaReportCard(
                title: 'North Avenue',
                lastUpdated: 'Last updated 1h ago',
                riskLevel: 'Low Risk',
                riskBg: _surfaceContainerHighest,
                riskTextColor: _onSurfaceVariant,
                mapUrl:
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDdhsydvEakB5r-GqLizrORx9wdpbCKyKFXBJz91P_i-f8un0lz6YWdG9PFAiC0Clb65bVpdpgJHNvD9egq1TehM_ODWCKcnq-nh5nXQi_ZAdGqqEm3WyvIwUb45RZCUtc7KH1xINvLlNUzOrHjFwC7-2bb-t84qqsfy-xcBpfjmSpJRcwO64AUzmBjKsMRbQ_IJyMBcAd0Pse3lSHWvjaMAZyMkRIffI7HT61uW-auDkChYkcJE78chlUF8TPQblEUmLG10hrNXxHr',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAreaReportCard({
    required String title,
    required String lastUpdated,
    required String riskLevel,
    required Color riskBg,
    required Color riskTextColor,
    required String mapUrl,
  }) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastUpdated,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: riskBg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  riskLevel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: riskTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                color: _secondaryContainer.withOpacity(0.3),
                child: Image.network(
                  mapUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFEFE9EB),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.map, size: 18, color: _primary),
                            SizedBox(width: 6),
                            Text('Map Preview', style: TextStyle(fontSize: 12, color: _onSurfaceVariant)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Recent Alerts Feed Section
  // ─────────────────────────────────────────────────────────────────
  Widget _buildRecentAlertsFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Alerts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _primary,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _alerts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final alert = _alerts[index];
            return _buildAlertCard(alert, index);
          },
        ),
      ],
    );
  }

  Widget _buildAlertCard(_AlertData alert, int index) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: alert.iconBg,
                    ),
                    child: Icon(
                      alert.icon,
                      color: alert.iconColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.location,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                alert.timeAgo,
                style: const TextStyle(
                  fontSize: 11,
                  color: _onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            alert.description,
            style: const TextStyle(
              fontSize: 14,
              color: _onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Divider
          const Divider(height: 1, color: Color(0x1AD1C3C9)),
          const SizedBox(height: 8),

          // Footer Row (Verified count + Author)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (alert.isVerifiedByMe) {
                      alert.verifiedCount--;
                      alert.isVerifiedByMe = false;
                    } else {
                      alert.verifiedCount++;
                      alert.isVerifiedByMe = true;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: alert.isVerifiedByMe ? const Color(0xFF48293D) : _primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${alert.verifiedCount} verified',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: alert.isVerifiedByMe ? const Color(0xFF48293D) : _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                alert.author,
                style: const TextStyle(
                  fontSize: 11,
                  color: _onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Floating SOS Button Widget
  // ─────────────────────────────────────────────────────────────────
  Widget _buildSOSFloatingButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS Alert Triggered! Emergency contacts notified.'),
              backgroundColor: _primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _primary,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 4),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'SOS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Report Incident Dialog
  // ─────────────────────────────────────────────────────────────────
  void _showReportIncidentDialog() {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.campaign_rounded, color: _primary),
              SizedBox(width: 8),
              Text(
                'Report Incident',
                style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Incident Type / Title',
                    hintText: 'e.g. Broken Streetlight, Crowd',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g. 5th Avenue Crossing',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Provide safety details for neighbors...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  setState(() {
                    _alerts.insert(
                      0,
                      _AlertData(
                        icon: Icons.report_problem_rounded,
                        iconBg: _secondaryContainer,
                        iconColor: _primary,
                        title: titleController.text,
                        location: locationController.text.isEmpty
                            ? 'Nearby Location'
                            : locationController.text,
                        timeAgo: 'Just now',
                        description: descController.text.isEmpty
                            ? 'No description provided.'
                            : descController.text,
                        author: 'By You',
                        verifiedCount: 1,
                        isVerifiedByMe: true,
                      ),
                    );
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Incident reported successfully! Thank you for keeping the community safe.'),
                      backgroundColor: _primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Submit Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class _AlertData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String location;
  final String timeAgo;
  final String description;
  final String author;
  int verifiedCount;
  bool isVerifiedByMe;

  _AlertData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.location,
    required this.timeAgo,
    required this.description,
    required this.author,
    required this.verifiedCount,
    required this.isVerifiedByMe,
  });
}
