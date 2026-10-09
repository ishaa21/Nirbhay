const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const { validateRegistration, validateLogin } = require('../validators/authValidator');

const SALT_ROUNDS = 10;
const TOKEN_EXPIRY = '7d';

/**
 * POST /api/auth/register
 * Register a new user
 */
exports.register = async (req, res) => {
  try {
    const { full_name, fullName, email, password, phone } = req.body;
    const name = (full_name || fullName || '').trim();

    // 1. Input Validation
    const validation = validateRegistration({ full_name: name, email, password, phone });
    if (!validation.isValid) {
      return res.status(400).json({
        message: 'Validation failed',
        errors: validation.errors,
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // 2. Check for duplicate email
    const existingUserQuery = 'SELECT id FROM users WHERE LOWER(email) = $1';
    const existingUserResult = await db.query(existingUserQuery, [normalizedEmail]);

    if (existingUserResult.rows.length > 0) {
      return res.status(409).json({
        message: 'An account with this email address already exists.',
      });
    }

    // 3. Hash password
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    // 4. Insert User using Parameterized Query
    const insertQuery = `
      INSERT INTO users (full_name, email, phone, password_hash)
      VALUES ($1, $2, $3, $4)
      RETURNING id, full_name, email, phone, created_at, updated_at
    `;
    const insertValues = [name, normalizedEmail, phone ? phone.trim() : null, passwordHash];
    const newUserResult = await db.query(insertQuery, insertValues);
    const user = newUserResult.rows[0];

    // 5. Generate Access Token
    const token = jwt.sign(
      { userId: user.id },
      process.env.JWT_SECRET,
      { expiresIn: TOKEN_EXPIRY }
    );

    // 6. Return Safe Profile + Token (Excluding password_hash)
    return res.status(201).json({
      message: 'User registered successfully',
      token,
      user: {
        id: user.id,
        fullName: user.full_name,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        createdAt: user.created_at,
        created_at: user.created_at,
        updatedAt: user.updated_at,
        updated_at: user.updated_at,
      },
    });
  } catch (error) {
    console.error('Error during registration:', error);
    return res.status(500).json({
      message: 'Internal server error during registration',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

/**
 * POST /api/auth/login
 * Authenticate user and issue JWT
 */
exports.login = async (req, res) => {
  const loginStart = Date.now();
  console.log(`[LOGIN] Request received from ${req.ip} at ${new Date().toISOString()}`);

  try {
    const { email, password } = req.body;

    // 1. Input Validation
    const validation = validateLogin({ email, password });
    if (!validation.isValid) {
      console.log(`[LOGIN] Validation failed: ${validation.errors.join(', ')}`);
      return res.status(400).json({
        message: 'Validation failed',
        errors: validation.errors,
      });
    }
    console.log(`[LOGIN] Validation OK for email: ${email?.split('@')[0]}@*** (+${Date.now() - loginStart}ms)`);

    const normalizedEmail = email.trim().toLowerCase();

    // 2. Find User by Email
    console.log(`[LOGIN] Querying DB for user... (+${Date.now() - loginStart}ms)`);
    const userQuery = 'SELECT id, full_name, email, phone, password_hash, created_at, updated_at FROM users WHERE LOWER(email) = $1';
    const userResult = await db.query(userQuery, [normalizedEmail]);
    console.log(`[LOGIN] DB query done, found ${userResult.rows.length} user(s) (+${Date.now() - loginStart}ms)`);

    if (userResult.rows.length === 0) {
      return res.status(401).json({
        message: 'Invalid email or password.',
      });
    }

    const user = userResult.rows[0];

    // 3. Verify Password Hash
    console.log(`[LOGIN] Verifying password hash... (+${Date.now() - loginStart}ms)`);
    const isMatch = await bcrypt.compare(password, user.password_hash);
    console.log(`[LOGIN] Password match: ${isMatch} (+${Date.now() - loginStart}ms)`);

    if (!isMatch) {
      return res.status(401).json({
        message: 'Invalid email or password.',
      });
    }

    // 4. Generate JWT
    const token = jwt.sign(
      { userId: user.id },
      process.env.JWT_SECRET,
      { expiresIn: TOKEN_EXPIRY }
    );
    console.log(`[LOGIN] JWT generated, sending 200 response (+${Date.now() - loginStart}ms)`);

    // 5. Return Safe Profile + Token
    return res.status(200).json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        fullName: user.full_name,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        createdAt: user.created_at,
        created_at: user.created_at,
        updatedAt: user.updated_at,
        updated_at: user.updated_at,
      },
    });
  } catch (error) {
    console.error(`[LOGIN] Error after +${Date.now() - loginStart}ms:`, error.message);
    return res.status(500).json({
      message: 'Internal server error during login',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};
