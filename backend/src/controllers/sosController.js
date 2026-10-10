const db = require('../config/db');
const { sendSosAlerts } = require('../services/notificationService');

/**
 * Validate coordinates
 */
function validateCoordinates(latitude, longitude) {
  if (latitude !== undefined && latitude !== null && latitude !== '') {
    const lat = Number(latitude);
    if (isNaN(lat) || lat < -90 || lat > 90) {
      return 'Latitude must be a valid number between -90 and 90.';
    }
  }
  if (longitude !== undefined && longitude !== null && longitude !== '') {
    const lng = Number(longitude);
    if (isNaN(lng) || lng < -180 || lng > 180) {
      return 'Longitude must be a valid number between -180 and 180.';
    }
  }
  return null;
}

/**
 * POST /api/sos
 * Create an SOS incident for authenticated user
 */
const createSos = async (req, res) => {
  const userId = req.userId;
  const { latitude, longitude } = req.body;

  // Validate coordinates if provided
  const coordError = validateCoordinates(latitude, longitude);
  if (coordError) {
    return res.status(400).json({ message: coordError });
  }

  const cleanLat = (latitude !== undefined && latitude !== null && latitude !== '') ? Number(latitude) : null;
  const cleanLng = (longitude !== undefined && longitude !== null && longitude !== '') ? Number(longitude) : null;

  try {
    // 1. Check for existing active incident to prevent duplicates
    const activeCheck = await db.query(
      `SELECT * FROM sos_incidents WHERE user_id = $1 AND status = 'ACTIVE' LIMIT 1`,
      [userId]
    );

    if (activeCheck.rows.length > 0) {
      return res.status(409).json({
        message: 'An active SOS incident is already in progress.',
        code: 'ACTIVE_INCIDENT_EXISTS',
        incident: activeCheck.rows[0],
      });
    }

    // 2. Create new SOS incident
    const insertQuery = `
      INSERT INTO sos_incidents (user_id, status, latitude, longitude, activated_at, notification_status)
      VALUES ($1, 'ACTIVE', $2, $3, CURRENT_TIMESTAMP, 'PENDING')
      RETURNING *
    `;
    const result = await db.query(insertQuery, [userId, cleanLat, cleanLng]);
    const newIncident = result.rows[0];

    // 3. Dispatch notifications asynchronously (or await notification dispatch)
    const notificationSummary = await sendSosAlerts({
      sosId: newIncident.id,
      userId,
      latitude: cleanLat,
      longitude: cleanLng,
      activatedAt: newIncident.activated_at,
    });

    // Re-fetch updated incident to get final notification_status
    const updatedIncidentRes = await db.query(
      `SELECT * FROM sos_incidents WHERE id = $1`,
      [newIncident.id]
    );

    return res.status(201).json({
      message: 'SOS emergency incident activated successfully.',
      incident: updatedIncidentRes.rows[0] || newIncident,
      notifications: notificationSummary,
    });
  } catch (error) {
    console.error('Error creating SOS incident:', error);

    // Handle unique constraint violation from partial index idx_sos_incidents_user_active if concurrent request
    if (error.code === '23505') {
      return res.status(409).json({
        message: 'An active SOS incident is already in progress.',
        code: 'ACTIVE_INCIDENT_EXISTS',
      });
    }

    return res.status(500).json({
      message: 'Failed to create SOS incident.',
      error: error.message,
    });
  }
};

/**
 * GET /api/sos/active
 * Retrieve the authenticated user's active SOS incident
 */
const getActiveSos = async (req, res) => {
  const userId = req.userId;

  try {
    const result = await db.query(
      `SELECT * FROM sos_incidents WHERE user_id = $1 AND status = 'ACTIVE' LIMIT 1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(200).json({
        active: false,
        incident: null,
        notifications: [],
      });
    }

    const incident = result.rows[0];
    const notificationsRes = await db.query(
      `SELECT * FROM sos_notifications WHERE sos_id = $1 ORDER BY sent_at DESC`,
      [incident.id]
    );

    return res.status(200).json({
      active: true,
      incident,
      notifications: notificationsRes.rows,
    });
  } catch (error) {
    console.error('Error retrieving active SOS incident:', error);
    return res.status(500).json({
      message: 'Failed to retrieve active SOS incident.',
      error: error.message,
    });
  }
};

/**
 * GET /api/sos/history
 * Retrieve the authenticated user's SOS incident history
 */
const getSosHistory = async (req, res) => {
  const userId = req.userId;

  try {
    const result = await db.query(
      `SELECT i.*, 
              (SELECT COUNT(*) FROM sos_notifications n WHERE n.sos_id = i.id) as notification_count
       FROM sos_incidents i 
       WHERE i.user_id = $1 
       ORDER BY i.activated_at DESC`,
      [userId]
    );

    return res.status(200).json({
      count: result.rows.length,
      incidents: result.rows,
    });
  } catch (error) {
    console.error('Error retrieving SOS history:', error);
    return res.status(500).json({
      message: 'Failed to retrieve SOS history.',
      error: error.message,
    });
  }
};

/**
 * PATCH /api/sos/:id/resolve
 * Resolve an active SOS incident
 */
const resolveSos = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;

  try {
    // Check ownership and current status
    const existing = await db.query(
      `SELECT * FROM sos_incidents WHERE id = $1 AND user_id = $2`,
      [id, userId]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({
        message: 'SOS incident not found or you do not have permission to access it.',
      });
    }

    const incident = existing.rows[0];
    if (incident.status !== 'ACTIVE') {
      return res.status(400).json({
        message: `Incident cannot be resolved because it is currently in '${incident.status}' state.`,
      });
    }

    const updateQuery = `
      UPDATE sos_incidents 
      SET status = 'RESOLVED', resolved_at = CURRENT_TIMESTAMP
      WHERE id = $1 AND user_id = $2
      RETURNING *
    `;
    const result = await db.query(updateQuery, [id, userId]);

    return res.status(200).json({
      message: 'SOS incident resolved successfully.',
      incident: result.rows[0],
    });
  } catch (error) {
    console.error('Error resolving SOS incident:', error);
    return res.status(500).json({
      message: 'Failed to resolve SOS incident.',
      error: error.message,
    });
  }
};

/**
 * PATCH /api/sos/:id/cancel
 * Cancel an active SOS incident
 */
const cancelSos = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;

  try {
    // Check ownership and current status
    const existing = await db.query(
      `SELECT * FROM sos_incidents WHERE id = $1 AND user_id = $2`,
      [id, userId]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({
        message: 'SOS incident not found or you do not have permission to access it.',
      });
    }

    const incident = existing.rows[0];
    if (incident.status !== 'ACTIVE') {
      return res.status(400).json({
        message: `Incident cannot be cancelled because it is currently in '${incident.status}' state.`,
      });
    }

    const updateQuery = `
      UPDATE sos_incidents 
      SET status = 'CANCELLED', cancelled_at = CURRENT_TIMESTAMP
      WHERE id = $1 AND user_id = $2
      RETURNING *
    `;
    const result = await db.query(updateQuery, [id, userId]);

    return res.status(200).json({
      message: 'SOS incident cancelled successfully.',
      incident: result.rows[0],
    });
  } catch (error) {
    console.error('Error cancelling SOS incident:', error);
    return res.status(500).json({
      message: 'Failed to cancel SOS incident.',
      error: error.message,
    });
  }
};

module.exports = {
  createSos,
  getActiveSos,
  getSosHistory,
  resolveSos,
  cancelSos,
};
