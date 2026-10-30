import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/app_language.dart';
import '../services/language_service.dart';

class LanguageSelectionScreen extends StatelessWidget {
  final bool isModal;

  const LanguageSelectionScreen({super.key, this.isModal = false});

  static const Color _primary = Color(0xFF301427);
  static const Color _surface = Color(0xFFFCF8F9);
  static const Color _secondaryContainer = Color(0xFFF2D9E4);
  static const Color _onSurface = Color(0xFF1B1B1C);
  static const Color _onSurfaceVariant = Color(0xFF4E4449);
  static const Color _cardBorder = Color(0x1A301427);

  /// Helper to show as a bottom sheet modal from anywhere
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LanguageSelectionScreen(isModal: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final content = ValueListenableBuilder<Locale>(
      valueListenable: LanguageService().localeNotifier,
      builder: (context, currentLocale, _) {
        final currentCode = currentLocale.languageCode.toLowerCase();

        return Column(
          mainAxisSize: isModal ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isModal) ...[
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    const Icon(Icons.language_rounded, color: _primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.selectLanguage,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _onSurfaceVariant),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '${l10n.currentLanguage}: ${LanguageService().currentLanguage.nativeName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: AppLanguage.supportedLanguages.map((language) {
                  final isSelected = language.code.toLowerCase() == currentCode;
                  return _buildLanguageCard(context, language, isSelected, l10n);
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.offline_bolt_rounded, color: Colors.amber.shade800, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.offlineLanguageNotice,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isModal ? 24 : 32),
          ],
        );
      },
    );

    if (isModal) {
      return Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(top: false, child: content),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text(
          l10n.selectLanguage,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context,
    AppLanguage language,
    bool isSelected,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? _secondaryContainer.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _primary : _cardBorder,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? _primary.withOpacity(0.08) : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (!isSelected) {
              await LanguageService().setLanguage(language.code);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${language.nativeName} (${language.name}) ${l10n.languageChangedNotice}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: _primary,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Radio indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _primary : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? _primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                // Native name and English name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            language.nativeName,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? _primary : _onSurface,
                            ),
                          ),
                          if (language.code != 'en') ...[
                            const SizedBox(width: 8),
                            Text(
                              '(${language.name})',
                              style: TextStyle(
                                fontSize: 14,
                                color: _onSurfaceVariant.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active Badge
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.enabled,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
