const db = require('../config/db');
const { validateCreateContact, validateUpdateContact } = require('../validators/contactValidator');

/**
 * Format database row into clean JSON API response object
 */
const formatContact = (c) => ({
    id: c.id,
    userId: c.user_id,
    user_id: c.user_id,
    name: c.name,
    contactName: c.name,
    phone: c.phone,
    phoneNumber: c.phone,
    relationship: c.relationship || '',
    autoAlert: c.auto_alert,
    auto_alert: c.auto_alert,
    createdAt: c.created_at,
    created_at: c.created_at,
    updatedAt: c.updated_at,
    updated_at: c.updated_at,
});

/**
 * List all emergency contacts for authenticated user
 * GET /api/contacts
 */
const getContacts = async (req, res) => {
    try {
        const userId = req.userId;

        const result = await db.query(
            `SELECT id, user_id, name, phone, relationship, auto_alert, created_at, updated_at
       FROM emergency_contacts
       WHERE user_id = $1
       ORDER BY created_at ASC`,
            [userId]
        );

        const contacts = result.rows.map(formatContact);

        res.status(200).json({
            contacts,
            count: contacts.length,
        });
    } catch (error) {
        console.error('Get Contacts Error:', error.message);
        res.status(500).json({
            message: 'Server error while fetching emergency contacts.',
        });
    }
};

/**
 * Add a new emergency contact for authenticated user
 * POST /api/contacts
 */
const addContact = async (req, res) => {
    try {
        const userId = req.userId;
        const { isValid, errors, sanitized } = validateCreateContact(req.body);

        if (!isValid) {
            return res.status(400).json({
                message: errors[0],
                errors,
            });
        }

        const { name, phone, relationship, autoAlert } = sanitized;

        const result = await db.query(
            `INSERT INTO emergency_contacts (user_id, name, phone, relationship, auto_alert)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, user_id, name, phone, relationship, auto_alert, created_at, updated_at`,
            [userId, name, phone, relationship, autoAlert]
        );

        const newContact = formatContact(result.rows[0]);

        res.status(201).json({
            message: 'Emergency contact added successfully.',
            contact: newContact,
        });
    } catch (error) {
        console.error('Add Contact Error:', error.message);
        res.status(500).json({
            message: 'Server error while adding emergency contact.',
        });
    }
};

/**
 * Update an existing emergency contact
 * PUT /api/contacts/:id
 */
const updateContact = async (req, res) => {
    try {
        const userId = req.userId;
        const contactId = req.params.id;

        // Verify contact existence & user ownership
        const checkRes = await db.query(
            'SELECT * FROM emergency_contacts WHERE id = $1 AND user_id = $2',
            [contactId, userId]
        );

        if (checkRes.rows.length === 0) {
            return res.status(404).json({
                message: 'Emergency contact not found or access denied.',
            });
        }

        const { isValid, errors, sanitized } = validateUpdateContact(req.body);
        if (!isValid) {
            return res.status(400).json({
                message: errors[0],
                errors,
            });
        }

        const existing = checkRes.rows[0];
        const newName = sanitized.name !== undefined ? sanitized.name : existing.name;
        const newPhone = sanitized.phone !== undefined ? sanitized.phone : existing.phone;
        const newRelationship = sanitized.relationship !== undefined ? sanitized.relationship : existing.relationship;
        const newAutoAlert = sanitized.autoAlert !== undefined ? sanitized.autoAlert : existing.auto_alert;

        const updateRes = await db.query(
            `UPDATE emergency_contacts
       SET name = $1, phone = $2, relationship = $3, auto_alert = $4, updated_at = CURRENT_TIMESTAMP
       WHERE id = $5 AND user_id = $6
       RETURNING id, user_id, name, phone, relationship, auto_alert, created_at, updated_at`,
            [newName, newPhone, newRelationship, newAutoAlert, contactId, userId]
        );

        const updatedContact = formatContact(updateRes.rows[0]);

        res.status(200).json({
            message: 'Emergency contact updated successfully.',
            contact: updatedContact,
        });
    } catch (error) {
        console.error('Update Contact Error:', error.message);
        res.status(500).json({
            message: 'Server error while updating emergency contact.',
        });
    }
};

/**
 * Delete an emergency contact
 * DELETE /api/contacts/:id
 */
const deleteContact = async (req, res) => {
    try {
        const userId = req.userId;
        const contactId = req.params.id;

        // Enforce ownership directly in parameterized DELETE query
        const deleteRes = await db.query(
            'DELETE FROM emergency_contacts WHERE id = $1 AND user_id = $2 RETURNING id',
            [contactId, userId]
        );

        if (deleteRes.rows.length === 0) {
            return res.status(404).json({
                message: 'Emergency contact not found or access denied.',
            });
        }

        res.status(200).json({
            message: 'Emergency contact deleted successfully.',
            id: contactId,
        });
    } catch (error) {
        console.error('Delete Contact Error:', error.message);
        res.status(500).json({
            message: 'Server error while deleting emergency contact.',
        });
    }
};

module.exports = {
    getContacts,
    addContact,
    updateContact,
    deleteContact,
};
