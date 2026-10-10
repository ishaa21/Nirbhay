const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/authMiddleware');
const {
  createSos,
  getActiveSos,
  getSosHistory,
  resolveSos,
  cancelSos,
} = require('../controllers/sosController');

// All SOS routes require JWT Authentication
router.use(authenticateToken);

// Create SOS Incident
router.post('/', createSos);

// Retrieve active SOS incident for authenticated user
router.get('/active', getActiveSos);

// Retrieve SOS incident history for authenticated user
router.get('/history', getSosHistory);

// Resolve an SOS incident
router.patch('/:id/resolve', resolveSos);

// Cancel an SOS incident
router.patch('/:id/cancel', cancelSos);

module.exports = router;
