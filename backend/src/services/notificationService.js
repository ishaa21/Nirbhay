const db = require('../config/db');
const smsGateway = require('./smsGatewayService');

/**
 * Format SMS alert body with timestamp, Google Maps location link, and live tracking URL
 */
function buildAlertMessage({ activatedAt, latitude, longitude, trackingUrl }) {
  const timeStr = new Date(activatedAt || Date.now()).toLocaleString('en-IN', {
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

  return `EMERGENCY ALERT: Nirbhay SOS activated at ${timeStr}. ${locationStr}.${trackingStr} Please check immediately.`;
}

/**
 * Send SOS Emergency Notifications to user's configured emergency contacts
 * using the Android SMS Gateway (https://sms-gate.app/)
 * 
 * @param {Object} params
 * @param {string} params.sosId - ID of the created SOS incident
 * @param {string} params.userId - Authenticated user's ID
 * @param {number|null} params.latitude - Initial latitude if available
 * @param {number|null} params.longitude - Initial longitude if available
 * @param {Date} params.activatedAt - Incident timestamp
 */
async function sendSosAlerts({ sosId, userId, latitude, longitude, activatedAt, trackingUrl, customMessage }) {
  try {
    // 1. Fetch user's saved emergency contacts where auto_alert is enabled
    const contactsResult = await db.query(
      `SELECT id, name, phone, auto_alert 
       FROM emergency_contacts 
       WHERE user_id = $1 AND auto_alert = true`,
      [userId]
    );

    const contacts = contactsResult.rows;

    if (contacts.length === 0) {
      console.log(`[SOS Notification] No emergency contacts found with auto_alert enabled for user ${userId}.`);
      await db.query(
        `UPDATE sos_incidents SET notification_status = 'NO_CONTACTS' WHERE id = $1`,
        [sosId]
      );
      return { status: 'NO_CONTACTS', sentCount: 0, pendingCount: 0, failedCount: 0, logs: [] };
    }

    // 2. Format alert message content (uses customMessage if provided, else standard SOS message)
    const messageBody = customMessage || buildAlertMessage({ activatedAt, latitude, longitude, trackingUrl });

    // 3. Provider Configuration Check
    const isGatewayConfigured = smsGateway.isGatewayConfigured();
    const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
    const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
    const twilioFromNumber = process.env.TWILIO_PHONE_NUMBER;
    const isTwilioConfigured = !!(twilioAccountSid && twilioAuthToken && twilioFromNumber);

    const isProviderConfigured = isGatewayConfigured || isTwilioConfigured;

    // Safe Test Mode configuration
    const isTestMode = process.env.SMS_TEST_MODE === 'true' || process.env.SMS_TEST_MODE === '1';
    const testPhoneNumber = process.env.SMS_TEST_PHONE_NUMBER;

    if (isTestMode) {
      console.log(`[SOS TEST MODE] Safe Test Mode is ACTIVE. Real contacts will NOT be alerted. Target: ${testPhoneNumber || 'NOT_SET'}`);
    }

    let sentCount = 0;
    let pendingCount = 0;
    let failedCount = 0;
    const notificationLogs = [];

    for (const contact of contacts) {
      // Determine destination phone number (safely diverted if test mode is active)
      let targetPhone = contact.phone;
      if (isTestMode) {
        if (!testPhoneNumber) {
          const errMsg = 'SMS_TEST_MODE is true but SMS_TEST_PHONE_NUMBER is not set. Aborting dispatch for safety.';
          console.error(`[SOS NOTIFICATION] ${errMsg}`);
          const insertRes = await db.query(
            `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, error_message)
             VALUES ($1, $2, $3, $4, 'SMS', 'FAILED', $5)
             RETURNING *`,
            [sosId, contact.id, contact.name, contact.phone, errMsg]
          );
          notificationLogs.push(insertRes.rows[0]);
          failedCount++;
          continue;
        }
        targetPhone = testPhoneNumber;
      }

      if (!isProviderConfigured) {
        // Neither Gateway nor Twilio configured — record NOT_CONFIGURED state
        const errorMsg = 'SMS Gateway credentials (SMS_GATEWAY_LOGIN / SMS_GATEWAY_PASSWORD) are not set in environment.';
        console.log(`[SOS NOTIFICATION] Contact: ${contact.name} (${contact.phone}) | Status: NOT_CONFIGURED | ${errorMsg}`);

        const insertRes = await db.query(
          `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, error_message)
           VALUES ($1, $2, $3, $4, 'SMS', 'NOT_CONFIGURED', $5)
           RETURNING *`,
          [sosId, contact.id, contact.name, contact.phone, errorMsg]
        );
        notificationLogs.push(insertRes.rows[0]);
        failedCount++;
      } else if (isGatewayConfigured) {
        // Dispatch via Android SMS Gateway
        try {
          const gatewayResult = await smsGateway.sendSms({
            to: targetPhone,
            message: messageBody,
          });

          if (gatewayResult.success) {
            // Note: An accepted request in sms-gate.app enters state 'Pending' on the gateway server
            // until the Android device picks it up. As required: do not falsely claim delivery!
            const mappedStatus = gatewayResult.state?.toUpperCase() === 'SENT' ? 'SENT' : 'PENDING';
            console.log(`[SOS NOTIFICATION] SMS enqueued to ${contact.name} (${targetPhone}). Gateway ID: ${gatewayResult.messageId}, State: ${mappedStatus}`);

            const insertRes = await db.query(
              `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, provider_message_id)
               VALUES ($1, $2, $3, $4, 'SMS', $5, $6)
               RETURNING *`,
              [sosId, contact.id, contact.name, contact.phone, mappedStatus, gatewayResult.messageId]
            );
            notificationLogs.push(insertRes.rows[0]);
            
            if (mappedStatus === 'SENT') {
              sentCount++;
            } else {
              pendingCount++;
            }
          } else {
            console.error(`[SOS NOTIFICATION] Failed enqueuing SMS to ${contact.name} (${targetPhone}): ${gatewayResult.error}`);
            const insertRes = await db.query(
              `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, error_message)
               VALUES ($1, $2, $3, $4, 'SMS', 'FAILED', $5)
               RETURNING *`,
              [sosId, contact.id, contact.name, contact.phone, gatewayResult.error || 'SMS Gateway dispatch failed.']
            );
            notificationLogs.push(insertRes.rows[0]);
            failedCount++;
          }
        } catch (gatewayErr) {
          console.error(`[SOS NOTIFICATION] Unexpected gateway error for ${contact.name}: ${gatewayErr.message}`);
          const insertRes = await db.query(
            `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, error_message)
             VALUES ($1, $2, $3, $4, 'SMS', 'FAILED', $5)
             RETURNING *`,
            [sosId, contact.id, contact.name, contact.phone, gatewayErr.message]
          );
          notificationLogs.push(insertRes.rows[0]);
          failedCount++;
        }
      } else if (isTwilioConfigured) {
        // Fallback to Twilio provider
        try {
          const authString = Buffer.from(`${twilioAccountSid}:${twilioAuthToken}`).toString('base64');
          const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`;

          const params = new URLSearchParams();
          params.append('To', targetPhone);
          params.append('From', twilioFromNumber);
          params.append('Body', messageBody);

          const response = await fetch(twilioUrl, {
            method: 'POST',
            headers: {
              'Authorization': `Basic ${authString}`,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: params.toString(),
            signal: AbortSignal.timeout(10000),
          });

          const resData = await response.json();

          if (response.ok && resData.sid) {
            console.log(`[SOS NOTIFICATION] Alert sent via Twilio to ${contact.name} (${targetPhone}). SID: ${resData.sid}`);
            const insertRes = await db.query(
              `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, provider_message_id)
               VALUES ($1, $2, $3, $4, 'SMS', 'SENT', $5)
               RETURNING *`,
              [sosId, contact.id, contact.name, contact.phone, resData.sid]
            );
            notificationLogs.push(insertRes.rows[0]);
            sentCount++;
          } else {
            const errorMsg = resData.message || resData.detail || 'Failed to dispatch via Twilio provider.';
            console.error(`[SOS NOTIFICATION] Twilio error for ${contact.name}: ${errorMsg}`);
            const insertRes = await db.query(
              `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, error_message)
               VALUES ($1, $2, $3, $4, 'SMS', 'FAILED', $5)
               RETURNING *`,
              [sosId, contact.id, contact.name, contact.phone, errorMsg]
            );
            notificationLogs.push(insertRes.rows[0]);
            failedCount++;
          }
        } catch (err) {
          console.error(`[SOS NOTIFICATION] Network error sending via Twilio to ${contact.name}: ${err.message}`);
          const insertRes = await db.query(
            `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, error_message)
             VALUES ($1, $2, $3, $4, 'SMS', 'FAILED', $5)
             RETURNING *`,
            [sosId, contact.id, contact.name, contact.phone, err.message]
          );
          notificationLogs.push(insertRes.rows[0]);
          failedCount++;
        }
      }
    }

    // 4. Update overall incident notification status
    let finalStatus = 'SENT';
    const totalSuccess = sentCount + pendingCount;

    if (totalSuccess === 0 && failedCount > 0) {
      finalStatus = 'FAILED';
    } else if (totalSuccess > 0 && failedCount > 0) {
      finalStatus = 'PARTIAL';
    } else if (pendingCount > 0 && sentCount === 0) {
      finalStatus = 'PENDING';
    } else if (sentCount > 0 && failedCount === 0) {
      finalStatus = 'SENT';
    }

    await db.query(
      `UPDATE sos_incidents SET notification_status = $1 WHERE id = $2`,
      [finalStatus, sosId]
    );

    return {
      status: finalStatus,
      isProviderConfigured,
      isTestMode,
      sentCount,
      pendingCount,
      failedCount,
      logs: notificationLogs,
    };
  } catch (error) {
    console.error('Error executing sendSosAlerts:', error);
    await db.query(
      `UPDATE sos_incidents SET notification_status = 'FAILED' WHERE id = $1`,
      [sosId]
    ).catch(() => {});
    return { status: 'FAILED', error: error.message };
  }
}

/**
 * Format SMS body for resolved incident ("user is safe now")
 */
function buildResolvedMessage({ resolvedAt, userName }) {
  const timeStr = new Date(resolvedAt || Date.now()).toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    dateStyle: 'medium',
    timeStyle: 'medium',
  });

  const name = userName ? userName.trim() : 'The user';
  return `STATUS UPDATE: ${name}'s Nirbhay SOS emergency alert has been RESOLVED at ${timeStr}. User is SAFE now. No further action is required.`;
}

/**
 * Send "User is Safe" notification when an SOS incident is resolved
 */
async function sendSosResolvedAlerts({ sosId, userId, resolvedAt }) {
  try {
    // 1. Fetch user's name
    const userRes = await db.query(`SELECT full_name FROM users WHERE id = $1`, [userId]);
    const userName = userRes.rows[0]?.full_name || 'The user';

    // 2. Fetch emergency contacts with auto_alert = true
    const contactsRes = await db.query(
      `SELECT id, name, phone, auto_alert 
       FROM emergency_contacts 
       WHERE user_id = $1 AND auto_alert = true`,
      [userId]
    );

    const contacts = contactsRes.rows;
    if (contacts.length === 0) {
      console.log(`[SOS Resolved Notification] No emergency contacts found with auto_alert for user ${userId}.`);
      return { status: 'NO_CONTACTS', sentCount: 0, pendingCount: 0, failedCount: 0 };
    }

    const messageBody = buildResolvedMessage({ resolvedAt, userName });
    const isGatewayConfigured = smsGateway.isGatewayConfigured();
    const isTestMode = process.env.SMS_TEST_MODE === 'true' || process.env.SMS_TEST_MODE === '1';
    const testPhoneNumber = process.env.SMS_TEST_PHONE_NUMBER;

    let sentCount = 0;
    let pendingCount = 0;
    let failedCount = 0;

    for (const contact of contacts) {
      let targetPhone = contact.phone;
      if (isTestMode) {
        if (!testPhoneNumber) continue;
        targetPhone = testPhoneNumber;
      }

      if (!isGatewayConfigured) {
        console.log(`[SOS RESOLVED] Contact: ${contact.name} (${contact.phone}) | Status: NOT_CONFIGURED`);
        await db.query(
          `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, error_message)
           VALUES ($1, $2, $3, $4, 'SMS', 'NOT_CONFIGURED', 'SMS Gateway credentials not set.')`,
          [sosId, contact.id, contact.name, contact.phone]
        );
        failedCount++;
      } else {
        try {
          const res = await smsGateway.sendSms({
            to: targetPhone,
            message: messageBody,
          });

          const mappedStatus = res.success
            ? (res.state?.toUpperCase() === 'SENT' ? 'SENT' : 'PENDING')
            : 'FAILED';

          console.log(`[SOS RESOLVED] "User is safe" SMS to ${contact.name} (${targetPhone}). State: ${mappedStatus}`);

          await db.query(
            `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, provider_message_id, error_message)
             VALUES ($1, $2, $3, $4, 'SMS', $5, $6, $7)`,
            [sosId, contact.id, contact.name, contact.phone, mappedStatus, res.messageId || null, res.error || null]
          );

          if (mappedStatus === 'SENT') sentCount++;
          else if (mappedStatus === 'PENDING') pendingCount++;
          else failedCount++;
        } catch (err) {
          console.error(`[SOS RESOLVED] Error dispatching to ${contact.name}:`, err.message);
          failedCount++;
        }
      }
    }

    return { success: true, sentCount, pendingCount, failedCount };
  } catch (err) {
    console.error('Error executing sendSosResolvedAlerts:', err);
    return { success: false, error: err.message };
  }
}

module.exports = {
  buildAlertMessage,
  buildResolvedMessage,
  sendSosAlerts,
  sendSosResolvedAlerts,
};

