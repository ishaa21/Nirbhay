const jwt = require('jsonwebtoken');

/**
 * Optional JWT Authentication Middleware
 * If a valid Bearer token is provided, attaches req.userId.
 * If no token is provided or token is invalid/expired, proceeds with req.userId = null
 * without blocking the request.
 */
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    req.userId = null;
    return next();
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded && decoded.userId) {
      req.userId = decoded.userId;
    } else {
      req.userId = null;
    }
  } catch (_) {
    req.userId = null;
  }
  next();
};

module.exports = optionalAuth;
