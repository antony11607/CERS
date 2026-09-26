const express = require('express');
const router = express.Router();
const MapController = require('../controllers/mapController');

/**
 * Map Routes
 * All routes are public (no authentication required)
 * These routes proxy requests to OpenRouteService
 */

// GET /api/maps/route - Get route between two coordinates
router.get('/route', MapController.getRoute);

// GET /api/maps/distance - Get distance and ETA between two coordinates
router.get('/distance', MapController.getDistance);

// GET /api/maps/eta - Get ETA between two coordinates
router.get('/eta', MapController.getETA);

// GET /api/maps/reverse-geocode - Reverse geocode coordinates to address
router.get('/reverse-geocode', MapController.reverseGeocode);

module.exports = router;