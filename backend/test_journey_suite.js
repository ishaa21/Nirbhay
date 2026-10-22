/**
 * test_journey_suite.js
 * Comprehensive integration test suite for Live Journey Tracking backend.
 */
require('dotenv').config();
process.env.SMS_TEST_MODE = 'true';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'nirbhay_test_secret_2026';

const http = require('http');
const express = require('express');
const jwt = require('jsonwebtoken');

// ── In-Memory Database ──────────────────────────────────────────────────────
const mockJourneys = [];
const mockLocations = [];
const mockUsers = [
  { id: 'user-uuid-1', full_name: 'Dhwani Patel', email: 'dhwani@example.com' },
];
const mockContacts = [
  { id: 'contact-1', user_id: 'user-uuid-1', name: 'Mom', phone: '+919876543210', auto_alert: true },
];

const mockDb = {
  query: async (text, params = []) => {
    const clean = text.replace(/\s+/g, ' ').trim();

    // 1. SELECT id, started_at FROM journeys WHERE user_id = $1 AND status = 'ACTIVE' ORDER BY started_at DESC LIMIT 1
    if (clean.includes('FROM journeys') && clean.includes("status = 'ACTIVE'") && clean.includes('LIMIT 1')) {
      const userId = params[0];
      const found = mockJourneys.filter(j => j.user_id === userId && j.status === 'ACTIVE');
      found.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
      return { rows: found.slice(0, 1) };
    }

    // 2. INSERT INTO journeys
    if (clean.includes('INSERT INTO journeys')) {
      const [userId, lat, lng, dest, token, url, routeDev, devThresh] = params;
      const newJourney = {
        id: `journey-uuid-${mockJourneys.length + 1}`,
        user_id: userId,
        status: 'ACTIVE',
        start_latitude: lat,
        start_longitude: lng,
        last_known_latitude: lat,
        last_known_longitude: lng,
        destination: dest,
        tracking_token: token,
        tracking_url: url,
        route_deviation_enabled: routeDev,
        deviation_threshold_meters: devThresh,
        started_at: new Date().toISOString(),
        ended_at: null,
      };
      mockJourneys.push(newJourney);
      return { rows: [newJourney] };
    }

    // 3. SELECT full_name FROM users WHERE id = $1
    if (clean.includes('FROM users WHERE id = $1')) {
      const user = mockUsers.find(u => u.id === params[0]) || { full_name: 'Test User' };
      return { rows: [user] };
    }

    // 4. SELECT * FROM journeys WHERE tracking_token = $1
    if (clean.includes('FROM journeys') && clean.includes('tracking_token = $1')) {
      const token = params[0];
      const journey = mockJourneys.find(j => j.tracking_token === token);
      if (journey) {
        return { rows: [{ ...journey, user_name: 'Dhwani Patel' }] };
      }
      return { rows: [] };
    }

    // 5. UPDATE journeys SET status = 'COMPLETED'
    if (clean.includes('UPDATE journeys SET status')) {
      const id = params[1] || params[0];
      const status = params[0] === 'COMPLETED' || params[0] === 'CANCELLED' ? params[0] : 'COMPLETED';
      const journey = mockJourneys.find(j => j.id === id);
      if (journey) {
        journey.status = status;
        journey.ended_at = new Date().toISOString();
        return { rows: [journey] };
      }
      return { rows: [] };
    }

    // 6. SELECT id, status FROM journeys WHERE id = $1 AND user_id = $2
    if (clean.includes('FROM journeys WHERE id = $1 AND user_id = $2')) {
      const [id, userId] = params;
      const journey = mockJourneys.find(j => j.id === id && j.user_id === userId);
      return { rows: journey ? [journey] : [] };
    }

    // 7. INSERT INTO journey_locations
    if (clean.includes('INSERT INTO journey_locations')) {
      const [journeyId, lat, lng, acc, spd, hdg] = params;
      const loc = {
        id: mockLocations.length + 1,
        journey_id: journeyId,
        latitude: lat,
        longitude: lng,
        accuracy: acc,
        speed: spd,
        heading: hdg,
        recorded_at: new Date().toISOString(),
      };
      mockLocations.push(loc);
      return { rows: [loc] };
    }

    // 8. UPDATE journeys SET last_known_latitude
    if (clean.includes('UPDATE journeys SET last_known_latitude')) {
      const [lat, lng, id] = params;
      const journey = mockJourneys.find(j => j.id === id);
      if (journey) {
        journey.last_known_latitude = lat;
        journey.last_known_longitude = lng;
      }
      return { rows: [journey] };
    }

    // 9. Location history / latest location
    if (clean.includes('FROM journey_locations WHERE journey_id = $1')) {
      const [journeyId] = params;
      const locs = mockLocations.filter(l => l.journey_id === journeyId);
      locs.sort((a, b) => new Date(b.recorded_at) - new Date(a.recorded_at));
      return { rows: locs.slice(0, 1) };
    }

    // 10. SELECT phone, name FROM emergency_contacts
    if (clean.includes('FROM emergency_contacts')) {
      return { rows: mockContacts };
    }

    // 11. Fallback for journey by id
    if (clean.includes('FROM journeys j') && clean.includes('WHERE j.id = $1')) {
      const journey = mockJourneys.find(j => j.id === params[0]);
      if (journey) {
        return { rows: [{ ...journey, user_name: 'Dhwani Patel' }] };
      }
      return { rows: [] };
    }

    return { rows: [] };
  },
};

