const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const authenticateToken = require('../middleware/authMiddleware');

// Protect all user routes with JWT middleware
router.use(authenticateToken);

// GET /api/users/me - Get logged-in user profile
router.get('/me', userController.getProfile);

// PUT /api/users/me - Update logged-in user profile
router.put('/me', userController.updateProfile);

module.exports = router;
