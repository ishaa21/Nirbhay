const db = require('../config/db');
const smsGateway = require('./smsGatewayService');
const { isDeviceSmsMode } = require('./smsDispatchMode');
const { prepareDeviceSosAlerts } = require('./deviceSmsDispatch');

/**
 * Format SMS alert body with timestamp, Google Maps location link, and live tracking URL
 */
function buildAlertMessage({ activatedAt, latitude, longitude, trackingUrl, lang = 'en' }) {
  const timeStr = new Date(activatedAt || Date.now()).toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    dateStyle: 'medium',
    timeStyle: 'medium',
  });

  const hasCoords = latitude !== null && latitude !== undefined && longitude !== null && longitude !== undefined;
  const latNum = hasCoords ? parseFloat(latitude) : NaN;
  const lngNum = hasCoords ? parseFloat(longitude) : NaN;
  const validCoords = !isNaN(latNum) && !isNaN(lngNum);

  if (lang === 'hi') {
    const locPart = validCoords
      ? `स्थान: https://maps.google.com/?q=${latNum},${lngNum} (${latNum.toFixed(4)}, ${lngNum.toFixed(4)})`
      : 'स्थान: अनुपलब्ध';
    const trackPart = trackingUrl ? ` लाइव ट्रैकिंग: ${trackingUrl}` : '';
    return `आपातकालीन सूचना: निर्भय SOS ${timeStr} पर सक्रिय हुआ। ${locPart}.${trackPart} कृपया तुरंत सहायता करें।`;
  }

  if (lang === 'gu') {
    const locPart = validCoords
      ? `સ્થળ: https://maps.google.com/?q=${latNum},${lngNum} (${latNum.toFixed(4)}, ${lngNum.toFixed(4)})`
      : 'સ્થળ: અપ્રાપ્ય';
    const trackPart = trackingUrl ? ` લાઇવ ટ્રેકિંગ: ${trackingUrl}` : '';
    return `કટોકટી ચેતવણી: નિર્ભય SOS ${timeStr} વાગ્યે સક્રિય થયું. ${locPart}.${trackPart} કૃપા કરીને તાત્કાલિક મદદ કરો.`;
  }

  let locationStr = 'Location: Unavailable';
  if (validCoords) {
    locationStr = `Location: https://maps.google.com/?q=${latNum},${lngNum} (${latNum.toFixed(4)}, ${lngNum.toFixed(4)})`;
  }
  const trackingStr = trackingUrl ? ` Live Tracking: ${trackingUrl}` : '';
  return `EMERGENCY ALERT: Nirbhay SOS activated at ${timeStr}. ${locationStr}.${trackingStr} Please check immediately.`;
}

function buildJourneyStartedMessage({ userName, trackingUrl, destination, startedAt, lang = 'en' }) {
  const timeStr = new Date(startedAt || Date.now()).toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    dateStyle: 'medium',
    timeStyle: 'medium',
  });
  const name = userName ? userName.trim() : 'User';

  if (lang === 'hi') {
    const destPart = destination ? ` गंतव्य: ${destination}।` : '';
    const trackPart = trackingUrl ? ` लाइव ट्रैकिंग: ${trackingUrl}` : '';
    return `यात्रा सूचना: ${name} ने निर्भय पर ${timeStr} पर यात्रा शुरू की।${destPart}${trackPart}`;
  }

  if (lang === 'gu') {
    const destPart = destination ? ` ગંતવ્ય: ${destination}.` : '';
    const trackPart = trackingUrl ? ` લાઇવ ટ્રેકિંગ: ${trackingUrl}` : '';
    return `મુસાફરી સૂચના: ${name} એ નિર્ભય પર ${timeStr} વાગ્યે મુસાફરી શરૂ કરી.${destPart}${trackPart}`;
  }

  const destPart = destination ? ` Heading to: ${destination}.` : '';
  const trackPart = trackingUrl ? ` Live Journey: ${trackingUrl}` : '';
  return `JOURNEY ALERT: ${name} started a live journey on Nirbhay at ${timeStr}.${destPart}${trackPart} You can follow their location on the link.`;
}

