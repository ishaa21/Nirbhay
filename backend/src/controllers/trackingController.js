const db = require('../config/db');

/**
 * Helper to validate a coordinate pair
 */
function validateCoord(lat, lng) {
  const latitude = parseFloat(lat);
  const longitude = parseFloat(lng);
  if (isNaN(latitude) || latitude < -90 || latitude > 90) {
    return { valid: false, error: 'Latitude must be a valid number between -90 and 90.' };
  }
  if (isNaN(longitude) || longitude < -180 || longitude > 180) {
    return { valid: false, error: 'Longitude must be a valid number between -180 and 180.' };
  }
  return { valid: true, latitude, longitude };
}

/**
 * Helper to parse and sanitize recorded_at timestamp
 */
function parseTimestamp(rawTs) {
  if (!rawTs) return new Date();
  const d = new Date(rawTs);
  if (isNaN(d.getTime())) return new Date();
  // Reject future timestamps more than 5 minutes ahead
  const fiveMinFromNow = Date.now() + 5 * 60 * 1000;
  if (d.getTime() > fiveMinFromNow) return new Date();
  return d;
}

/**
 * POST /api/sos/:id/location
 * Authenticated: Upload one or more GPS coordinates for an active SOS incident.
 * Supports single fix or batch { updates: [...] } for offline queue replay.
 */
const uploadLocation = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;

  try {
    // 1. Verify incident exists, belongs to user, and is still ACTIVE
    const incidentRes = await db.query(
      `SELECT id, status, latitude, longitude FROM sos_incidents WHERE id = $1 AND user_id = $2`,
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

    // 2. Normalize input items (single point or array in `updates`)
    let items = [];
    if (Array.isArray(req.body.updates) && req.body.updates.length > 0) {
      items = req.body.updates;
    } else if (req.body.latitude !== undefined && req.body.longitude !== undefined) {
      items = [req.body];
    } else {
      return res.status(400).json({
        message: 'latitude and longitude (or updates array) are required.',
      });
    }

    // Cap batch size to 50 for safety
    if (items.length > 50) {
      items = items.slice(items.length - 50);
    }

    // 3. Get latest recorded point to prevent duplicates and handle out-of-order updates
    const latestRes = await db.query(
      `SELECT latitude, longitude, recorded_at 
       FROM sos_location_updates 
       WHERE sos_id = $1 
       ORDER BY recorded_at DESC 
       LIMIT 1`,
      [id]
    );
    let latestRecordedAt = latestRes.rows.length > 0 ? new Date(latestRes.rows[0].recorded_at) : null;
    let latestLat = latestRes.rows.length > 0 ? parseFloat(latestRes.rows[0].latitude) : null;
    let latestLng = latestRes.rows.length > 0 ? parseFloat(latestRes.rows[0].longitude) : null;

    let insertedCount = 0;
    let mostRecentFix = null;
    let mostRecentFixTime = latestRecordedAt || new Date(0);

    for (const item of items) {
      const coordCheck = validateCoord(item.latitude, item.longitude);
      if (!coordCheck.valid) {
        // If single item, fail immediately with 400
        if (items.length === 1) {
          return res.status(400).json({ message: coordCheck.error });
        }
        continue;
      }

      const lat = coordCheck.latitude;
      const lng = coordCheck.longitude;
      const acc = item.accuracy !== undefined && item.accuracy !== null ? parseFloat(item.accuracy) : null;
      const cleanAcc = (acc !== null && !isNaN(acc) && acc >= 0) ? acc : null;
      const recTime = parseTimestamp(item.recorded_at || item.timestamp);

      // Duplicate suppression: if identical coords within 5 seconds of latest point, skip insert
      if (
        latestLat !== null &&
        latestLng !== null &&
        latestRecordedAt !== null &&
        Math.abs(lat - latestLat) < 0.00001 &&
        Math.abs(lng - latestLng) < 0.00001 &&
        Math.abs(recTime.getTime() - latestRecordedAt.getTime()) < 5000
      ) {
        continue;
      }

      await db.query(
        `INSERT INTO sos_location_updates (sos_id, latitude, longitude, accuracy, recorded_at)
         VALUES ($1, $2, $3, $4, $5)`,
        [id, lat, lng, cleanAcc, recTime]
      );
      insertedCount++;

      latestLat = lat;
      latestLng = lng;
      latestRecordedAt = recTime;

      // Track the newest coordinate timestamp for canonical update
      if (recTime.getTime() >= mostRecentFixTime.getTime()) {
        mostRecentFixTime = recTime;
        mostRecentFix = { lat, lng };
      }
    }

    // 4. Update canonical lat/lng on the incident only if we have a fix newer than what was stored
    if (mostRecentFix) {
      await db.query(
        `UPDATE sos_incidents 
         SET latitude = $1, longitude = $2, updated_at = CURRENT_TIMESTAMP 
         WHERE id = $3`,
        [mostRecentFix.lat, mostRecentFix.lng, id]
      );
    }

    return res.status(200).json({
      success: true,
      message: `Location update recorded (${insertedCount} points).`,
      inserted: insertedCount,
      canonical: mostRecentFix || null,
    });
  } catch (error) {
    console.error('[TRACKING] Error uploading location:', error);
    return res.status(500).json({
      message: 'Failed to record location update.',
      error: error.message,
    });
  }
};

/**
 * GET /api/sos/track/:token
 * Public (no JWT required): Returns the latest tracking data for the web tracking page.
 * Guardians open this via the link in the SOS SMS.
 */
const getTrackingData = async (req, res) => {
  const { token } = req.params;

  if (!token || typeof token !== 'string' || token.trim().length < 10) {
    return res.status(400).json({ message: 'Invalid or missing tracking token.' });
  }

  const cleanToken = token.trim();

  try {
    // Fetch incident by tracking_token
    const incidentRes = await db.query(
      `SELECT i.id, i.status, i.latitude, i.longitude,
              i.activated_at, i.resolved_at, i.cancelled_at,
              u.full_name as user_name
       FROM sos_incidents i
       JOIN users u ON u.id = i.user_id
       WHERE i.tracking_token = $1`,
      [cleanToken]
    );

    if (incidentRes.rows.length === 0) {
      return res.status(404).json({
        message: 'This tracking link is invalid, expired, or does not exist.',
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
    const lat = latestUpdate
      ? parseFloat(latestUpdate.latitude)
      : (incident.latitude ? parseFloat(incident.latitude) : null);
    const lng = latestUpdate
      ? parseFloat(latestUpdate.longitude)
      : (incident.longitude ? parseFloat(incident.longitude) : null);
    const lastUpdatedAt = latestUpdate ? latestUpdate.recorded_at : incident.activated_at;

    // Only expose first name for privacy
    const firstName = (incident.user_name || 'User').trim().split(' ')[0];

    const isStale = lastUpdatedAt
      ? (Date.now() - new Date(lastUpdatedAt).getTime()) > 60000
      : false;

    return res.status(200).json({
      active: incident.status === 'ACTIVE',
      status: incident.status,
      userName: firstName,
      latitude: lat,
      longitude: lng,
      accuracy: latestUpdate?.accuracy ? parseFloat(latestUpdate.accuracy) : null,
      lastUpdatedAt,
      activatedAt: incident.activated_at,
      resolvedAt: incident.resolved_at,
      cancelledAt: incident.cancelled_at,
      isStale,
    });
  } catch (error) {
    console.error('[TRACKING] Error fetching tracking data:', error);
    return res.status(500).json({
      message: 'Failed to retrieve tracking data.',
      error: error.message,
    });
  }
};

module.exports = { uploadLocation, getTrackingData };
