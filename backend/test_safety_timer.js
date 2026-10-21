/**
 * test_safety_timer.js
 * ─────────────────────────────────────────────────────────────────
 * Integration tests for the Safety Timer backend API.
 * Runs against the LOCAL backend (http://localhost:5000).
 *
 * Prerequisites:
 *   1. Local PostgreSQL running with the safety_app database.
 *   2. migrate_safety_timer.sql applied.
 *   3. Backend running:  npm run dev (in backend/)
 *   4. At least one registered user in the DB.
 *
 * Usage:
 *   node test_safety_timer.js
 *
 * All tests use SMS_TEST_MODE=true (no real SMS sent).
 */

const http = require('http');

const BASE_URL = 'http://localhost:5000';

// ─── Config ────────────────────────────────────────────────────────────────
// Fill in a valid JWT token for a test user before running.
// You can obtain one by calling POST /api/auth/login.
const TEST_TOKEN = process.env.TEST_TOKEN || 'YOUR_JWT_TOKEN_HERE';

// ─── Helpers ───────────────────────────────────────────────────────────────
function request(method, path, body, token) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'localhost',
            port: 5000,
            path,
            method,
            headers: {
                'Content-Type': 'application/json',
                ...(token ? { Authorization: `Bearer ${token}` } : {}),
            },
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => (data += chunk));
            res.on('end', () => {
                try {
                    resolve({ status: res.statusCode, body: JSON.parse(data) });
                } catch {
                    resolve({ status: res.statusCode, body: data });
                }
            });
        });

        req.on('error', reject);
        if (body) req.write(JSON.stringify(body));
        req.end();
    });
}

let passed = 0;
let failed = 0;
let activeTimerId = null;

function assert(condition, label, detail = '') {
    if (condition) {
        console.log(`  ✅ PASS: ${label}`);
        passed++;
    } else {
        console.error(`  ❌ FAIL: ${label}${detail ? ' — ' + detail : ''}`);
        failed++;
    }
}

// ─── Tests ─────────────────────────────────────────────────────────────────

async function testHealthCheck() {
    console.log('\n[1] Health Check');
    const res = await request('GET', '/health', null, null);
    assert(res.status === 200, 'Server is UP', JSON.stringify(res.body));
}

async function testGetActiveTimer_NoTimer() {
    console.log('\n[2] GET /api/timer/active — no active timer');
    const res = await request('GET', '/api/timer/active', null, TEST_TOKEN);
    assert(res.status === 200, 'Returns 200');
    assert(res.body.active === false, 'active = false when no timer');
    assert(res.body.timer === null, 'timer = null when no timer');
}

async function testCreateTimer_InvalidDuration() {
    console.log('\n[3] POST /api/timer — invalid duration');
    const res = await request('POST', '/api/timer', { durationMinutes: 0 }, TEST_TOKEN);
    assert(res.status === 400, 'Returns 400 for invalid duration');
    assert(res.body.message?.includes('Invalid duration'), 'Error message mentions Invalid duration');
}

async function testCreateTimer_Valid() {
    console.log('\n[4] POST /api/timer — create 5-minute timer');
    const res = await request('POST', '/api/timer', {
        durationMinutes: 5,
        latitude: 12.9716,
        longitude: 77.5946,
    }, TEST_TOKEN);
    assert(res.status === 201, 'Returns 201');
    assert(res.body.timer?.id, 'Timer ID returned');
    assert(res.body.timer?.status === 'ACTIVE', 'Status is ACTIVE');
    assert(res.body.timer?.duration_minutes === 5, 'Duration is 5 minutes');
    activeTimerId = res.body.timer?.id;
    console.log(`  → Timer ID: ${activeTimerId}`);
}

async function testCreateTimer_DuplicatePrevented() {
    console.log('\n[5] POST /api/timer — duplicate timer prevented');
    const res = await request('POST', '/api/timer', { durationMinutes: 15 }, TEST_TOKEN);
    assert(res.status === 409, 'Returns 409 for duplicate timer');
    assert(res.body.code === 'TIMER_ALREADY_ACTIVE', 'Code is TIMER_ALREADY_ACTIVE');
}

async function testGetActiveTimer_WithTimer() {
    console.log('\n[6] GET /api/timer/active — with active timer');
    const res = await request('GET', '/api/timer/active', null, TEST_TOKEN);
    assert(res.status === 200, 'Returns 200');
    assert(res.body.active === true, 'active = true');
    assert(res.body.timer?.id === activeTimerId, 'Correct timer returned');
    assert(typeof res.body.remainingMs === 'number', 'remainingMs is a number');
    assert(res.body.remainingMs > 0, 'remainingMs > 0');
}

async function testExtendTimer() {
    console.log('\n[7] POST /api/timer/:id/extend — extend by 15 minutes');
    const res = await request('POST', `/api/timer/${activeTimerId}/extend`, { extendMinutes: 15 }, TEST_TOKEN);
    assert(res.status === 200, 'Returns 200');
    assert(res.body.timer?.duration_minutes === 20, 'Duration extended to 20 minutes (5 + 15)');
    assert(new Date(res.body.timer?.expires_at) > new Date(), 'New expiry is in the future');
}

