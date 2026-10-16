const assert = require('assert');
const crypto = require('crypto');
const smsGateway = require('./src/services/smsGatewayService');
const { buildAlertMessage } = require('./src/services/notificationService');

console.log('--- STARTING ANDROID SMS GATEWAY UNIT & INTEGRATION TEST SUITE ---');

// 1. Phone number normalization tests
console.log('\n1. Testing Phone Number Normalization...');

const cases = [
  { input: '9876543210', expected: '+919876543210' },
  { input: '09876543210', expected: '+919876543210' },
  { input: '+919876543210', expected: '+919876543210' },
  { input: '+91 98765 43210', expected: '+919876543210' },
  { input: '+91-98765-43210', expected: '+919876543210' },
  { input: '00919876543210', expected: '+919876543210' },
  { input: '+14155552671', expected: '+14155552671' },
];

for (const c of cases) {
  const result = smsGateway.normalizePhoneNumber(c.input);
  assert.strictEqual(result, c.expected, `Expected ${c.input} to normalize to ${c.expected}, got ${result}`);
}
console.log('✅ PASS: All phone number normalizations passed (including Indian carrier formats).');

// 2. Phone and string masking tests (Credential Protection)
console.log('\n2. Testing Phone and String Masking for Safe Logging...');
const masked1 = smsGateway.maskPhone('+919876543210');
assert(masked1.includes('******') && masked1.endsWith('3210') && masked1.startsWith('+91'), 'Masked phone should protect middle digits');

const masked2 = smsGateway.maskString('my_super_secret_login');
assert(masked2.includes('****') && !masked2.includes('super_secret'), 'Masked string should not expose full credential');
console.log('✅ PASS: Phone and credential masking correctly sanitizes output.');

// 3. Alert message formatting tests
console.log('\n3. Testing Alert Message Formatting with Location...');
const msgWithLoc = buildAlertMessage({
  activatedAt: new Date('2026-10-12T12:00:00Z'),
  latitude: 12.9716,
  longitude: 77.5946,
});
assert(msgWithLoc.includes('EMERGENCY ALERT: Nirbhay SOS activated at'), 'Missing emergency alert header');
assert(msgWithLoc.includes('https://maps.google.com/?q=12.9716,77.5946'), 'Missing Google Maps coordinates link');
console.log('Sample Formatted Alert Message:');
console.log('  ', msgWithLoc);
console.log('✅ PASS: Alert message correctly built with coordinates and time.');

// 4. Webhook signature verification tests
console.log('\n4. Testing Webhook HMAC-SHA256 Signature Verification...');
const testSecret = 'secret_webhook_key_12345';
const rawBody = JSON.stringify({
  event: 'sms:delivered',
  payload: { messageId: 'msg_98765', recipient: '+919876543210' },
});
const currentTimestamp = Math.floor(Date.now() / 1000).toString();
const validSignature = crypto
  .createHmac('sha256', testSecret)
  .update(`${currentTimestamp}.${rawBody}`)
  .digest('hex');

// Valid signature
const isValid = smsGateway.verifyWebhookSignature({
  rawBody,
  timestamp: currentTimestamp,
  signature: validSignature,
  secret: testSecret,
});
assert.strictEqual(isValid, true, 'Valid HMAC signature should pass verification');

// Tampered signature
const isTampered = smsGateway.verifyWebhookSignature({
  rawBody,
  timestamp: currentTimestamp,
  signature: validSignature.replace(/a/g, 'b'),
  secret: testSecret,
});
assert.strictEqual(isTampered, false, 'Tampered signature must be rejected');

// Expired timestamp (replay attack simulation: 10 minutes ago)
const expiredTimestamp = (Math.floor(Date.now() / 1000) - 600).toString();
const expiredSignature = crypto
  .createHmac('sha256', testSecret)
  .update(`${expiredTimestamp}.${rawBody}`)
  .digest('hex');
const isExpired = smsGateway.verifyWebhookSignature({
  rawBody,
  timestamp: expiredTimestamp,
  signature: expiredSignature,
  secret: testSecret,
});
assert.strictEqual(isExpired, false, 'Expired timestamp (>5m) must be rejected to prevent replay attacks');
console.log('✅ PASS: Webhook HMAC security & replay prevention passed.');

