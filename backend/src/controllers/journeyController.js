const db = require('../config/db');
const {
  buildJourneyStartedMessage,
  buildJourneyEndedMessage,
  buildJourneyDeviationMessage,
  sendAlertsToUserContacts,
} = require('../services/notificationService');
const crypto = require('crypto');

const DEVIATION_ALERT_COOLDOWN_MS = 15 * 60 * 1000;

/**
 * POST /api/journey/start
 * Start a live journey sharing session.
 * Creates a journey record and notifies guardians with a live tracking link.
 */
const startJourney = async (req, res) => {
  const userId = req.userId;
  const { latitude, longitude, destination, routeDeviationEnabled = true, deviationThresholdMeters = 150 } = req.body;

  try {
    const existing = await db.query(
      `SELECT id FROM journeys WHERE user_id = $1 AND status = 'ACTIVE' LIMIT 1`,
      [userId]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({
        success: false,
        code: 'ACTIVE_JOURNEY_EXISTS',
        message: 'A journey is already active.',
        journeyId: existing.rows[0].id,
      });
    }

    const trackingToken = crypto.randomBytes(24).toString('hex');
    const backendBaseUrl = process.env.BACKEND_BASE_URL || 'https://nirbhay-9d5i.onrender.com';
    const trackingUrl = `${backendBaseUrl}/track/${trackingToken}`;

    const result = await db.query(
      `INSERT INTO journeys
         (user_id, status, start_latitude, start_longitude, destination,
          tracking_token, tracking_url,
          route_deviation_enabled, deviation_threshold_meters, started_at)
       VALUES ($1, 'ACTIVE', $2, $3, $4, $5, $6, $7, $8, NOW())
       RETURNING *`,
      [userId, latitude || null, longitude || null, destination || null,
        trackingToken, trackingUrl,
        routeDeviationEnabled, deviationThresholdMeters]
    );

    const journey = result.rows[0];

    const userRes = await db.query(`SELECT full_name FROM users WHERE id = $1`, [userId]);
    const firstName = (userRes.rows[0]?.full_name || 'User').split(' ')[0];
    const smsBody = buildJourneyStartedMessage({
      userName: firstName,
      trackingUrl,
      destination: destination || null,
      startedAt: journey.started_at,
    });
    const notifications = await sendAlertsToUserContacts({ userId, messageBody: smsBody });

    return res.status(201).json({
      success: true,
      message: 'Journey started. Live tracking is active. Guardians notified via SMS.',
      journey,
      trackingUrl,
      notifications,
    });
  } catch (err) {
    console.error('[JOURNEY] Error starting journey:', err);
    return res.status(500).json({ success: false, message: 'Failed to start journey.', error: err.message });
  }
};

/**
 * POST /api/journey/:id/location
 * Upload a GPS location breadcrumb for an active journey.
 * Also checks for route deviation if enabled.
 */
