const crypto = require('crypto');
const db = require('../config/db');
const { sendSosAlerts } = require('../services/notificationService');

// ─────────────────────────────────────────────────────────────────────────────
// Helper: build a timer-expired alert message reusing notificationService format
// ─────────────────────────────────────────────────────────────────────────────
function buildTimerExpiredAlertMessage({ expiredAt, latitude, longitude, durationMinutes, trackingUrl }) {
    const timeStr = new Date(expiredAt || Date.now()).toLocaleString('en-IN', {
        timeZone: 'Asia/Kolkata',
        dateStyle: 'medium',
        timeStyle: 'medium',
    });

    let locationStr = 'Location: Unavailable';
    if (latitude !== null && latitude !== undefined && longitude !== null && longitude !== undefined) {
        const latNum = parseFloat(latitude);
        const lngNum = parseFloat(longitude);
        if (!isNaN(latNum) && !isNaN(lngNum)) {
            locationStr = `Location: https://maps.google.com/?q=${latNum},${lngNum} (${latNum.toFixed(4)}, ${lngNum.toFixed(4)})`;
        }
    }

    let trackingStr = '';
    if (trackingUrl) {
        trackingStr = ` Live Tracking: ${trackingUrl}`;
    }

    return `EMERGENCY ALERT: Nirbhay Safety Timer (${durationMinutes} min) expired at ${timeStr} without check-in. ${locationStr}.${trackingStr} Please check on this person immediately.`;
}

/**
 * POST /api/timer
 * Start a new safety timer for the authenticated user.
 */