// Override database in require cache
const dbPath = require.resolve('./src/config/db');
require.cache[dbPath] = { exports: mockDb };

// Build Express app
const app = express();
app.use(express.json());

const journeyRoutes = require('./src/routes/journeyRoutes');
app.use('/api/journey', journeyRoutes);

// Auth Token helper
const testToken = jwt.sign(
  { userId: 'user-uuid-1', email: 'dhwani@example.com' },
  process.env.JWT_SECRET,
  { expiresIn: '1h' }
);

function makeRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : '';
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (body) headers['Content-Length'] = Buffer.byteLength(postData);

    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: server.address().port,
        path,
        method,
        headers,
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () => {
          let data = {};
          try {
            data = JSON.parse(raw);
          } catch (_) {
            data = { raw };
          }
          resolve({ status: res.statusCode, data });
        });
      }
    );

    req.on('error', reject);
    if (body) req.write(postData);
    req.end();
  });
}

let server;
let passed = 0;
let failed = 0;

function assert(cond, desc) {
  if (cond) {
    console.log(`  ✅ PASS: ${desc}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${desc}`);
    failed++;
  }
}

async function runTests() {
  server = http.createServer(app);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));

  console.log('╔═══════════════════════════════════════════════════════════════╗');
  console.log('║       NIRBHAY LIVE JOURNEY TRACKING TEST SUITE                ║');
  console.log('╚═══════════════════════════════════════════════════════════════╝\n');

  console.log('--- [1] Authentication Guard ---');
  let res = await makeRequest('GET', '/api/journey/active');
  assert(res.status === 401, 'Rejects unauthenticated GET /active with 401');

  res = await makeRequest('POST', '/api/journey', { destination: 'Home' });
  assert(res.status === 401, 'Rejects unauthenticated POST /journey with 401');

  console.log('\n--- [2] Initial Idle State ---');
  res = await makeRequest('GET', '/api/journey/active', null, testToken);
  assert(res.status === 200, 'GET /active returns 200');
  assert(res.data.active === false, 'active is false when none exists');
  assert(res.data.journey === null, 'journey is null when idle');

  console.log('\n--- [3] Start Journey Session ---');
  res = await makeRequest('POST', '/api/journey', {
    destination: 'Home',
    latitude: 28.6139,
    longitude: 77.2090,
  }, testToken);
  assert(res.status === 201, 'POST /journey returns 201 Created');
  assert(res.data.success === true, 'Response reports success: true');
  assert(res.data.journey != null, 'Journey record returned');
  assert(res.data.journey.status === 'ACTIVE', 'Journey status is ACTIVE');
  assert(typeof res.data.trackingUrl === 'string' && res.data.trackingUrl.includes('/track/'), 'Tracking URL generated');

  const journeyId = res.data.journey.id;
  const trackingToken = res.data.journey.tracking_token;

  console.log('\n--- [4] Active Journey Query ---');
  res = await makeRequest('GET', '/api/journey/active', null, testToken);
  assert(res.status === 200, 'GET /active returns 200');
  assert(res.data.active === true, 'active is true when journey is running');
  assert(res.data.journey.id === journeyId, 'Returns correct running journey ID');

  console.log('\n--- [5] Duplicate Prevention & ForceNew ---');
  res = await makeRequest('POST', '/api/journey', { destination: 'Office' }, testToken);
  assert(res.status === 409, 'Rejects duplicate journey without forceNew with 409 Conflict');
  assert(res.data.code === 'ACTIVE_JOURNEY_EXISTS', 'Returns code ACTIVE_JOURNEY_EXISTS');

  res = await makeRequest('POST', '/api/journey', { destination: 'Office', forceNew: true }, testToken);
  assert(res.status === 201, 'POST /journey with forceNew=true completes old and starts new (201)');
  const newJourneyId = res.data.journey.id;
  assert(newJourneyId !== journeyId, 'New journey created with new ID');

  console.log('\n--- [6] Upload GPS Breadcrumb ---');
  res = await makeRequest('POST', `/api/journey/${newJourneyId}/location`, {
    latitude: 28.6200,
    longitude: 77.2150,
    accuracy: 10.5,
    speed: 5.2,
    heading: 90.0,
  }, testToken);
  assert(res.status === 200, 'POST /:id/location returns 200 OK');
  assert(res.data.success === true, 'Location upload reported success');

  console.log('\n--- [7] Public Live Tracking Link ---');
  const newToken = res.data.journey?.tracking_token || mockJourneys.find(j => j.id === newJourneyId)?.tracking_token;
  res = await makeRequest('GET', `/api/journey/track/${newToken}`);
  assert(res.status === 200, 'GET /track/:token returns 200 without JWT');
  assert(res.data.active === true, 'Public endpoint reports active: true');
  assert(res.data.userName === 'Dhwani', 'Exposes sanitized first name');

  console.log('\n--- [8] End Journey ---');
  res = await makeRequest('PATCH', `/api/journey/${newJourneyId}/end`, { reason: 'COMPLETED' }, testToken);
  assert(res.status === 200, 'PATCH /:id/end returns 200 OK');
  assert(res.data.journey.status === 'COMPLETED', 'Journey status updated to COMPLETED');

  console.log('\n--- [9] State After Ending ---');
  res = await makeRequest('GET', '/api/journey/active', null, testToken);
  assert(res.status === 200, 'GET /active returns 200');
  assert(res.data.active === false, 'active is false after journey ended');
  assert(res.data.journey === null, 'journey is null after journey ended');

  console.log('\n--- [10] End Active Journey By Identifier ---');
  // Start another journey to test ending via /active/end
  res = await makeRequest('POST', '/api/journey', { destination: 'Station' }, testToken);
  assert(res.status === 201, 'Started new journey for active/end test');

  res = await makeRequest('PATCH', '/api/journey/active/end', { reason: 'COMPLETED' }, testToken);
  assert(res.status === 200, 'PATCH /active/end successfully ends active journey');

  res = await makeRequest('GET', '/api/journey/active', null, testToken);
  assert(res.data.active === false, 'active is false after /active/end');

  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log(`  RESULTS: ${passed} PASSED | ${failed} FAILED`);
  console.log('═══════════════════════════════════════════════════════════════\n');

  server.close();
  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch((e) => {
  console.error('Test error:', e);
  if (server) server.close();
  process.exit(1);
});