const uploadJourneyLocation = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;
  const { latitude, longitude, accuracy, speed, heading } = req.body;

  if (latitude === undefined || longitude === undefined) {
    return res.status(400).json({ message: 'latitude and longitude are required.' });
  }

  const lat = parseFloat(latitude);
  const lng = parseFloat(longitude);
  const acc = accuracy !== undefined ? parseFloat(accuracy) : null;
  const spd = speed !== undefined ? parseFloat(speed) : null;
  const hdg = heading !== undefined ? parseFloat(heading) : null;

  if (isNaN(lat) || lat < -90 || lat > 90 || isNaN(lng) || lng < -180 || lng > 180) {
    return res.status(400).json({ message: 'Invalid coordinates.' });
  }

  try {
    let journeyRes;
    try {
      journeyRes = await db.query(
        `SELECT j.id, j.status, j.user_id, j.tracking_url,
                j.route_deviation_enabled, j.deviation_threshold_meters,
                j.start_latitude, j.start_longitude,
                j.last_deviation_alert_at,
                u.full_name AS user_name
         FROM journeys j
         JOIN users u ON u.id = j.user_id
         WHERE j.id = $1 AND j.user_id = $2`,
        [id, userId]
      );
    } catch (colErr) {
      if (!String(colErr.message).includes('last_deviation_alert_at')) throw colErr;
      journeyRes = await db.query(
        `SELECT j.id, j.status, j.user_id, j.tracking_url,
                j.route_deviation_enabled, j.deviation_threshold_meters,
                j.start_latitude, j.start_longitude,
                NULL::timestamptz AS last_deviation_alert_at,
                u.full_name AS user_name
         FROM journeys j
         JOIN users u ON u.id = j.user_id
         WHERE j.id = $1 AND j.user_id = $2`,
        [id, userId]
      );
    }

    if (journeyRes.rows.length === 0) {
      return res.status(404).json({ message: 'Journey not found.' });
    }
    const journey = journeyRes.rows[0];
    if (journey.status !== 'ACTIVE') {
      return res.status(400).json({ message: `Journey is already ${journey.status}.` });
    }

    // Backfill start coordinates on first fix if journey started without GPS
    if (journey.start_latitude == null || journey.start_longitude == null) {
      await db.query(
        `UPDATE journeys SET start_latitude = $1, start_longitude = $2 WHERE id = $3`,
        [lat, lng, id]
      );
      journey.start_latitude = lat;
      journey.start_longitude = lng;
    }

    const prevLocRes = await db.query(
      `SELECT latitude, longitude FROM journey_locations
       WHERE journey_id = $1 ORDER BY recorded_at DESC LIMIT 1`,
      [id]
    );
    const prevLoc = prevLocRes.rows[0] || null;

    await db.query(
      `INSERT INTO journey_locations (journey_id, latitude, longitude, accuracy, speed, heading)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [id, lat, lng, acc, spd, hdg]
    );

    await db.query(
      `UPDATE journeys SET last_known_latitude = $1, last_known_longitude = $2, last_updated_at = NOW()
       WHERE id = $3`,
      [lat, lng, id]
    );

    let deviationDetected = false;
    let deviationDistance = null;
    let deviationAlertSent = false;

    if (journey.route_deviation_enabled && journey.start_latitude != null && journey.start_longitude != null) {
      const threshold = journey.deviation_threshold_meters || 150;
      const startLat = parseFloat(journey.start_latitude);
      const startLng = parseFloat(journey.start_longitude);

      const lateralDist = prevLoc
        ? pointToSegmentDistanceMeters(
          lat, lng,
          startLat, startLng,
          parseFloat(prevLoc.latitude), parseFloat(prevLoc.longitude)
        )
        : 0;
      deviationDistance = Math.round(lateralDist);

      if (lateralDist > threshold && prevLoc) {
        deviationDetected = true;

        const lastAlert = journey.last_deviation_alert_at
          ? new Date(journey.last_deviation_alert_at).getTime()
          : 0;
        const cooldownOk = Date.now() - lastAlert >= DEVIATION_ALERT_COOLDOWN_MS;

        if (cooldownOk) {
          const firstName = (journey.user_name || 'User').split(' ')[0];
          const smsBody = buildJourneyDeviationMessage({
            userName: firstName,
            latitude: lat,
            longitude: lng,
            trackingUrl: journey.tracking_url,
            distanceMeters: lateralDist,
          });
          const notif = await sendAlertsToUserContacts({ userId, messageBody: smsBody });
          deviationAlertSent = notif.sentCount + notif.pendingCount > 0;
          if (deviationAlertSent || notif.status !== 'NO_CONTACTS') {
            try {
              await db.query(
                `UPDATE journeys SET last_deviation_alert_at = NOW() WHERE id = $1`,
                [id]
              );
            } catch (updErr) {
              if (!String(updErr.message).includes('last_deviation_alert_at')) throw updErr;
            }
          }
          console.log(`[JOURNEY] Route deviation alert for journey ${id}: ~${lateralDist.toFixed(0)}m (SMS: ${notif.status})`);
        }
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Location updated.',
      deviationDetected,
      deviationDistance,
      deviationAlertSent,
    });
  } catch (err) {
    console.error('[JOURNEY] Error uploading location:', err);
    return res.status(500).json({ success: false, message: 'Failed to update location.', error: err.message });
  }
};

/**
 * GET /api/journey/active
 */
const getActiveJourney = async (req, res) => {
  const userId = req.userId;
  try {
    const result = await db.query(
      `SELECT j.*,
              (SELECT row_to_json(l) FROM (
                SELECT latitude, longitude, accuracy, speed, recorded_at
                FROM journey_locations WHERE journey_id = j.id
                ORDER BY recorded_at DESC LIMIT 1
              ) l) AS latest_location,
              (SELECT COUNT(*) FROM journey_locations WHERE journey_id = j.id) AS breadcrumb_count
       FROM journeys j
       WHERE j.user_id = $1 AND j.status = 'ACTIVE'
       LIMIT 1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(200).json({ active: false, journey: null });
    }

    const journey = result.rows[0];
    const startedAt = new Date(journey.started_at);
    const hoursElapsed = (Date.now() - startedAt.getTime()) / (1000 * 60 * 60);

    // If journey has been open for > 24 hours, auto-expire it
    if (hoursElapsed > 24) {
      try {
        await db.query(
          `UPDATE journeys SET status = 'EXPIRED', ended_at = NOW(), end_reason = 'AUTO_EXPIRED' WHERE id = $1`,
          [journey.id]
        );
      } catch (_) {}
      return res.status(200).json({ active: false, journey: null });
    }

    return res.status(200).json({ active: true, journey });
  } catch (err) {
    console.error('[JOURNEY] Error fetching active journey:', err);
    return res.status(500).json({ success: false, message: 'Failed to fetch journey.', error: err.message });
  }
};

