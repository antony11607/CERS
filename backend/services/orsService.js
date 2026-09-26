const axios = require('axios');
require('dotenv').config();

// OpenRouteService API configuration
const ORS_API_KEY = process.env.ORS_API_KEY;
const ORS_BASE_URL = 'https://api.openrouteservice.org';

// Validate API key on load
if (!ORS_API_KEY) {
  console.error('[ORSService] ERROR: ORS_API_KEY is not defined in .env file');
}

/**
 * OpenRouteService API Service
 * Handles all map-related API calls to OpenRouteService
 */
class ORSService {
  /**
   * Get route between two coordinates
   * @param {number} startLat - Starting latitude
   * @param {number} startLng - Starting longitude
   * @param {number} endLat - Ending latitude
   * @param {number} endLng - Ending longitude
   * @returns {Promise<Object>} Route data with coordinates, distance, and duration
   */
  static async getRoute(startLat, startLng, endLat, endLng) {
    try {
      console.log(`[ORSService] Fetching route: (${startLat},${startLng}) -> (${endLat},${endLng})`);

      const url = `${ORS_BASE_URL}/v2/directions/driving-car?start=${startLng},${startLat}&end=${endLng},${startLat}`;

      console.log(`[ORSService] Request URL: ${url.replace(ORS_API_KEY, '***MASKED***')}`);
      const maskedKey = ORS_API_KEY ? `${ORS_API_KEY.substring(0, 10)}...` : 'UNDEFINED';
      console.log(`[ORSService] Request Headers:`, {
        'Authorization': `Bearer ${maskedKey}`,
        'Accept': 'application/json',
      });

      const response = await axios.get(url, {
        headers: {
          'Authorization': `Bearer ${ORS_API_KEY}`,
          'Accept': 'application/geo+json;charset=UTF-8',
        },
        timeout: 15000,
      });

      console.log(`[ORSService] Response Status: ${response.status}`);
      console.log(`[ORSService] Response Data:`, JSON.stringify(response.data).substring(0, 200));

      if (response.status === 200 && response.data.features && response.data.features.length > 0) {
        const feature = response.data.features[0];
        const coordinates = feature.geometry.coordinates;
        const summary = feature.properties.summary;

        // Convert [lng, lat] to [lat, lng] for Flutter
        const route = coordinates.map(coord => [coord[1], coord[0]]);

        console.log(`[ORSService] Route fetched successfully - ${route.length} points, ${summary.distance}m, ${summary.duration}s`);

        return {
          success: true,
          data: {
            route: route,
            distance: summary.distance,
            duration: summary.duration,
          },
        };
      } else {
        console.error('[ORSService] No route found in response');
        return {
          success: false,
          message: 'No route found',
        };
      }
    } catch (error) {
      console.error('[ORSService] Error fetching route:', error.message);
      if (error.response) {
        console.error('[ORSService] Error Response Status:', error.response.status);
        console.error('[ORSService] Error Response Data:', JSON.stringify(error.response.data));
        throw new Error(`Failed to fetch route: ${error.response.status} - ${JSON.stringify(error.response.data)}`);
      }
      throw new Error(`Failed to fetch route: ${error.message}`);
    }
  }

  /**
   * Get distance and ETA between two coordinates
   * @param {number} startLat - Starting latitude
   * @param {number} startLng - Starting longitude
   * @param {number} endLat - Ending latitude
   * @param {number} endLng - Ending longitude
   * @returns {Promise<Object>} Distance and duration data
   */
  static async getDistanceAndETA(startLat, startLng, endLat, endLng) {
    try {
      console.log(`[ORSService] Fetching distance/ETA: (${startLat},${startLng}) -> (${endLat},${endLng})`);

      const url = `${ORS_BASE_URL}/v2/directions/driving-car?start=${startLng},${startLat}&end=${endLng},${endLat}`;

      console.log(`[ORSService] Request URL: ${url.replace(ORS_API_KEY, '***MASKED***')}`);

      const response = await axios.get(url, {
        headers: {
          'Authorization': `Bearer ${ORS_API_KEY}`,
          'Accept': 'application/geo+json;charset=UTF-8',
        },
        timeout: 15000,
      });

      console.log(`[ORSService] Response Status: ${response.status}`);

      if (response.status === 200 && response.data.features && response.data.features.length > 0) {
        const summary = response.data.features[0].properties.summary;

        console.log(`[ORSService] Distance/ETA fetched - ${summary.distance}m, ${summary.duration}s`);

        return {
          success: true,
          data: {
            distance: summary.distance,
            duration: summary.duration,
          },
        };
      } else {
        console.error('[ORSService] No distance data found');
        return {
          success: false,
          message: 'No distance data found',
        };
      }
    } catch (error) {
      console.error('[ORSService] Error fetching distance:', error.message);
      if (error.response) {
        console.error('[ORSService] Error Response Status:', error.response.status);
        console.error('[ORSService] Error Response Data:', JSON.stringify(error.response.data));
        throw new Error(`Failed to fetch distance: ${error.response.status} - ${JSON.stringify(error.response.data)}`);
      }
      throw new Error(`Failed to fetch distance: ${error.message}`);
    }
  }

  /**
   * Reverse geocode coordinates to address
   * @param {number} lat - Latitude
   * @param {number} lng - Longitude
   * @returns {Promise<Object>} Address data
   */
  static async reverseGeocode(lat, lng) {
    try {
      console.log(`[ORSService] Reverse geocoding: (${lat}, ${lng})`);

      const url = `${ORS_BASE_URL}/geocode/reverse?point.lat=${lat}&point.lon=${lng}&format=json`;

      console.log(`[ORSService] Request URL: ${url.replace(ORS_API_KEY, '***MASKED***')}`);

      const response = await axios.get(url, {
        headers: {
          'Authorization': `Bearer ${ORS_API_KEY}`,
          'Accept': 'application/geo+json;charset=UTF-8',
        },
        timeout: 15000,
      });

      console.log(`[ORSService] Response Status: ${response.status}`);

      if (response.status === 200 && response.data.features && response.data.features.length > 0) {
        const address = response.data.features[0].properties.label;

        console.log(`[ORSService] Reverse geocoding successful: ${address}`);

        return {
          success: true,
          data: {
            address: address,
          },
        };
      } else {
        console.log('[ORSService] No address found for coordinates');
        return {
          success: false,
          message: 'Address not found for the given coordinates',
        };
      }
    } catch (error) {
      console.error('[ORSService] Error reverse geocoding:', error.message);
      if (error.response) {
        console.error('[ORSService] Error Response Status:', error.response.status);
        console.error('[ORSService] Error Response Data:', JSON.stringify(error.response.data));
        throw new Error(`Failed to reverse geocode: ${error.response.status} - ${JSON.stringify(error.response.data)}`);
      }
      throw new Error(`Failed to reverse geocode: ${error.message}`);
    }
  }
}

module.exports = ORSService;