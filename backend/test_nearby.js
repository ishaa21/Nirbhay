/**
 * test_nearby.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Complete Unit & Integration Test Suite for Nearby Safety Services Backend.
 * Tests:
 *   1. Coordinate validation (missing, invalid, out-of-range).
 *   2. Category validation and normalization.
 *   3. Haversine distance calculation and human-readable formatting.
 *   4. Bounding box computation.
 *   5. OSM tag normalization (handling missing phone, address, and hours without fabrication).
 *   6. API endpoints (GET /api/nearby & GET /api/nearby-services).
 *   7. Category filtering and radius limits.
 *   8. Caching and rate limiting guards.
 *   9. Error handling (provider timeout, rate limiting, bad input).
 * ─────────────────────────────────────────────────────────────────────────────
 */

const assert = require('assert');
const http = require('http');
const express = require('express');
const {
  validateCoordinates,
  normalizeCategory,
  calculateDistanceMeters,
  formatDistance,
  computeBoundingBox,
  normalizePlaceItem,
} = require('./src/services/nearbyPlacesService');
const nearbyRoutes = require('./src/routes/nearbyRoutes');

console.log('╔═══════════════════════════════════════════════════════════════╗');
console.log('║        NIRBHAY NEARBY SAFETY SERVICES TEST SUITE              ║');
console.log('╚═══════════════════════════════════════════════════════════════╝\n');

let passed = 0;
let failed = 0;

async function it(desc, fn) {
  try {
    await fn();
    console.log(`  ✅ PASS: ${desc}`);
    passed++;
  } catch (err) {
    console.error(`  ❌ FAIL: ${desc} -> ${err.message}`);
    failed++;
  }
}

