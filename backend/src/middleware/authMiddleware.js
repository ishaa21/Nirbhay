const jwt = require('jsonwebtoken');

/**
 * JWT Authentication Middleware
 * Verifies Bearer token in Authorization header and attaches req.userId
 */
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Extract token from "Bearer <token>"

  if (!token) {
    return res.status(401).json({
      message: 'Authentication token required. Please log in.',
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (!decoded || !decoded.userId) {
      return res.status(401).json({
        message: 'Invalid token payload.',
      });
    }

    // Attach authenticated user ID to request
    req.userId = decoded.userId;
    next();
  } catch (error) {
    console.error('JWT Verification Error:', error.message);
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        message: 'Authentication token has expired. Please log in again.',
        code: 'TOKEN_EXPIRED',
      });
    }
    return res.status(401).json({
      message: 'Invalid or corrupted authentication token.',
      code: 'TOKEN_INVALID',
    });
  }
};

module.exports = authenticateToken;
