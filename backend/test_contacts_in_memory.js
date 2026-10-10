require('dotenv').config();
const http = require('http');
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');

// Set dummy JWT_SECRET if not set
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_123';

// In-memory data store for testing controller and route logic
const mockUsers = [];
const mockContacts = [];

// Mock DB implementation replacing postgres pool for test verification
const mockDb = {
    query: async (text, params) => {
        const cleanSql = text.replace(/\s+/g, ' ').trim();

        // 1. Users table queries
        if (cleanSql.includes('INSERT INTO users')) {
            const newUser = {
                id: `user-uuid-${mockUsers.length + 1}`,
                full_name: params[0],
                email: params[1],
                phone: params[3] || null,
                password_hash: params[2],
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
            };
            mockUsers.push(newUser);
            return { rows: [newUser] };
        }

        if (cleanSql.includes('SELECT') && cleanSql.includes('FROM users WHERE email = $1')) {
            const found = mockUsers.filter((u) => u.email === params[0]);
            return { rows: found };
        }

        // 2. Emergency Contacts queries
        if (cleanSql.includes('SELECT') && cleanSql.includes('FROM emergency_contacts WHERE user_id = $1')) {
            const found = mockContacts.filter((c) => c.user_id === params[0]);
            return { rows: found };
        }

        if (cleanSql.includes('INSERT INTO emergency_contacts')) {
            const newContact = {
                id: `contact-uuid-${mockContacts.length + 1}`,
                user_id: params[0],
                name: params[1],
                phone: params[2],
                relationship: params[3] || '',
                auto_alert: params[4] !== undefined ? params[4] : true,
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
            };
            mockContacts.push(newContact);
            return { rows: [newContact] };
        }

        if (cleanSql.includes('SELECT * FROM emergency_contacts WHERE id = $1 AND user_id = $2')) {
            const found = mockContacts.filter((c) => c.id === params[0] && c.user_id === params[1]);
            return { rows: found };
        }

        if (cleanSql.includes('UPDATE emergency_contacts')) {
            const index = mockContacts.findIndex((c) => c.id === params[4] && c.user_id === params[5]);
            if (index !== -1) {
                mockContacts[index].name = params[0];
                mockContacts[index].phone = params[1];
                mockContacts[index].relationship = params[2];
                mockContacts[index].auto_alert = params[3];
                mockContacts[index].updated_at = new Date().toISOString();
                return { rows: [mockContacts[index]] };
            }
            return { rows: [] };
        }

        if (cleanSql.includes('DELETE FROM emergency_contacts WHERE id = $1 AND user_id = $2')) {
            const index = mockContacts.findIndex((c) => c.id === params[0] && c.user_id === params[1]);
            if (index !== -1) {
                const deleted = mockContacts.splice(index, 1)[0];
                return { rows: [{ id: deleted.id }] };
            }
            return { rows: [] };
        }

        return { rows: [] };
    },
};

// Require real controllers/middleware and inject mockDb
const contactController = require('./src/controllers/contactController');
const authenticateToken = require('./src/middleware/authMiddleware');

// Override db in controller by replacing query execution
const originalDb = require('./src/config/db');
originalDb.query = mockDb.query;

// Build Express App for isolated test
const app = express();
app.use(cors());
app.use(express.json());

// Auth helper routes for test setup
app.post('/api/auth/register', (req, res) => {
    const { fullName, email, password } = req.body;
    const user = {
        id: `user-${Date.now()}-${Math.random()}`,
        fullName,
        email,
    };
    mockUsers.push(user);
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '1h' });
    res.status(201).json({ message: 'User registered.', token, user });
});

const router = express.Router();
router.use(authenticateToken);
router.get('/', contactController.getContacts);
router.post('/', contactController.addContact);
router.put('/:id', contactController.updateContact);
router.delete('/:id', contactController.deleteContact);

app.use('/api/contacts', router);

