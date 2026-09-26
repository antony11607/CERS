const Joi = require('joi');

/**
 * Validation middleware factory
 */
const validate = (schema) => {
  return (req, res, next) => {
    const { error } = schema.validate(req.body);
    
    if (error) {
      console.error('[Validation] Validation error:', error.details[0].message);
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        error: error.details[0].message,
      });
    }

    console.log('[Validation] Request payload validated successfully');
    next();
  };
};

// Validation schemas
const schemas = {
  // Emergency creation schema
  createEmergency: Joi.object({
    latitude: Joi.number().required().min(-90).max(90),
    longitude: Joi.number().required().min(-180).max(180),
  }),

  // Emergency acceptance schema
  acceptEmergency: Joi.object({
    emergencyId: Joi.string().required(),
    volunteerId: Joi.string().required(),
    volunteerName: Joi.string().required(),
    volunteerPhone: Joi.string().required(),
  }),

  // Emergency cancellation schema
  cancelEmergency: Joi.object({
    emergencyId: Joi.string().required(),
  }),

  // Volunteer location update schema
  updateVolunteerLocation: Joi.object({
    volunteerId: Joi.string().required(),
    latitude: Joi.number().required().min(-90).max(90),
    longitude: Joi.number().required().min(-180).max(180),
  }),

  // Route request schema
  getRoute: Joi.object({
    startLat: Joi.number().required().min(-90).max(90),
    startLng: Joi.number().required().min(-180).max(180),
    endLat: Joi.number().required().min(-90).max(90),
    endLng: Joi.number().required().min(-180).max(180),
  }),

  // Distance/ETA request schema
  getDistanceAndETA: Joi.object({
    startLat: Joi.number().required().min(-90).max(90),
    startLng: Joi.number().required().min(-180).max(180),
    endLat: Joi.number().required().min(-90).max(90),
    endLng: Joi.number().required().min(-180).max(180),
  }),

  // Reverse geocode request schema
  reverseGeocode: Joi.object({
    lat: Joi.number().required().min(-90).max(90),
    lng: Joi.number().required().min(-180).max(180),
  }),

  // Update emergency status schema
  updateEmergencyStatus: Joi.object({
    emergencyId: Joi.string().required(),
    status: Joi.string().valid('waiting', 'accepted', 'en_route', 'arrived', 'resolved', 'cancelled').required(),
  }),
};

module.exports = { validate, schemas };