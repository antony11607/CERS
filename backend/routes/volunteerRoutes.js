const express = require('express');
const router = express.Router();
const volunteerController = require('../controllers/volunteerController');
const { authenticate } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validation');

// Update volunteer location
router.post('/location', authenticate, validate(schemas.updateVolunteerLocation), volunteerController.updateVolunteerLocation);

// Get nearby volunteers
router.get('/nearby', authenticate, volunteerController.getNearbyVolunteers);

module.exports = router;