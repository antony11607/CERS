import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as perm_handler;

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  bool _isFetchingLocation = false;

  Position? get currentPosition => _currentPosition;
  bool get isFetchingLocation => _isFetchingLocation;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      bool isEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[LocationService] GPS enabled: $isEnabled');
      return isEnabled;
    } catch (e) {
      debugPrint('[LocationService] Error checking location service: $e');
      return false;
    }
  }

  /// Check location permission status
  Future<PermissionStatus> checkLocationPermission() async {
    try {
      PermissionStatus status = await Permission.location.status;
      debugPrint('[LocationService] Permission status: $status');
      return status;
    } catch (e) {
      debugPrint('[LocationService] Error checking permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request location permission
  Future<PermissionStatus> requestLocationPermission() async {
    try {
      debugPrint('[LocationService] Requesting location permission...');
      PermissionStatus status = await Permission.location.request();
      debugPrint('[LocationService] Permission result: $status');
      return status;
    } catch (e) {
      debugPrint('[LocationService] Error requesting permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check if permission is permanently denied
  bool isPermanentlyDenied(PermissionStatus status) {
    return status == PermissionStatus.permanentlyDenied ||
        status == PermissionStatus.restricted;
  }

  /// Get current location with high accuracy
  Future<Position?> getCurrentLocation() async {
    if (_isFetchingLocation) {
      debugPrint('[LocationService] Already fetching location...');
      return _currentPosition;
    }

    _isFetchingLocation = true;
    debugPrint('[LocationService] Starting location fetch...');

    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services disabled');
        _isFetchingLocation = false;
        return null;
      }

      // Check permission
      PermissionStatus permissionStatus = await checkLocationPermission();
      if (permissionStatus != PermissionStatus.granted) {
        debugPrint('[LocationService] Permission not granted: $permissionStatus');
        _isFetchingLocation = false;
        return null;
      }

      // Get current position with high accuracy
      debugPrint('[LocationService] Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      debugPrint('[LocationService] Location received - Lat: ${position.latitude}, Lng: ${position.longitude}');
      debugPrint('[LocationService] Accuracy: ${position.accuracy}m');
      
      _isFetchingLocation = false;
      return position;
    } on TimeoutException {
      debugPrint('[LocationService] Location fetch timeout');
      _isFetchingLocation = false;
      return null;
    } on LocationServiceDisabledException {
      debugPrint('[LocationService] Location service disabled exception');
      _isFetchingLocation = false;
      return null;
    } on PermissionDeniedException {
      debugPrint('[LocationService] Permission denied exception');
      _isFetchingLocation = false;
      return null;
    } catch (e) {
      debugPrint('[LocationService] Error getting location: $e');
      _isFetchingLocation = false;
      return null;
    }
  }

  /// Refresh current location
  Future<Position?> refreshLocation() async {
    debugPrint('[LocationService] Refreshing location...');
    _currentPosition = null;
    return await getCurrentLocation();
  }

  /// Start continuous location tracking with distance filter
  Stream<Position>? startLocationTracking({double distanceFilter = 20.0}) {
    try {
      debugPrint('[LocationService] Starting location tracking with distance filter: ${distanceFilter}m');
      
      return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter.toInt(),
        ),
      );
    } catch (e) {
      debugPrint('[LocationService] Error starting location tracking: $e');
      return null;
    }
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    try {
      await perm_handler.openAppSettings();
    } catch (e) {
      debugPrint('[LocationService] Error opening settings: $e');
    }
  }

  /// Get formatted location string
  String getFormattedLocation(Position? position) {
    if (position == null) {
      return 'Unable to retrieve your current location.';
    }
    
    String lat = position.latitude >= 0 ? '${position.latitude}° N' : '${position.latitude.abs()}° S';
    String lng = position.longitude >= 0 ? '${position.longitude}° E' : '${position.longitude.abs()}° W';
    
    return '$lat, $lng';
  }

  /// Get detailed location string
  String getDetailedLocation(Position? position) {
    if (position == null) {
      return 'Unable to retrieve your current location.';
    }

    return 'Latitude: ${position.latitude.toStringAsFixed(6)}\nLongitude: ${position.longitude.toStringAsFixed(6)}';
  }
}