function buildJourneyEndedMessage({ userName, resolvedAt, lang = 'en' }) {
  const timeStr = new Date(resolvedAt || Date.now()).toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    dateStyle: 'medium',
    timeStyle: 'medium',
  });
  const name = userName ? userName.trim() : 'The user';

  if (lang === 'hi') {
    return `यात्रा अपडेट: ${name} सुरक्षित पहुंच गए हैं और ${timeStr} पर निर्भय यात्रा समाप्त की।`;
  }

  if (lang === 'gu') {
    return `મુસાફરી અપડેટ: ${name} સુરક્ષિત પહોંચી ગયા છે અને ${timeStr} વાગ્યે મુસાફરી પૂર્ણ કરી.`;
  }

  return `JOURNEY UPDATE: ${name} has arrived safely and ended their Nirbhay live journey at ${timeStr}. No further action needed.`;
}

function buildJourneyDeviationMessage({ userName, latitude, longitude, trackingUrl, distanceMeters, lang = 'en' }) {
  const name = userName ? userName.trim() : 'User';
  let locationStr = 'Location: Unavailable';
  if (latitude != null && longitude != null) {
    const latNum = parseFloat(latitude);
    const lngNum = parseFloat(longitude);
    if (!isNaN(latNum) && !isNaN(lngNum)) {
      locationStr = `Location: https://maps.google.com/?q=${latNum},${lngNum}`;
    }
  }

  if (lang === 'hi') {
    const distPart = distanceMeters != null ? ` मार्ग विचलन ~${Math.round(distanceMeters)}m।` : '';
    const trackPart = trackingUrl ? ` लाइव यात्रा: ${trackingUrl}` : '';
    return `मार्ग चेतावनी: ${name} निर्भय पर अपने नियोजित मार्ग से भटक गए हो सकते हैं।${distPart} ${locationStr}.${trackPart} कृपया संपर्क करें।`;
  }

  if (lang === 'gu') {
    const distPart = distanceMeters != null ? ` રૂટ વિચલન ~${Math.round(distanceMeters)}m.` : '';
    const trackPart = trackingUrl ? ` લાઇવ મુસાફરી: ${trackingUrl}` : '';
    return `રૂટ ચેતવણી: ${name} નિર્ભય પર તેમના આયોજિત રૂટથી ભટકી ગયા હોઈ શકે છે.${distPart} ${locationStr}.${trackPart} કૃપા કરીને સંપર્ક કરો.`;
  }

  const distPart = distanceMeters != null ? ` Route drift ~${Math.round(distanceMeters)}m.` : '';
  const trackPart = trackingUrl ? ` Live Journey: ${trackingUrl}` : '';
  return `ROUTE ALERT: ${name} may have deviated from their planned route on Nirbhay.${distPart} ${locationStr}.${trackPart} Please check on them.`;
}

/**
 * Send SMS to all emergency contacts with auto_alert enabled (no SOS incident record required).
 */
