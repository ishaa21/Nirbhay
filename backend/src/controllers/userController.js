const db = require('../config/db');

/**
 * Get current authenticated user profile
 * GET /api/users/me
 */
const getProfile = async (req, res) => {
  try {
    const userId = req.userId;

    const userResult = await db.query(
      'SELECT id, full_name, email, phone, created_at, updated_at FROM users WHERE id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({
        message: 'User profile not found.',
      });
    }

    const user = userResult.rows[0];

    res.status(200).json({
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
    console.error('Get Profile Error:', error.message);
    res.status(500).json({
      message: 'Server error while fetching profile. Please try again later.',
    });
  }
};

/**
 * Update authenticated user profile
 * PUT /api/users/me
 */
const updateProfile = async (req, res) => {
  try {
    const userId = req.userId;
    const { fullName, email, phone } = req.body;

    // Fetch existing user
    const existingUserRes = await db.query('SELECT * FROM users WHERE id = $1', [userId]);
    if (existingUserRes.rows.length === 0) {
      return res.status(404).json({
        message: 'User profile not found.',
      });
    }

    const currentProfile = existingUserRes.rows[0];

    // Determine target values (preserve existing if not provided)
    const targetName = fullName !== undefined ? fullName : (req.body.full_name !== undefined ? req.body.full_name : undefined);
    const newFullName = targetName !== undefined ? targetName.trim() : currentProfile.full_name;
    const newEmail = email !== undefined ? email.trim().toLowerCase() : currentProfile.email;
    const newPhone = phone !== undefined ? (phone ? phone.trim() : null) : currentProfile.phone;

    if (!newFullName) {
      return res.status(400).json({
        message: 'Full name cannot be empty.',
      });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(newEmail)) {
      return res.status(400).json({
        message: 'Invalid email address format.',
      });
    }

    // Check if new email conflicts with another user
    if (newEmail !== currentProfile.email) {
      const emailCheck = await db.query('SELECT id FROM users WHERE email = $1 AND id != $2', [
        newEmail,
        userId,
      ]);
      if (emailCheck.rows.length > 0) {
        return res.status(409).json({
          message: 'An account with this email address already exists.',
        });
      }
    }

    // Execute update
    const updateResult = await db.query(
      `UPDATE users
       SET full_name = $1, email = $2, phone = $3, updated_at = CURRENT_TIMESTAMP
       WHERE id = $4
       RETURNING id, full_name, email, phone, created_at, updated_at`,
      [newFullName, newEmail, newPhone, userId]
    );

    const updatedUser = updateResult.rows[0];

    res.status(200).json({
      message: 'Profile updated successfully.',
      user: {
        id: updatedUser.id,
        fullName: updatedUser.full_name,
        full_name: updatedUser.full_name,
        email: updatedUser.email,
        phone: updatedUser.phone,
        createdAt: updatedUser.created_at,
        created_at: updatedUser.created_at,
        updatedAt: updatedUser.updated_at,
        updated_at: updatedUser.updated_at,
      },
    });
  } catch (error) {
    console.error('Update Profile Error:', error.message);
    res.status(500).json({
      message: 'Server error while updating profile. Please try again later.',
    });
  }
};

module.exports = {
  getProfile,
  updateProfile,
};
