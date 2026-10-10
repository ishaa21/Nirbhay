const express = require('express');
const router = express.Router();
const contactController = require('../controllers/contactController');
const authenticateToken = require('../middleware/authMiddleware');

// Protect all emergency contact routes with JWT authentication middleware
router.use(authenticateToken);

// GET /api/contacts - List emergency contacts for authenticated user
router.get('/', contactController.getContacts);

// POST /api/contacts - Add a new emergency contact
router.post('/', contactController.addContact);

// PUT /api/contacts/:id - Update an emergency contact
router.put('/:id', contactController.updateContact);

// DELETE /api/contacts/:id - Delete an emergency contact
router.delete('/:id', contactController.deleteContact);

module.exports = router;
