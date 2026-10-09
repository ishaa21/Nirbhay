require('dotenv').config();
const http = require('http');

const PORT = process.env.PORT || 5000;
const testEmail = `test_phase_b_${Date.now()}@example.com`;
const testPassword = 'Password123!';
const testFullName = 'Phase B User';
const testPhone = '9876543210';

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

async function runTests() {
  console.log('--- STARTING PHASE B TEST SUITE ---');
  let authToken = null;

  try {
    // 1. Unauthenticated GET /api/users/me (Should fail with 401)
    console.log('\n1. Testing GET /api/users/me without token...');
    const unauthRes = await makeRequest({
      hostname: 'localhost',
      port: PORT,
      path: '/api/users/me',
      method: 'GET',
    });
    console.log(`Status: ${unauthRes.status}`);
    console.log(`Response:`, unauthRes.body);
    if (unauthRes.status === 401) {
      console.log('✅ PASS: Rejected unauthenticated request.');
    } else {
      console.error('❌ FAIL: Expected 401 status.');
    }

    // 2. Register new test user
    console.log('\n2. Registering new test user for Phase B...');
    const regRes = await makeRequest(
      {
        hostname: 'localhost',
        port: PORT,
        path: '/api/auth/register',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      { fullName: testFullName, email: testEmail, password: testPassword, phone: testPhone }
    );
    console.log(`Status: ${regRes.status}`);
    console.log(`Response:`, regRes.body);

    if (regRes.status === 201 && regRes.body.token) {
      authToken = regRes.body.token;
      console.log('✅ PASS: User registered and token received.');
    } else {
      console.error('❌ FAIL: User registration failed.');
      return;
    }

    // 3. Authenticated GET /api/users/me with Bearer token
    console.log('\n3. Testing GET /api/users/me with valid JWT token...');
    const profileRes = await makeRequest({
      hostname: 'localhost',
      port: PORT,
      path: '/api/users/me',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${authToken}`,
      },
    });
    console.log(`Status: ${profileRes.status}`);
    console.log(`Response:`, profileRes.body);

    if (
      profileRes.status === 200 &&
      profileRes.body.user &&
      profileRes.body.user.email === testEmail
    ) {
      console.log('✅ PASS: Authenticated user profile retrieved successfully.');
    } else {
      console.error('❌ FAIL: Could not retrieve valid profile.');
    }

    // 4. Authenticated PUT /api/users/me to update profile
    console.log('\n4. Testing PUT /api/users/me to update profile details...');
    const updatedName = 'Phase B Updated Name';
    const updatedPhone = '9998887776';
    const updateRes = await makeRequest(
      {
        hostname: 'localhost',
        port: PORT,
        path: '/api/users/me',
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`,
        },
      },
      { fullName: updatedName, phone: updatedPhone }
    );
    console.log(`Status: ${updateRes.status}`);
    console.log(`Response:`, updateRes.body);

    if (
      updateRes.status === 200 &&
      updateRes.body.user &&
      updateRes.body.user.fullName === updatedName &&
      updateRes.body.user.phone === updatedPhone
    ) {
      console.log('✅ PASS: Profile updated successfully.');
    } else {
      console.error('❌ FAIL: Profile update failed.');
    }

    // 5. Verify update via GET /api/users/me
    console.log('\n5. Re-fetching profile to verify updated state persistence...');
    const verifyRes = await makeRequest({
      hostname: 'localhost',
      port: PORT,
      path: '/api/users/me',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${authToken}`,
      },
    });
    console.log(`Status: ${verifyRes.status}`);
    console.log(`Response:`, verifyRes.body);

    if (
      verifyRes.status === 200 &&
      verifyRes.body.user.fullName === updatedName &&
      verifyRes.body.user.phone === updatedPhone
    ) {
      console.log('✅ PASS: Verified profile state updated in database.');
    } else {
      console.error('❌ FAIL: Verified state does not match update.');
    }

    console.log('\n--- PHASE B TEST SUITE COMPLETED SUCCESSFULLY ---');
  } catch (err) {
    console.error('Unexpected test error:', err);
  }
}

runTests();
