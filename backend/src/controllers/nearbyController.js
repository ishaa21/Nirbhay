/**
 * nearbyController.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Controller for GET /api/nearby and GET /api/nearby/reverse
 * ─────────────────────────────────────────────────────────────────────────────
 */

const nearbyService = require('../services/nearbyPlacesService');

/**
 * GET /api/nearby
 * GET /api/nearby-services
 */
async function getNearbyPlaces(req, res) {
  try {
    const lat = req.query.lat !== undefined ? req.query.lat : req.query.latitude;
    const lng = req.query.lng !== undefined ? req.query.lng : req.query.longitude;
    const category = req.query.category || 'all';
    const radius = req.query.radius || 5000;
    const limit = req.query.limit || 20;

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

/**
 * GET /api/nearby/reverse
 * GET /api/nearby-services/reverse
 * 
 * Query params:
 *   - lat / latitude: number (-90 to 90) [required]
 *   - lng / longitude: number (-180 to 180) [required]
 */
async function reverseGeocode(req, res) {
  try {
    const lat = req.query.lat !== undefined ? req.query.lat : req.query.latitude;
    const lng = req.query.lng !== undefined ? req.query.lng : req.query.longitude;

    const clientIp = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip;

    const result = await nearbyService.reverseGeocode({
      latitude: lat,
      longitude: lng,
      clientIp,
    });

    return res.status(200).json(result);
  } catch (err) {
    const status = err.status || 500;
    if (status >= 500) {
      console.error('[REVERSE_GEOCODE_ERROR]', err.message);
    }

    return res.status(status).json({
      success: false,
      code: err.code || 'SERVER_ERROR',
      message: err.message || 'Unable to reverse geocode location.',
    });
  }
}

module.exports = {
  getNearbyPlaces,
  reverseGeocode,
};
