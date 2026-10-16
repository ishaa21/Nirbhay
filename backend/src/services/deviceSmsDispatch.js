const smsGateway = require('./smsGatewayService');

/**
 * Prepare SOS notification rows for on-device SMS dispatch (no gateway/Twilio).
 * Creates sos_notifications in PENDING and returns payload for the Flutter client.
 */
async function prepareDeviceSosAlerts({
  db,
  sosId,
  contacts,
  messageBody,
  isTestMode,
  testPhoneNumber,
}) {
  let pendingCount = 0;
  let failedCount = 0;
  const notificationLogs = [];
  const recipients = [];
  let testSmsDispatched = false;

  for (const contact of contacts) {
    let targetPhone = smsGateway.normalizePhoneNumber(contact.phone);
    let simulateOnly = false;

    if (isTestMode) {
      if (!testPhoneNumber) {
        const errMsg =
          'SMS_TEST_MODE is true but SMS_TEST_PHONE_NUMBER is not set. Aborting device dispatch for safety.';
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

      if (testSmsDispatched) {
        simulateOnly = true;
      } else {
        targetPhone = smsGateway.normalizePhoneNumber(testPhoneNumber);
        testSmsDispatched = true;
      }
    }

    if (!targetPhone) {
      const insertRes = await db.query(
        `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, error_message)
         VALUES ($1, $2, $3, $4, 'SMS', 'FAILED', $5)
         RETURNING *`,
        [sosId, contact.id, contact.name, contact.phone, 'Invalid or empty phone number.']
      );
      notificationLogs.push(insertRes.rows[0]);
      failedCount++;
      continue;
    }

    const insertRes = await db.query(
      `INSERT INTO sos_notifications (sos_id, contact_id, contact_name, contact_phone, channel, status, provider_message_id)
       VALUES ($1, $2, $3, $4, 'SMS', 'PENDING', $5)
       RETURNING *`,
      [
        sosId,
        contact.id,
        contact.name,
        contact.phone,
        simulateOnly ? 'DEVICE_TEST_SIMULATED' : 'DEVICE_PENDING',
      ]
    );
    const row = insertRes.rows[0];
    notificationLogs.push(row);
    pendingCount++;

    recipients.push({
      notificationId: row.id,
      contactId: contact.id,
      contactName: contact.name,
      contactPhone: contact.phone,
      dispatchPhone: targetPhone,
      simulateOnly,
    });
  }

  let finalStatus = 'PENDING';
  if (pendingCount === 0 && failedCount > 0) {
    finalStatus = 'FAILED';
  } else if (failedCount > 0) {
    finalStatus = 'PARTIAL';
  }

  await db.query(`UPDATE sos_incidents SET notification_status = $1 WHERE id = $2`, [
    finalStatus,
    sosId,
  ]);

  return {
    status: finalStatus,
    isProviderConfigured: true,
    isTestMode,
    dispatchMode: 'DEVICE',
    sentCount: 0,
    pendingCount,
    failedCount,
    logs: notificationLogs,
    deviceSms: {
      messageBody,
      recipients,
      isTestMode: !!isTestMode,
    },
  };
}

module.exports = {
  prepareDeviceSosAlerts,
};
