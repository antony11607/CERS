const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');

// Import routes
const healthRoutes = require('./routes/healthRoutes');
const mapRoutes = require('./routes/mapRoutes');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(',') || true,
  credentials: true,
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Routes
app.use('/api/health', healthRoutes);
app.use('/api/maps', mapRoutes);

// 404 handler
app.use((req, res) => {
  console.log(`[404] Route not found: ${req.method} ${req.path}`);
  res.status(404).json({
    success: false,
    message: 'Route not found',
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('[Error] Global error handler:', err.message);
  console.error('[Error] Stack:', err.stack);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined,
  });
});

// Start server
app.listen(PORT, () => {
  console.log('========================================');
  console.log('CERS Map Services Backend');
  console.log('========================================');
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/api/health/check`);
  console.log('========================================');
  console.log('Registered API routes:');
  console.log('  - Health:');
  console.log('    GET  /api/health/check');
  console.log('  - Maps:');
  console.log('    GET    /api/maps/route');
  console.log('    GET    /api/maps/distance');
  console.log('    GET    /api/maps/eta');
  console.log('    GET    /api/maps/reverse-geocode');
  console.log('========================================');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[Server] SIGTERM signal received: closing HTTP server');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('[Server] SIGINT signal received: closing HTTP server');
  process.exit(0);
});

module.exports = app;