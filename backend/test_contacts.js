require('dotenv').config();
const http = require('http');
const db = require('./src/config/db');

const PORT = process.env.PORT || 5000;
const timestamp = Date.now();
const userA_email = `contact_test_userA_${timestamp}@example.com`;
const userB_email = `contact_test_userB_${timestamp}@example.com`;
const password = 'Password123!';

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
    console.log('=== STARTING EMERGENCY CONTACTS TEST SUITE ===');

    let tokenA = null;
    let tokenB = null;
    let contact1_Id = null;
    let contact2_Id = null;
    let passedTests = 0;
    let totalTests = 0;

    function assert(condition, message) {
        totalTests++;
        if (condition) {
            console.log(`✅ PASS: ${message}`);
            passedTests++;
        } else {
            console.error(`❌ FAIL: ${message}`);
        }
    }

    try {
        // 0. Ensure schema is applied
        console.log('\n--- Applying database schema ---');
        const schemaSql = `
      CREATE EXTENSION IF NOT EXISTS "pgcrypto";
      CREATE TABLE IF NOT EXISTS users (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          full_name VARCHAR(255) NOT NULL,
          email VARCHAR(255) UNIQUE NOT NULL,
          phone VARCHAR(50),
          password_hash VARCHAR(255) NOT NULL,
          created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
      CREATE TABLE IF NOT EXISTS emergency_contacts (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          name VARCHAR(255) NOT NULL,
          phone VARCHAR(50) NOT NULL,
          relationship VARCHAR(100),
          auto_alert BOOLEAN NOT NULL DEFAULT true,
          created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    `;
        await db.query(schemaSql);
        console.log('Database schema verified.');

        // 1. Unauthenticated request (Should fail with 401)
        console.log('\n1. Testing GET /api/contacts without token...');
        const unauthRes = await makeRequest({
            hostname: 'localhost',
            port: PORT,
            path: '/api/contacts',
            method: 'GET',
        });
        assert(unauthRes.status === 401, 'Unauthenticated request rejected with status 401.');

        // 2. Register User A
        console.log('\n2. Registering User A...');
        const regA = await makeRequest(
            {
                hostname: 'localhost',
                port: PORT,
                path: '/api/auth/register',
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
            },
            { fullName: 'User A', email: userA_email, password }
        );
        tokenA = regA.body.token;
        assert(regA.status === 201 && tokenA, 'User A registered successfully.');

        // 3. Register User B
        console.log('\n3. Registering User B...');
        const regB = await makeRequest(
            {
                hostname: 'localhost',
                port: PORT,
                path: '/api/auth/register',
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
            },
            { fullName: 'User B', email: userB_email, password }
        );
        tokenB = regB.body.token;
        assert(regB.status === 201 && tokenB, 'User B registered successfully.');

        // 4. User A creates Emergency Contact 1
        console.log('\n4. User A creating Emergency Contact 1...');
        const addRes1 = await makeRequest(
            {
                hostname: 'localhost',
                port: PORT,
                path: '/api/contacts',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${tokenA}`,
                },
            },
            {
                name: 'Jane Doe (Sister)',
                phone: '+91 9876543210',
                relationship: 'Sister',
                autoAlert: true,
            }
        );
        assert(addRes1.status === 201 && addRes1.body.contact, 'Emergency Contact 1 created with status 201.');
        contact1_Id = addRes1.body.contact?.id;
        assert(addRes1.body.contact?.name === 'Jane Doe (Sister)', 'Contact name matches payload.');
        assert(addRes1.body.contact?.autoAlert === true, 'Contact autoAlert is true.');

        // 5. User A creates Emergency Contact 2
        console.log('\n5. User A creating Emergency Contact 2...');
        const addRes2 = await makeRequest(
            {
                hostname: 'localhost',
                port: PORT,
                path: '/api/contacts',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${tokenA}`,
                },
            },
            {
                name: 'Rahul Kumar',
                phone: '+91 9988776655',
                relationship: 'Friend',
                autoAlert: false,
            }
        );
        assert(addRes2.status === 201 && addRes2.body.contact, 'Emergency Contact 2 created with status 201.');
        contact2_Id = addRes2.body.contact?.id;

        // 6. User A lists emergency contacts (expect 2)
        console.log('\n6. User A fetching contact list...');
        const listResA = await makeRequest({
            hostname: 'localhost',
            port: PORT,
            path: '/api/contacts',
            method: 'GET',
            headers: { Authorization: `Bearer ${tokenA}` },
        });
        assert(listResA.status === 200, 'GET /api/contacts returned 200.');
        assert(listResA.body.contacts?.length === 2, 'User A has exactly 2 emergency contacts.');

        // 7. Validation tests (missing name, invalid phone)
        console.log('\n7. Testing input validation for POST /api/contacts...');
        const valRes1 = await makeRequest(
            {
                hostname: 'localhost',
                port: PORT,
                path: '/api/contacts',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${tokenA}`,
                },
            },
            { name: '', phone: '1234567' }
        );
        assert(valRes1.status === 400, 'Empty contact name rejected with 400.');

        const valRes2 = await makeRequest(
            {
                hostname: 'localhost',
                port: PORT,
                path: '/api/contacts',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${tokenA}`,
                },
            },
            { name: 'Test', phone: 'abc' }
        );
        assert(valRes2.status === 400, 'Invalid phone format rejected with 400.');

        // 8. User A updates Emergency Contact 1
        console.log('\n8. User A updating Emergency Contact 1...');
        const updateRes1 = await makeRequest(
            {
                hostname: 'localhost',
                port: PORT,
                path: `/api/contacts/${contact1_Id}`,
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${tokenA}`,
                },
            },
            { name: 'Jane Doe (Updated)', autoAlert: false }
        );
        assert(updateRes1.status === 200, 'PUT /api/contacts/:id returned 200.');
        assert(updateRes1.body.contact?.name === 'Jane Doe (Updated)', 'Updated name saved properly.');
        assert(updateRes1.body.contact?.autoAlert === false, 'Updated autoAlert saved properly.');

        // 9. Ownership Enforcement: User B attempts to update or delete User A's contact
        console.log('\n9. Testing ownership enforcement (User B trying to modify User A contact)...');
        const bUpdateRes = await makeRequest(
            {
                hostname: 'localhost',
                port: PORT,
                path: `/api/contacts/${contact1_Id}`,
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    Authorization: `Bearer ${tokenB}`,
                },
            },
            { name: 'Hacked Name' }
        );
        assert(bUpdateRes.status === 404, 'User B update on User A contact blocked with 404 Not Found.');

        const bDeleteRes = await makeRequest({
            hostname: 'localhost',
            port: PORT,
            path: `/api/contacts/${contact1_Id}`,
            method: 'DELETE',
            headers: { Authorization: `Bearer ${tokenB}` },
        });
        assert(bDeleteRes.status === 404, 'User B delete on User A contact blocked with 404 Not Found.');

        // 10. User B lists contacts (expect 0)
        console.log('\n10. User B fetching contact list...');
        const listResB = await makeRequest({
            hostname: 'localhost',
            port: PORT,
            path: '/api/contacts',
            method: 'GET',
            headers: { Authorization: `Bearer ${tokenB}` },
        });
        assert(listResB.body.contacts?.length === 0, 'User B contacts list is empty (0 contacts).');

        // 11. User A deletes Emergency Contact 2
        console.log('\n11. User A deleting Emergency Contact 2...');
        const deleteRes2 = await makeRequest({
            hostname: 'localhost',
            port: PORT,
            path: `/api/contacts/${contact2_Id}`,
            method: 'DELETE',
            headers: { Authorization: `Bearer ${tokenA}` },
        });
        assert(deleteRes2.status === 200, 'DELETE /api/contacts/:id returned 200.');

        // 12. Re-fetch User A contact list (expect 1 contact remaining)
        console.log('\n12. User A re-fetching contact list after deletion...');
        const finalListA = await makeRequest({
            hostname: 'localhost',
            port: PORT,
            path: '/api/contacts',
            method: 'GET',
            headers: { Authorization: `Bearer ${tokenA}` },
        });
        assert(finalListA.body.contacts?.length === 1, 'Exactly 1 contact remains in User A list.');
        assert(finalListA.body.contacts[0].id === contact1_Id, 'Remaining contact is Contact 1.');

        console.log(`\n==========================================`);
        console.log(`TEST RESULTS: ${passedTests}/${totalTests} TESTS PASSED`);
        console.log(`==========================================\n`);
    } catch (err) {
        console.error('Unexpected test failure:', err);
    } finally {
        process.exit(passedTests === totalTests ? 0 : 1);
    }
}

runTests();
