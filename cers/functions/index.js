const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');
const app = express();

// Middleware
app.use(cors({ origin: true }));
app.use(express.json());

// Import routes
const mapRoutes = require('./routes/mapRoutes');
const healthRoutes = require('./routes/healthRoutes');

// Routes
app.use('/api/maps', mapRoutes);
app.use('/api/health', healthRoutes);

// Debug logs for startup
console.log('Firebase Functions initialized.');
console.log('Express server initialized.');
console.log('Registered API routes: /api/maps, /api/health');
console.log('Environment variables loaded successfully.');

// Export the Express app as a Firebase Cloud Function
exports.api = functions.https.onRequest(app);