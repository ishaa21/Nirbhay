import 'package:flutter_test/flutter_test.dart';
import 'package:nirbhay/utils/phone_normalizer.dart';

void main() {
  group('normalizePhoneNumber — Indian 10-digit numbers', () {
    test('normalizes Indian 10-digit mobile starting with 9', () {
      expect(normalizePhoneNumber('9876543210'), '+919876543210');
    });

    test('normalizes Indian 10-digit mobile starting with 8', () {
      expect(normalizePhoneNumber('8888888888'), '+918888888888');
    });

    test('normalizes Indian 10-digit mobile starting with 7', () {
      expect(normalizePhoneNumber('7777777777'), '+917777777777');
    });

    test('normalizes Indian 10-digit mobile starting with 6', () {
      expect(normalizePhoneNumber('6666666666'), '+916666666666');
    });
  });

  group('normalizePhoneNumber — Domestic leading-zero format', () {
    test('normalizes domestic 11-digit number with leading 0', () {
      expect(normalizePhoneNumber('09876543210'), '+919876543210');
    });
  });

  group('normalizePhoneNumber — International format', () {
    test('preserves E.164 with + prefix (US number)', () {
      expect(normalizePhoneNumber('+14155552671'), '+14155552671');
    });

    test('preserves E.164 with + prefix (Indian number already normalised)', () {
      expect(normalizePhoneNumber('+919876543210'), '+919876543210');
    });

    test('converts 00-prefixed international to +', () {
      expect(normalizePhoneNumber('00919876543210'), '+919876543210');
    });
  });

  group('normalizePhoneNumber — Whitespace and separator stripping', () {
    test('strips spaces from Indian number', () {
      expect(normalizePhoneNumber('98765 43210'), '+919876543210');
    });

    test('strips hyphens from Indian number', () {
      expect(normalizePhoneNumber('98765-43210'), '+919876543210');
    });

    test('strips mixed spaces and hyphens', () {
      expect(normalizePhoneNumber('987 654-3210'), '+919876543210');
    });
  });

  group('normalizePhoneNumber — Null / empty edge cases', () {
    test('returns empty string for null input', () {
      expect(normalizePhoneNumber(null), '');
    });

    test('returns empty string for whitespace-only input', () {
      expect(normalizePhoneNumber('   '), '');
    });

    test('returns empty string for empty string input', () {
      expect(normalizePhoneNumber(''), '');
    });
  });

  group('phoneForSmsDispatch', () {
    test('preserves normalised E.164 as-is (+ prefix kept)', () {
      expect(phoneForSmsDispatch('+919876543210'), '+919876543210');
    });

    test('preserves US number with + prefix', () {
      expect(phoneForSmsDispatch('+14155552671'), '+14155552671');
    });
  });
}
