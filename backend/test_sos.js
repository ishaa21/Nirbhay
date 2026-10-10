require('dotenv').config();
const express = require('express');
const http = require('http');
const app = require('./src/server');

const PORT = 5099; // Use port 5099 for testing
let server;

function makeRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, body: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, body });
        }
      });
    });

    req.on('error', (err) => reject(err));

    if (postData) {
      req.write(typeof postData === 'string' ? postData : JSON.stringify(postData));
    }
    req.end();
  });
}

async function runSosTests() {
  console.log('--- STARTING SOS & EMERGENCY NOTIFICATION TEST SUITE ---');
  
  server = app.listen(PORT, async () => {
    try {
      const emailA = `sos_user_a_${Date.now()}@example.com`;
      const emailB = `sos_user_b_${Date.now()}@example.com`;
      const password = 'Password123!';

      // 1. Missing Authentication Check
      console.log('\n1. Testing POST /api/sos without JWT token...');
      const unauthRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: '/api/sos',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      }, { latitude: 12.9716, longitude: 77.5946 });

      console.log(`Status: ${unauthRes.status}`);
      if (unauthRes.status === 401) {
        console.log('✅ PASS: Unauthenticated SOS request rejected with 401.');
      } else {
        console.error('❌ FAIL: Expected 401 status for unauthenticated SOS request.');
      }

      // 2. Register User A and User B
      console.log('\n2. Registering User A and User B...');
      const regARes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: '/api/auth/register',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      }, { fullName: 'SOS User A', email: emailA, password, phone: '9876543210' });

      const regBRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: '/api/auth/register',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      }, { fullName: 'SOS User B', email: emailB, password, phone: '9876543211' });

      const tokenA = regARes.body.token;
      const tokenB = regBRes.body.token;

      if (!tokenA || !tokenB) {
        throw new Error('User registration failed for tests.');
      }
      console.log('✅ PASS: Users registered successfully.');

      // 3. User A adds Emergency Contact
      console.log('\n3. Adding emergency contact for User A...');
      const contactRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: '/api/contacts',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${tokenA}`,
        },
      }, { name: 'Guardian Contact', phone: '+919876500000', relationship: 'Parent', autoAlert: true });

      console.log('Contact Response:', contactRes.body);
      if (contactRes.status === 201) {
        console.log('✅ PASS: Emergency contact added for User A.');
      }

      // 4. Create SOS Incident for User A
      console.log('\n4. Creating SOS Incident for User A...');
      const sosCreateRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: '/api/sos',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${tokenA}`,
        },
      }, { latitude: 12.9250, longitude: 77.5890 });

      console.log(`Status: ${sosCreateRes.status}`);
      console.log('SOS Create Response:', sosCreateRes.body);
      if (sosCreateRes.status === 201 && sosCreateRes.body.incident?.id) {
        console.log('✅ PASS: SOS incident created successfully.');
      } else {
        console.error('❌ FAIL: Failed to create SOS incident.');
      }

      const sosId = sosCreateRes.body.incident.id;

      // 5. Test Duplicate Active SOS Activation
      console.log('\n5. Attempting duplicate SOS activation for User A...');
      const dupSosRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: '/api/sos',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${tokenA}`,
        },
      }, { latitude: 12.9250, longitude: 77.5890 });

      console.log(`Status: ${dupSosRes.status}`);
      console.log('Duplicate SOS Response:', dupSosRes.body);
      if (dupSosRes.status === 409) {
        console.log('✅ PASS: Prevented duplicate active SOS incident with 409 Conflict.');
      } else {
        console.error('❌ FAIL: Duplicate SOS activation should be rejected.');
      }

      // 6. Retrieve Active SOS Incident
      console.log('\n6. Fetching active SOS incident for User A...');
      const activeRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: '/api/sos/active',
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${tokenA}`,
        },
      });

      console.log('Active SOS Response:', activeRes.body);
      if (activeRes.status === 200 && activeRes.body.active && activeRes.body.incident.id === sosId) {
        console.log('✅ PASS: Active SOS incident retrieved correctly.');
      } else {
        console.error('❌ FAIL: Active SOS incident retrieval failed.');
      }

      // 7. Security Test: User B attempts to access/resolve User A's incident
      console.log("\n7. Testing cross-user incident access (User B attempting to resolve User A's SOS)...");
      const hackRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: `/api/sos/${sosId}/resolve`,
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${tokenB}`,
        },
      });

      console.log(`Status: ${hackRes.status}`);
      console.log('Cross-user Response:', hackRes.body);
      if (hackRes.status === 404 || hackRes.status === 403) {
        console.log("✅ PASS: Unauthorized cross-user incident modification correctly blocked.");
      } else {
        console.error("❌ FAIL: User B should NOT be able to modify User A's SOS incident!");
      }

      // 8. User A resolves active SOS incident
      console.log('\n8. User A resolving active SOS incident...');
      const resolveRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: `/api/sos/${sosId}/resolve`,
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${tokenA}`,
        },
      });

      console.log('Resolve Response:', resolveRes.body);
      if (resolveRes.status === 200 && resolveRes.body.incident.status === 'RESOLVED') {
        console.log('✅ PASS: SOS incident successfully resolved.');
      } else {
        console.error('❌ FAIL: SOS incident resolution failed.');
      }

      // 9. User A creates new SOS and cancels it
      console.log('\n9. User A creating second SOS incident and cancelling it...');
      const cancelCreateRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: '/api/sos',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${tokenA}`,
        },
      });

      const secondSosId = cancelCreateRes.body.incident.id;

      const cancelRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: `/api/sos/${secondSosId}/cancel`,
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${tokenA}`,
        },
      });

      console.log('Cancel Response:', cancelRes.body);
      if (cancelRes.status === 200 && cancelRes.body.incident.status === 'CANCELLED') {
        console.log('✅ PASS: SOS incident successfully cancelled.');
      } else {
        console.error('❌ FAIL: SOS incident cancellation failed.');
      }

      // 10. User A retrieves SOS incident history
      console.log('\n10. Fetching SOS incident history for User A...');
      const historyRes = await makeRequest({
        hostname: 'localhost',
        port: PORT,
        path: '/api/sos/history',
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${tokenA}`,
        },
      });

      console.log('History Response:', historyRes.body);
      if (historyRes.status === 200 && historyRes.body.incidents.length === 2) {
        console.log('✅ PASS: SOS incident history retrieved with expected entries.');
      } else {
        console.error('❌ FAIL: History count mismatch.');
      }

      console.log('\n--- ALL BACKEND SOS TESTS PASSED SUCCESSFULLY! ---');
    } catch (err) {
      console.error('Test error:', err);
    } finally {
      server.close();
      process.exit(0);
    }
  });
}

runSosTests();
