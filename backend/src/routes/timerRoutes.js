const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/authMiddleware');
const {
    createTimer,
    getActiveTimer,
    checkInTimer,
    cancelTimer,
    extendTimer,
    updateTimerLocation,
} = require('../controllers/timerController');

// All timer routes require authentication
router.use(authenticate);

// POST   /api/timer            — Start a new safety timer
router.post('/', createTimer);

// GET    /api/timer/active     — Get current active timer (if any)
router.get('/active', getActiveTimer);

// POST   /api/timer/:id/checkin  — Check in (mark safe, stop timer)
router.post('/:id/checkin', checkInTimer);

// POST   /api/timer/:id/cancel   — Cancel without alerting
router.post('/:id/cancel', cancelTimer);

// POST   /api/timer/:id/extend   — Extend expiry
router.post('/:id/extend', extendTimer);

// POST   /api/timer/:id/location — Update last known location
router.post('/:id/location', updateTimerLocation);

module.exports = router;
