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

  console.log('\n--- ALL SMS GATEWAY UNIT TESTS PASSED SUCCESSFULLY! ---');
}).catch((err) => {
  console.error('Test failure:', err);
  process.exit(1);
});