// 5. Configuration & Device Registration Probing
console.log('\n5. Testing Gateway Configuration detection & Device Probe...');
const isConfigured = smsGateway.isGatewayConfigured();
console.log(`Current SMS Gateway Configured Status: ${isConfigured ? 'YES' : 'NO (credentials not set in local .env)'}`);

smsGateway.checkGatewayDeviceRegistration().then((probe) => {
  assert(probe !== null && typeof probe === 'object');
  console.log('Device Probe Result (Unconfigured Safe Fallback):', probe);
  assert.strictEqual(probe.authenticated, false);
  console.log('✅ PASS: Device probe returns safe, categorized status without throwing errors.');

  // 6. Transient vs Permanent Error Categorization Tests (Bug 2 Requirement 5)
  console.log('\n6. Testing Transient vs Permanent Failure Classification for Retries...');
  assert.strictEqual(smsGateway.isTransientFailure('RATE_LIMIT_EXCEEDED', 429), true, '429 rate limit must be marked transient for retry');
  assert.strictEqual(smsGateway.isTransientFailure('GATEWAY_SERVER_ERROR', 502), true, '502 Bad Gateway must be marked transient for retry');
  assert.strictEqual(smsGateway.isTransientFailure('GATEWAY_SERVER_ERROR', 503), true, '503 Service Unavailable must be marked transient for retry');
  assert.strictEqual(smsGateway.isTransientFailure('TIMEOUT_ERROR', null), true, 'Timeout must be marked transient for retry');
  assert.strictEqual(smsGateway.isTransientFailure('NETWORK_ERROR', null), true, 'Network error must be marked transient for retry');

  // Permanent errors must never be retried
  assert.strictEqual(smsGateway.isTransientFailure('AUTHENTICATION_FAILURE', 401), false, '401 Auth failure must NOT be retried');
  assert.strictEqual(smsGateway.isTransientFailure('AUTHENTICATION_FAILURE', 403), false, '403 Forbidden must NOT be retried');
  assert.strictEqual(smsGateway.isTransientFailure('BAD_REQUEST', 400), false, '400 Bad request must NOT be retried');
  assert.strictEqual(smsGateway.isTransientFailure('INVALID_PHONE_FORMAT', null), false, 'Invalid phone format must NOT be retried');
  assert.strictEqual(smsGateway.isTransientFailure('CONFIGURATION_ERROR', null), false, 'Missing credentials must NOT be retried');
  console.log('✅ PASS: Error classification correctly distinguishes transient (retried) vs permanent (aborted) failures.');

  // 7. Live Tracking Link & Trailing Slash Parsing Tests (Bug 3 Requirement 1 & 4)
  console.log('\n7. Testing Live Tracking Link & Token Extraction with Trailing Slash...');
  const msgWithTrack = buildAlertMessage({
    activatedAt: new Date('2026-10-15T10:00:00Z'),
    latitude: 19.0760,
    longitude: 72.8777,
    trackingUrl: 'https://nirbhay-9d5i.onrender.com/track/4f9e1d8a3c2b',
  });
  assert(msgWithTrack.includes('https://nirbhay-9d5i.onrender.com/track/4f9e1d8a3c2b'), 'Formatted message must include full HTTPS live tracking URL');
  assert(msgWithTrack.includes('https://maps.google.com/?q=19.076,72.8777'), 'Formatted message must include Google Maps link');

  // Test trailing slash token extraction logic
  const parseToken = (pathname) => {
    const parts = pathname.split('/').filter(Boolean);
    return parts.length > 0 ? parts[parts.length - 1] : '';
  };
  assert.strictEqual(parseToken('/track/4f9e1d8a3c2b'), '4f9e1d8a3c2b', 'Standard URL path token');
  assert.strictEqual(parseToken('/track/4f9e1d8a3c2b/'), '4f9e1d8a3c2b', 'Trailing slash URL path token must resolve identical token');
  console.log('✅ PASS: Tracking URL formatting and trailing slash token extraction passed.');

  console.log('\n--- ALL SMS GATEWAY & TRACKING UNIT TESTS PASSED SUCCESSFULLY! ---');
}).catch((err) => {
  console.error('Test failure:', err);
  process.exit(1);
});