/**
 * PATCH /api/journey/:id/end
 */
const endJourney = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;
  const { reason = 'COMPLETED' } = req.body;

  try {
    const existing = await db.query(
      `SELECT id, status FROM journeys WHERE id = $1 AND user_id = $2`,
      [id, userId]
    );
    if (existing.rows.length === 0) {
      return res.status(404).json({ message: 'Journey not found.' });
    }
    if (existing.rows[0].status !== 'ACTIVE') {
      return res.status(400).json({ message: `Journey is already ${existing.rows[0].status}.` });
    }

    const finalStatus = reason === 'CANCELLED' ? 'CANCELLED' : 'COMPLETED';

    const updated = await db.query(
      `UPDATE journeys SET status = $1, ended_at = NOW() WHERE id = $2 RETURNING *`,
      [finalStatus, id]
    );

    let notifications = null;
    if (finalStatus === 'COMPLETED') {
      const userRes = await db.query(`SELECT full_name FROM users WHERE id = $1`, [userId]);
      const firstName = (userRes.rows[0]?.full_name || 'User').split(' ')[0];
      const smsBody = buildJourneyEndedMessage({
        userName: firstName,
        resolvedAt: updated.rows[0].ended_at,
      });
      notifications = await sendAlertsToUserContacts({ userId, messageBody: smsBody });
    }

    return res.status(200).json({
      success: true,
      message: `Journey ${finalStatus.toLowerCase()} successfully.`,
      journey: updated.rows[0],
      notifications,
    });
  } catch (err) {
    console.error('[JOURNEY] Error ending journey:', err);
    return res.status(500).json({ success: false, message: 'Failed to end journey.', error: err.message });
  }
};