const createTimer = async (req, res) => {
    const userId = req.userId;
    const { durationMinutes, latitude, longitude } = req.body;

    const duration = parseInt(durationMinutes, 10);

    if (isNaN(duration) || duration < 1 || duration > 1440) {
        return res.status(400).json({
            message: 'Invalid duration. Duration must be between 1 and 1440 minutes (up to 24 hours).',
        });
    }

    const cleanLat = (latitude !== undefined && latitude !== null && latitude !== '') ? Number(latitude) : null;
    const cleanLng = (longitude !== undefined && longitude !== null && longitude !== '') ? Number(longitude) : null;
    const locationAt = (cleanLat !== null && cleanLng !== null) ? new Date() : null;

    try {
        // Guard: one ACTIVE timer per user at a time
        const existing = await db.query(
            `SELECT id FROM safety_timers WHERE user_id = $1 AND status = 'ACTIVE' LIMIT 1`,
            [userId]
        );
        if (existing.rows.length > 0) {
            return res.status(409).json({
                message: 'An active safety timer already exists. Cancel or check in first.',
                code: 'TIMER_ALREADY_ACTIVE',
                timerId: existing.rows[0].id,
            });
        }

        const expiresAt = new Date(Date.now() + duration * 60 * 1000);

        const result = await db.query(
            `INSERT INTO safety_timers
         (user_id, duration_minutes, expires_at, latitude, longitude, location_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
            [userId, duration, expiresAt, cleanLat, cleanLng, locationAt]
        );

        return res.status(201).json({
            message: 'Safety timer started successfully.',
            timer: result.rows[0],
        });
    } catch (error) {
        if (error.code === '23505') {
            return res.status(409).json({
                message: 'An active safety timer already exists.',
                code: 'TIMER_ALREADY_ACTIVE',
            });
        }
        console.error('[TIMER] Error creating timer:', error);
        return res.status(500).json({ message: 'Failed to start safety timer.', error: error.message });
    }
};

/**
 * GET /api/timer/active
 * Retrieve the authenticated user's current active timer (if any).
 */
const getActiveTimer = async (req, res) => {
    const userId = req.userId;
    try {
        const result = await db.query(
            `SELECT * FROM safety_timers WHERE user_id = $1 AND status = 'ACTIVE' LIMIT 1`,
            [userId]
        );

        if (result.rows.length === 0) {
            return res.status(200).json({ active: false, timer: null });
        }

        const timer = result.rows[0];
        const now = new Date();
        const remainingMs = Math.max(0, new Date(timer.expires_at).getTime() - now.getTime());

        return res.status(200).json({
            active: true,
            timer,
            remainingMs,
        });
    } catch (error) {
        console.error('[TIMER] Error fetching active timer:', error);
        return res.status(500).json({ message: 'Failed to fetch active timer.', error: error.message });
    }
};

/**
 * POST /api/timer/:id/checkin
 * User checks in — marks the timer as CHECKED_IN (safe).
 */
const checkInTimer = async (req, res) => {
    const userId = req.userId;
    const { id } = req.params;

    try {
        const existing = await db.query(
            `SELECT * FROM safety_timers WHERE id = $1 AND user_id = $2`,
            [id, userId]
        );

        if (existing.rows.length === 0) {
            return res.status(404).json({ message: 'Timer not found or access denied.' });
        }

        const timer = existing.rows[0];
        if (timer.status !== 'ACTIVE') {
            return res.status(400).json({
                message: `Cannot check in. Timer is already in '${timer.status}' state.`,
            });
        }

        const result = await db.query(
            `UPDATE safety_timers
       SET status = 'CHECKED_IN', checked_in_at = CURRENT_TIMESTAMP
       WHERE id = $1 AND user_id = $2
       RETURNING *`,
            [id, userId]
        );

        return res.status(200).json({
            message: 'Check-in successful. You are marked safe.',
            timer: result.rows[0],
        });
    } catch (error) {
        console.error('[TIMER] Error during check-in:', error);
        return res.status(500).json({ message: 'Failed to check in.', error: error.message });
    }
};

/**
 * POST /api/timer/:id/cancel
 * Cancel an active timer without alerting anyone.
 */
const cancelTimer = async (req, res) => {
    const userId = req.userId;
    const { id } = req.params;

    try {
        const existing = await db.query(
            `SELECT * FROM safety_timers WHERE id = $1 AND user_id = $2`,
            [id, userId]
        );

        if (existing.rows.length === 0) {
            return res.status(404).json({ message: 'Timer not found or access denied.' });
        }

        const timer = existing.rows[0];
        if (timer.status !== 'ACTIVE') {
            return res.status(400).json({
                message: `Cannot cancel. Timer is already in '${timer.status}' state.`,
            });
        }

        const result = await db.query(
            `UPDATE safety_timers
       SET status = 'CANCELLED', cancelled_at = CURRENT_TIMESTAMP
       WHERE id = $1 AND user_id = $2
       RETURNING *`,
            [id, userId]
        );

        return res.status(200).json({
            message: 'Safety timer cancelled.',
            timer: result.rows[0],
        });
    } catch (error) {
        console.error('[TIMER] Error cancelling timer:', error);
        return res.status(500).json({ message: 'Failed to cancel timer.', error: error.message });
    }
};

/**
 * POST /api/timer/:id/extend
 * Extend an ACTIVE timer by an additional number of minutes.
 * Allowed extension values: 5, 15, 30, 60 minutes.
 */
const extendTimer = async (req, res) => {
    const userId = req.userId;
    const { id } = req.params;
    const { extendMinutes, latitude, longitude } = req.body;

    const extend = parseInt(extendMinutes, 10);

    if (isNaN(extend) || extend < 1 || extend > 1440) {
        return res.status(400).json({
            message: 'Invalid extension. Extension must be between 1 and 1440 minutes.',
        });
    }

    try {
        const existing = await db.query(
            `SELECT * FROM safety_timers WHERE id = $1 AND user_id = $2`,
            [id, userId]
        );

        if (existing.rows.length === 0) {
            return res.status(404).json({ message: 'Timer not found or access denied.' });
        }

        const timer = existing.rows[0];
        if (timer.status !== 'ACTIVE') {
            return res.status(400).json({
                message: `Cannot extend. Timer is already in '${timer.status}' state.`,
            });
        }

        const newExpiry = new Date(new Date(timer.expires_at).getTime() + extend * 60 * 1000);
        const newDuration = timer.duration_minutes + extend;

        const cleanLat = (latitude !== undefined && latitude !== null && latitude !== '') ? Number(latitude) : timer.latitude;
        const cleanLng = (longitude !== undefined && longitude !== null && longitude !== '') ? Number(longitude) : timer.longitude;
        const locationAt = (latitude !== undefined && longitude !== undefined) ? new Date() : timer.location_at;

        const result = await db.query(
            `UPDATE safety_timers
       SET expires_at = $1, duration_minutes = $2, latitude = $3, longitude = $4, location_at = $5
       WHERE id = $6 AND user_id = $7
       RETURNING *`,
            [newExpiry, newDuration, cleanLat, cleanLng, locationAt, id, userId]
        );

        return res.status(200).json({
            message: `Timer extended by ${extend} minutes.`,
            timer: result.rows[0],
        });
    } catch (error) {
        console.error('[TIMER] Error extending timer:', error);
        return res.status(500).json({ message: 'Failed to extend timer.', error: error.message });
    }
};

/**
 * POST /api/timer/:id/location
 * Update last known location for an ACTIVE timer.
 */
const updateTimerLocation = async (req, res) => {
    const userId = req.userId;
    const { id } = req.params;
    const { latitude, longitude } = req.body;

    const cleanLat = (latitude !== undefined && latitude !== null && latitude !== '') ? Number(latitude) : null;
    const cleanLng = (longitude !== undefined && longitude !== null && longitude !== '') ? Number(longitude) : null;

    if (cleanLat === null || cleanLng === null || isNaN(cleanLat) || isNaN(cleanLng)) {
        return res.status(400).json({ message: 'Valid latitude and longitude numbers are required.' });
    }

    try {
        const result = await db.query(
            `UPDATE safety_timers
       SET latitude = $1, longitude = $2, location_at = CURRENT_TIMESTAMP
       WHERE id = $3 AND user_id = $4 AND status = 'ACTIVE'
       RETURNING *`,
            [cleanLat, cleanLng, id, userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Active timer not found or access denied.' });
        }

        return res.status(200).json({
            message: 'Timer location updated successfully.',
            timer: result.rows[0],
        });
    } catch (error) {
        console.error('[TIMER] Error updating timer location:', error);
        return res.status(500).json({ message: 'Failed to update location.', error: error.message });
    }
};

/**
 * processExpiredTimers()
 * Called by the cron scheduler every 60 seconds (and on server boot).
 * Atomically claims expired timers (via alert_fired flag) and dispatches alerts.
 * Idempotent — safe to call concurrently or on server restart.
 */
const processExpiredTimers = async () => {
    try {
        // Atomic claim: set alert_fired = TRUE only for timers not yet processed.
        // The WHERE clause filters only ACTIVE + expired + not already fired.
        const claimResult = await db.query(
            `UPDATE safety_timers
       SET alert_fired = TRUE, status = 'EXPIRED', expired_at = CURRENT_TIMESTAMP
       WHERE status = 'ACTIVE'
         AND expires_at <= NOW()
         AND alert_fired = FALSE
       RETURNING *`
        );

        const expired = claimResult.rows;

        if (expired.length === 0) return 0;

        console.log(`[TIMER CRON] Processing ${expired.length} expired timer(s).`);

        for (const timer of expired) {
            try {
                console.log(`[TIMER CRON] Timer ${timer.id} for user ${timer.user_id} expired. Initiating emergency alert.`);
                await handleExpiredTimerAlert(timer);
            } catch (err) {
                console.error(`[TIMER CRON] Error processing timer ${timer.id}:`, err.message);
            }
        }
        return expired.length;
    } catch (err) {
        console.error('[TIMER CRON] Fatal error in processExpiredTimers:', err.message);
        return 0;
    }
};

/**
 * Internal: initiates emergency alert workflow for an expired safety timer.
 * Reuses existing sos_incidents model, notificationService (SMS Gateway + Twilio + safe test mode),
 * generates tracking link, and logs to sos_notifications.
 */
async function handleExpiredTimerAlert(timer) {
    const userId = timer.user_id;
    const cleanLat = timer.latitude ? Number(timer.latitude) : null;
    const cleanLng = timer.longitude ? Number(timer.longitude) : null;
    const backendBaseUrl = process.env.BACKEND_BASE_URL || 'https://nirbhay-9d5i.onrender.com';

    // 1. Check if user already has an active SOS incident to prevent duplicate violation of partial index
    let incident;
    const activeIncidentRes = await db.query(
        `SELECT * FROM sos_incidents WHERE user_id = $1 AND status = 'ACTIVE' LIMIT 1`,
        [userId]
    );

    if (activeIncidentRes.rows.length > 0) {
        incident = activeIncidentRes.rows[0];
        console.log(`[TIMER ALERT] User ${userId} already has active SOS incident ${incident.id}. Reusing.`);
    } else {
        // Create emergency SOS incident initiated by the Safety Timer
        const trackingToken = crypto.randomBytes(24).toString('hex');
        const insertQuery = `
            INSERT INTO sos_incidents (user_id, status, latitude, longitude, activated_at, notification_status, tracking_token)
            VALUES ($1, 'ACTIVE', $2, $3, $4, 'PENDING', $5)
            RETURNING *
        `;
        const result = await db.query(insertQuery, [
            userId,
            cleanLat,
            cleanLng,
            timer.expired_at || new Date(),
            trackingToken,
        ]);
        incident = result.rows[0];
        console.log(`[TIMER ALERT] Created emergency SOS incident ${incident.id} for expired timer ${timer.id}.`);
    }

    const trackingUrl = incident.tracking_token ? `${backendBaseUrl}/track/${incident.tracking_token}` : null;

    // 2. Format emergency alert message with timestamp, location, and tracking URL
    const alertMessage = buildTimerExpiredAlertMessage({
        expiredAt: timer.expired_at,
        latitude: cleanLat,
        longitude: cleanLng,
        durationMinutes: timer.duration_minutes,
        trackingUrl,
    });

    // 3. Dispatch alerts to emergency contacts using notificationService
    // Respects user consent (auto_alert = true), SMS_TEST_MODE, Android SMS Gateway / Twilio fallback,
    // and logs each delivery to sos_notifications.
    const alertSummary = await sendSosAlerts({
        sosId: incident.id,
        userId,
        latitude: cleanLat,
        longitude: cleanLng,
        activatedAt: timer.expired_at || incident.activated_at,
        trackingUrl,
        customMessage: alertMessage,
    });

    return alertSummary;
}

module.exports = {
    createTimer,
    getActiveTimer,
    checkInTimer,
    cancelTimer,
    extendTimer,
    updateTimerLocation,
    processExpiredTimers,
    handleExpiredTimerAlert,
    buildTimerExpiredAlertMessage,
};
