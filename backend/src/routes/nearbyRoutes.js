/**
 * nearbyRoutes.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Routes for Nearby Safety Services
 * Publicly accessible so users and emergency callers can view nearby help immediately.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const express = require('express');
const router = express.Router();
const nearbyController = require('../controllers/nearbyController');

// GET /api/nearby or GET /api/nearby-services
router.get('/', nearbyController.getNearbyPlaces);

module.exports = router;