const getJourneyBreadcrumbs = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;
  const limit = Math.min(parseInt(req.query.limit || '200', 10), 500);

  try {
    const ownerRes = await db.query(`SELECT id FROM journeys WHERE id = $1 AND user_id = $2`, [id, userId]);
    if (ownerRes.rows.length === 0) {
      return res.status(404).json({ message: 'Journey not found.' });
    }

    const locs = await db.query(
      `SELECT latitude, longitude, accuracy, speed, heading, recorded_at
       FROM journey_locations WHERE journey_id = $1
       ORDER BY recorded_at DESC LIMIT $2`,
      [id, limit]
    );

    return res.status(200).json({ journeyId: id, count: locs.rows.length, breadcrumbs: locs.rows });
  } catch (err) {
    console.error('[JOURNEY] Error fetching breadcrumbs:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
};

const getJourneyHistory = async (req, res) => {
  const userId = req.userId;
  try {
    const result = await db.query(
      `SELECT id, status, destination, tracking_url, started_at, ended_at,
              start_latitude, start_longitude, last_known_latitude, last_known_longitude,
              (SELECT COUNT(*) FROM journey_locations jl WHERE jl.journey_id = j.id) AS breadcrumb_count
       FROM journeys j
       WHERE user_id = $1
       ORDER BY started_at DESC
       LIMIT 50`,
      [userId]
    );
    return res.status(200).json({ count: result.rows.length, journeys: result.rows });
  } catch (err) {
    console.error('[JOURNEY] Error fetching journey history:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
};

const updateDeviationAlarm = async (req, res) => {
  const userId = req.userId;
  const { id } = req.params;
  const { enabled, thresholdMeters } = req.body;

  try {
    const result = await db.query(
      `UPDATE journeys
       SET route_deviation_enabled = COALESCE($1, route_deviation_enabled),
           deviation_threshold_meters = COALESCE($2, deviation_threshold_meters)
       WHERE id = $3 AND user_id = $4 AND status = 'ACTIVE'
       RETURNING id, route_deviation_enabled, deviation_threshold_meters`,
      [enabled !== undefined ? enabled : null, thresholdMeters || null, id, userId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Active journey not found.' });
    }
    return res.status(200).json({ success: true, ...result.rows[0] });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
};

/**
 * GET /api/journey/track/:token  (Public — no auth)
 */
const getJourneyTrackingData = async (req, res) => {
  const { token } = req.params;
  if (!token || token.length < 10) {
    return res.status(400).json({ message: 'Invalid tracking token.' });
  }

  try {
    const journeyRes = await db.query(
      `SELECT j.id, j.status, j.destination, j.started_at, j.ended_at,
              j.last_known_latitude, j.last_known_longitude, j.last_updated_at,
              u.full_name AS user_name
       FROM journeys j
       JOIN users u ON u.id = j.user_id
       WHERE j.tracking_token = $1`,
      [token]
    );

    if (journeyRes.rows.length === 0) {
      return res.status(404).json({ message: 'Tracking link is invalid or expired.' });
    }

    const journey = journeyRes.rows[0];

    const latestLocRes = await db.query(
      `SELECT latitude, longitude, accuracy, speed, recorded_at
       FROM journey_locations WHERE journey_id = $1
       ORDER BY recorded_at DESC LIMIT 1`,
      [journey.id]
    );

    const latestLoc = latestLocRes.rows[0] || null;
    const lat = latestLoc ? parseFloat(latestLoc.latitude) : (journey.last_known_latitude ? parseFloat(journey.last_known_latitude) : null);
    const lng = latestLoc ? parseFloat(latestLoc.longitude) : (journey.last_known_longitude ? parseFloat(journey.last_known_longitude) : null);

    return res.status(200).json({
      active: journey.status === 'ACTIVE',
      status: journey.status,
      userName: (journey.user_name || 'User').split(' ')[0],
      destination: journey.destination,
      latitude: lat,
      longitude: lng,
      accuracy: latestLoc?.accuracy || null,
      speed: latestLoc?.speed || null,
      lastUpdatedAt: latestLoc?.recorded_at || journey.last_updated_at,
      startedAt: journey.started_at,
      endedAt: journey.ended_at,
      activatedAt: journey.started_at,
      resolvedAt: journey.ended_at,
    });
  } catch (err) {
    console.error('[JOURNEY] Error fetching tracking data:', err);
    return res.status(500).json({ message: 'Failed to retrieve tracking data.', error: err.message });
  }
};

function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

/**
 * Perpendicular distance from point P to segment AB (meters), using equirectangular projection.
 */
function pointToSegmentDistanceMeters(pLat, pLon, aLat, aLon, bLat, bLon) {
  const lat0 = toRad((aLat + bLat + pLat) / 3);
  const cosLat = Math.cos(lat0);

  const px = toRad(pLon) * cosLat * 6371000;
  const py = toRad(pLat) * 6371000;
  const ax = toRad(aLon) * cosLat * 6371000;
  const ay = toRad(aLat) * 6371000;
  const bx = toRad(bLon) * cosLat * 6371000;
  const by = toRad(bLat) * 6371000;

  const abx = bx - ax;
  const aby = by - ay;
  const apx = px - ax;
  const apy = py - ay;
  const abLenSq = abx * abx + aby * aby;

  if (abLenSq < 1) {
    return haversineMeters(pLat, pLon, aLat, aLon);
  }

  let t = (apx * abx + apy * aby) / abLenSq;
  t = Math.max(0, Math.min(1, t));
  const cx = ax + t * abx;
  const cy = ay + t * aby;
  const dx = px - cx;
  const dy = py - cy;
  return Math.sqrt(dx * dx + dy * dy);
}

module.exports = {
  startJourney,
  uploadJourneyLocation,
  getActiveJourney,
  endJourney,
  getJourneyBreadcrumbs,
  getJourneyHistory,
  updateDeviationAlarm,
  getJourneyTrackingData,
};
