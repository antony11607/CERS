import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'backend_api_service.dart';

class MapService {
  /// Get route between two points via backend API (OpenRouteService backend)
  /// Returns list of LatLng points representing the route
  static Future<List<LatLng>> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    debugPrint('[MapService] getRoute called: origin(${origin.latitude},${origin.longitude}) -> dest(${destination.latitude},${destination.longitude})');
    
    try {
      final points = await BackendApiService.getRoute(
        startLat: origin.latitude,
        startLng: origin.longitude,
        endLat: destination.latitude,
        endLng: destination.longitude,
      );
      
      debugPrint('[MapService] Route received from backend API with ${points.length} points');
      return points;
    } catch (e) {
      debugPrint('[MapService] Error getting route: $e');
      return [origin, destination]; // Fallback to straight line
    }
  }

  /// Get distance and duration between two points via backend API
  /// Returns Map with 'distance' (in meters) and 'duration' (in seconds)
  static Future<Map<String, double>?> getDistanceAndDuration({
    required LatLng origin,
    required LatLng destination,
  }) async {
    debugPrint('[MapService] getDistanceAndDuration called');
    
    try {
      final result = await BackendApiService.getDistanceAndETA(
        startLat: origin.latitude,
        startLng: origin.longitude,
        endLat: destination.latitude,
        endLng: destination.longitude,
      );
      
      if (result != null) {
        debugPrint('[MapService] Distance: ${result['distance']}m, Duration: ${result['duration']}s');
      } else {
        debugPrint('[MapService] getDistanceAndDuration returned null from backend API');
      }
      
      return result;
    } catch (e) {
      debugPrint('[MapService] Error getting distance: $e');
      return null;
    }
  }

  /// Calculate ETA in minutes from duration in seconds
  static int calculateETAInMinutes(double durationInSeconds) {
    return BackendApiService.calculateETAInMinutes(durationInSeconds);
  }

  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    return BackendApiService.formatDistance(distanceInMeters);
  }

  /// Format duration for display
  static String formatDuration(int minutes) {
    return BackendApiService.formatDuration(minutes);
  }
}
