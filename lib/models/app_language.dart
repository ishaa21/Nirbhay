import 'package:flutter/material.dart';

/// Represents a supported language in Nirbhay.
class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String subtitle;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.subtitle,
  });

  Locale get locale => Locale(code, '');

  static const List<AppLanguage> supportedLanguages = [
    AppLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      subtitle: 'Default (International)',
    ),
    AppLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      subtitle: 'राष्ट्रीय भाषा (Devanagari)',
    ),
    AppLanguage(
      code: 'gu',
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      subtitle: 'પ્રાદેશિક ભાષા (Gujarati Script)',
    ),
  ];

  static AppLanguage fromCode(String? code) {
    if (code == null) return supportedLanguages.first;
    return supportedLanguages.firstWhere(
      (lang) => lang.code.toLowerCase() == code.toLowerCase(),
      orElse: () => supportedLanguages.first,
    );
  }
}
