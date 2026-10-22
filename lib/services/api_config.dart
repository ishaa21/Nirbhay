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

  // ─────────────────────────────────────────────────────────────────────────
  // Map Provider Configuration (OpenFreeMap & OpenStreetMap)
  // ─────────────────────────────────────────────────────────────────────────
  /// OpenFreeMap vector MapLibre style URL (Liberty / Positron)
  static const String openFreeMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  /// OpenStreetMap standard raster tile template
  static const String mapRasterTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Fast high-availability raster tile alternative (CartoDB Voyager)
  static const String cartoRasterTileUrl = 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  /// Application identifier for OSM tile usage policy
  static const String mapUserAgentPackage = 'com.ishaa21.nirbhay';

  /// Mandatory legal attribution for OpenStreetMap data & tiles
  static const String mapAttribution = 'Data © OpenStreetMap contributors, ODbL 1.0';
}
