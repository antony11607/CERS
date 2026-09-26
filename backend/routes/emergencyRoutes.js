const express = require('express');
const router = express.Router();
const emergencyController = require('../controllers/emergencyController');
const { authenticate } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validation');

// Create a new emergency
router.post('/', authenticate, validate(schemas.createEmergency), emergencyController.createEmergency);

// Accept an emergency
router.post('/accept', authenticate, validate(schemas.acceptEmergency), emergencyController.acceptEmergency);

// Cancel an emergency
router.post('/cancel', authenticate, validate(schemas.cancelEmergency), emergencyController.cancelEmergency);

// Update emergency status
router.post('/status', authenticate, validate(schemas.updateEmergencyStatus), emergencyController.updateEmergencyStatus);

// Get nearby emergencies
router.get('/nearby', authenticate, emergencyController.getNearbyEmergencies);

module.exports = router;