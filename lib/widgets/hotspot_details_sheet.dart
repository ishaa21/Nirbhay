import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/safety_hotspot_model.dart';
import '../services/community_service.dart';

class HotspotDetailsSheet extends StatefulWidget {
  final SafetyHotspotModel hotspot;
  final VoidCallback? onFeedbackSubmitted;

  const HotspotDetailsSheet({
    super.key,
    required this.hotspot,
    this.onFeedbackSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required SafetyHotspotModel hotspot,
    VoidCallback? onFeedbackSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HotspotDetailsSheet(
        hotspot: hotspot,
        onFeedbackSubmitted: onFeedbackSubmitted,
      ),
    );
  }

  @override
  State<HotspotDetailsSheet> createState() => _HotspotDetailsSheetState();
}

class _HotspotDetailsSheetState extends State<HotspotDetailsSheet> {
  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF807479);
  static const Color _border = Color(0xFFE5DCE0);

  bool _isSubmittingFeedback = false;
  String? _submittedFeedbackType;
  int _confirmationsCount = 0;
  int _disputesCount = 0;

  @override
  void initState() {
    super.initState();
    _confirmationsCount = widget.hotspot.confirmationsCount;
    _disputesCount = widget.hotspot.disputesCount;
  }

  Future<void> _submitFeedback(String feedbackType) async {
    if (_isSubmittingFeedback || _submittedFeedbackType != null) return;

    final firstReportId = widget.hotspot.reports.isNotEmpty
        ? widget.hotspot.reports.first.id
        : widget.hotspot.id;

    setState(() => _isSubmittingFeedback = true);

    try {
      final res = await CommunityService().submitHotspotFeedback(
        firstReportId,
        feedbackType: feedbackType,
        postId: firstReportId,
      );

      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _submittedFeedbackType = feedbackType;
            if (feedbackType == 'STILL_PRESENT') {
              _confirmationsCount += 1;
            } else if (feedbackType == 'INACCURATE') {
              _disputesCount += 1;
            }
          });
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.feedbackSubmitted),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          widget.onFeedbackSubmitted?.call();
        } else {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? l10n.feedbackError),
              backgroundColor: const Color(0xFFC62828),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.feedbackError),
            backgroundColor: const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
      }
    }
  }

  String _formatTimeAgo(DateTime dt, BuildContext context) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 30).floor()}mo ago';
    }
  }

  Color _getRiskColor(HotspotRiskLevel level) {
    switch (level) {
      case HotspotRiskLevel.red:
        return const Color(0xFFE53935);
      case HotspotRiskLevel.orange:
        return const Color(0xFFFB8C00);
      case HotspotRiskLevel.yellow:
        return const Color(0xFFFDD835);
    }
  }

  Color _getRiskTextColor(HotspotRiskLevel level) {
    switch (level) {
      case HotspotRiskLevel.red:
        return const Color(0xFFB71C1C);
      case HotspotRiskLevel.orange:
        return const Color(0xFFE65100);
      case HotspotRiskLevel.yellow:
        return const Color(0xFF7F6000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hotspot = widget.hotspot;
    final riskColor = _getRiskColor(hotspot.riskLevel);
    final riskTextColor = _getRiskTextColor(hotspot.riskLevel);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.35, 0.65, 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Scrollable body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // Header Row: Risk Badge & Verification Tag (wrapped for small screens)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Risk Level Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: riskColor, width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: riskColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hotspot.localizedRiskLevelLabel(l10n),
                                style: TextStyle(
                                  color: riskTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Verification Status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hotspot.verificationStatus == HotspotVerificationStatus.communityVerified
                                    ? Icons.verified_rounded
                                    : (hotspot.verificationStatus == HotspotVerificationStatus.disputed
                                        ? Icons.help_outline_rounded
                                        : Icons.groups_rounded),
                                size: 13,
                                color: const Color(0xFF475569),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hotspot.localizedVerificationLabel(l10n),
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Primary Category Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hotspot.localizedCategoryLabel(l10n),
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Area Name
                    Text(
                      hotspot.locationName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Metrics Banner
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricItem(
                            icon: Icons.assignment_late_outlined,
                            count: '${hotspot.reportCount}',
                            label: l10n.hotspotReportsCount(hotspot.reportCount),
                          ),
                          Container(width: 1, height: 26, color: _border),
                          _buildMetricItem(
                            icon: Icons.people_alt_outlined,
                            count: '${hotspot.independentAuthorCount}',
                            label: l10n.hotspotAuthorsCount(hotspot.independentAuthorCount),
                          ),
                          Container(width: 1, height: 26, color: _border),
                          _buildMetricItem(
                            icon: Icons.access_time_rounded,
                            count: _formatTimeAgo(hotspot.latestReportAt, context),
                            label: l10n.hotspotLatestReport(''),
                          ),
                        ],
                      ),
                    ),

                    // Summary
                    if (hotspot.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        hotspot.summary,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A4A4A),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Category Breakdown Chips
                    if (hotspot.categoryCounts.length > 1) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: hotspot.categoryCounts.entries.map((entry) {
                          return Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: const Color(0xFFF3E8EE),
                            label: Text(
                              '${entry.key}: ${entry.value}',
                              style: const TextStyle(fontSize: 11, color: _primary),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Reports List (masked privacy)
                    if (hotspot.reports.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 16, color: _primary),
                          const SizedBox(width: 6),
                          Text(
                            l10n.translate('communityReports'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...hotspot.reports.map((report) => _buildReportCard(report, context)),
                      const SizedBox(height: 14),
                    ],

                    // Community Comments
                    if (hotspot.comments.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.comment_outlined, size: 16, color: _primary),
                          const SizedBox(width: 6),
                          Text(
                            l10n.translate('communityComments'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...hotspot.comments.map((comment) => _buildCommentCard(comment, context)),
                      const SizedBox(height: 14),
                    ],

                    // Feedback Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.help_outline_rounded, size: 16, color: _primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.hotspotFeedbackTitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _primary,
                                      ),
                                    ),
                                    if (_confirmationsCount > 0 || _disputesCount > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '$_confirmationsCount verified • $_disputesCount disputed',
                                          style: const TextStyle(fontSize: 10, color: _onSurfaceVariant),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_isSubmittingFeedback)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                                ),
                              ),
                            )
                          else
                            Row(
                              children: [
                                // Still Present
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _submittedFeedbackType != null
                                        ? null
                                        : () => _submitFeedback('STILL_PRESENT'),
                                    icon: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 15,
                                      color: _submittedFeedbackType == 'STILL_PRESENT'
                                          ? Colors.white
                                          : const Color(0xFFC62828),
                                    ),
                                    label: Text(
                                      l10n.stillPresent,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _submittedFeedbackType == 'STILL_PRESENT'
                                            ? Colors.white
                                            : const Color(0xFFC62828),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _submittedFeedbackType == 'STILL_PRESENT'
                                          ? const Color(0xFFC62828)
                                          : Colors.transparent,
                                      side: const BorderSide(color: Color(0xFFEF9A9A)),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Resolved
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _submittedFeedbackType != null
                                        ? null
                                        : () => _submitFeedback('RESOLVED'),
                                    icon: Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 15,
                                      color: _submittedFeedbackType == 'RESOLVED'
                                          ? Colors.white
                                          : const Color(0xFF2E7D32),
                                    ),
                                    label: Text(
                                      l10n.markResolved,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _submittedFeedbackType == 'RESOLVED'
                                            ? Colors.white
                                            : const Color(0xFF2E7D32),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _submittedFeedbackType == 'RESOLVED'
                                          ? const Color(0xFF2E7D32)
                                          : Colors.transparent,
                                      side: const BorderSide(color: Color(0xFFA5D6A7)),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Inaccurate
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _submittedFeedbackType != null
                                        ? null
                                        : () => _submitFeedback('INACCURATE'),
                                    icon: Icon(
                                      Icons.flag_outlined,
                                      size: 15,
                                      color: _submittedFeedbackType == 'INACCURATE'
                                          ? Colors.white
                                          : const Color(0xFF455A64),
                                    ),
                                    label: Text(
                                      l10n.markInaccurate,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _submittedFeedbackType == 'INACCURATE'
                                            ? Colors.white
                                            : const Color(0xFF455A64),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _submittedFeedbackType == 'INACCURATE'
                                          ? const Color(0xFF455A64)
                                          : Colors.transparent,
                                      side: const BorderSide(color: Color(0xFFB0BEC5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mandatory Legal & Safety Disclaimer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF57F17)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.hotspotDisclaimer,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                color: Color(0xFF5D4037),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String count,
    required String label,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(height: 3),
          Text(
            count,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _onSurface,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: _onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(HotspotReportItem report, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                report.authorFullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _primary,
                ),
              ),
              Text(
                _formatTimeAgo(report.createdAt, context),
                style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (report.title.isNotEmpty)
            Text(
              report.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: _onSurface,
              ),
            ),
          if (report.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              report.description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A4A4A)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentCard(HotspotCommentItem comment, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment.authorName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _primary,
                ),
              ),
              Text(
                _formatTimeAgo(comment.createdAt, context),
                style: const TextStyle(fontSize: 10, color: _onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            comment.content,
            style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }
}
