const crypto = require('crypto');
const db = require('../config/db');

/**
 * Mask sensitive phone number for logs (e.g., +919876543210 -> +91******3210)
 */
function maskPhone(phone) {
  if (!phone || typeof phone !== 'string') return 'N/A';
  return phone.replace(/(\+?\d{2,4})\d+(\d{4})/, '$1******$2');
}

/**
 * Mask general sensitive string
 */
function maskString(str) {
  if (!str || typeof str !== 'string') return 'N/A';
  if (str.length <= 4) return '****';
  return str.slice(0, 2) + '****' + str.slice(-2);
}

/**
 * Standardize and clean phone numbers, formatting Indian numbers to international E.164.
 * e.g., '9876543210' -> '+919876543210', '09876543210' -> '+919876543210'
 */
function normalizePhoneNumber(rawPhone) {
  if (!rawPhone || typeof rawPhone !== 'string') return '';
  
  // Remove spaces, hyphens, parentheses
  let cleaned = rawPhone.replace(/[\s\-\(\)]/g, '').trim();

  // If already in international format starting with +
  if (cleaned.startsWith('+')) {
    return cleaned;
  }

  // If starts with 00 (international prefix)
  if (cleaned.startsWith('00')) {
    return '+' + cleaned.slice(2);
  }

  // If 11 digits starting with 0 (common domestic notation in India)
  if (cleaned.length === 11 && cleaned.startsWith('0')) {
    return '+91' + cleaned.slice(1);
  }

  // If standard 10-digit Indian mobile number
  if (cleaned.length === 10 && /^[6-9]\d{9}$/.test(cleaned)) {
    return '+91' + cleaned;
  }

  // Fallback: prepend + if only digits
  return cleaned.startsWith('+') ? cleaned : `+${cleaned}`;
}

/**
 * Check if the Android SMS Gateway is configured in environment variables.
 */
function isGatewayConfigured() {
  const login = process.env.SMS_GATEWAY_LOGIN || process.env.SMS_GATEWAY_USERNAME;
  const password = process.env.SMS_GATEWAY_PASSWORD;
  return Boolean(login && password);
}

/**
 * Verify whether the gateway server is reachable and inspect registered Android devices
 * Endpoint: GET https://api.sms-gate.app/3rdparty/v1/devices
 * 
 * @returns {Promise<{reachable: boolean, authenticated: boolean, devices: Array, error?: string, errorCategory?: string}>}
 */
