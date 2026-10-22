/**
 * nearbyRoutes.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Routes for Nearby Safety Services and Reverse Geocoding
 * Publicly accessible so emergency lookup and home-page locality work immediately.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const express = require('express');
const router = express.Router();
const nearbyController = require('../controllers/nearbyController');

// GET /api/nearby/reverse or GET /api/nearby-services/reverse
router.get('/reverse', nearbyController.reverseGeocode);

// GET /api/nearby or GET /api/nearby-services
router.get('/', nearbyController.getNearbyPlaces);

module.exports = router;
