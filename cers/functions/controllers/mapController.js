const axios = require('axios');
require('dotenv').config();

// OpenRouteService API key from environment
const ORS_API_KEY = process.env.ORS_API_KEY;
const ORS_BASE_URL = 'https://api.openrouteservice.org';

/**
 * Get route between two coordinates
 * Query params: startLat, startLng, endLat, endLng
 */
exports.getRoute = async (req, res) => {
  try {
    const { startLat, startLng, endLat, endLng } = req.query;

    if (!startLat || !startLng || !endLat || !endLng) {
      return res.status(400).json({
        success: false,
        message: 'Missing required parameters: startLat, startLng, endLat, endLng'
      });
    }

    const url = `${ORS_BASE_URL}/v2/directions/driving-car?api_key=${ORS_API_KEY}&start=${startLng},${startLat}&end=${endLng},${endLat}`;

    const response = await axios.get(url, {
      headers: { 'Accept': 'application/json' }
    });

    if (response.status === 200) {
      const coordinates = response.data.features[0].geometry.coordinates;
      
      // Convert [lng, lat] to [lat, lng] for Flutter
      const route = coordinates.map(coord => [coord[1], coord[0]]);

      res.status(200).json({
        success: true,
        data: {
          route: route,
          distance: response.data.features[0].properties.summary.distance,
          duration: response.data.features[0].properties.summary.duration
        }
      });
    } else {
      throw new Error('OpenRouteService API error');
    }
  } catch (error) {
    console.error('Error fetching route:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch route',
      error: error.message
    });
  }
};

/**
 * Get distance and ETA between two coordinates
 * Query params: startLat, startLng, endLat, endLng
 */
exports.getDistanceAndETA = async (req, res) => {
  try {
    const { startLat, startLng, endLat, endLng } = req.query;

    if (!startLat || !startLng || !endLat || !endLng) {
      return res.status(400).json({
        success: false,
        message: 'Missing required parameters: startLat, startLng, endLat, endLng'
      });
    }

    const url = `${ORS_BASE_URL}/v2/directions/driving-car?api_key=${ORS_API_KEY}&start=${startLng},${startLat}&end=${endLng},${endLat}`;

    const response = await axios.get(url, {
      headers: { 'Accept': 'application/json' }
    });

    if (response.status === 200) {
      const summary = response.data.features[0].properties.summary;

      res.status(200).json({
        success: true,
        data: {
          distance: summary.distance, // in meters
          duration: summary.duration // in seconds
        }
      });
    } else {
      throw new Error('OpenRouteService API error');
    }
  } catch (error) {
    console.error('Error fetching distance:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch distance and ETA',
      error: error.message
    });
  }
};

/**
 * Reverse geocode coordinates to address
 * Query params: lat, lng
 */
exports.reverseGeocode = async (req, res) => {
  try {
    const { lat, lng } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({
        success: false,
        message: 'Missing required parameters: lat, lng'
      });
    }

    const url = `${ORS_BASE_URL}/geocode/reverse?api_key=${ORS_API_KEY}&point.lat=${lat}&point.lon=${lng}&format=json`;

    const response = await axios.get(url, {
      headers: { 'Accept': 'application/json' }
    });

    if (response.status === 200 && response.data.features && response.data.features.length > 0) {
      const address = response.data.features[0].properties.label;

      res.status(200).json({
        success: true,
        data: {
          address: address
        }
      });
    } else {
      res.status(404).json({
        success: false,
        message: 'Address not found for the given coordinates'
      });
    }
  } catch (error) {
    console.error('Error reverse geocoding:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to reverse geocode',
      error: error.message
    });
  }
};