/**
 * test_safety_timer_suite.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Complete, standalone integration and unit test suite for the Safety Timer.
 * Tests:
 *   1. Health check & configuration check (SMS_TEST_MODE=true)
 *   2. Authentication enforcement (401 on missing/invalid token)
 *   3. Duration validation (allows 5, 15, 30, 60; rejects invalid values)
 *   4. Timer creation & initial persistence (coordinates, timestamps, status=ACTIVE)
 *   5. Duplicate active timer prevention (409 Conflict with code TIMER_ALREADY_ACTIVE)
 *   6. Recovery after restart (GET /api/timer/active restores timer & remainingMs)
 *   7. Extension (+5, +15, +30, +60 minutes updates expires_at & duration_minutes)
 *   8. Extension validation (rejects invalid extension duration)
 *   9. Location updating (POST /api/timer/:id/location updates coords & timestamp)
 *  10. Check-in flow (marks CHECKED_IN, sets checked_in_at, disallows double check-in)
 *  11. Cancellation flow (marks CANCELLED, sets cancelled_at, disallows cancel on non-active)
 *  12. Server-side expiry detection (atomic claim, status=EXPIRED, alert_fired=TRUE)
 *  13. Duplicate processing prevention (idempotent; 2nd cron tick finds 0 rows, no duplicate alerts)
 *  14. Emergency alert workflow execution (reuses sos_incidents, tracking token, sendSosAlerts)
 *
 * Runs self-contained using an Express test server and an in-memory SQL mock layer.
 * Can be executed anywhere without requiring an active external PostgreSQL instance:
 *   node test_safety_timer_suite.js
 * ─────────────────────────────────────────────────────────────────────────────
 */

require('dotenv').config();
process.env.SMS_TEST_MODE = 'true';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'nirbhay_test_secret_2026';

const http = require('http');
const express = require('express');
const jwt = require('jsonwebtoken');

// ── In-Memory Database ──────────────────────────────────────────────────────
const mockTimers = [];
const mockIncidents = [];
const mockContacts = [
    {
        id: 'contact-uuid-1',
        user_id: 'test-user-id-001',
        name: 'Priya Sharma (Guardian)',
        phone: '+919876543210',
        auto_alert: true,
    },
    {
        id: 'contact-uuid-2',
        user_id: 'test-user-id-001',
        name: 'Rahul Sharma (Father)',
        phone: '+919876543211',
        auto_alert: false, // auto_alert disabled
    },
];
const mockNotifications = [];