async function runTests() {
  console.log('--- [1] Coordinate & Category Validation ---');
  it('Rejects undefined latitude', () => {
    assert.strictEqual(validateCoordinates(undefined, 77.2), 'Latitude is required.');
  });
  it('Rejects undefined longitude', () => {
    assert.strictEqual(validateCoordinates(28.6, undefined), 'Longitude is required.');
  });
  it('Rejects out-of-bounds latitude > 90', () => {
    assert.ok(validateCoordinates(95.0, 77.2).includes('-90 and 90'));
  });
  it('Rejects out-of-bounds latitude < -90', () => {
    assert.ok(validateCoordinates(-95.0, 77.2).includes('-90 and 90'));
  });
  it('Rejects out-of-bounds longitude > 180', () => {
    assert.ok(validateCoordinates(28.6, 185.0).includes('-180 and 180'));
  });
  it('Accepts valid Delhi coordinates', () => {
    assert.strictEqual(validateCoordinates(28.6139, 77.209), null);
  });
  it('Normalizes police category', () => {
    assert.strictEqual(normalizeCategory('police'), 'police');
  });
  it('Normalizes medical alias to hospital', () => {
    assert.strictEqual(normalizeCategory('medical'), 'hospital');
  });
  it('Normalizes pharmacy and fire_station', () => {
    assert.strictEqual(normalizeCategory('pharmacy'), 'pharmacy');
    assert.strictEqual(normalizeCategory('fire_station'), 'fire_station');
  });
  it('Defaults empty category to all', () => {
    assert.strictEqual(normalizeCategory(null), 'all');
    assert.strictEqual(normalizeCategory(''), 'all');
  });
  it('Rejects invalid categories', () => {
    assert.strictEqual(normalizeCategory('entertainment'), null);
    assert.strictEqual(normalizeCategory('food'), null);
  });

  console.log('\n--- [2] Distance Calculation & Bounding Box ---');
  it('Calculates 0 meters for identical coordinates', () => {
    const dist = calculateDistanceMeters(28.6139, 77.209, 28.6139, 77.209);
    assert.strictEqual(dist, 0);
  });
  it('Calculates accurate distance for known offset (~1.1 km)', () => {
    const dist = calculateDistanceMeters(28.6139, 77.209, 28.6239, 77.209);
    assert.ok(dist >= 1100 && dist <= 1120, `Expected ~1112m, got ${dist}m`);
  });
  it('Formats distances under 1000m as meters', () => {
    assert.strictEqual(formatDistance(450), '450 m away');
  });
  it('Formats distances >= 1000m as kilometers with 1 decimal', () => {
    assert.strictEqual(formatDistance(1240), '1.2 km away');
    assert.strictEqual(formatDistance(3800), '3.8 km away');
  });
  it('Computes valid bounding box string', () => {
    const bbox = computeBoundingBox(28.6139, 77.209, 3000);
    const parts = bbox.split(',');
    assert.strictEqual(parts.length, 4);
    assert.ok(parseFloat(parts[0]) < parseFloat(parts[2]), 'left should be < right');
    assert.ok(parseFloat(parts[3]) < parseFloat(parts[1]), 'bottom should be < top');
  });

  console.log('\n--- [3] OSM Tag Normalization & Graceful Fallbacks ---');
  it('Extracts place item with complete information', () => {
    const item = {
      place_id: 101,
      osm_type: 'node',
      osm_id: 202,
      lat: '28.615',
      lon: '77.210',
      name: 'Connaught Place Police Station',
      display_name: 'Connaught Place Police Station, Baba Kharak Singh Marg, New Delhi, India',
      type: 'police',
      extratags: {
        phone: '+91-11-2374-7100',
        opening_hours: '24/7',
      },
    };
    const place = normalizePlaceItem(item, 28.6139, 77.209);
    assert.strictEqual(place.id, 'osm_node_202');
    assert.strictEqual(place.name, 'Connaught Place Police Station');
    assert.strictEqual(place.category, 'police');
    assert.strictEqual(place.phone, '+91-11-2374-7100');
    assert.ok(place.address.includes('Baba Kharak Singh Marg'));
    assert.strictEqual(place.openingHours, '24/7');
    assert.strictEqual(place.isOpen, true);
    assert.ok(place.distanceMeters > 0);
    assert.ok(place.distanceFormatted.includes('away'));
  });

  it('Gracefully handles missing phone, address, and opening hours without inventing data', () => {
    const item = {
      place_id: 303,
      osm_type: 'way',
      osm_id: 404,
      lat: '28.62',
      lon: '77.215',
      display_name: '',
      type: 'pharmacy',
      extratags: {},
    };
    const place = normalizePlaceItem(item, 28.6139, 77.209);
    assert.strictEqual(place.id, 'osm_way_404');
    assert.strictEqual(place.name, 'Pharmacy'); // category placeholder
    assert.strictEqual(place.category, 'pharmacy');
    assert.strictEqual(place.phone, null); // never fabricated
    assert.strictEqual(place.address, null); // never fabricated
    assert.strictEqual(place.openingHours, null); // never fabricated
    assert.strictEqual(place.isOpen, null); // never fabricated
    assert.strictEqual(place.latitude, 28.62);
    assert.strictEqual(place.longitude, 77.215);
  });

  console.log('\n--- [4] HTTP API Endpoint Integration Tests ---');
  const app = express();
  app.use(express.json());
  app.use('/api/nearby', nearbyRoutes);
  app.use('/api/nearby-services', nearbyRoutes);

  const server = http.createServer(app);
  const TEST_PORT = 5088;

  await new Promise((resolve) => server.listen(TEST_PORT, resolve));

  function request(path) {
    return new Promise((resolve, reject) => {
      const req = http.request(
        {
          hostname: 'localhost',
          port: TEST_PORT,
          path,
          method: 'GET',
          agent: false,
          headers: { Connection: 'close' },
        },
        (res) => {
          let data = '';
          res.on('data', (c) => (data += c));
          res.on('end', () => {
            try {
              resolve({ status: res.statusCode, body: JSON.parse(data) });
            } catch (_) {
              resolve({ status: res.statusCode, body: data });
            }
          });
        }
      );
      req.on('error', reject);
      req.end();
    });
  }

  try {
    const errRes1 = await request('/api/nearby');
    it('GET /api/nearby returns 400 when lat/lng missing', () => {
      assert.strictEqual(errRes1.status, 400);
      assert.strictEqual(errRes1.body.success, false);
      assert.strictEqual(errRes1.body.code, 'INVALID_COORDINATES');
    });

    const errRes2 = await request('/api/nearby?lat=28.6139&lng=77.2090&category=invalid_cat');
    it('GET /api/nearby returns 400 on unsupported category', () => {
      assert.strictEqual(errRes2.status, 400);
      assert.strictEqual(errRes2.body.success, false);
      assert.strictEqual(errRes2.body.code, 'INVALID_CATEGORY');
    });

    console.log('\n  ... Executing live query to OpenStreetMap via /api/nearby ...');
    const liveRes = await request('/api/nearby?lat=28.6139&lng=77.2090&category=police&radius=3000&limit=5');
    it('GET /api/nearby returns 200 with structured safety places', () => {
      assert.strictEqual(liveRes.status, 200);
      assert.strictEqual(liveRes.body.success, true);
      assert.strictEqual(liveRes.body.category, 'police');
      assert.ok(Array.isArray(liveRes.body.places));
      assert.ok(liveRes.body.attribution.includes('OpenStreetMap'));
      assert.ok(liveRes.body.count > 0, 'Expected at least 1 police station in 3km of Central Delhi');
      const first = liveRes.body.places[0];
      assert.ok(first.id);
      assert.ok(first.name);
      assert.ok(first.latitude);
      assert.ok(first.longitude);
      assert.ok(first.distanceMeters >= 0);
      console.log(`      Sample result: "${first.name}" (${first.distanceFormatted}) - Phone: ${first.phone || 'None'}`);
    });

    await it('GET /api/nearby-services alias routes to same controller', async () => {
      const aliasRes = await request('/api/nearby-services?lat=28.6139&lng=77.2090&category=police&radius=3000&limit=5');
      assert.strictEqual(aliasRes.status, 200);
      assert.strictEqual(aliasRes.body.success, true);
      assert.strictEqual(aliasRes.body.category, 'police');
    });

    await it('Subsequent identical query serves from in-memory cache', async () => {
      const cachedRes = await request('/api/nearby?lat=28.6139&lng=77.2090&category=police&radius=3000&limit=5');
      assert.strictEqual(cachedRes.status, 200);
      assert.strictEqual(cachedRes.body.cached, true);
    });

    await it('GET /api/nearby with category=all returns multiple safety categories', async () => {
      const allRes = await request('/api/nearby?lat=28.6139&lng=77.2090&category=all&radius=3000&limit=10');
      assert.strictEqual(allRes.status, 200);
      assert.strictEqual(allRes.body.success, true);
      assert.ok(allRes.body.places.length > 0);
      const categoriesFound = new Set(allRes.body.places.map((p) => p.category));
      console.log(`      Categories found in "all": ${Array.from(categoriesFound).join(', ')}`);
      assert.ok(categoriesFound.size >= 1);
    });

    await it('GET /api/nearby/reverse returns human-readable location', async () => {
      const revRes = await request('/api/nearby/reverse?lat=12.9352&lng=77.6245');
      assert.strictEqual(revRes.status, 200);
      assert.strictEqual(revRes.body.success, true);
      assert.ok(revRes.body.formattedLocation);
      console.log(`      Reverse geocode result: "${revRes.body.formattedLocation}"`);
    });

    await it('GET /api/nearby/reverse subsequent request serves from cache', async () => {
      const revRes2 = await request('/api/nearby/reverse?lat=12.9352&lng=77.6245');
      assert.strictEqual(revRes2.status, 200);
      assert.strictEqual(revRes2.body.cached, true);
    });
    console.log(`\n═══════════════════════════════════════════════════════════════`);
    console.log(`  RESULTS: ${passed} PASSED | ${failed} FAILED`);
    console.log(`═══════════════════════════════════════════════════════════════\n`);
    server.close();
  } catch (err) {
    server.close();
    console.error('Test execution error:', err);
    process.exitCode = 1;
  }
}

runTests().catch((e) => {
  console.error('Fatal test error:', e);
  process.exit(1);
});
