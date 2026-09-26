import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong2;

class BackendApiService {
  // Backend API base URL - configure this in a single location
  // For development: http://localhost:3000
  // For production: https://your-backend-domain.com
  static const String _baseUrl = 'http://localhost:3000';

  /// Health check
  static Future<bool> healthCheck() async {
    try {
      final url = Uri.parse('$_baseUrl/api/health/check');
      debugPrint('[BackendAPI] GET /api/health/check - Request started');

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      debugPrint('[BackendAPI] Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendAPI] Health check failed: $e');
      return false;
    }
  }

  /// Get route between two coordinates via backend API
  /// Returns list of LatLng points representing the route
  static Future<List<latlong2.LatLng>> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/api/maps/route?startLat=$startLat&startLng=$startLng&endLat=$endLat&endLng=$endLng',
    );
    
    debugPrint('[BackendAPI] GET /api/maps/route - Request started');
    debugPrint('[BackendAPI] Params: start($startLat,$startLng) -> end($endLat,$endLng)');

    try {
      final startTime = DateTime.now();
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      debugPrint('[BackendAPI] GET /api/maps/route - Response received (${response.statusCode}) in ${elapsed}ms');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> routeData = data['data']['route'];
          debugPrint('[BackendAPI] Route generation successful - ${routeData.length} points received');
          debugPrint('[BackendAPI] Distance: ${data['data']['distance']}m, Duration: ${data['data']['duration']}s');

          // Convert [lat, lng] format from backend to LatLng
          final points = routeData.map<latlong2.LatLng>((coord) {
            return latlong2.LatLng(
              (coord[0] as num).toDouble(),
              (coord[1] as num).toDouble(),
            );
          }).toList();

          debugPrint('[BackendAPI] Route points converted successfully');
          return points;
        } else {
          debugPrint('[BackendAPI] Route API returned success=false: ${data['message']}');
          return _fallbackRoute(startLat, startLng, endLat, endLng);
        }
      } else {
        debugPrint('[BackendAPI] Route API error: ${response.statusCode} - ${response.body}');
        return _fallbackRoute(startLat, startLng, endLat, endLng);
      }
    } catch (e) {
      debugPrint('[BackendAPI] Route API request failed: $e');
      return _fallbackRoute(startLat, startLng, endLat, endLng);
    }
  }

  /// Fallback to straight line route
  static List<latlong2.LatLng> _fallbackRoute(
    double startLat, double startLng, double endLat, double endLng) {
    debugPrint('[BackendAPI] Using fallback straight-line route');
    return [
      latlong2.LatLng(startLat, startLng),
      latlong2.LatLng(endLat, endLng),
    ];
  }

  /// Get distance and ETA between two coordinates via backend API
  /// Returns Map with 'distance' (in meters) and 'duration' (in seconds)
  static Future<Map<String, double>?> getDistanceAndETA({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/api/maps/distance?startLat=$startLat&startLng=$startLng&endLat=$endLat&endLng=$endLng',
    );
    
    debugPrint('[BackendAPI] GET /api/maps/distance - Request started');
    debugPrint('[BackendAPI] Params: start($startLat,$startLng) -> end($endLat,$endLng)');

    try {
      final startTime = DateTime.now();
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      debugPrint('[BackendAPI] GET /api/maps/distance - Response received (${response.statusCode}) in ${elapsed}ms');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final distance = (data['data']['distance'] as num).toDouble();
          final duration = (data['data']['duration'] as num).toDouble();
          debugPrint('[BackendAPI] Distance and ETA received - Distance: ${distance}m, Duration: ${duration}s');
          return {
            'distance': distance, // in meters
            'duration': duration, // in seconds
          };
        } else {
          debugPrint('[BackendAPI] Distance API returned success=false: ${data['message']}');
          return _fallbackDistance(startLat, startLng, endLat, endLng);
        }
      } else {
        debugPrint('[BackendAPI] Distance API error: ${response.statusCode} - ${response.body}');
        return _fallbackDistance(startLat, startLng, endLat, endLng);
      }
    } catch (e) {
      debugPrint('[BackendAPI] Distance API request failed: $e');
      return _fallbackDistance(startLat, startLng, endLat, endLng);
    }
  }

  /// Fallback distance calculation using Haversine formula
  static Map<String, double>? _fallbackDistance(
    double startLat, double startLng, double endLat, double endLng) {
    debugPrint('[BackendAPI] Using fallback Haversine distance calculation');
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(startLat)) * _cos(_toRadians(endLat)) *
        _sin(dLng / 2) * _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    final distance = earthRadius * c;
    final duration = (distance / 8.33); // ~30 km/h average speed
    debugPrint('[BackendAPI] Fallback distance: ${distance}m, duration: ${duration}s');
    return {
      'distance': distance,
      'duration': duration,
    };
  }

  // Simplified math helpers for Haversine calculation
  static double _toRadians(double degree) => degree * 3.141592653589793 / 180;
  static double _sin(double val) => val - (val * val * val) / 6;
  static double _cos(double val) => 1 - (val * val) / 2;
  static double _sqrt(double val) => val < 0 ? 0 : val > 1 ? 1 : val;
  static double _atan2(double y, double x) {
    if (x > 0) return y / x;
    if (x < 0) return y > 0 ? 3.141592653589793 : -3.141592653589793;
    return y > 0 ? 3.141592653589793 / 2 : -3.141592653589793 / 2;
  }

  /// Reverse geocode coordinates to address via backend API
  static Future<String?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    final url = Uri.parse('$_baseUrl/api/maps/reverse-geocode?lat=$lat&lng=$lng');
    debugPrint('[BackendAPI] GET /api/maps/reverse-geocode - Request started for ($lat, $lng)');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      debugPrint('[BackendAPI] GET /api/maps/reverse-geocode - Response received (${response.statusCode})');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final address = data['data']['address'] as String;
          debugPrint('[BackendAPI] Reverse geocoding successful: $address');
          return address;
        } else {
          debugPrint('[BackendAPI] Reverse geocode returned success=false: ${data['message']}');
          return null;
        }
      } else {
        debugPrint('[BackendAPI] Reverse geocode error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[BackendAPI] Reverse geocode request failed: $e');
      return null;
    }
  }

  /// Calculate ETA in minutes from duration in seconds
  static int calculateETAInMinutes(double durationInSeconds) {
    final minutes = (durationInSeconds / 60).round();
    debugPrint('[BackendAPI] calculateETAInMinutes: ${durationInSeconds}s -> ${minutes}min');
    return minutes;
  }

  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Format duration for display
  static String formatDuration(int minutes) {
    if (minutes < 1) {
      return '< 1 min';
    } else if (minutes < 60) {
      return '$minutes mins';
    } else {
      int hours = minutes ~/ 60;
      int mins = minutes % 60;
      return '$hours hr ${mins > 0 ? '$mins mins' : ''}';
    }
  }
}