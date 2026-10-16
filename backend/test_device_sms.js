/**
 * Unit tests for DEVICE-mode SOS SMS preparation (no real SMS, no DB).
 */
const smsGateway = require('./src/services/smsGatewayService');
const { buildAlertMessage } = require('./src/services/notificationService');
const { getSmsDispatchMode } = require('./src/services/smsDispatchMode');

console.log('=== Nirbhay Device SMS Unit Tests ===\n');

let passed = 0;
let failed = 0;

function assert(condition, label) {
  if (condition) {
    console.log(`✅ PASS: ${label}`);
    passed++;
  } else {
    console.log(`❌ FAIL: ${label}`);
    failed++;
  }
}

assert(getSmsDispatchMode() === 'DEVICE' || process.env.SMS_DISPATCH_MODE === 'GATEWAY', 'Default dispatch mode is DEVICE unless env overrides');

assert(smsGateway.normalizePhoneNumber('9876543210') === '+919876543210', 'Indian 10-digit normalization');
assert(smsGateway.normalizePhoneNumber('09876543210') === '+919876543210', 'Indian leading-zero normalization');
assert(smsGateway.normalizePhoneNumber('+14155552671') === '+14155552671', 'International passthrough');

const body = buildAlertMessage({
  activatedAt: new Date('2026-01-01T12:00:00Z'),
  latitude: 23.0225,
  longitude: 72.5714,
  trackingUrl: 'https://example.com/track/abc',
});
assert(body.includes('EMERGENCY ALERT'), 'SOS message prefix');
assert(body.includes('https://maps.google.com/?q=23.0225,72.5714'), 'Google Maps link in SOS body');
assert(body.includes('Live Tracking: https://example.com/track/abc'), 'Live tracking URL in SOS body');

const bodyNoGps = buildAlertMessage({
  activatedAt: new Date('2026-01-01T12:00:00Z'),
  latitude: null,
  longitude: null,
  trackingUrl: 'https://example.com/track/abc',
});
assert(bodyNoGps.includes('Location: Unavailable'), 'Unavailable location when GPS missing');

console.log(`\nResults: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
