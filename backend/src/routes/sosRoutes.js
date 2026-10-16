const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/authMiddleware');
const {
  createSos,
  getActiveSos,
  getSosHistory,
  resolveSos,
  cancelSos,
  testSms,
  getGatewayStatus,
  getMessageDetails,
  handleGatewayWebhook,
  reportDeviceSmsResults,
} = require('../controllers/sosController');
const { uploadLocation, getTrackingData } = require('../controllers/trackingController');

// 1. Webhook endpoint for Android SMS Gateway delivery reports
// Uses cryptographic HMAC-SHA256 signature verification via X-Signature header instead of user JWT
router.post('/webhook/sms-gateway', handleGatewayWebhook);

// 2. Public live tracking data endpoint — no JWT needed (opened by guardians via SMS link)
router.get(['/track/:token', '/track/:token/'], getTrackingData);

// 2. All subsequent user SOS routes require JWT Authentication
router.use(authenticateToken);

// Create SOS Incident
router.post('/', createSos);

// Safe SMS Gateway test endpoint (strictly routes to SMS_TEST_PHONE_NUMBER when SMS_TEST_MODE=true)
router.post('/test-sms', testSms);

// Check SMS Gateway server connectivity and registered device status
router.get('/gateway-status', getGatewayStatus);

// Inspect real-time status of a specific message ID from the gateway
router.get('/messages/:id', getMessageDetails);

// Retrieve active SOS incident for authenticated user
router.get('/active', getActiveSos);

// Retrieve SOS incident history for authenticated user
router.get('/history', getSosHistory);

// Resolve an SOS incident
router.patch('/:id/resolve', resolveSos);

// Cancel an SOS incident
router.patch('/:id/cancel', cancelSos);

// Upload real-time GPS location for an active SOS incident (called by Flutter app periodically)
router.post('/:id/location', uploadLocation);

// Report direct Android SMS results (DEVICE dispatch mode)
router.post('/:id/device-sms/results', reportDeviceSmsResults);

module.exports = router;