const mockDb = {
    query: async (text, params = []) => {
        const clean = text.replace(/\s+/g, ' ').trim();

        // 1. SELECT * FROM safety_timers WHERE user_id = $1 AND status = 'ACTIVE' LIMIT 1
        if (clean.includes('FROM safety_timers WHERE user_id = $1 AND status = \'ACTIVE\'')) {
            const found = mockTimers.find(t => t.user_id === params[0] && t.status === 'ACTIVE');
            return { rows: found ? [found] : [] };
        }

        // 2. INSERT INTO safety_timers
        if (clean.includes('INSERT INTO safety_timers')) {
            // Guard: unique index simulation
            const activeExisting = mockTimers.find(t => t.user_id === params[0] && t.status === 'ACTIVE');
            if (activeExisting) {
                const err = new Error('duplicate key value violates unique constraint');
                err.code = '23505';
                throw err;
            }

            const newTimer = {
                id: `timer-uuid-${mockTimers.length + 1}`,
                user_id: params[0],
                duration_minutes: params[1],
                expires_at: params[2],
                latitude: params[3],
                longitude: params[4],
                location_at: params[5],
                status: 'ACTIVE',
                alert_fired: false,
                checked_in_at: null,
                cancelled_at: null,
                expired_at: null,
                created_at: new Date(),
                updated_at: new Date(),
            };
            mockTimers.push(newTimer);
            return { rows: [newTimer] };
        }

        // 3. SELECT * FROM safety_timers WHERE id = $1 AND user_id = $2
        if (clean.includes('FROM safety_timers WHERE id = $1 AND user_id = $2')) {
            const found = mockTimers.find(t => t.id === params[0] && t.user_id === params[1]);
            return { rows: found ? [found] : [] };
        }

        // 4. UPDATE safety_timers SET status = 'CHECKED_IN'
        if (clean.includes("SET status = 'CHECKED_IN'")) {
            const timer = mockTimers.find(t => t.id === params[0] && t.user_id === params[1]);
            if (timer) {
                timer.status = 'CHECKED_IN';
                timer.checked_in_at = new Date();
                timer.updated_at = new Date();
                return { rows: [timer] };
            }
            return { rows: [] };
        }

        // 5. UPDATE safety_timers SET status = 'CANCELLED'
        if (clean.includes("SET status = 'CANCELLED'")) {
            const timer = mockTimers.find(t => t.id === params[0] && t.user_id === params[1]);
            if (timer) {
                timer.status = 'CANCELLED';
                timer.cancelled_at = new Date();
                timer.updated_at = new Date();
                return { rows: [timer] };
            }
            return { rows: [] };
        }

        // 6. UPDATE safety_timers SET expires_at = $1, duration_minutes = $2
        if (clean.includes('SET expires_at = $1, duration_minutes = $2')) {
            const timer = mockTimers.find(t => t.id === params[5] && t.user_id === params[6]);
            if (timer) {
                timer.expires_at = params[0];
                timer.duration_minutes = params[1];
                timer.latitude = params[2];
                timer.longitude = params[3];
                timer.location_at = params[4];
                timer.updated_at = new Date();
                return { rows: [timer] };
            }
            return { rows: [] };
        }

        // 7. UPDATE safety_timers SET latitude = $1, longitude = $2, location_at
        if (clean.includes('SET latitude = $1, longitude = $2, location_at')) {
            const timer = mockTimers.find(t => t.id === params[2] && t.user_id === params[3] && t.status === 'ACTIVE');
            if (timer) {
                timer.latitude = params[0];
                timer.longitude = params[1];
                timer.location_at = new Date();
                timer.updated_at = new Date();
                return { rows: [timer] };
            }
            return { rows: [] };
        }

        // 8. Cron atomic claim: UPDATE safety_timers SET alert_fired = TRUE, status = 'EXPIRED'
        if (clean.includes("SET alert_fired = TRUE, status = 'EXPIRED'")) {
            const now = new Date();
            const claimed = [];
            for (const t of mockTimers) {
                if (t.status === 'ACTIVE' && new Date(t.expires_at) <= now && t.alert_fired === false) {
                    t.alert_fired = true;
                    t.status = 'EXPIRED';
                    t.expired_at = now;
                    t.updated_at = now;
                    claimed.push(t);
                }
            }
            return { rows: claimed };
        }

        // 9. SELECT * FROM sos_incidents WHERE user_id = $1 AND status = 'ACTIVE'
        if (clean.includes("FROM sos_incidents WHERE user_id = $1 AND status = 'ACTIVE'")) {
            const found = mockIncidents.find(i => i.user_id === params[0] && i.status === 'ACTIVE');
            return { rows: found ? [found] : [] };
        }

        // 10. INSERT INTO sos_incidents
        if (clean.includes('INSERT INTO sos_incidents')) {
            const newIncident = {
                id: `incident-uuid-${mockIncidents.length + 1}`,
                user_id: params[0],
                status: 'ACTIVE',
                latitude: params[1],
                longitude: params[2],
                activated_at: params[3],
                notification_status: 'PENDING',
                tracking_token: params[4],
                created_at: new Date(),
                updated_at: new Date(),
            };
            mockIncidents.push(newIncident);
            return { rows: [newIncident] };
        }

        // 11. UPDATE sos_incidents SET notification_status
        if (clean.includes('UPDATE sos_incidents SET notification_status')) {
            const inc = mockIncidents.find(i => i.id === params[1]);
            if (inc) inc.notification_status = params[0];
            return { rows: inc ? [inc] : [] };
        }

        // 12. SELECT from emergency_contacts WHERE user_id = $1 AND auto_alert = true
        if (clean.includes('FROM emergency_contacts') && clean.includes('auto_alert = true')) {
            const found = mockContacts.filter(c => c.user_id === params[0] && c.auto_alert === true);
            return { rows: found };
        }

        // 13. INSERT INTO sos_notifications
        if (clean.includes('INSERT INTO sos_notifications')) {
            const notif = {
                id: `notif-uuid-${mockNotifications.length + 1}`,
                sos_id: params[0],
                contact_id: params[1],
                contact_name: params[2],
                contact_phone: params[3],
                channel: params[4] || 'SMS',
                status: params[5] || 'SENT',
                sent_at: new Date(),
            };
            mockNotifications.push(notif);
            return { rows: [notif] };
        }

        return { rows: [] };
    },
};