async function sendAlertsToUserContacts({ userId, messageBody }) {
  const contactsResult = await db.query(
    `SELECT id, name, phone, auto_alert 
     FROM emergency_contacts 
     WHERE user_id = $1 AND auto_alert = true`,
    [userId]
  );
  const contacts = contactsResult.rows;

  if (contacts.length === 0) {
    console.log(`[CONTACT SMS] No auto_alert contacts for user ${userId}.`);
    return { status: 'NO_CONTACTS', sentCount: 0, pendingCount: 0, failedCount: 0, isProviderConfigured: false };
  }

  if (isDeviceSmsMode()) {
    console.log(
      `[CONTACT SMS] SMS_DISPATCH_MODE=DEVICE — journey/contact alerts must be sent from the user's Android device (not via Render). Skipping gateway.`
    );
    return {
      status: 'DEVICE_REQUIRED',
      sentCount: 0,
      pendingCount: 0,
      failedCount: 0,
      isProviderConfigured: false,
      dispatchMode: 'DEVICE',
    };
  }

  const isGatewayConfigured = smsGateway.isGatewayConfigured();
  const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
  const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
  const twilioFromNumber = process.env.TWILIO_PHONE_NUMBER;
  const isTwilioConfigured = !!(twilioAccountSid && twilioAuthToken && twilioFromNumber);
  const isProviderConfigured = isGatewayConfigured || isTwilioConfigured;

  const isTestMode = process.env.SMS_TEST_MODE === 'true' || process.env.SMS_TEST_MODE === '1';
  const testPhoneNumber = process.env.SMS_TEST_PHONE_NUMBER;

  let sentCount = 0;
  let pendingCount = 0;
  let failedCount = 0;
  let testSmsDispatched = false;

  for (const contact of contacts) {
    let targetPhone = contact.phone;
    if (isTestMode) {
      if (!testPhoneNumber) {
        failedCount++;
        continue;
      }
      if (testSmsDispatched) {
        pendingCount++;
        continue;
      }
      targetPhone = testPhoneNumber;
    }

    if (!isProviderConfigured) {
      failedCount++;
      continue;
    }

    if (isGatewayConfigured) {
      try {
        const gatewayResult = await smsGateway.sendSms({ to: targetPhone, message: messageBody });
        if (isTestMode) testSmsDispatched = true;
        if (gatewayResult.success) {
          const mappedStatus = gatewayResult.state?.toUpperCase() === 'SENT' ? 'SENT' : 'PENDING';
          if (mappedStatus === 'SENT') sentCount++;
          else pendingCount++;
        } else {
          failedCount++;
        }
      } catch (_) {
        failedCount++;
      }
    } else if (isTwilioConfigured) {
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
            Authorization: `Basic ${authString}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: params.toString(),
          signal: AbortSignal.timeout(10000),
        });
        const resData = await response.json();
        if (response.ok && resData.sid) sentCount++;
        else failedCount++;
      } catch (_) {
        failedCount++;
      }
    }
  }

  let finalStatus = 'SENT';
  const totalSuccess = sentCount + pendingCount;
  if (totalSuccess === 0 && failedCount > 0) finalStatus = 'FAILED';
  else if (totalSuccess > 0 && failedCount > 0) finalStatus = 'PARTIAL';
  else if (pendingCount > 0 && sentCount === 0) finalStatus = 'PENDING';
  else if (!isProviderConfigured) finalStatus = 'NOT_CONFIGURED';

  return { status: finalStatus, isProviderConfigured, isTestMode, sentCount, pendingCount, failedCount };
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

    const isTestMode = process.env.SMS_TEST_MODE === 'true' || process.env.SMS_TEST_MODE === '1';
    const testPhoneNumber = process.env.SMS_TEST_PHONE_NUMBER;

    if (isDeviceSmsMode()) {
      console.log(
        `[SOS Notification] DEVICE dispatch mode — creating PENDING notification rows; Android app will send via SIM.`
      );
      if (isTestMode) {
        console.log(
          `[SOS TEST MODE] Active. Real contacts will NOT receive SMS. Test target: ${smsGateway.maskPhone(testPhoneNumber)}`
        );
      }
      return prepareDeviceSosAlerts({
        db,
        sosId,
        contacts,
        messageBody,
        isTestMode,
        testPhoneNumber,
      });
    }

    // 3. Provider Configuration Check (GATEWAY / Twilio legacy path)
    const isGatewayConfigured = smsGateway.isGatewayConfigured();
    const twilioAccountSid = process.env.TWILIO_ACCOUNT_SID;
    const twilioAuthToken = process.env.TWILIO_AUTH_TOKEN;
    const twilioFromNumber = process.env.TWILIO_PHONE_NUMBER;
    const isTwilioConfigured = !!(twilioAccountSid && twilioAuthToken && twilioFromNumber);

    const isProviderConfigured = isGatewayConfigured || isTwilioConfigured;

    if (isTestMode) {
      console.log(`[SOS TEST MODE] Safe Test Mode is ACTIVE. Real contacts will NOT be alerted. Target: ${smsGateway.maskPhone(testPhoneNumber)}`);
    }

    let sentCount = 0;
    let pendingCount = 0;
    let failedCount = 0;
    const notificationLogs = [];
    let testSmsDispatched = false;
    let testSmsResult = null;

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

        // In test mode, only send 1 physical SMS to testPhoneNumber for this incident to avoid spamming the test number
        if (testSmsDispatched) {
          console.log(`[SOS TEST MODE] Safe simulation for contact ${contact.name} (${smsGateway.maskPhone(contact.phone)}). Test SMS already dispatched to ${smsGateway.maskPhone(testPhoneNumber)}.`);
          const simulatedStatus = testSmsResult && testSmsResult.success ? 'PENDING' : 'FAILED';
          const insertRes = await db.query(
            `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, provider_message_id)
             VALUES ($1, $2, $3, $4, 'SMS', $5, $6)
             RETURNING *`,
            [sosId, contact.id, contact.name, contact.phone, simulatedStatus, `TEST_SIMULATED_${testSmsResult ? testSmsResult.messageId : 'NONE'}`]
          );
          notificationLogs.push(insertRes.rows[0]);
          if (simulatedStatus === 'PENDING') pendingCount++; else failedCount++;
          continue;
        }

        targetPhone = testPhoneNumber;
      }

      if (!isProviderConfigured) {
        // Neither Gateway nor Twilio configured — record NOT_CONFIGURED state
        const errorMsg = 'SMS Gateway credentials (SMS_GATEWAY_LOGIN / SMS_GATEWAY_PASSWORD) are not set in environment.';
        console.log(`[SOS NOTIFICATION] Contact: ${contact.name} (${smsGateway.maskPhone(contact.phone)}) | Status: NOT_CONFIGURED`);

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

          if (isTestMode) {
            testSmsDispatched = true;
            testSmsResult = gatewayResult;
          }

          if (gatewayResult.success) {
            // Note: An accepted request in sms-gate.app enters state 'Pending' on the gateway server
            // until the Android device picks it up. As required: do not falsely claim delivery!
            const mappedStatus = gatewayResult.state?.toUpperCase() === 'SENT' ? 'SENT' : 'PENDING';
            console.log(`[SOS NOTIFICATION] SMS enqueued to ${contact.name} (${smsGateway.maskPhone(targetPhone)}). Gateway ID: ${gatewayResult.messageId}, State: ${mappedStatus}`);

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
    const isTestMode = process.env.SMS_TEST_MODE === 'true' || process.env.SMS_TEST_MODE === '1';
    const testPhoneNumber = process.env.SMS_TEST_PHONE_NUMBER;

    if (isDeviceSmsMode()) {
      const prep = await prepareDeviceSosAlerts({
        db,
        sosId,
        contacts,
        messageBody,
        isTestMode,
        testPhoneNumber,
      });
      return {
        success: true,
        dispatchMode: 'DEVICE',
        deviceSms: prep.deviceSms,
        sentCount: 0,
        pendingCount: prep.pendingCount,
        failedCount: prep.failedCount,
      };
    }

    const isGatewayConfigured = smsGateway.isGatewayConfigured();

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

/**
 * Apply device-reported SMS status updates from the authenticated user's phone.
 */
async function reportDeviceSmsResults({ sosId, userId, results }) {
  if (!Array.isArray(results) || results.length === 0) {
    return { updated: 0, message: 'No results provided.' };
  }

  const incidentRes = await db.query(
    `SELECT id FROM sos_incidents WHERE id = $1 AND user_id = $2`,
    [sosId, userId]
  );
  if (incidentRes.rows.length === 0) {
    const err = new Error('SOS incident not found or access denied.');
    err.statusCode = 404;
    throw err;
  }

  const allowed = new Set(['PENDING', 'SENT', 'DELIVERED', 'FAILED']);
  let updated = 0;

  for (const item of results) {
    const notificationId = item.notificationId;
    const status = (item.status || '').toUpperCase();
    if (!notificationId || !allowed.has(status)) continue;

    const updateRes = await db.query(
      `UPDATE sos_notifications n
       SET status = $1,
           error_message = $2,
           provider_message_id = COALESCE($3, n.provider_message_id),
           sent_at = CASE WHEN $1 IN ('SENT', 'DELIVERED', 'FAILED') THEN COALESCE(n.sent_at, CURRENT_TIMESTAMP) ELSE n.sent_at END
       FROM sos_incidents i
       WHERE n.id = $4 AND n.sos_id = i.id AND i.id = $5 AND i.user_id = $6
       RETURNING n.*`,
      [
        status,
        item.errorMessage || null,
        item.providerMessageId || null,
        notificationId,
        sosId,
        userId,
      ]
    );
    if (updateRes.rows.length > 0) updated++;
  }

  const countsRes = await db.query(
    `SELECT status, COUNT(*)::int AS cnt
     FROM sos_notifications WHERE sos_id = $1 GROUP BY status`,
    [sosId]
  );
  const counts = Object.fromEntries(countsRes.rows.map((r) => [r.status, r.cnt]));
  const sent = counts.SENT || 0;
  const delivered = counts.DELIVERED || 0;
  const pending = counts.PENDING || 0;
  const failed = counts.FAILED || 0;
  const successLike = sent + delivered + pending;

  let finalStatus = 'PENDING';
  if (successLike === 0 && failed > 0) finalStatus = 'FAILED';
  else if (failed > 0 && successLike > 0) finalStatus = 'PARTIAL';
  else if (pending > 0 && sent + delivered === 0) finalStatus = 'PENDING';
  else if (sent + delivered > 0 && failed === 0 && pending === 0) finalStatus = 'SENT';

  await db.query(`UPDATE sos_incidents SET notification_status = $1 WHERE id = $2`, [
    finalStatus,
    sosId,
  ]);

  return { updated, incidentNotificationStatus: finalStatus, counts };
}

/**
 * Build device SMS payload for notifications still waiting on the phone (PENDING + DEVICE_*).
 */
async function buildPendingDeviceSmsPayload({ sosId, incident, customMessage }) {
  const pendingRes = await db.query(
    `SELECT n.* FROM sos_notifications n
     WHERE n.sos_id = $1 AND n.status = 'PENDING'
       AND (n.provider_message_id LIKE 'DEVICE_%' OR n.provider_message_id = 'DEVICE_PENDING')
     ORDER BY n.sent_at ASC NULLS FIRST, n.id ASC`,
    [sosId]
  );
  if (pendingRes.rows.length === 0) return null;

  const messageBody =
    customMessage ||
    buildAlertMessage({
      activatedAt: incident.activated_at,
      latitude: incident.latitude,
      longitude: incident.longitude,
      trackingUrl: incident.tracking_token
        ? `${process.env.BACKEND_BASE_URL || 'https://nirbhay-9d5i.onrender.com'}/track/${incident.tracking_token}`
        : null,
    });

  const recipients = pendingRes.rows.map((row) => ({
    notificationId: row.id,
    contactId: row.contact_id,
    contactName: row.contact_name,
    contactPhone: row.contact_phone,
    dispatchPhone: smsGateway.normalizePhoneNumber(row.contact_phone),
    simulateOnly: row.provider_message_id === 'DEVICE_TEST_SIMULATED',
  }));

  return { messageBody, recipients, isTestMode: false };
}

module.exports = {
  buildAlertMessage,
  buildResolvedMessage,
  buildJourneyStartedMessage,
  buildJourneyEndedMessage,
  buildJourneyDeviationMessage,
  sendAlertsToUserContacts,
  sendSosAlerts,
  sendSosResolvedAlerts,
  reportDeviceSmsResults,
  buildPendingDeviceSmsPayload,
};

