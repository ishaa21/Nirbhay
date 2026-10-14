const db = require('../config/db');

/**
 * POST /api/sos/:id/location
 * Authenticated: Upload a new GPS coordinate for an active SOS incident.
 * Called by the Flutter app periodically while SOS is active.
 */
const uploadLocation = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;
  const { latitude, longitude, accuracy } = req.body;

  if (latitude === undefined || longitude === undefined) {
    return res.status(400).json({ message: 'latitude and longitude are required.' });
  }

  const lat = parseFloat(latitude);
  const lng = parseFloat(longitude);
  const acc = accuracy !== undefined ? parseFloat(accuracy) : null;

  if (isNaN(lat) || lat < -90 || lat > 90) {
    return res.status(400).json({ message: 'Invalid latitude value.' });
  }
  if (isNaN(lng) || lng < -180 || lng > 180) {
    return res.status(400).json({ message: 'Invalid longitude value.' });
  }

  try {
    // Verify incident belongs to user and is still ACTIVE
    const incidentRes = await db.query(
      `SELECT id, status FROM sos_incidents WHERE id = $1 AND user_id = $2`,
      [id, userId]
    );

    if (incidentRes.rows.length === 0) {
      return res.status(404).json({ message: 'SOS incident not found.' });
    }

    const incident = incidentRes.rows[0];
    if (incident.status !== 'ACTIVE') {
      return res.status(400).json({
        message: `Location update rejected — incident is already ${incident.status}.`,
      });
    }

    // Insert breadcrumb location record
    await db.query(
      `INSERT INTO sos_location_updates (sos_id, latitude, longitude, accuracy)
       VALUES ($1, $2, $3, $4)`,
      [id, lat, lng, acc]
    );

    // Also update the canonical lat/lng on the incident for tracking page fallback
    await db.query(
      `UPDATE sos_incidents SET latitude = $1, longitude = $2 WHERE id = $3`,
      [lat, lng, id]
    );

    return res.status(200).json({ success: true, message: 'Location update recorded.' });
  } catch (error) {
    console.error('[TRACKING] Error uploading location:', error);
    return res.status(500).json({ message: 'Failed to record location update.', error: error.message });
  }
};

/**
 * GET /api/sos/track/:token
 * Public (no JWT required): Returns the latest tracking data for the web tracking page.
 * Guardians open this via the link in the SOS SMS.
 */
const getTrackingData = async (req, res) => {
  const { token } = req.params;

  if (!token || token.length < 10) {
    return res.status(400).json({ message: 'Invalid tracking token.' });
  }

  try {
    // Fetch incident by tracking_token
    const incidentRes = await db.query(
      `SELECT i.id, i.status, i.latitude, i.longitude,
              i.activated_at, i.resolved_at, i.cancelled_at,
              u.full_name as user_name
       FROM sos_incidents i
       JOIN users u ON u.id = i.user_id
       WHERE i.tracking_token = $1`,
      [token]
    );

    if (incidentRes.rows.length === 0) {
      return res.status(404).json({
        message: 'This tracking link is invalid or has expired.',
      });
    }

    const incident = incidentRes.rows[0];

    // Fetch the latest breadcrumb location if available
    const locationRes = await db.query(
      `SELECT latitude, longitude, accuracy, recorded_at
       FROM sos_location_updates
       WHERE sos_id = $1
       ORDER BY recorded_at DESC
       LIMIT 1`,
      [incident.id]
    );

    const latestUpdate = locationRes.rows[0] || null;

    // Prefer the most recent breadcrumb; fall back to incident's canonical coords
    const lat = latestUpdate ? parseFloat(latestUpdate.latitude) : (incident.latitude ? parseFloat(incident.latitude) : null);
    const lng = latestUpdate ? parseFloat(latestUpdate.longitude) : (incident.longitude ? parseFloat(incident.longitude) : null);
    const lastUpdatedAt = latestUpdate ? latestUpdate.recorded_at : incident.activated_at;

    // Only expose first name for privacy
    const firstName = (incident.user_name || 'User').split(' ')[0];

    return res.status(200).json({
      active: incident.status === 'ACTIVE',
      status: incident.status,
      userName: firstName,
      latitude: lat,
      longitude: lng,
      accuracy: latestUpdate?.accuracy || null,
      lastUpdatedAt,
      activatedAt: incident.activated_at,
      resolvedAt: incident.resolved_at,
      cancelledAt: incident.cancelled_at,
    });
  } catch (error) {
    console.error('[TRACKING] Error fetching tracking data:', error);
    return res.status(500).json({ message: 'Failed to retrieve tracking data.', error: error.message });
  }
};

module.exports = { uploadLocation, getTrackingData };
