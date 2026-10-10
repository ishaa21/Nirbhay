const db = require('../config/db');

/**
 * Send SOS Emergency Notifications to user's configured emergency contacts
 * 
 * @param {Object} params
 * @param {string} params.sosId - ID of the created SOS incident
 * @param {string} params.userId - Authenticated user's ID
 * @param {number|null} params.latitude - Initial latitude if available
 * @param {number|null} params.longitude - Initial longitude if available
 * @param {Date} params.activatedAt - Incident timestamp
 */
async function sendSosAlerts({ sosId, userId, latitude, longitude, activatedAt }) {
  try {
    // 1. Fetch user's saved contacts where auto_alert is enabled
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
      return { status: 'NO_CONTACTS', sentCount: 0, failedCount: 0 };
    }

    // 2. Format alert message content
    const timeStr = new Date(activatedAt || Date.now()).toLocaleString();
    let locationStr = 'Location: Unavailable';
    if (latitude !== null && latitude !== undefined && longitude !== null && longitude !== undefined) {
      const latNum = parseFloat(latitude);
      const lngNum = parseFloat(longitude);
      locationStr = `Location: https://maps.google.com/?q=${latNum},${lngNum} (${latNum.toFixed(4)}, ${lngNum.toFixed(4)})`;
    }

    const messageBody = `EMERGENCY ALERT: An SOS trigger has been activated at ${timeStr}. ${locationStr}. Please check on the user immediately.`;

    // 3. Check for Provider Credentials (e.g. Twilio)
    const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
    const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
    const twilioFromNumber = process.env.TWILIO_PHONE_NUMBER;

    const isProviderConfigured = !!(twilioAccountSid && twilioAuthToken && twilioFromNumber);

    let sentCount = 0;
    let failedCount = 0;
    const notificationLogs = [];

    for (const contact of contacts) {
      if (!isProviderConfigured) {
        // Provider credentials unavailable — strictly log NOT_CONFIGURED state
        const errorMsg = 'SMS Provider credentials (TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN) not set in environment.';
        console.log(`[SOS NOTIFICATION PROVIDER] Contact: ${contact.name} (${contact.phone}) | Status: NOT_CONFIGURED | ${errorMsg}`);
        
        const insertRes = await db.query(
          `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, error_message)
           VALUES ($1, $2, $3, $4, 'SMS', 'NOT_CONFIGURED', $5)
           RETURNING *`,
          [sosId, contact.id, contact.name, contact.phone, errorMsg]
        );
        notificationLogs.push(insertRes.rows[0]);
        failedCount++;
      } else {
        // Real Twilio Provider dispatch
        try {
          // Using standard Twilio REST API via fetch/http to avoid external npm dependencies
          const authString = Buffer.from(`${twilioAccountSid}:${twilioAuthToken}`).toString('base64');
          const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`;
          
          const params = new URLSearchParams();
          params.append('To', contact.phone);
          params.append('From', twilioFromNumber);
          params.append('Body', messageBody);

          const response = await fetch(twilioUrl, {
            method: 'POST',
            headers: {
              'Authorization': `Basic ${authString}`,
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: params.toString()
          });

          const resData = await response.json();

          if (response.ok && resData.sid) {
            console.log(`[SOS NOTIFICATION PROVIDER] Alert sent to ${contact.name} (${contact.phone}). Twilio SID: ${resData.sid}`);
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
            console.error(`[SOS NOTIFICATION PROVIDER] Failed sending to ${contact.name} (${contact.phone}): ${errorMsg}`);
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
          console.error(`[SOS NOTIFICATION PROVIDER] Network error sending to ${contact.name}: ${err.message}`);
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
    if (sentCount === 0 && failedCount > 0) {
      finalStatus = 'FAILED';
    } else if (sentCount > 0 && failedCount > 0) {
      finalStatus = 'PARTIAL';
    }

    await db.query(
      `UPDATE sos_incidents SET notification_status = $1 WHERE id = $2`,
      [finalStatus, sosId]
    );

    return {
      status: finalStatus,
      isProviderConfigured,
      sentCount,
      failedCount,
      logs: notificationLogs
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

module.exports = {
  sendSosAlerts,
};
