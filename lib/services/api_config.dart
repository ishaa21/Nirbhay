import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Physical device testing: set to your PC's local IP address
  // Current LAN IP (updated): 10.142.35.163
  static const String _customBaseUrl = 'http://10.142.35.163:5000/api';

  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }

    try {
      if (Platform.isAndroid) {
        // Android Emulator maps host localhost to 10.0.2.2
        return 'http://10.0.2.2:5000/api';
      }
    } catch (e) {
      // Platform check may fail on non-supported platforms
    }

    return 'http://localhost:5000/api';
  }
}