async function testExtendTimer_InvalidExtension() {
    console.log('\n[8] POST /api/timer/:id/extend — invalid extension amount');
    const res = await request('POST', `/api/timer/${activeTimerId}/extend`, { extendMinutes: 45 }, TEST_TOKEN);
    assert(res.status === 400, 'Returns 400 for invalid extension');
}

async function testCheckIn() {
    console.log('\n[9] POST /api/timer/:id/checkin — check in');
    const res = await request('POST', `/api/timer/${activeTimerId}/checkin`, null, TEST_TOKEN);
    assert(res.status === 200, 'Returns 200');
    assert(res.body.timer?.status === 'CHECKED_IN', 'Status is CHECKED_IN');
    assert(res.body.timer?.checked_in_at, 'checked_in_at is set');
}

async function testCheckIn_AlreadyCheckedIn() {
    console.log('\n[10] POST /api/timer/:id/checkin — cannot check in twice');
    const res = await request('POST', `/api/timer/${activeTimerId}/checkin`, null, TEST_TOKEN);
    assert(res.status === 400, 'Returns 400 on second check-in');
}

async function testCancel_NotActive() {
    console.log('\n[11] POST /api/timer/:id/cancel — cancel a CHECKED_IN timer');
    const res = await request('POST', `/api/timer/${activeTimerId}/cancel`, null, TEST_TOKEN);
    assert(res.status === 400, 'Returns 400 — cannot cancel non-ACTIVE timer');
}

async function testCancelFlow() {
    console.log('\n[12] Full cancel flow — create then cancel');

    // Create a fresh timer
    const createRes = await request('POST', '/api/timer', { durationMinutes: 30 }, TEST_TOKEN);
    assert(createRes.status === 201, 'Created new 30-min timer');
    const newId = createRes.body.timer?.id;

    const cancelRes = await request('POST', `/api/timer/${newId}/cancel`, null, TEST_TOKEN);
    assert(cancelRes.status === 200, 'Returns 200 on cancel');
    assert(cancelRes.body.timer?.status === 'CANCELLED', 'Status is CANCELLED');
    assert(cancelRes.body.timer?.cancelled_at, 'cancelled_at is set');

    // Verify no active timer now
    const activeRes = await request('GET', '/api/timer/active', null, TEST_TOKEN);
    assert(activeRes.body.active === false, 'No active timer after cancel');
}

async function testRecoveryAfterRestart() {
    console.log('\n[13] Recovery after restart — create timer and fetch it');

    const createRes = await request('POST', '/api/timer', { durationMinutes: 60, latitude: 12.9, longitude: 77.6 }, TEST_TOKEN);
    assert(createRes.status === 201, 'Timer created');
    const recoveryId = createRes.body.timer?.id;

    // Simulate "restart" by fetching the active timer fresh
    const fetchRes = await request('GET', '/api/timer/active', null, TEST_TOKEN);
    assert(fetchRes.body.active === true, 'Timer recoverable via GET /active');
    assert(fetchRes.body.timer?.id === recoveryId, 'Correct timer recovered');
    assert(fetchRes.body.remainingMs > 0, 'Remaining time calculated server-side');

    // Clean up
    await request('POST', `/api/timer/${recoveryId}/cancel`, null, TEST_TOKEN);
    console.log('  → Cleaned up recovery test timer.');
}

async function testUnauthenticated() {
    console.log('\n[14] Unauthenticated request — should return 401');
    const res = await request('GET', '/api/timer/active', null, 'invalid.token.xyz');
    assert(res.status === 401 || res.status === 403, 'Returns 401 or 403 for bad token');
}

// ─── Main ──────────────────────────────────────────────────────────────────
async function main() {
    console.log('═══════════════════════════════════════════════════════');
    console.log('  Nirbhay — Safety Timer Backend Tests');
    console.log('═══════════════════════════════════════════════════════');

    if (TEST_TOKEN === 'YOUR_JWT_TOKEN_HERE') {
        console.error('\n⚠️  Set TEST_TOKEN env var before running:');
        console.error('   TEST_TOKEN=<your_jwt> node test_safety_timer.js\n');
        process.exit(1);
    }

    try {
        await testHealthCheck();
        await testGetActiveTimer_NoTimer();
        await testCreateTimer_InvalidDuration();
        await testCreateTimer_Valid();
        await testCreateTimer_DuplicatePrevented();
        await testGetActiveTimer_WithTimer();
        await testExtendTimer();
        await testExtendTimer_InvalidExtension();
        await testCheckIn();
        await testCheckIn_AlreadyCheckedIn();
        await testCancel_NotActive();
        await testCancelFlow();
        await testRecoveryAfterRestart();
        await testUnauthenticated();
    } catch (err) {
        console.error('\nUnhandled test error:', err.message);
        failed++;
    }

    console.log('\n═══════════════════════════════════════════════════════');
    console.log(`  Results: ${passed} passed, ${failed} failed`);
    console.log('═══════════════════════════════════════════════════════\n');
    process.exit(failed > 0 ? 1 : 0);
}

main();
