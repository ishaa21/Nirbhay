/**
 * SMS dispatch strategy for Nirbhay.
 * DEVICE (default): SMS must be sent from the user's Android phone; backend only logs results.
 * GATEWAY: Legacy sms-gate.app / Twilio path (disabled unless explicitly configured).
 */
function getSmsDispatchMode() {
  const raw = (process.env.SMS_DISPATCH_MODE || 'DEVICE').trim().toUpperCase();
  return raw === 'GATEWAY' ? 'GATEWAY' : 'DEVICE';
}

function isDeviceSmsMode() {
  return getSmsDispatchMode() === 'DEVICE';
}

function isGatewaySmsMode() {
  return getSmsDispatchMode() === 'GATEWAY';
}

module.exports = {
  getSmsDispatchMode,
  isDeviceSmsMode,
  isGatewaySmsMode,
};
