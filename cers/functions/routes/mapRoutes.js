const express = require('express');
const router = express.Router();
const mapController = require('../controllers/mapController');

// Get route between two coordinates
router.get('/route', mapController.getRoute);

// Get distance and ETA between two coordinates
router.get('/distance', mapController.getDistanceAndETA);

// Reverse geocode coordinates to address
router.get('/geocode', mapController.reverseGeocode);

module.exports = router;