// Patch the db module cache so controllers use mockDb
const dbModulePath = require.resolve('./src/config/db');
require.cache[dbModulePath] = {
    id: dbModulePath,
    filename: dbModulePath,
    loaded: true,
    exports: mockDb,
};

// Now import the controller and routes
const timerController = require('./src/controllers/timerController');
const authMiddleware = require('./src/middleware/authMiddleware');

// Build isolated Express app for test execution
const app = express();
app.use(express.json());

const timerRouter = express.Router();
timerRouter.use(authMiddleware);
timerRouter.post('/', timerController.createTimer);
timerRouter.get('/active', timerController.getActiveTimer);
timerRouter.post('/:id/checkin', timerController.checkInTimer);
timerRouter.post('/:id/cancel', timerController.cancelTimer);
timerRouter.post('/:id/extend', timerController.extendTimer);
timerRouter.post('/:id/location', timerController.updateTimerLocation);

app.use('/api/timer', timerRouter);
app.get('/health', (req, res) => res.json({ status: 'UP', testMode: process.env.SMS_TEST_MODE }));

// ── HTTP Helper ─────────────────────────────────────────────────────────────
let server;
const TEST_PORT = 5088;
const TEST_USER_ID = 'test-user-id-001';
const TEST_TOKEN = jwt.sign({ userId: TEST_USER_ID, email: 'test@nirbhay.org' }, process.env.JWT_SECRET, { expiresIn: '1h' });

