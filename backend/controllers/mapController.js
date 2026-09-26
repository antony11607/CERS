const ORSService = require('../services/orsService');

/**
 * Map Controller
 * Handles map-related API endpoints using OpenRouteService
 */
class MapController {
  /**
   * Get route between two coordinates
   * GET /api/maps/route
   * Query params: startLat, startLng, endLat, endLng
   */
  static async getRoute(req, res) {
    try {
      const { startLat, startLng, endLat, endLng } = req.query;

      console.log(`[MapController] GET /route - Request started`);
      console.log(`[MapController] Params: start(${startLat},${startLng}) -> end(${endLat},${endLng})`);

      // Validate required parameters
      if (!startLat || !startLng || !endLat || !endLng) {
        return res.status(400).json({
          success: false,
          message: 'Missing required parameters: startLat, startLng, endLat, endLng',
        });
      }

      // Parse coordinates
      const startLatNum = parseFloat(startLat);
      const startLngNum = parseFloat(startLng);
      const endLatNum = parseFloat(endLat);
      const endLngNum = parseFloat(endLng);

      if (isNaN(startLatNum) || isNaN(startLngNum) || isNaN(endLatNum) || isNaN(endLngNum)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid coordinate values',
        });
      }

      // Call OpenRouteService
      const result = await ORSService.getRoute(startLatNum, startLngNum, endLatNum, endLngNum);

      if (result.success) {
        console.log(`[MapController] Route generated successfully - ${result.data.route.length} points`);
        console.log(`[MapController] Distance: ${result.data.distance}m, Duration: ${result.data.duration}s`);

        return res.status(200).json({
          success: true,
          data: result.data,
        });
      } else {
        console.error('[MapController] Route generation failed:', result.message);
        return res.status(500).json({
          success: false,
          message: result.message || 'Failed to generate route',
        });
      }
    } catch (error) {
      console.error('[MapController] Error in getRoute:', error.message);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch route',
        error: error.message,
      });
    }
  }

  /**
   * Get distance and ETA between two coordinates
   * GET /api/maps/distance
   * Query params: startLat, startLng, endLat, endLng
   */
  static async getDistance(req, res) {
    try {
      const { startLat, startLng, endLat, endLng } = req.query;

      console.log(`[MapController] GET /distance - Request started`);
      console.log(`[MapController] Params: start(${startLat},${startLng}) -> end(${endLat},${endLng})`);

      // Validate required parameters
      if (!startLat || !startLng || !endLat || !endLng) {
        return res.status(400).json({
          success: false,
          message: 'Missing required parameters: startLat, startLng, endLat, endLng',
        });
      }

      // Parse coordinates
      const startLatNum = parseFloat(startLat);
      const startLngNum = parseFloat(startLng);
      const endLatNum = parseFloat(endLat);
      const endLngNum = parseFloat(endLng);

      if (isNaN(startLatNum) || isNaN(startLngNum) || isNaN(endLatNum) || isNaN(endLngNum)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid coordinate values',
        });
      }

      // Call OpenRouteService
      const result = await ORSService.getDistanceAndETA(startLatNum, startLngNum, endLatNum, endLngNum);

      if (result.success) {
        console.log(`[MapController] Distance/ETA received - ${result.data.distance}m, ${result.data.duration}s`);

        return res.status(200).json({
          success: true,
          data: result.data,
        });
      } else {
        console.error('[MapController] Distance calculation failed:', result.message);
        return res.status(500).json({
          success: false,
          message: result.message || 'Failed to calculate distance',
        });
      }
    } catch (error) {
      console.error('[MapController] Error in getDistance:', error.message);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch distance and ETA',
        error: error.message,
      });
    }
  }

  /**
   * Get ETA between two coordinates
   * GET /api/maps/eta
   * Query params: startLat, startLng, endLat, endLng
   */
  static async getETA(req, res) {
    try {
      const { startLat, startLng, endLat, endLng } = req.query;

      console.log(`[MapController] GET /eta - Request started`);
      console.log(`[MapController] Params: start(${startLat},${startLng}) -> end(${endLat},${endLng})`);

      // Validate required parameters
      if (!startLat || !startLng || !endLat || !endLng) {
        return res.status(400).json({
          success: false,
          message: 'Missing required parameters: startLat, startLng, endLat, endLng',
        });
      }

      // Parse coordinates
      const startLatNum = parseFloat(startLat);
      const startLngNum = parseFloat(startLng);
      const endLatNum = parseFloat(endLat);
      const endLngNum = parseFloat(endLng);

      if (isNaN(startLatNum) || isNaN(startLngNum) || isNaN(endLatNum) || isNaN(endLngNum)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid coordinate values',
        });
      }

      // Call OpenRouteService
      const result = await ORSService.getDistanceAndETA(startLatNum, startLngNum, endLatNum, endLngNum);

      if (result.success) {
        const etaSeconds = result.data.duration;
        const etaMinutes = Math.ceil(etaSeconds / 60);

        console.log(`[MapController] ETA calculated - ${etaSeconds}s (${etaMinutes} min)`);

        return res.status(200).json({
          success: true,
          data: {
            etaSeconds: etaSeconds,
            etaMinutes: etaMinutes,
          },
        });
      } else {
        console.error('[MapController] ETA calculation failed:', result.message);
        return res.status(500).json({
          success: false,
          message: result.message || 'Failed to calculate ETA',
        });
      }
    } catch (error) {
      console.error('[MapController] Error in getETA:', error.message);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch ETA',
        error: error.message,
      });
    }
  }

  /**
   * Reverse geocode coordinates to address
   * GET /api/maps/reverse-geocode
   * Query params: lat, lng
   */
  static async reverseGeocode(req, res) {
    try {
      const { lat, lng } = req.query;

      console.log(`[MapController] GET /reverse-geocode - Request started for (${lat}, ${lng})`);

      // Validate required parameters
      if (!lat || !lng) {
        return res.status(400).json({
          success: false,
          message: 'Missing required parameters: lat, lng',
        });
      }

      // Parse coordinates
      const latNum = parseFloat(lat);
      const lngNum = parseFloat(lng);

      if (isNaN(latNum) || isNaN(lngNum)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid coordinate values',
        });
      }

      // Call OpenRouteService
      const result = await ORSService.reverseGeocode(latNum, lngNum);

      if (result.success) {
        console.log(`[MapController] Reverse geocoding successful: ${result.data.address}`);

        return res.status(200).json({
          success: true,
          data: result.data,
        });
      } else {
        console.log(`[MapController] Address not found for coordinates`);
        return res.status(404).json({
          success: false,
          message: result.message || 'Address not found',
        });
      }
    } catch (error) {
      console.error('[MapController] Error in reverseGeocode:', error.message);
      return res.status(500).json({
        success: false,
        message: 'Failed to reverse geocode',
        error: error.message,
      });
    }
  }
}

module.exports = MapController;