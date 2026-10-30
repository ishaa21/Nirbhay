require('dotenv').config();
const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const db = require('../src/config/db');
const {
  CATEGORY_WEIGHTS,
  haversineDistanceMeters,
  getRecencyDecay,
  clusterReports,
  computeHotspotDetails,
  evaluateRouteProximity,
} = require('../src/services/hotspotScoringService');
const {
  getSafetyHotspots,
  getNearbyHotspots,
  getHotspotById,
  submitHotspotFeedback,
  checkRouteHotspots,
} = require('../src/controllers/communityController');

describe('Safety Hotspots & Proactive Route Warning Tests', () => {
  let testUserId1;
  let testUserId2;
  let testUserId3;
  let testUserToken1;
  let createdPostIds = [];

  before(async () => {
    // Create test users
    const u1 = await db.query(
      `INSERT INTO users (full_name, email, password_hash, phone)
       VALUES ('Ananya Sharma', 'hotspot_user1@nirbhay.local', 'mockhash', '+919811111111')
       RETURNING id`
    );
    testUserId1 = u1.rows[0].id;

    const u2 = await db.query(
      `INSERT INTO users (full_name, email, password_hash, phone)
       VALUES ('Neha Patel', 'hotspot_user2@nirbhay.local', 'mockhash', '+919822222222')
       RETURNING id`
    );
    testUserId2 = u2.rows[0].id;

    const u3 = await db.query(
      `INSERT INTO users (full_name, email, password_hash, phone)
       VALUES ('Kavita Rao', 'hotspot_user3@nirbhay.local', 'mockhash', '+919833333333')
       RETURNING id`
    );
    testUserId3 = u3.rows[0].id;

    const secret = process.env.JWT_SECRET || 'secret';
    testUserToken1 = jwt.sign({ userId: testUserId1, email: 'hotspot_user1@nirbhay.local' }, secret, { expiresIn: '1h' });
  });

  after(async () => {
    try {
      if (createdPostIds.length > 0) {
        await db.query('DELETE FROM community_posts WHERE id = ANY($1)', [createdPostIds]);
      }
      if (testUserId1 || testUserId2 || testUserId3) {
        await db.query(
          "DELETE FROM users WHERE email IN ('hotspot_user1@nirbhay.local', 'hotspot_user2@nirbhay.local', 'hotspot_user3@nirbhay.local')"
        );
      }
    } catch (_) {}
  });

  // ── 1. Unit Tests for Scoring & Spatial Math ───────────────────────────────

  test('Geospatial Math: haversineDistanceMeters calculates accurate distance', () => {
    // Distance between Connaught Place (28.6315, 77.2167) and India Gate (28.6129, 77.2295) is ~2.4km
    const dist = haversineDistanceMeters(28.6315, 77.2167, 28.6129, 77.2295);
    assert.ok(dist >= 2300 && dist <= 2600, `Expected ~2450m, got ${dist}`);

    // Distance to same point is 0
    assert.equal(haversineDistanceMeters(28.6, 77.2, 28.6, 77.2), 0);
  });

  test('Recency Decay: fresh reports have full weight, old reports decay, >30 days expire', () => {
    const now = new Date();
    const twoDaysAgo = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
    const fiveDaysAgo = new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000);
    const tenDaysAgo = new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000);
    const twentyDaysAgo = new Date(now.getTime() - 20 * 24 * 60 * 60 * 1000);
    const fortyDaysAgo = new Date(now.getTime() - 40 * 24 * 60 * 60 * 1000);

    assert.equal(getRecencyDecay(twoDaysAgo, now), 1.0);
    assert.equal(getRecencyDecay(fiveDaysAgo, now), 0.8);
    assert.equal(getRecencyDecay(tenDaysAgo, now), 0.55);
    assert.equal(getRecencyDecay(twentyDaysAgo, now), 0.25);
    assert.equal(getRecencyDecay(fortyDaysAgo, now), 0.0); // Expired
  });

  test('Clustering: Groups nearby reports within 280m and separates distant reports', () => {
    const reports = [
      { id: '1', latitude: 28.6139, longitude: 77.2090 }, // Center
      { id: '2', latitude: 28.6145, longitude: 77.2095 }, // ~80m away
      { id: '3', latitude: 28.6500, longitude: 77.2300 }, // ~4km away (separate)
    ];

    const clusters = clusterReports(reports, 280);
    assert.equal(clusters.length, 2);
    assert.equal(clusters[0].length, 2);
    assert.equal(clusters[1].length, 1);
  });

  test('Rule 1: A single author CANNOT create a RED risk zone even with multiple reports', () => {
    const now = new Date();
    const singleAuthorCluster = [
      {
        id: 'r1',
        user_id: 'user_A',
        category: 'HARASSMENT',
        latitude: 28.6139,
        longitude: 77.2090,
        upvotes_count: 5,
        confirmations_count: 3,
        disputes_count: 0,
        created_at: now.toISOString(),
      },
      {
        id: 'r2',
        user_id: 'user_A', // Same author!
        category: 'UNSAFE_AREA',
        latitude: 28.6141,
        longitude: 77.2092,
        upvotes_count: 2,
        confirmations_count: 1,
        disputes_count: 0,
        created_at: now.toISOString(),
      },
      {
        id: 'r3',
        user_id: 'user_A', // Same author!
        category: 'SUSPICIOUS_ACTIVITY',
        latitude: 28.6140,
        longitude: 77.2091,
        upvotes_count: 1,
        confirmations_count: 0,
        disputes_count: 0,
        created_at: now.toISOString(),
      },
    ];

    const hotspot = computeHotspotDetails(singleAuthorCluster, now);
    assert.ok(hotspot !== null);
    assert.equal(hotspot.independentAuthorCount, 1);
    // MUST NOT be RED because independent author count < 2!
    assert.notEqual(hotspot.riskLevel, 'RED', 'Single author must never generate a RED hotspot zone');
  });

  test('Rule 2: Multiple independent authors with severe reports produce an appropriately weighted RED hotspot', () => {
    const now = new Date();
    const multiAuthorCluster = [
      {
        id: 'r10',
        user_id: 'user_A',
        category: 'HARASSMENT',
        latitude: 28.6139,
        longitude: 77.2090,
        upvotes_count: 4,
        confirmations_count: 2,
        disputes_count: 0,
        created_at: now.toISOString(),
      },
      {
        id: 'r11',
        user_id: 'user_B', // Second independent author
        category: 'HARASSMENT',
        latitude: 28.6142,
        longitude: 77.2093,
        upvotes_count: 3,
        confirmations_count: 1,
        disputes_count: 0,
        created_at: now.toISOString(),
      },
      {
        id: 'r12',
        user_id: 'user_C', // Third independent author
        category: 'UNSAFE_AREA',
        latitude: 28.6140,
        longitude: 77.2091,
        upvotes_count: 2,
        confirmations_count: 1,
        disputes_count: 0,
        created_at: now.toISOString(),
      },
      {
        id: 'r13',
        user_id: 'user_D', // Fourth independent author
        category: 'SUSPICIOUS_ACTIVITY',
        latitude: 28.6143,
        longitude: 77.2094,
        upvotes_count: 1,
        confirmations_count: 1,
        disputes_count: 0,
        created_at: now.toISOString(),
      },
    ];

    const hotspot = computeHotspotDetails(multiAuthorCluster, now);
    assert.ok(hotspot !== null);
    assert.equal(hotspot.independentAuthorCount, 4);
    assert.equal(hotspot.riskLevel, 'RED');
    assert.equal(hotspot.verificationStatus, 'COMMUNITY_VERIFIED');
    assert.ok(hotspot.riskScore >= 4.0);
  });

  test('Rule 3: Old/expired reports do not create active hotspots', () => {
    const now = new Date();
    const expiredDate = new Date(now.getTime() - 45 * 24 * 60 * 60 * 1000); // 45 days ago

    const expiredCluster = [
      {
        id: 'exp1',
        user_id: 'user_X',
        category: 'UNSAFE_AREA',
        latitude: 28.6139,
        longitude: 77.2090,
        upvotes_count: 0,
        confirmations_count: 0,
        disputes_count: 0,
        created_at: expiredDate.toISOString(),
      },
    ];

    const hotspot = computeHotspotDetails(expiredCluster, now);
    assert.equal(hotspot, null, 'Expired reports must not yield an active hotspot');
  });

  // ── 2. Route Proximity Detection Unit Tests ────────────────────────────────

  test('Route Alert: Detects when user path approaches a hotspot within warning distance', () => {
    const hotspot = {
      center: { latitude: 28.6200, longitude: 77.2100 },
      radiusMeters: 180,
    };

    // User is at 28.6160, 77.2100 (~440m south) heading towards hotspot
    const userLocation = { latitude: 28.6160, longitude: 77.2100 };
    const routeWaypoints = [
      { latitude: 28.6160, longitude: 77.2100 },
      { latitude: 28.6250, longitude: 77.2100 }, // Route goes straight north through hotspot
    ];

    const result = evaluateRouteProximity(hotspot, userLocation, routeWaypoints, 350, 600);
    assert.equal(result.isApproaching, true);
    assert.equal(result.isAlongRoute, true);
    assert.ok(result.tier === 'EARLY' || result.tier === 'APPROACHING');
  });

  test('Route Alert: Does NOT alert for a hotspot outside the route corridor', () => {
    const hotspot = {
      center: { latitude: 28.6200, longitude: 77.2300 }, // ~2km to the East
      radiusMeters: 150,
    };

    // User is moving North along 77.2100
    const userLocation = { latitude: 28.6160, longitude: 77.2100 };
    const routeWaypoints = [
      { latitude: 28.6160, longitude: 77.2100 },
      { latitude: 28.6300, longitude: 77.2100 },
    ];

    const result = evaluateRouteProximity(hotspot, userLocation, routeWaypoints, 350, 600);
    assert.equal(result.isApproaching, false);
    assert.equal(result.isAlongRoute, false);
  });

  // ── 3. Integration Tests for Hotspot Endpoints ──────────────────────────────

  test('Integration: Seed community reports and query safety hotspots', async () => {
    // Insert 2 real reports in close proximity (<100m) from testUserId1 and testUserId2
    const p1 = await db.query(
      `INSERT INTO community_posts (user_id, category, title, description, location_name, latitude, longitude, status, moderation_status)
       VALUES ($1, 'HARASSMENT', 'Catcalling near metro gate 2', 'Group gathering and catcalling late evenings', 'Metro Station Gate 2', 28.6250, 77.2150, 'ACTIVE', 'APPROVED')
       RETURNING id`,
      [testUserId1]
    );
    createdPostIds.push(p1.rows[0].id);

    const p2 = await db.query(
      `INSERT INTO community_posts (user_id, category, title, description, location_name, latitude, longitude, status, moderation_status)
       VALUES ($1, 'UNSAFE_AREA', 'Broken streetlights near metro', 'Dark corridor after sunset with no lighting', 'Metro Station Corridor', 28.6255, 77.2154, 'ACTIVE', 'APPROVED')
       RETURNING id`,
      [testUserId2]
    );
    createdPostIds.push(p2.rows[0].id);

    // Call getSafetyHotspots
    const req = {
      query: {
        latitude: '28.6250',
        longitude: '28.6250',
        radiusKm: '5',
      },
    };

    let responseData = null;
    let statusCode = null;
    const res = {
      status: (code) => {
        statusCode = code;
        return {
          json: (data) => {
            responseData = data;
          },
        };
      },
    };

    await getSafetyHotspots(
      { query: { latitude: '28.6250', longitude: '77.2150', radiusKm: '5' } },
      res
    );

    assert.equal(statusCode, 200);
    assert.ok(responseData.success);
    assert.ok(responseData.hotspots.length >= 1);

    const match = responseData.hotspots.find((h) => h.reportCount >= 2);
    assert.ok(match, 'Expected cluster containing the 2 seeded reports');
    assert.equal(match.independentAuthorCount, 2);
    assert.ok(match.riskScore >= 1.5);
    assert.ok(responseData.disclaimer.includes('Safety information is based on community reports'));
  });

  test('Integration: Submit verification feedback and prevent duplicate submissions', async () => {
    const targetPostId = createdPostIds[0];

    let responseData = null;
    let statusCode = null;
    const res = {
      status: (code) => {
        statusCode = code;
        return {
          json: (data) => {
            responseData = data;
          },
        };
      },
    };

    // First feedback submission
    await submitHotspotFeedback(
      {
        userId: testUserId3,
        params: { id: `hotspot_${Math.round(28.625 * 1000)}_${Math.round(77.215 * 1000)}` },
        body: { type: 'STILL_PRESENT', postId: targetPostId, comments: 'Confirmed this morning' },
      },
      res
    );

    assert.equal(statusCode, 200);
    assert.ok(responseData.success);

    // Verify post confirmations_count was incremented in DB
    const postCheck = await db.query('SELECT confirmations_count FROM community_posts WHERE id = $1', [targetPostId]);
    assert.ok(postCheck.rows[0].confirmations_count >= 1);

    // Second feedback from the same user must be rejected with 409 Conflict
    await submitHotspotFeedback(
      {
        userId: testUserId3,
        params: { id: `hotspot_${Math.round(28.625 * 1000)}_${Math.round(77.215 * 1000)}` },
        body: { type: 'STILL_PRESENT', postId: targetPostId },
      },
      res
    );

    assert.equal(statusCode, 409);
    assert.equal(responseData.success, false);
    assert.ok(responseData.message.includes('already submitted feedback'));
  });

  test('Integration: Route check evaluates route against seeded hotspots', async () => {
    let responseData = null;
    let statusCode = null;
    const res = {
      status: (code) => {
        statusCode = code;
        return {
          json: (data) => {
            responseData = data;
          },
        };
      },
    };

    await checkRouteHotspots(
      {
        body: {
          latitude: 28.6210, // ~450m south of seeded hotspot (28.6250, 77.2150)
          longitude: 77.2150,
          waypoints: [
            { latitude: 28.6210, longitude: 77.2150 },
            { latitude: 28.6300, longitude: 77.2150 }, // Route goes right past the hotspot
          ],
          warningDistanceMeters: 600,
        },
      },
      res
    );

    assert.equal(statusCode, 200);
    assert.ok(responseData.success);
    assert.equal(responseData.hasUpcomingHotspots, true);
    assert.ok(responseData.upcomingHotspots.length >= 1);
    const alert = responseData.upcomingHotspots[0];
    assert.ok(alert.distanceMeters <= 600);
    assert.ok(['EARLY', 'APPROACHING', 'INSIDE'].includes(alert.tier));
  });
});
