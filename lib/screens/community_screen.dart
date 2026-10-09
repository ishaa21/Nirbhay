import 'package:flutter/material.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  // ── Color tokens ───────────────────────────────────────────────────
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

  // ── Alert data ─────────────────────────────────────────────────────
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
        comments: [
          _Comment(author: 'Priya S.', text: 'Confirmed – walked past 10 mins ago, very unsafe.', timeAgo: '1 min ago'),
          _Comment(author: 'Dev K.', text: 'Reported to municipal corp already.', timeAgo: '30 secs ago'),
        ],
        ratingTotal: 14,
        ratingCount: 4,
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
        comments: [
          _Comment(author: 'Arjun T.', text: 'Still crowded as of 5 mins ago.', timeAgo: '3 mins ago'),
        ],
        ratingTotal: 9,
        ratingCount: 3,
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
        comments: [],
        ratingTotal: 12,
        ratingCount: 3,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroHeader(),
                const SizedBox(height: 24),
                _buildReportIncidentCTA(),
                const SizedBox(height: 32),
                _buildAreaSafetyReports(),
                const SizedBox(height: 32),
                _buildRecentAlertsFeed(),
              ],
            ),
          ),
        ),
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
  //  Report Incident CTA
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Area Safety Reports
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
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
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
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600, color: _primary)),
                  const SizedBox(height: 2),
                  Text(lastUpdated,
                      style: const TextStyle(fontSize: 11, color: _onSurfaceVariant)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: riskBg, borderRadius: BorderRadius.circular(30)),
                child: Text(riskLevel,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: riskTextColor)),
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
                            Text('Map Preview',
                                style: TextStyle(fontSize: 12, color: _onSurfaceVariant)),
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
  //  Recent Alerts Feed
  // ─────────────────────────────────────────────────────────────────
  Widget _buildRecentAlertsFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Alerts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _primary),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _alerts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _AlertCard(
              key: ValueKey(_alerts[index].title + index.toString()),
              alert: _alerts[index],
              onStateChanged: () => setState(() {}),
            );
          },
        ),
      ],
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
              Text('Report Incident',
                  style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
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
                        comments: [],
                        ratingTotal: 0,
                        ratingCount: 0,
                      ),
                    );
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Incident reported successfully! Thank you for keeping the community safe.'),
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

// ─────────────────────────────────────────────────────────────────
//  Alert Card Widget (stateful to manage local expand/comment state)
// ─────────────────────────────────────────────────────────────────
class _AlertCard extends StatefulWidget {
  final _AlertData alert;
  final VoidCallback onStateChanged;

  const _AlertCard({super.key, required this.alert, required this.onStateChanged});

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _surfaceContainerHighest = Color(0xFFE4E2E3);
  static const Color _cardBorder = Color(0x1A301427);
  static const Color _starActive = Color(0xFFD4A017);
  static const Color _starInactive = Color(0xFFDDD5D8);

