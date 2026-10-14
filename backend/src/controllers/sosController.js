const db = require('../config/db');
const crypto = require('crypto');
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

    // 2. Generate a secure tracking token for guardian map link
    const trackingToken = crypto.randomBytes(24).toString('hex');

    // 3. Create new SOS incident
    const insertQuery = `
      INSERT INTO sos_incidents (user_id, status, latitude, longitude, activated_at, notification_status, tracking_token)
      VALUES ($1, 'ACTIVE', $2, $3, CURRENT_TIMESTAMP, 'PENDING', $4)
      RETURNING *
    `;
    const result = await db.query(insertQuery, [userId, cleanLat, cleanLng, trackingToken]);
    const newIncident = result.rows[0];

    // 4. Build tracking URL for guardians
    const backendBaseUrl = process.env.BACKEND_BASE_URL || 'https://nirbhay-9d5i.onrender.com';
    const trackingUrl = `${backendBaseUrl}/track/${trackingToken}`;

    // 5. Dispatch notifications asynchronously (or await notification dispatch)
    const notificationSummary = await sendSosAlerts({
      sosId: newIncident.id,
      userId,
      latitude: cleanLat,
      longitude: cleanLng,
      activatedAt: newIncident.activated_at,
      trackingUrl,
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
    const resolvedIncident = result.rows[0];

    // Dispatch "User is safe now" notification to emergency contacts
    const { sendSosResolvedAlerts } = require('../services/notificationService');
    const resolutionNotifications = await sendSosResolvedAlerts({
      sosId: id,
      userId,
      resolvedAt: resolvedIncident.resolved_at,
    });

    return res.status(200).json({
      message: 'SOS incident resolved successfully. Emergency contacts notified that you are safe now.',
      incident: resolvedIncident,
      notifications: resolutionNotifications,
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

/**
 * POST /api/sos/test-sms
 * Safe test endpoint to verify SMS Gateway connectivity
 */
const testSms = async (req, res) => {
  const userId = req.userId;
  const { phone, message } = req.body;

  try {
    const smsGateway = require('../services/smsGatewayService');
    const isConfigured = smsGateway.isGatewayConfigured();

    if (!isConfigured) {
      return res.status(400).json({
        success: false,
        status: 'NOT_CONFIGURED',
        errorCategory: 'CONFIGURATION_ERROR',
        message: 'SMS Gateway credentials (SMS_GATEWAY_LOGIN and SMS_GATEWAY_PASSWORD) are not configured in environment variables.',
      });
    }

    const isTestMode = process.env.SMS_TEST_MODE === 'true' || process.env.SMS_TEST_MODE === '1';
    const testPhoneNumber = process.env.SMS_TEST_PHONE_NUMBER;

    let targetPhone = phone;

    if (isTestMode) {
      // In safe test mode, strictly enforce dispatch ONLY to SMS_TEST_PHONE_NUMBER
      if (!testPhoneNumber) {
        return res.status(400).json({
          success: false,
          status: 'CONFIG_ERROR',
          errorCategory: 'CONFIGURATION_ERROR',
          message: 'SMS_TEST_MODE is true, but SMS_TEST_PHONE_NUMBER is not set in environment variables. Aborting test dispatch for safety.',
        });
      }
      targetPhone = testPhoneNumber;
    } else {
      // If test mode is not enabled, use passed phone or user profile phone
      if (!targetPhone) {
        const userRes = await db.query(`SELECT phone FROM users WHERE id = $1`, [userId]);
        if (userRes.rows.length > 0 && userRes.rows[0].phone) {
          targetPhone = userRes.rows[0].phone;
        }
      }
    }

    if (!targetPhone) {
      return res.status(400).json({
        success: false,
        status: 'MISSING_RECIPIENT',
        message: 'Recipient phone number is required. Provide "phone" in request body or configure SMS_TEST_PHONE_NUMBER.',
      });
    }

    const testMsg = message || `TEST ALERT: Safe connectivity test from Nirbhay Women Safety Application at ${new Date().toLocaleTimeString('en-IN')}. No emergency.`;

    const result = await smsGateway.sendSms({
      to: targetPhone,
      message: testMsg,
    });

    if (result.success) {
      // An accepted message enters state "Pending" on the gateway. Never describe as delivered.
      const initialStatus = result.state?.toUpperCase() === 'SENT' ? 'SENT' : 'PENDING';

      return res.status(200).json({
        success: true,
        status: initialStatus,
        delivered: false,
        testModeActive: isTestMode,
        recipient: smsGateway.maskPhone(targetPhone),
        messageId: result.messageId,
        message: 'Test SMS successfully accepted and enqueued on Android SMS Gateway.',
        note: 'The message is enqueued with the gateway (PENDING). Delivery occurs when the Android phone dispatches the SMS via SIM.',
      });
    } else {
      return res.status(502).json({
        success: false,
        status: 'FAILED',
        errorCategory: result.errorCategory || 'GATEWAY_ERROR',
        error: result.error,
        message: 'Failed to send test SMS via Android SMS Gateway.',
      });
    }
  } catch (error) {
    console.error('Error sending test SMS:', error);
    return res.status(500).json({
      success: false,
      status: 'SERVER_ERROR',
      message: 'Internal server error while sending test SMS.',
      error: error.message,
    });
  }
};

/**
 * GET /api/sos/gateway-status
 * Check SMS Gateway server reachability, credential validity, and registered Android devices
 */
const getGatewayStatus = async (req, res) => {
  try {
    const smsGateway = require('../services/smsGatewayService');
    const isConfigured = smsGateway.isGatewayConfigured();
    const isTestMode = process.env.SMS_TEST_MODE === 'true' || process.env.SMS_TEST_MODE === '1';
    const testPhone = process.env.SMS_TEST_PHONE_NUMBER;

    if (!isConfigured) {
      return res.status(200).json({
        gatewayConfigured: false,
        testModeActive: isTestMode,
        testPhoneNumber: smsGateway.maskPhone(testPhone),
        connectivity: 'NOT_CONFIGURED',
        message: 'SMS Gateway credentials are not configured in environment variables.',
      });
    }

    const probeResult = await smsGateway.checkGatewayDeviceRegistration();

    return res.status(200).json({
      gatewayConfigured: true,
      testModeActive: isTestMode,
      testPhoneNumber: smsGateway.maskPhone(testPhone),
      connectivity: probeResult.reachable && probeResult.authenticated ? 'CONNECTED' : 'ERROR',
      authenticated: probeResult.authenticated,
      devicesCount: probeResult.devices.length,
      devices: probeResult.devices,
      error: probeResult.error || null,
      errorCategory: probeResult.errorCategory || null,
    });
  } catch (error) {
    console.error('Error fetching gateway status:', error);
    return res.status(500).json({
      message: 'Failed to probe SMS Gateway status.',
      error: error.message,
    });
  }
};

/**
 * POST /api/sos/webhook/sms-gateway
 * Receive real-time message status updates (sms:sent, sms:delivered, sms:failed) from sms-gate.app
 */
const handleGatewayWebhook = async (req, res) => {
  try {
    const smsGateway = require('../services/smsGatewayService');
    const secret = process.env.SMS_GATEWAY_WEBHOOK_SECRET;

    // Verify webhook signature if secret configured
    if (secret) {
      const signature = req.headers['x-signature'];
      const timestamp = req.headers['x-timestamp'];
      const rawBody = JSON.stringify(req.body);

      const isValid = smsGateway.verifyWebhookSignature({
        rawBody,
        timestamp,
        signature,
        secret,
      });

      if (!isValid) {
        console.warn('[SMS_GATEWAY_AUTH_FAILURE] Rejected unauthorized webhook call with invalid HMAC signature.');
        return res.status(401).json({ message: 'Invalid webhook signature.' });
      }
    }

    console.log('[SMS_GATEWAY_WEBHOOK] Received event from SMS Gateway:', req.body.event, 'Msg ID:', req.body.payload?.messageId);
    const result = await smsGateway.processWebhookEvent(req.body);

    return res.status(200).json({
      received: true,
      result,
    });
  } catch (error) {
    console.error('[SMS_GATEWAY_WEBHOOK_ERROR]', error);
    return res.status(500).json({ error: error.message });
  }
};

/**
 * GET /api/sos/messages/:id
 * Query real-time message status and carrier error details from gateway
 */
const getMessageDetails = async (req, res) => {
  try {
    const { id } = req.params;
    const smsGateway = require('../services/smsGatewayService');
    const statusData = await smsGateway.getMessageStatus(id);
    return res.status(200).json({ messageId: id, statusData });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};

module.exports = {
  createSos,
  getActiveSos,
  getSosHistory,
  resolveSos,
  cancelSos,
  testSms,
  getGatewayStatus,
  getMessageDetails,
  handleGatewayWebhook,
};



