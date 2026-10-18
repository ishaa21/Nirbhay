import 'package:flutter/foundation.dart';

class ApiConfig {
  // ─────────────────────────────────────────────────────────────────────────
  // Production backend deployed on Render (HTTPS — works on any network/device)
  // ─────────────────────────────────────────────────────────────────────────
  static const String _productionUrl = 'https://nirbhay-9d5i.onrender.com/api';

  // ─────────────────────────────────────────────────────────────────────────
  // Local development override (only used in debug builds when non-empty).
  // Set this to your PC's LAN IP if you need to test against a local server,
  // e.g. 'http://10.142.35.163:5000/api'. Leave empty for production.
  // ─────────────────────────────────────────────────────────────────────────
  static const String _localDevUrl = '';

  static String get baseUrl {
    // In debug mode, use local override if provided; otherwise use production.
    if (kDebugMode && _localDevUrl.isNotEmpty) {
      return _localDevUrl;
    }
    return _productionUrl;
  }

  /// Web origin for public tracking links (no /api suffix).
  static String get publicWebBaseUrl {
    final api = baseUrl;
    if (api.endsWith('/api')) {
      return api.substring(0, api.length - 4);
    }
    return api.replaceAll(RegExp(r'/api/?$'), '');
  }
}
