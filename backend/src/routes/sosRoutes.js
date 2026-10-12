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
  handleGatewayWebhook,
} = require('../controllers/sosController');

// 1. Webhook endpoint for Android SMS Gateway delivery reports
// Uses cryptographic HMAC-SHA256 signature verification via X-Signature header instead of user JWT
router.post('/webhook/sms-gateway', handleGatewayWebhook);

// 2. All subsequent user SOS routes require JWT Authentication
router.use(authenticateToken);

// Create SOS Incident
router.post('/', createSos);

// Safe SMS Gateway test endpoint (strictly routes to SMS_TEST_PHONE_NUMBER when SMS_TEST_MODE=true)
router.post('/test-sms', testSms);

// Check SMS Gateway server connectivity and registered device status
router.get('/gateway-status', getGatewayStatus);

// Retrieve active SOS incident for authenticated user
router.get('/active', getActiveSos);

// Retrieve SOS incident history for authenticated user
router.get('/history', getSosHistory);

// Resolve an SOS incident
router.patch('/:id/resolve', resolveSos);

// Cancel an SOS incident
router.patch('/:id/cancel', cancelSos);

module.exports = router;