  bool _showComments = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  double get _avgRating =>
      widget.alert.ratingCount == 0 ? 0 : widget.alert.ratingTotal / widget.alert.ratingCount;

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.alert.comments.add(
        _Comment(author: 'You', text: text, timeAgo: 'Just now'),
      );
      _commentController.clear();
    });
    widget.onStateChanged();
  }

  // ── Safety threshold: BOTH avg AND rater count required ────────────
  //
  // Tier          | Min avg | Min raters | Logic
  // ────────────  | ─────── | ─────────── | ──────────────────────────────
  // Low Concern   | ≥ 1.0   | ≥ 3         | Needs a few people to confirm
  // Moderate Risk | ≥ 2.0   | ≥ 5         | Meaningful pattern forming
  // Unsafe        | ≥ 3.0   | ≥ 8         | Enough voices to be credible
  // Highly Unsafe | ≥ 3.8   | ≥ 12        | Strong community signal
  // Critical      | ≥ 4.5   | ≥ 20        | Must be widely confirmed
  //
  // If avg qualifies for a higher tier but count is too low, the badge
  // stays at the tier below and shows a "Need X more ratings" hint.
  Map<String, dynamic> _getSafetyLevel(double avg, int count) {
    if (count == 0 || avg == 0) {
      return {
        'label': 'Unrated',
        'sublabel': null,
        'bg': const Color(0xFFEEEEEE),
        'textColor': const Color(0xFF757575),
        'icon': Icons.help_outline_rounded,
      };
    }

    if (avg >= 4.5) {
      if (count >= 20) {
        return {
          'label': 'Critical — Avoid Area',
          'sublabel': null,
          'bg': const Color(0xFF93000A),
          'textColor': Colors.white,
          'icon': Icons.crisis_alert_rounded,
        };
      }
      final need = 20 - count;
      return {
        'label': 'Highly Unsafe',
        'sublabel': 'Need $need more rating${need == 1 ? '' : 's'} to confirm Critical',
        'bg': const Color(0xFFFFDAD6),
        'textColor': const Color(0xFF93000A),
        'icon': Icons.dangerous_rounded,
      };
    }

    if (avg >= 3.8) {
      if (count >= 12) {
        return {
          'label': 'Highly Unsafe',
          'sublabel': null,
          'bg': const Color(0xFFFFDAD6),
          'textColor': const Color(0xFF93000A),
          'icon': Icons.dangerous_rounded,
        };
      }
      final need = 12 - count;
      return {
        'label': 'Unsafe',
        'sublabel': 'Need $need more rating${need == 1 ? '' : 's'} to confirm Highly Unsafe',
        'bg': const Color(0xFFFFE0C2),
        'textColor': const Color(0xFFB84C00),
        'icon': Icons.report_problem_rounded,
      };
    }

    if (avg >= 3.0) {
      if (count >= 8) {
        return {
          'label': 'Unsafe',
          'sublabel': null,
          'bg': const Color(0xFFFFE0C2),
          'textColor': const Color(0xFFB84C00),
          'icon': Icons.report_problem_rounded,
        };
      }
      final need = 8 - count;
      return {
        'label': 'Moderate Risk',
        'sublabel': 'Need $need more rating${need == 1 ? '' : 's'} to confirm Unsafe',
        'bg': const Color(0xFFFFF3CD),
        'textColor': const Color(0xFF856404),
        'icon': Icons.warning_amber_rounded,
      };
    }

    if (avg >= 2.0) {
      if (count >= 5) {
        return {
          'label': 'Moderate Risk',
          'sublabel': null,
          'bg': const Color(0xFFFFF3CD),
          'textColor': const Color(0xFF856404),
          'icon': Icons.warning_amber_rounded,
        };
      }
      final need = 5 - count;
      return {
        'label': 'Low Concern',
        'sublabel': 'Need $need more rating${need == 1 ? '' : 's'} to confirm Moderate Risk',
        'bg': const Color(0xFFDCF5E4),
        'textColor': const Color(0xFF1B6B35),
        'icon': Icons.check_circle_outline_rounded,
      };
    }

    // avg >= 1.0
    if (count >= 3) {
      return {
        'label': 'Low Concern',
        'sublabel': null,
        'bg': const Color(0xFFDCF5E4),
        'textColor': const Color(0xFF1B6B35),
        'icon': Icons.check_circle_outline_rounded,
      };
    }
    final need = 3 - count;
    return {
      'label': 'Unconfirmed',
      'sublabel': 'Need $need more rating${need == 1 ? '' : 's'} to assess risk',
      'bg': const Color(0xFFEEEEEE),
      'textColor': const Color(0xFF757575),
      'icon': Icons.pending_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main card body ───────────────────────────────────────
          Padding(
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
                          child: Icon(alert.icon, color: alert.iconColor, size: 22),
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
                                  color: _onSurface),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alert.location,
                              style: const TextStyle(
                                  fontSize: 11, color: _onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(alert.timeAgo,
                        style:
                            const TextStyle(fontSize: 11, color: _onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  alert.description,
                  style: const TextStyle(
                      fontSize: 14, color: _onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 14),

                // ── Star Rating Row ────────────────────────────────
                _buildStarRatingRow(alert),
                const SizedBox(height: 12),

                const Divider(height: 1, color: Color(0x1AD1C3C9)),
                const SizedBox(height: 8),

                // ── Footer: confirm + comment toggle + author ──────
                Row(
                  children: [
                    // Experienced this
                    Expanded(
                      child: GestureDetector(
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
                          widget.onStateChanged();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: alert.isVerifiedByMe
                                ? _primary.withOpacity(0.10)
                                : _surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: alert.isVerifiedByMe
                                  ? _primary
                                  : _surfaceContainerHighest,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                alert.isVerifiedByMe
                                    ? Icons.thumb_up_rounded
                                    : Icons.thumb_up_alt_outlined,
                                size: 14,
                                color: alert.isVerifiedByMe
                                    ? _primary
                                    : _onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  alert.isVerifiedByMe
                                      ? 'You & ${alert.verifiedCount - 1} others'
                                      : '${alert.verifiedCount} experienced this',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: alert.isVerifiedByMe
                                        ? _primary
                                        : _onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Comment toggle button
                    GestureDetector(
                      onTap: () => setState(() => _showComments = !_showComments),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _showComments
                              ? _primary.withOpacity(0.10)
                              : _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _showComments
                                ? _primary
                                : _surfaceContainerHighest,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 14,
                              color: _showComments ? _primary : _onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${alert.comments.length} comments',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _showComments ? _primary : _onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Author
                    Text(
                      alert.author,
                      style: const TextStyle(fontSize: 10, color: _onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Comments Section (expandable) ────────────────────────
          if (_showComments) _buildCommentsSection(alert),
        ],
      ),
    );
  }

  // ── Star Rating Row + Safety Badge ─────────────────────────────────
  Widget _buildStarRatingRow(_AlertData alert) {
    final safety = _getSafetyLevel(_avgRating, alert.ratingCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Row 1: stars + numeric score ──────────────────────────
        Row(
          children: [
            // Tappable stars
            for (int star = 1; star <= 5; star++)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (alert.myRating == star) {
                      alert.ratingTotal -= star;
                      alert.ratingCount--;
                      alert.myRating = 0;
                    } else if (alert.myRating == 0) {
                      alert.ratingTotal += star;
                      alert.ratingCount++;
                      alert.myRating = star;
                    } else {
                      alert.ratingTotal = alert.ratingTotal - alert.myRating + star;
                      alert.myRating = star;
                    }
                  });
                  widget.onStateChanged();
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      star <= (alert.myRating > 0 ? alert.myRating : _avgRating.round())
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      key: ValueKey('star_${alert.title}_$star'),
                      size: 22,
                      color: star <= (alert.myRating > 0 ? alert.myRating : _avgRating.round())
                          ? _starActive
                          : _starInactive,
                    ),
                  ),
                ),
              ),

            const SizedBox(width: 8),

            Text(
              alert.ratingCount == 0
                  ? 'Tap to rate severity'
                  : '${_avgRating.toStringAsFixed(1)} (${alert.ratingCount} ${alert.ratingCount == 1 ? 'rating' : 'ratings'})',
              style: TextStyle(
                fontSize: 12,
                color: alert.ratingCount == 0 ? _onSurfaceVariant : _starActive,
                fontWeight: FontWeight.w600,
              ),
            ),

            if (alert.myRating > 0) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    alert.ratingTotal -= alert.myRating;
                    alert.ratingCount--;
                    alert.myRating = 0;
                  });
                  widget.onStateChanged();
                },
                child: const Text(
                  '· Remove',
                  style: TextStyle(fontSize: 11, color: _onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),

        // ── Row 2: animated safety threshold badge + sublabel ──────
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (safety['bg'] as Color),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                safety['icon'] as IconData,
                size: 13,
                color: safety['textColor'] as Color,
              ),
              const SizedBox(width: 5),
              Text(
                safety['label'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: safety['textColor'] as Color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        // sublabel: "Need X more ratings to confirm ..."
        if (safety['sublabel'] != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.people_alt_outlined,
                  size: 11, color: const Color(0xFF757575)),
              const SizedBox(width: 4),
              Text(
                safety['sublabel'] as String,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF757575),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Comments Section ───────────────────────────────────────────────
  Widget _buildCommentsSection(_AlertData alert) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF5F7),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: Color(0x1AD1C3C9)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Existing comments
          if (alert.comments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No comments yet. Be the first to share your experience.',
                style: TextStyle(
                    fontSize: 12,
                    color: _onSurfaceVariant.withOpacity(0.7),
                    fontStyle: FontStyle.italic),
              ),
            )
          else
            ...alert.comments.map((c) => _buildCommentBubble(c)),

          const SizedBox(height: 10),

          // Comment input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primary.withOpacity(0.15),
                ),
                child: const Center(
                  child: Text('Y',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _primary)),
                ),
              ),
              const SizedBox(width: 10),

              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x33301427), width: 1.2),
                  ),
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13, color: _onSurface),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: _onSurfaceVariant),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              GestureDetector(
                onTap: _submitComment,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: _primary.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(_Comment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar circle with initial
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primary.withOpacity(0.12),
            ),
            child: Center(
              child: Text(
                comment.author[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _primary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _onSurface),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      comment.timeAgo,
                      style: const TextStyle(
                          fontSize: 10, color: _onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(color: const Color(0x1AD1C3C9)),
                  ),
                  child: Text(
                    comment.text,
                    style: const TextStyle(
                        fontSize: 13, color: _onSurface, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Data Models
// ─────────────────────────────────────────────────────────────────
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
  List<_Comment> comments;
  int ratingTotal;
  int ratingCount;
  int myRating; // 0 = not rated, 1–5

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
    required this.comments,
    required this.ratingTotal,
    required this.ratingCount,
    this.myRating = 0,
  });
}

class _Comment {
  final String author;
  final String text;
  final String timeAgo;

  _Comment({required this.author, required this.text, required this.timeAgo});
}