const TEST_PORT = 5055;
const server = app.listen(TEST_PORT, async () => {
    console.log(`Test server running on port ${TEST_PORT}`);
    await runTests();
    server.close(() => process.exit(0));
});

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
    console.log('\n=== RUNNING IN-MEMORY EMERGENCY CONTACTS API INTEGRATION TESTS ===');
    let passed = 0;
    let total = 0;

    function assert(cond, msg) {
        total++;
        if (cond) {
            console.log(`✅ PASS: ${msg}`);
            passed++;
        } else {
            console.error(`❌ FAIL: ${msg}`);
        }
    }

    // 1. Test 401 Unauthenticated
    const r1 = await makeRequest({ hostname: 'localhost', port: TEST_PORT, path: '/api/contacts', method: 'GET' });
    assert(r1.status === 401, '401 Unauthorized returned when no Bearer token provided.');

    // 2. Register User A and User B
    const rUserA = await makeRequest(
        { hostname: 'localhost', port: TEST_PORT, path: '/api/auth/register', method: 'POST', headers: { 'Content-Type': 'application/json' } },
        { fullName: 'User A', email: 'usera@example.com' }
    );
    const tokenA = rUserA.body.token;

    const rUserB = await makeRequest(
        { hostname: 'localhost', port: TEST_PORT, path: '/api/auth/register', method: 'POST', headers: { 'Content-Type': 'application/json' } },
        { fullName: 'User B', email: 'userb@example.com' }
    );
    const tokenB = rUserB.body.token;

    // 3. User A Adds Contact 1
    const rAdd1 = await makeRequest(
        {
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/contacts',
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokenA}` },
        },
        { name: 'Jane Doe', phone: '+91 9876543210', relationship: 'Sister', autoAlert: true }
    );
    assert(rAdd1.status === 201, 'POST /api/contacts returned status 201 Created.');
    assert(rAdd1.body.contact.name === 'Jane Doe', 'Contact name matches input.');
    assert(rAdd1.body.contact.autoAlert === true, 'AutoAlert is true.');
    const contact1Id = rAdd1.body.contact.id;

    // 4. User A Adds Contact 2
    const rAdd2 = await makeRequest(
        {
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/contacts',
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokenA}` },
        },
        { name: 'Rahul Kumar', phone: '+91 9988776655', relationship: 'Friend', autoAlert: false }
    );
    assert(rAdd2.status === 201, 'POST /api/contacts created second contact.');
    const contact2Id = rAdd2.body.contact.id;

    // 5. User A Lists Contacts (Expect 2)
    const rListA = await makeRequest({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/api/contacts',
        method: 'GET',
        headers: { Authorization: `Bearer ${tokenA}` },
    });
    assert(rListA.status === 200, 'GET /api/contacts returned 200 OK.');
    assert(rListA.body.contacts.length === 2, 'User A list contains 2 contacts.');

    // 6. Input Validation: Missing name
    const rVal1 = await makeRequest(
        {
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/contacts',
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokenA}` },
        },
        { name: '   ', phone: '+91 9876543210' }
    );
    assert(rVal1.status === 400, 'Validation: Empty contact name rejected with 400.');

    // 7. Input Validation: Invalid phone number
    const rVal2 = await makeRequest(
        {
            hostname: 'localhost',
            port: TEST_PORT,
            path: '/api/contacts',
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokenA}` },
        },
        { name: 'Valid Name', phone: '123' }
    );
    assert(rVal2.status === 400, 'Validation: Short phone number rejected with 400.');

    // 8. User A Updates Contact 1
    const rUp1 = await makeRequest(
        {
            hostname: 'localhost',
            port: TEST_PORT,
            path: `/api/contacts/${contact1Id}`,
            method: 'PUT',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokenA}` },
        },
        { name: 'Jane Doe (Updated)', autoAlert: false }
    );
    assert(rUp1.status === 200, 'PUT /api/contacts/:id returned 200 OK.');
    assert(rUp1.body.contact.name === 'Jane Doe (Updated)', 'Name updated correctly.');
    assert(rUp1.body.contact.autoAlert === false, 'AutoAlert updated correctly.');

    // 9. Ownership Enforcement: User B tries to update User A's contact
    const rHackedUp = await makeRequest(
        {
            hostname: 'localhost',
            port: TEST_PORT,
            path: `/api/contacts/${contact1Id}`,
            method: 'PUT',
            headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokenB}` },
        },
        { name: 'Unauthorized Name' }
    );
    assert(rHackedUp.status === 404, 'Ownership Enforcement: User B update on User A contact blocked with 404.');

    // 10. Ownership Enforcement: User B tries to delete User A's contact
    const rHackedDel = await makeRequest({
        hostname: 'localhost',
        port: TEST_PORT,
        path: `/api/contacts/${contact1Id}`,
        method: 'DELETE',
        headers: { Authorization: `Bearer ${tokenB}` },
    });
    assert(rHackedDel.status === 404, 'Ownership Enforcement: User B delete on User A contact blocked with 404.');

    // 11. User B Lists Contacts (Expect 0)
    const rListB = await makeRequest({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/api/contacts',
        method: 'GET',
        headers: { Authorization: `Bearer ${tokenB}` },
    });
    assert(rListB.body.contacts.length === 0, 'User B contacts list is empty (0 contacts).');

    // 12. User A Deletes Contact 2
    const rDel2 = await makeRequest({
        hostname: 'localhost',
        port: TEST_PORT,
        path: `/api/contacts/${contact2Id}`,
        method: 'DELETE',
        headers: { Authorization: `Bearer ${tokenA}` },
    });
    assert(rDel2.status === 200, 'DELETE /api/contacts/:id returned 200 OK.');

    // 13. Verify final list for User A (Expect 1 contact remaining)
    const rFinalListA = await makeRequest({
        hostname: 'localhost',
        port: TEST_PORT,
        path: '/api/contacts',
        method: 'GET',
        headers: { Authorization: `Bearer ${tokenA}` },
    });
    assert(rFinalListA.body.contacts.length === 1, 'Final List: Exactly 1 contact remaining for User A.');
    assert(rFinalListA.body.contacts[0].id === contact1Id, 'Remaining contact is Contact 1.');

    console.log(`\n======================================================`);
    console.log(`RESULT: ${passed}/${total} TESTS PASSED SUCCESSFULLY!`);
    console.log(`======================================================\n`);
}
