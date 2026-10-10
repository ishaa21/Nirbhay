import 'package:flutter/foundation.dart';

class ApiConfig {
  // ─────────────────────────────────────────────────────────────────────────
  // Production backend deployed on Render (HTTPS — accessible from anywhere)
  // ─────────────────────────────────────────────────────────────────────────
  static const String _productionUrl = 'https://nirbhay-9d5i.onrender.com/api';

  // ─────────────────────────────────────────────────────────────────────────
  // Local development override:
  // - For Android Emulator: 'http://10.0.2.2:5000/api'
  // - For Physical Device (same Wi-Fi): 'http://10.107.175.106:5000/api'
  // - For Web/Windows: 'http://localhost:5000/api'
  // ─────────────────────────────────────────────────────────────────────────
  static const String _localDevUrl = 'http://10.0.2.2:5000/api';

  static String get baseUrl {
    if (kDebugMode && _localDevUrl.isNotEmpty) {
      return _localDevUrl;
    }
    return _productionUrl;
  }
}


