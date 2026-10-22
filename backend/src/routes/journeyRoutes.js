const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/authMiddleware');
const {
  startJourney,
  uploadJourneyLocation,
  getActiveJourney,
  endJourney,
  getJourneyBreadcrumbs,
  getJourneyHistory,
  updateDeviationAlarm,
  getJourneyTrackingData,
} = require('../controllers/journeyController');

// ── Public Endpoint (no JWT required) ────────────────────────────────────────
// Guardian-facing live tracking data for the sharing link
router.get(['/track/:token', '/track/:token/'], getJourneyTrackingData);

// ── Authenticated Endpoints ───────────────────────────────────────────────────
router.use(authenticateToken);

// Start a new journey session
router.post(['', '/'], startJourney);

// Get currently active journey
router.get(['/active', '/active/'], getActiveJourney);

// Get journey history
router.get(['/history', '/history/'], getJourneyHistory);

// Upload a GPS breadcrumb for an active journey
router.post(['/:id/location', '/:id/location/'], uploadJourneyLocation);

// End (complete or cancel) a journey - supports both PATCH and POST
router.patch(['/:id/end', '/:id/end/'], endJourney);
router.post(['/:id/end', '/:id/end/'], endJourney);

// Fetch location history / breadcrumbs for a journey
router.get(['/:id/breadcrumbs', '/:id/breadcrumbs/'], getJourneyBreadcrumbs);

// Toggle route deviation alarm
router.patch(['/:id/deviation-alarm', '/:id/deviation-alarm/'], updateDeviationAlarm);

module.exports = router;
