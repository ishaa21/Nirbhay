const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const http = require('http');
const express = require('express');

const db = require('./src/config/db');
const { uploadLocation, getTrackingData } = require('./src/controllers/trackingController');

// Test runner helper
let passedCount = 0;
let failedCount = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  [PASS] ${message}`);
    passedCount++;
  } else {
    console.error(`  [FAIL] ${message}`);
    failedCount++;
  }
}

async function runTests() {
  console.log('====================================================');
  console.log('   NIRBHAY LIVE TRACKING BACKEND VERIFICATION TEST   ');
  console.log('====================================================\n');

  // Verify DB connection
  try {
    const dbTest = await db.query('SELECT NOW()');
    console.log(`[DB] Connected to PostgreSQL. Timestamp: ${dbTest.rows[0].now}\n`);
  } catch (err) {
    console.error('[DB] Connection failed:', err.message);
    process.exit(1);
  }

  // 1. Fetch or create a test user
  let userRes = await db.query("SELECT id, full_name, email FROM users LIMIT 1");
  let testUser = userRes.rows[0];
  if (!testUser) {
    const newUid = crypto.randomUUID();
    await db.query(
      "INSERT INTO users (id, full_name, email, password, phone) VALUES ($1, 'Test Tracker User', 'tracker@example.com', 'hashedpass', '+919876543210')",
      [newUid]
    );
    testUser = { id: newUid, full_name: 'Test Tracker User' };
  }
  console.log(`[User] Using test user: ${testUser.full_name} (${testUser.id})`);

  // Clean up any stale active incidents for this test user
  await db.query("UPDATE sos_incidents SET status = 'RESOLVED' WHERE user_id = $1 AND status = 'ACTIVE'", [testUser.id]);

  // Create an active test SOS incident
  const activeToken = crypto.randomBytes(24).toString('hex');
  const incidentRes = await db.query(
    `INSERT INTO sos_incidents (user_id, status, latitude, longitude, activated_at, notification_status, tracking_token)
     VALUES ($1, 'ACTIVE', 22.2500, 73.2000, CURRENT_TIMESTAMP, 'PENDING', $2)
     RETURNING *`,
    [testUser.id, activeToken]
  );
  const activeIncident = incidentRes.rows[0];
  console.log(`[SOS] Created active SOS incident: ${activeIncident.id} with token: ${activeToken}\n`);

  // Mock response object builder
  function mockRes() {
    return {
      statusCode: 200,
      body: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.body = data;
        return this;
      },
    };
  }

  // ── TEST SUITE 1: Coordinate Validation ──────────────────────────────────
  console.log('1. Testing Coordinate Validation & Rejection');
  {
    const req = {
      userId: testUser.id,
      params: { id: activeIncident.id },
      body: { latitude: 95.0, longitude: 73.2000 }, // Invalid lat > 90
    };
    const res = mockRes();
    await uploadLocation(req, res);
    assert(res.statusCode === 400, 'Rejects latitude > 90 with HTTP 400');
  }
  {
    const req = {
      userId: testUser.id,
      params: { id: activeIncident.id },
      body: { latitude: 22.2500, longitude: 200.0 }, // Invalid lng > 180
    };
    const res = mockRes();
    await uploadLocation(req, res);
    assert(res.statusCode === 400, 'Rejects longitude > 180 with HTTP 400');
  }
  {
    const req = {
      userId: testUser.id,
      params: { id: activeIncident.id },
      body: { latitude: 'abc', longitude: 73.2000 }, // Not a number
    };
    const res = mockRes();
    await uploadLocation(req, res);
    assert(res.statusCode === 400, 'Rejects non-numeric latitude with HTTP 400');
  }
  {
    const req = {
      userId: testUser.id,
      params: { id: activeIncident.id },
      body: {}, // Missing lat/lng
    };
    const res = mockRes();
    await uploadLocation(req, res);
    assert(res.statusCode === 400, 'Rejects missing coordinates with HTTP 400');
  }

  // ── TEST SUITE 2: Single Coordinate Upload & Persistence ─────────────────
  console.log('\n2. Testing Single Coordinate Upload & Canonical Update');
  {
    const testLat = 22.2512;
    const testLng = 73.2045;
    const testAcc = 14.5;
    const req = {
      userId: testUser.id,
      params: { id: activeIncident.id },
      body: { latitude: testLat, longitude: testLng, accuracy: testAcc },
    };
    const res = mockRes();
    await uploadLocation(req, res);
    assert(res.statusCode === 200, 'Accepts valid GPS coordinate with HTTP 200');
    assert(res.body && res.body.success === true, 'Response contains success: true');

    // Verify persisted in sos_location_updates
    const checkDb = await db.query(
      `SELECT latitude, longitude, accuracy FROM sos_location_updates WHERE sos_id = $1 ORDER BY recorded_at DESC LIMIT 1`,
      [activeIncident.id]
    );
    assert(checkDb.rows.length > 0, 'Coordinate saved in sos_location_updates table');
    assert(Math.abs(parseFloat(checkDb.rows[0].latitude) - testLat) < 0.0001, 'Latitude matches in database');
    assert(Math.abs(parseFloat(checkDb.rows[0].longitude) - testLng) < 0.0001, 'Longitude matches in database');

    // Verify canonical updated on sos_incidents
    const checkIncident = await db.query(`SELECT latitude, longitude FROM sos_incidents WHERE id = $1`, [activeIncident.id]);
    assert(Math.abs(parseFloat(checkIncident.rows[0].latitude) - testLat) < 0.0001, 'Canonical incident latitude updated');
  }

  // ── TEST SUITE 3: Duplicate Suppression ──────────────────────────────────
  console.log('\n3. Testing Duplicate Coordinate Suppression');
  {
    const initialCountRes = await db.query(`SELECT COUNT(*) as c FROM sos_location_updates WHERE sos_id = $1`, [activeIncident.id]);
    const initialCount = parseInt(initialCountRes.rows[0].c, 10);

    // Upload exact same coordinate immediately
    const req = {
      userId: testUser.id,
      params: { id: activeIncident.id },
      body: { latitude: 22.2512, longitude: 73.2045, accuracy: 14.5 },
    };
    const res = mockRes();
    await uploadLocation(req, res);
    assert(res.statusCode === 200, 'Duplicate upload returns HTTP 200');

    const newCountRes = await db.query(`SELECT COUNT(*) as c FROM sos_location_updates WHERE sos_id = $1`, [activeIncident.id]);
    const newCount = parseInt(newCountRes.rows[0].c, 10);
    assert(newCount === initialCount, 'Duplicate coordinate within 5 seconds suppressed (no duplicate DB row)');
  }

  // ── TEST SUITE 4: Offline Queue Batch Replay ─────────────────────────────
  console.log('\n4. Testing Offline Queue Batch Upload');
  {
    const now = Date.now();
    const batchUpdates = [
      { latitude: 22.2520, longitude: 73.2050, accuracy: 12.0, recorded_at: new Date(now - 30000).toISOString() },
      { latitude: 22.2530, longitude: 73.2060, accuracy: 10.0, recorded_at: new Date(now - 15000).toISOString() },
      { latitude: 22.2540, longitude: 73.2070, accuracy: 8.0, recorded_at: new Date(now).toISOString() },
    ];
    const req = {
      userId: testUser.id,
      params: { id: activeIncident.id },
      body: { updates: batchUpdates },
    };
    const res = mockRes();
    await uploadLocation(req, res);
    assert(res.statusCode === 200, 'Accepts offline batch updates with HTTP 200');
    assert(res.body && res.body.inserted === 3, 'All 3 buffered offline updates persisted');

    // Canonical coords on incident should be updated to the newest fix (22.2540, 73.2070)
    const checkIncident = await db.query(`SELECT latitude, longitude FROM sos_incidents WHERE id = $1`, [activeIncident.id]);
    assert(Math.abs(parseFloat(checkIncident.rows[0].latitude) - 22.2540) < 0.0001, 'Canonical coords set to newest fix in batch');
  }

  // ── TEST SUITE 5: Public Tracking Data API (Token Auth) ──────────────────
  console.log('\n5. Testing Public Live Tracking Data Endpoint');
  {
    const req = { params: { token: activeToken } };
    const res = mockRes();
    await getTrackingData(req, res);
    assert(res.statusCode === 200, 'Valid token returns HTTP 200 without JWT');
    assert(res.body && res.body.active === true, 'Indicates active: true');
    assert(res.body && res.body.status === 'ACTIVE', 'Indicates status: ACTIVE');
    assert(res.body && res.body.userName === testUser.full_name.split(' ')[0], 'Exposes only first name for privacy');
    assert(Math.abs(res.body.latitude - 22.2540) < 0.0001, 'Returns latest latitude');
    assert(Math.abs(res.body.longitude - 73.2070) < 0.0001, 'Returns latest longitude');
    assert(res.body.lastUpdatedAt !== null, 'Includes lastUpdatedAt timestamp');
  }
  {
    // Test invalid / missing token (< 10 chars)
    const req = { params: { token: 'short' } };
    const res = mockRes();
    await getTrackingData(req, res);
    assert(res.statusCode === 400, 'Short/malformed token rejected with HTTP 400');
  }
  {
    // Test non-existent token
    const req = { params: { token: '000000000000000000000000000000000000000000000000' } };
    const res = mockRes();
    await getTrackingData(req, res);
    assert(res.statusCode === 404, 'Non-existent token rejected with HTTP 404');
  }

  // ── TEST SUITE 6: Incident Resolution & Tracking Expiration ──────────────
  console.log('\n6. Testing SOS Resolution & Tracking Expiration');
  {
    await db.query(`UPDATE sos_incidents SET status = 'RESOLVED', resolved_at = CURRENT_TIMESTAMP WHERE id = $1`, [activeIncident.id]);

    // Subsequent location upload should be rejected
    const req = {
      userId: testUser.id,
      params: { id: activeIncident.id },
      body: { latitude: 22.2550, longitude: 73.2080 },
    };
    const res = mockRes();
    await uploadLocation(req, res);
    assert(res.statusCode === 400, 'Upload rejected when incident is RESOLVED');

    // Public tracking page should reflect RESOLVED status
    const trackReq = { params: { token: activeToken } };
    const trackRes = mockRes();
    await getTrackingData(trackReq, trackRes);
    assert(trackRes.statusCode === 200, 'Tracking link still accessible after resolution');
    assert(trackRes.body && trackRes.body.active === false, 'Indicates active: false');
    assert(trackRes.body && trackRes.body.status === 'RESOLVED', 'Status is RESOLVED');
    assert(trackRes.body && trackRes.body.resolvedAt !== null, 'Includes resolvedAt timestamp');
  }

  // Clean up test incident
  await db.query(`DELETE FROM sos_location_updates WHERE sos_id = $1`, [activeIncident.id]);
  await db.query(`DELETE FROM sos_incidents WHERE id = $1`, [activeIncident.id]);

  console.log('\n====================================================');
  console.log(`TEST SUMMARY: ${passedCount} PASSED, ${failedCount} FAILED`);
  console.log('====================================================\n');

  await db.pool.end();
  process.exit(failedCount > 0 ? 1 : 0);
}

runTests().catch(err => {
  console.error('Test runner fatal error:', err);
  process.exit(1);
});
