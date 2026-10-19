/**
 * nearbyController.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Controller for GET /api/nearby and GET /api/nearby-services
 * ─────────────────────────────────────────────────────────────────────────────
 */

const nearbyService = require('../services/nearbyPlacesService');

/**
 * GET /api/nearby
 * GET /api/nearby-services
 * 
 * Query params:
 *   - lat / latitude: number (-90 to 90) [required]
 *   - lng / longitude: number (-180 to 180) [required]
 *   - category: 'police' | 'hospital' | 'pharmacy' | 'fire_station' | 'all' [optional, default 'all']
 *   - radius: number in meters (500 to 20000) [optional, default 5000]
 *   - limit: number (1 to 50) [optional, default 20]
 */
async function getNearbyPlaces(req, res) {
  try {
    const lat = req.query.lat !== undefined ? req.query.lat : req.query.latitude;
    const lng = req.query.lng !== undefined ? req.query.lng : req.query.longitude;
    const category = req.query.category || 'all';
    const radius = req.query.radius || 5000;
    const limit = req.query.limit || 20;

    // Use client IP for rate limiting
    const clientIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip;

    const result = await nearbyService.getNearbyPlaces({
      latitude: lat,
      longitude: lng,
      category,
      radius,
      limit,
      clientIp,
    });

    return res.status(200).json(result);
  } catch (err) {
    const status = err.status || 500;
    // Log unexpected 500 errors only, without exposing sensitive internal stacks to client
    if (status >= 500) {
      console.error('[NEARBY_CONTROLLER_ERROR]', err.message);
    }

    return res.status(status).json({
      success: false,
      code: err.code || 'SERVER_ERROR',
      message: err.message || 'An error occurred while fetching nearby services.',
    });
  }
}

module.exports = {
  getNearbyPlaces,
};