async function checkGatewayDeviceRegistration() {
  const login = process.env.SMS_GATEWAY_LOGIN || process.env.SMS_GATEWAY_USERNAME;
  const password = process.env.SMS_GATEWAY_PASSWORD;

  if (!login || !password) {
    console.warn('[SMS_GATEWAY_CONFIG_ERROR] Cannot probe devices: SMS_GATEWAY_LOGIN / SMS_GATEWAY_PASSWORD missing.');
    return {
      reachable: false,
      authenticated: false,
      devices: [],
      errorCategory: 'CONFIGURATION_ERROR',
      error: 'SMS Gateway credentials (SMS_GATEWAY_LOGIN and SMS_GATEWAY_PASSWORD) are not set.',
    };
  }

  const rawUrl = process.env.SMS_GATEWAY_URL || 'https://api.sms-gate.app/3rdparty/v1/messages';
  const devicesUrl = rawUrl.replace(/\/messages\/?$/, '') + '/devices';
  const basicAuth = Buffer.from(`${login}:${password}`).toString('base64');

  try {
    const response = await fetch(devicesUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Basic ${basicAuth}`,
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(8000),
    });

    if (response.status === 401 || response.status === 403) {
      console.error('[SMS_GATEWAY_AUTH_FAILURE] Gateway rejected credentials (HTTP ' + response.status + '). Check login/password.');
      return {
        reachable: true,
        authenticated: false,
        devices: [],
        errorCategory: 'AUTHENTICATION_FAILURE',
        error: `Gateway authentication failed (HTTP ${response.status}). Verify SMS_GATEWAY_LOGIN and SMS_GATEWAY_PASSWORD on Render.`,
      };
    }

    if (!response.ok) {
      console.error(`[SMS_GATEWAY_REJECTED] Device check failed with HTTP ${response.status}.`);
      return {
        reachable: true,
        authenticated: true,
        devices: [],
        errorCategory: 'GATEWAY_ERROR',
        error: `Gateway returned HTTP ${response.status} when listing devices.`,
      };
    }

    const data = await response.json();
    const devicesList = Array.isArray(data) ? data : [];

    console.log(`[SMS_GATEWAY_DIAGNOSTIC] Gateway reachable. Registered devices found: ${devicesList.length}`);
    return {
      reachable: true,
      authenticated: true,
      devices: devicesList.map((d) => ({
        id: d.id,
        name: d.name || 'Android Gateway Phone',
        lastSeen: d.lastSeen,
      })),
    };
  } catch (error) {
    let errorCategory = 'NETWORK_ERROR';
    let errorMsg = error.message;

    if (error.name === 'TimeoutError' || error.name === 'AbortError') {
      errorCategory = 'TIMEOUT_ERROR';
      errorMsg = 'Connection timed out while probing SMS Gateway devices endpoint.';
    }

    console.error(`[SMS_GATEWAY_NETWORK_ERROR] ${errorCategory}: ${errorMsg}`);
    return {
      reachable: false,
      authenticated: false,
      devices: [],
      errorCategory,
      error: errorMsg,
    };
  }
}

/**
 * Determine if a gateway failure is transient (eligible for retry) or permanent.
 */
function isTransientFailure(category, httpStatus) {
  if (category === 'RATE_LIMIT_EXCEEDED' || httpStatus === 429) return true;
  if (category === 'GATEWAY_SERVER_ERROR' || (httpStatus >= 500 && httpStatus <= 504)) return true;
  if (category === 'TIMEOUT_ERROR') return true;
  if (category === 'NETWORK_ERROR') return true;
  return false;
}

/**
 * Send an SMS message via the official Android SMS Gateway REST API (https://sms-gate.app/)
 * Includes bounded exponential backoff retries for transient errors (rate limit 429, timeouts, 5xx server errors).
 * 
 * @param {Object} options
 * @param {string} options.to - Recipient phone number (E.164 format)
 * @param {string} options.message - Text message content
 * @param {string} [options.deviceId] - Optional target device ID
 * @param {number} [options.simNumber] - Optional SIM slot index (1 or 2)
 * @param {number} [options.maxRetries=2] - Maximum retry attempts for transient errors
 * @returns {Promise<{success: boolean, messageId?: string, state?: string, error?: string, errorCategory?: string, raw?: any}>}
 */
async function sendSms({ to, message, deviceId, simNumber, maxRetries = 2 }) {
  const login = process.env.SMS_GATEWAY_LOGIN || process.env.SMS_GATEWAY_USERNAME;
  const password = process.env.SMS_GATEWAY_PASSWORD;

  if (!login || !password) {
    console.error('[SMS_GATEWAY_CONFIG_ERROR] Dispatch aborted: SMS_GATEWAY_LOGIN or SMS_GATEWAY_PASSWORD not configured.');
    return {
      success: false,
      state: 'NOT_CONFIGURED',
      errorCategory: 'CONFIGURATION_ERROR',
      error: 'SMS Gateway credentials (SMS_GATEWAY_LOGIN and SMS_GATEWAY_PASSWORD) are not set.',
    };
  }

  const normalizedTo = normalizePhoneNumber(to);
  if (!normalizedTo) {
    console.error(`[SMS_GATEWAY_REJECTED] Invalid recipient phone format: "${to}".`);
    return {
      success: false,
      state: 'FAILED',
      errorCategory: 'INVALID_PHONE_FORMAT',
      error: `Invalid recipient phone number format: "${to}". Must be standard 10-digit Indian number or international E.164.`,
    };
  }

  const targetUrl = process.env.SMS_GATEWAY_URL || 'https://api.sms-gate.app/3rdparty/v1/messages';
  const targetDeviceId = deviceId || process.env.SMS_GATEWAY_DEVICE_ID;
  const targetSim = simNumber !== undefined ? simNumber : (process.env.SMS_GATEWAY_SIM_NUMBER ? parseInt(process.env.SMS_GATEWAY_SIM_NUMBER, 10) : undefined);

  const payload = {
    textMessage: {
      text: message,
    },
    phoneNumbers: [normalizedTo],
    withDeliveryReport: true,
  };

  if (targetDeviceId) {
    payload.deviceId = targetDeviceId;
  }
  if (targetSim && !isNaN(targetSim)) {
    payload.simNumber = targetSim;
  }

  const basicAuth = Buffer.from(`${login}:${password}`).toString('base64');
  let attempt = 0;
  let lastResult = null;

  while (attempt <= maxRetries) {
    try {
      // 10-second request timeout using AbortSignal to avoid hanging requests
      const response = await fetch(targetUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${basicAuth}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(10000),
      });

      const resText = await response.text();
      let resData;
      try {
        resData = JSON.parse(resText);
      } catch (_) {
        resData = { raw: resText };
      }

      if (response.ok) {
        // Successful response returns { id: "...", state: "Pending" | "Sent" | "Delivered", recipients: [...] }
        const messageId = resData.id || (resData.recipients && resData.recipients[0] && resData.recipients[0].id) || 'GATEWAY_ACCEPTED';
        const state = resData.state || 'Pending';

        console.log(`[SMS_GATEWAY_ACCEPTED] Enqueued SMS to ${maskPhone(normalizedTo)}. Gateway Msg ID: ${messageId}, Initial State: ${state}`);
        console.log(`[SMS_GATEWAY_NOTE] Gateway acceptance indicates message is enqueued on gateway server. Recipient delivery is confirmed via webhook.`);

        return {
          success: true,
          messageId,
          state,
          recipientMasked: maskPhone(normalizedTo),
          attempts: attempt + 1,
          raw: resData,
        };
      } else if (response.status === 401 || response.status === 403) {
        // Permanent error: Bad credentials
        console.error(`[SMS_GATEWAY_AUTH_FAILURE] Authentication failed with HTTP ${response.status}. Permanent error — will NOT retry.`);
        return {
          success: false,
          state: 'FAILED',
          errorCategory: 'AUTHENTICATION_FAILURE',
          error: `Gateway authentication rejected (HTTP ${response.status}). Check credentials.`,
          raw: resData,
        };
      } else if (response.status === 400 || response.status === 422) {
        // Permanent error: Invalid payload
        const errorMsg = resData.message || resData.error || `Bad request (HTTP ${response.status})`;
        console.error(`[SMS_GATEWAY_REJECTED] Bad request to gateway: ${errorMsg}. Permanent error — will NOT retry.`);
        return {
          success: false,
          state: 'FAILED',
          errorCategory: 'BAD_REQUEST',
          error: errorMsg,
          raw: resData,
        };
      } else if (response.status === 429) {
        // Transient error: Rate limit
        const errorMsg = 'Rate limit exceeded on SMS Gateway (HTTP 429).';
        console.warn(`[SMS_GATEWAY_RATE_LIMIT] ${errorMsg}`);
        lastResult = {
          success: false,
          state: 'FAILED',
          errorCategory: 'RATE_LIMIT_EXCEEDED',
          error: errorMsg,
          raw: resData,
        };
      } else if (response.status >= 500 && response.status <= 504) {
        // Transient error: Gateway server error
        const errorMsg = resData.message || `Gateway server error (HTTP ${response.status})`;
        console.warn(`[SMS_GATEWAY_SERVER_ERROR] HTTP ${response.status}: ${errorMsg}`);
        lastResult = {
          success: false,
          state: 'FAILED',
          errorCategory: 'GATEWAY_SERVER_ERROR',
          error: errorMsg,
          raw: resData,
        };
      } else {
        // Other unexpected gateway error
        const errorMsg = resData.message || resData.error || `Gateway error (HTTP ${response.status})`;
        console.error(`[SMS_GATEWAY_REJECTED] Gateway returned HTTP ${response.status}: ${errorMsg}`);
        return {
          success: false,
          state: 'FAILED',
          errorCategory: 'REJECTED_BY_GATEWAY',
          error: errorMsg,
          raw: resData,
        };
      }
    } catch (error) {
      let errorCategory = 'NETWORK_ERROR';
      let errorMsg = error.message;

      if (error.name === 'TimeoutError' || error.name === 'AbortError') {
        errorCategory = 'TIMEOUT_ERROR';
        errorMsg = 'Request timed out (10s) while connecting to SMS Gateway.';
      }

      console.warn(`[SMS_GATEWAY_TRANSIENT_ERROR] ${errorCategory}: ${errorMsg}`);
      lastResult = {
        success: false,
        state: 'FAILED',
        errorCategory,
        error: errorMsg,
      };
    }

    // Check if eligible for bounded exponential retry
    if (attempt < maxRetries && lastResult && isTransientFailure(lastResult.errorCategory)) {
      attempt++;
      const backoffDelay = attempt === 1 ? 1000 : 2500;
      console.log(`[SMS_GATEWAY_RETRY] Retrying dispatch to ${maskPhone(normalizedTo)} in ${backoffDelay}ms (attempt ${attempt + 1}/${maxRetries + 1})...`);
      await new Promise((resolve) => setTimeout(resolve, backoffDelay));
    } else {
      break;
    }
  }

  // If retries exhausted
  console.error(`[SMS_GATEWAY_FAILED] Dispatch exhausted all attempts for ${maskPhone(normalizedTo)}. Category: ${lastResult?.errorCategory}`);
  return lastResult || {
    success: false,
    state: 'FAILED',
    errorCategory: 'UNKNOWN_FAILURE',
    error: 'Failed to dispatch SMS after bounded retries.',
  };
}

/**
 * Verify HMAC-SHA256 signature for incoming webhooks from sms-gate.app
 * Header: X-Signature, X-Timestamp
 */
function verifyWebhookSignature({ rawBody, timestamp, signature, secret }) {
  if (!secret) return true; // If no webhook secret configured, pass through
  if (!timestamp || !signature) return false;

  // Check timestamp freshness (within 5 minutes) to protect against replay attacks
  const tsNumber = parseInt(timestamp, 10);
  const now = Math.floor(Date.now() / 1000);
  if (isNaN(tsNumber) || Math.abs(now - tsNumber) > 300) {
    return false;
  }

  try {
    const signedPayload = `${timestamp}.${rawBody}`;
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(signedPayload)
      .digest('hex');

    return crypto.timingSafeEqual(
      Buffer.from(signature, 'utf8'),
      Buffer.from(expectedSignature, 'utf8')
    );
  } catch (_) {
    return false;
  }
}

/**
 * Handle incoming webhook notifications from the Android SMS Gateway
 * Events: sms:sent, sms:delivered, sms:failed, sms:cancelled
 */
async function processWebhookEvent(eventData) {
  const { event, payload } = eventData || {};
  if (!event || !payload) {
    return { updated: false, reason: 'Missing event or payload structure' };
  }

  const messageId = payload.messageId || payload.id;
  if (!messageId) {
    return { updated: false, reason: 'No messageId found in payload' };
  }

  let newStatus = null;
  let errorMessage = null;

  switch (event) {
    case 'sms:delivered':
      newStatus = 'DELIVERED';
      console.log(`[SMS_GATEWAY_DELIVERED] Recipient confirmed receipt for Msg ID: ${messageId}`);
      break;
    case 'sms:sent':
      newStatus = 'SENT';
      console.log(`[SMS_GATEWAY_SENT] Carrier/SMSC confirmed transmission for Msg ID: ${messageId}`);
      break;
    case 'sms:failed':
      newStatus = 'FAILED';
      errorMessage = payload.error || payload.reason || 'SMS failed during transmission on Android device.';
      console.error(`[SMS_GATEWAY_FAILED] Transmission failed for Msg ID: ${messageId} - ${errorMessage}`);
      break;
    case 'sms:cancelled':
      newStatus = 'FAILED';
      errorMessage = 'SMS cancelled before transmission.';
      console.warn(`[SMS_GATEWAY_CANCELLED] Message was cancelled for Msg ID: ${messageId}`);
      break;
    default:
      return { updated: false, reason: `Ignored event type: ${event}` };
  }

  // Update notification record in DB
  const updateQuery = errorMessage
    ? `UPDATE sos_notifications 
       SET status = $1, error_message = $2 
       WHERE provider_message_id = $3 
       RETURNING sos_id, status`
    : `UPDATE sos_notifications 
       SET status = $1 
       WHERE provider_message_id = $2 
       RETURNING sos_id, status`;

  const queryParams = errorMessage ? [newStatus, errorMessage, messageId] : [newStatus, messageId];
  const notifResult = await db.query(updateQuery, queryParams);

  if (notifResult.rows.length === 0) {
    return { updated: false, reason: `No notification log found matching messageId ${messageId}` };
  }

  // Recalculate parent SOS incident's notification_status
  const sosId = notifResult.rows[0].sos_id;
  await recalculateIncidentNotificationStatus(sosId);

  return { updated: true, newStatus, messageId, sosId };
}

/**
 * Recalculate overall incident notification_status based on child sos_notifications
 */
async function recalculateIncidentNotificationStatus(sosId) {
  try {
    const countsRes = await db.query(
      `SELECT status, COUNT(*) as count 
       FROM sos_notifications 
       WHERE sos_id = $1 
       GROUP BY status`,
      [sosId]
    );

    let sent = 0;
    let delivered = 0;
    let pending = 0;
    let failed = 0;

    for (const row of countsRes.rows) {
      const c = parseInt(row.count, 10);
      if (row.status === 'DELIVERED') delivered += c;
      else if (row.status === 'SENT') sent += c;
      else if (row.status === 'PENDING') pending += c;
      else if (row.status === 'FAILED' || row.status === 'NOT_CONFIGURED') failed += c;
    }

    let overallStatus = 'PENDING';
    const successTotal = delivered + sent;

    if (pending > 0 && successTotal === 0 && failed === 0) {
      overallStatus = 'PENDING';
    } else if (successTotal > 0 && failed === 0) {
      overallStatus = 'SENT';
    } else if (successTotal > 0 && failed > 0) {
      overallStatus = 'PARTIAL';
    } else if (failed > 0 && successTotal === 0 && pending === 0) {
      overallStatus = 'FAILED';
    }

    await db.query(
      `UPDATE sos_incidents SET notification_status = $1 WHERE id = $2`,
      [overallStatus, sosId]
    );
  } catch (err) {
    console.error(`Failed to recalculate notification_status for SOS ${sosId}:`, err.message);
  }
}

/**
 * Fetch detailed message status directly from the gateway server
 * Endpoint: GET https://api.sms-gate.app/3rdparty/v1/messages/{id}
 */
async function getMessageStatus(messageId) {
  const login = process.env.SMS_GATEWAY_LOGIN || process.env.SMS_GATEWAY_USERNAME;
  const password = process.env.SMS_GATEWAY_PASSWORD;
  if (!login || !password) return { error: 'Gateway credentials not set' };

  const rawUrl = process.env.SMS_GATEWAY_URL || 'https://api.sms-gate.app/3rdparty/v1/messages';
  const msgUrl = rawUrl.replace(/\/+$/, '') + '/' + encodeURIComponent(messageId);
  const basicAuth = Buffer.from(`${login}:${password}`).toString('base64');

  try {
    const response = await fetch(msgUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Basic ${basicAuth}`,
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(8000),
    });

    if (!response.ok) {
      return { status: response.status, error: `Gateway returned HTTP ${response.status}` };
    }

    return await response.json();
  } catch (err) {
    return { error: err.message };
  }
}

module.exports = {
  maskPhone,
  maskString,
  normalizePhoneNumber,
  isGatewayConfigured,
  checkGatewayDeviceRegistration,
  getMessageStatus,
  sendSms,
  verifyWebhookSignature,
  processWebhookEvent,
  recalculateIncidentNotificationStatus,
  isTransientFailure,
};

