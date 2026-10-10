require('dotenv').config();
const express = require('express');
const cors = require('cors');
const db = require('./config/db');
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const contactRoutes = require('./routes/contactRoutes');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/contacts', contactRoutes);

// Health Check Endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    message: 'Nirbhay Women Safety Application Backend API is running smoothly.',
    timestamp: new Date().toISOString(),
  });
});

// Database Health Check Endpoint
app.get('/health/db', async (req, res) => {
  try {
    const result = await db.query('SELECT NOW()');
    res.status(200).json({
      status: 'UP',
      database: 'Connected',
      dbTimestamp: result.rows[0].now,
      message: 'PostgreSQL database connection pool is active.',
    });
  } catch (error) {
    console.error('Database connection test failed:', error.message);
    res.status(500).json({
      status: 'DOWN',
      database: 'Disconnected',
      error: error.message,
      hint: 'Ensure PostgreSQL is running and the "safety_app" database exists.',
    });
  }
});

// Start Server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`),
    console.log(`Local:    http://localhost:${PORT}/health`),
    console.log(`Network:  http://10.107.175.106:${PORT}/health`),
    console.log(`DB check: http://localhost:${PORT}/health/db`)
});

module.exports = app;