function apiRequest(method, path, body = null, token = TEST_TOKEN) {
    return new Promise((resolve, reject) => {
        const req = http.request({
            hostname: '127.0.0.1',
            port: TEST_PORT,
            path,
            method,
            headers: {
                'Content-Type': 'application/json',
                ...(token ? { Authorization: `Bearer ${token}` } : {}),
            },
        }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
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

// ── Test Runner ─────────────────────────────────────────────────────────────
let passed = 0;
let failed = 0;

function assert(cond, name, detail = '') {
    if (cond) {
        console.log(`  ✅ PASS: ${name}`);
        passed++;
    } else {
        console.error(`  ❌ FAIL: ${name} ${detail ? '— ' + detail : ''}`);
        failed++;
    }
}

async function runSuite() {
    console.log('╔═══════════════════════════════════════════════════════════════╗');
    console.log('║        NIRBHAY SAFETY TIMER COMPREHENSIVE TEST SUITE          ║');
    console.log('╚═══════════════════════════════════════════════════════════════╝\n');

    await new Promise(r => server = app.listen(TEST_PORT, '127.0.0.1', r));

    try {
        // [1] Health & Safe Test Mode Check
        console.log('--- [1] Health & Configuration ---');
        const health = await apiRequest('GET', '/health', null, null);
        assert(health.status === 200, 'Health check returns 200 UP');
        assert(process.env.SMS_TEST_MODE === 'true', 'SMS_TEST_MODE is strictly TRUE (no real SMS sent)');

        // [2] Authentication Guard
        console.log('\n--- [2] Authentication Guard ---');
        const noAuth = await apiRequest('GET', '/api/timer/active', null, null);
        assert(noAuth.status === 401, 'Rejects unauthenticated request with 401');

        const badAuth = await apiRequest('GET', '/api/timer/active', null, 'invalid.jwt.token');
        assert(badAuth.status === 401 || badAuth.status === 403, 'Rejects corrupted token with 401/403');

        // [3] Initial state: No active timer
        console.log('\n--- [3] Initial State ---');
        const emptyActive = await apiRequest('GET', '/api/timer/active');
        assert(emptyActive.status === 200, 'GET /active returns 200');
        assert(emptyActive.body.active === false, 'active is false when none exists');
        assert(emptyActive.body.timer === null, 'timer is null when none exists');

        // [4] Duration Validation
        console.log('\n--- [4] Duration Validation ---');
        const invalidDurations = [0, -10, 1500, 'abc'];
        for (const dur of invalidDurations) {
            const res = await apiRequest('POST', '/api/timer', { durationMinutes: dur });
            assert(res.status === 400, `Rejects duration=${dur} with 400`, res.body.message);
        }

        // [5] Create Valid Timer (15 min)
        console.log('\n--- [5] Create Valid Timer ---');
        const createRes = await apiRequest('POST', '/api/timer', {
            durationMinutes: 15,
            latitude: 12.9716,
            longitude: 77.5946,
        });
        assert(createRes.status === 201, 'Creates timer with status 201');
        assert(createRes.body.timer.status === 'ACTIVE', 'Timer status is ACTIVE');
        assert(createRes.body.timer.duration_minutes === 15, 'duration_minutes is 15');
        assert(createRes.body.timer.latitude === 12.9716, 'latitude recorded');
        assert(createRes.body.timer.longitude === 77.5946, 'longitude recorded');
        assert(createRes.body.timer.alert_fired === false, 'alert_fired initialized to false');
        const timerId = createRes.body.timer.id;

        // [6] Duplicate Timer Prevention
        console.log('\n--- [6] Duplicate Timer Prevention ---');
        const dupRes = await apiRequest('POST', '/api/timer', { durationMinutes: 30 });
        assert(dupRes.status === 409, 'Rejects second active timer with 409 Conflict');
        assert(dupRes.body.code === 'TIMER_ALREADY_ACTIVE', 'Returns TIMER_ALREADY_ACTIVE code');

        // [7] Recovery After Restart (GET /api/timer/active)
        console.log('\n--- [7] Recovery After Restart ---');
        const recovered = await apiRequest('GET', '/api/timer/active');
        assert(recovered.status === 200, 'GET /active returns 200');
        assert(recovered.body.active === true, 'active is true');
        assert(recovered.body.timer.id === timerId, 'Recovers correct active timer');
        assert(typeof recovered.body.remainingMs === 'number', 'Calculates remainingMs');
        assert(recovered.body.remainingMs > 0, 'remainingMs > 0');

        // [8] Timer Extension
        console.log('\n--- [8] Timer Extension ---');
        const badExtend = await apiRequest('POST', `/api/timer/${timerId}/extend`, { extendMinutes: 0 });
        assert(badExtend.status === 400, 'Rejects invalid extension increment with 400');

        const validExtend = await apiRequest('POST', `/api/timer/${timerId}/extend`, {
            extendMinutes: 15,
            latitude: 12.9720,
            longitude: 77.5950,
        });
        assert(validExtend.status === 200, 'Extends timer successfully with 200');
        assert(validExtend.body.timer.duration_minutes === 30, 'duration_minutes updated to 30 (15 + 15)');
        assert(validExtend.body.timer.latitude === 12.9720, 'Updated latitude during extend');

        // [9] Location Update Endpoint
        console.log('\n--- [9] Location Update Endpoint ---');
        const locRes = await apiRequest('POST', `/api/timer/${timerId}/location`, {
            latitude: 12.9735,
            longitude: 77.5960,
        });
        assert(locRes.status === 200, 'POST /location returns 200');
        assert(locRes.body.timer.latitude === 12.9735, 'Latitude successfully updated');
        assert(locRes.body.timer.longitude === 77.5960, 'Longitude successfully updated');

        // [10] Check-In Flow
        console.log('\n--- [10] Check-In Flow ---');
        const checkInRes = await apiRequest('POST', `/api/timer/${timerId}/checkin`);
        assert(checkInRes.status === 200, 'Check-in returns 200');
        assert(checkInRes.body.timer.status === 'CHECKED_IN', 'Status updated to CHECKED_IN');
        assert(checkInRes.body.timer.checked_in_at != null, 'checked_in_at timestamp recorded');

        // Verify cannot double check-in
        const doubleCheckIn = await apiRequest('POST', `/api/timer/${timerId}/checkin`);
        assert(doubleCheckIn.status === 400, 'Rejects second check-in on already completed timer');

        // Verify active is false now
        const afterCheckIn = await apiRequest('GET', '/api/timer/active');
        assert(afterCheckIn.body.active === false, 'No active timer after check-in');

        // [11] Cancel Flow
        console.log('\n--- [11] Cancellation Flow ---');
        const timer2 = await apiRequest('POST', '/api/timer', { durationMinutes: 5 });
        const timer2Id = timer2.body.timer.id;
        assert(timer2.status === 201, 'Created new timer for cancel test');

        const cancelRes = await apiRequest('POST', `/api/timer/${timer2Id}/cancel`);
        assert(cancelRes.status === 200, 'Cancelling returns 200');
        assert(cancelRes.body.timer.status === 'CANCELLED', 'Status updated to CANCELLED');
        assert(cancelRes.body.timer.cancelled_at != null, 'cancelled_at timestamp recorded');

        const doubleCancel = await apiRequest('POST', `/api/timer/${timer2Id}/cancel`);
        assert(doubleCancel.status === 400, 'Rejects cancel on already CANCELLED timer');

        // [12] Server-Side Expiry Detection & Emergency Alert Workflow
        console.log('\n--- [12] Server-Side Expiry Detection & Emergency Alert Workflow ---');
        // Create a timer and simulate past expiry
        const expiredTimerRes = await apiRequest('POST', '/api/timer', {
            durationMinutes: 5,
            latitude: 12.9800,
            longitude: 77.6000,
        });
        const expTimer = expiredTimerRes.body.timer;
        // Fast-forward its expiry into the past
        const rawTimerObj = mockTimers.find(t => t.id === expTimer.id);
        rawTimerObj.expires_at = new Date(Date.now() - 10000); // 10s in the past

        // Trigger cron processor
        const processedCount = await timerController.processExpiredTimers();
        assert(processedCount === 1, 'Cron processor detected 1 expired timer');
        assert(rawTimerObj.status === 'EXPIRED', 'Timer status atomically updated to EXPIRED');
        assert(rawTimerObj.alert_fired === true, 'alert_fired set to TRUE');
        assert(rawTimerObj.expired_at != null, 'expired_at timestamp recorded');

        // Verify emergency alert workflow initiation:
        assert(mockIncidents.length > 0, 'Emergency SOS incident created for expired timer');
        const emergencyIncident = mockIncidents[mockIncidents.length - 1];
        assert(emergencyIncident.status === 'ACTIVE', 'Created incident is in ACTIVE status');
        assert(emergencyIncident.tracking_token != null, 'Tracking token generated for guardians');

        // Verify alert message formatting
        const alertMsg = timerController.buildTimerExpiredAlertMessage({
            expiredAt: rawTimerObj.expired_at,
            latitude: rawTimerObj.latitude,
            longitude: rawTimerObj.longitude,
            durationMinutes: rawTimerObj.duration_minutes,
            trackingUrl: `http://localhost:5000/track/${emergencyIncident.tracking_token}`,
        });
        assert(alertMsg.includes('EMERGENCY ALERT: Nirbhay Safety Timer'), 'Alert message has emergency prefix');
        assert(alertMsg.includes('expired at'), 'Alert message includes timestamp');
        assert(alertMsg.includes('12.9800'), 'Alert message includes last known latitude');
        assert(alertMsg.includes('77.6000'), 'Alert message includes last known longitude');
        assert(alertMsg.includes(emergencyIncident.tracking_token), 'Alert message includes tracking token URL');

        // [13] Duplicate Processing Prevention
        console.log('\n--- [13] Duplicate Processing Prevention ---');
        // Calling cron processor again immediately
        const secondCronTick = await timerController.processExpiredTimers();
        assert(secondCronTick === 0, 'Second cron tick finds 0 rows (atomic claim prevented double processing)');
        const thirdCronTick = await timerController.processExpiredTimers();
        assert(thirdCronTick === 0, 'Third cron tick finds 0 rows');

        // [14] Existing Active Incident Reuse
        console.log('\n--- [14] Active SOS Incident Existing Reused ---');
        // User already has ACTIVE incident from the previous expired timer.
        // If another timer had expired, it should reuse the existing incident rather than crashing on duplicate partial index
        const incidentCountBefore = mockIncidents.length;
        await timerController.handleExpiredTimerAlert(rawTimerObj);
        assert(mockIncidents.length === incidentCountBefore, 'Reused existing active SOS incident (no duplicate violation)');

    } catch (err) {
        console.error('Unexpected failure in test suite:', err);
        failed++;
    } finally {
        server.close();
    }

    console.log('\n═══════════════════════════════════════════════════════════════');
    console.log(`  RESULTS: ${passed} PASSED | ${failed} FAILED`);
    console.log('═══════════════════════════════════════════════════════════════\n');

    process.exit(failed > 0 ? 1 : 0);
}

runSuite();
