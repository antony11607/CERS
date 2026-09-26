import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_map/flutter_map.dart';
import '../../location_service.dart';
import 'volunteer_service.dart';
import 'volunteer_dashboard_screen.dart';
import 'volunteer_arrived_screen.dart';
import 'emergency_resolved_screen.dart';
import '../../services/map_service.dart';

class EmergencyResponseScreen extends StatefulWidget {
  final String emergencyId;

  const EmergencyResponseScreen({
    super.key,
    required this.emergencyId,
  });

  @override
  State<EmergencyResponseScreen> createState() => _EmergencyResponseScreenState();
}

class _EmergencyResponseScreenState extends State<EmergencyResponseScreen> {
  final LocationService _locationService = LocationService();
  final VolunteerService _volunteerService = VolunteerService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot>? _emergencyStreamSubscription;
  StreamSubscription<DocumentSnapshot>? _volunteerSubscription;
  Map<String, dynamic>? _emergencyData;
  Map<String, dynamic>? _volunteerData;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _hasArrived = false;
  bool _hasNavigatedToArrived = false;
  Timer? _locationUpdateTimer;

  // Arrival threshold in meters
  static const double _arrivalThreshold = 10.0;

  // Map controllers
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<latlong2.LatLng> _routePoints = [];

  // Location data
  latlong2.LatLng? _victimLocation;
  latlong2.LatLng? _volunteerLocation;
  double _distance = 0.0;
  int _etaMinutes = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('[EmergencyResponse] ========================================');
    debugPrint('[EmergencyResponse] Emergency Response Screen initialized');
    debugPrint('[EmergencyResponse] Emergency ID: ${widget.emergencyId}');
    debugPrint('[EmergencyResponse] Arrival threshold: $_arrivalThreshold meters');
    debugPrint('[EmergencyResponse] ========================================');
    _initializeScreen();
    _startLocationUpdateTimer();
  }

  @override
  void dispose() {
    _emergencyStreamSubscription?.cancel();
    _volunteerSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _getVolunteerLocation();
    _listenToEmergencyUpdates();
    _listenToVolunteerUpdates();
  }

  Future<void> _getVolunteerLocation() async {
    try {
      Position? position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _volunteerLocation = latlong2.LatLng(position.latitude, position.longitude);
        });
        debugPrint('[EmergencyResponse] Volunteer location obtained: (${position.latitude}, ${position.longitude})');
      }
    } catch (e) {
      debugPrint('[EmergencyResponse] Error getting volunteer location: $e');
    }
  }

  void _listenToEmergencyUpdates() {
    _emergencyStreamSubscription = _volunteerService.getEmergencyStream(widget.emergencyId)?.listen(
      (DocumentSnapshot snapshot) {
        if (!snapshot.exists || !mounted) return;

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        String previousStatus = _emergencyData?['status'] ?? 'unknown';
        String newStatus = data['status'] ?? 'unknown';

        if (previousStatus != newStatus) {
          debugPrint('[EmergencyResponse] Previous status: $previousStatus → New status: $newStatus');
        }
        debugPrint('[EmergencyResponse] Firestore read: emergency update received, status = "$newStatus"');
        
        setState(() {
          _emergencyData = data;
          _isLoading = false;
        });

        // Update victim location from emergency data
        if (data['victimLatitude'] != null && data['victimLongitude'] != null) {
          _victimLocation = latlong2.LatLng(
            data['victimLatitude'],
            data['victimLongitude'],
          );
          debugPrint('[EmergencyResponse] Victim location: (${data['victimLatitude']}, ${data['victimLongitude']})');
          _calculateDistanceAndETA();
          _updateMapMarkers();
          _updateRoute();
        }

        // Show arrived popup dialog if status becomes "arrived"
        if (newStatus == 'arrived' && !_hasNavigatedToArrived) {
          debugPrint('[EmergencyResponse] Firestore listener received status = "arrived"');
          _hasNavigatedToArrived = true;
          _showArrivedPopup();
        } else if (newStatus == 'cancelled' || newStatus == 'resolved') {
          _navigateToDashboard();
        }
      },
      onError: (error) {
        debugPrint('[EmergencyResponse] Error listening to emergency: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _listenToVolunteerUpdates() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      _volunteerSubscription = _firestore
          .collection('volunteers')
          .doc(currentUser.uid)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
            if (!snapshot.exists || !mounted) return;

            setState(() {
              _volunteerData = snapshot.data() as Map<String, dynamic>;
            });
            debugPrint('[EmergencyResponse] Volunteer Firestore update received');
          });
    } catch (e) {
      debugPrint('[EmergencyResponse] Error listening to volunteer: $e');
    }
  }

  void _startLocationUpdateTimer() {
    // Update location every 30 seconds
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateVolunteerLocation();
    });
  }

  Future<void> _updateVolunteerLocation() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      Position? position = await _locationService.getCurrentLocation();
      if (position != null) {
        debugPrint('[EmergencyResponse] Updating volunteer location to Firestore');
        await _volunteerService.updateVolunteerLocation(
          volunteerId: currentUser.uid,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        setState(() {
          _volunteerLocation = latlong2.LatLng(position.latitude, position.longitude);
        });

        _updateMapMarkers();
        _updateRoute();
        debugPrint('[EmergencyResponse] Volunteer location updated to Firestore');

        // Check for automatic arrival based on distance
        _checkAutomaticArrival();
      }
    } catch (e) {
      debugPrint('[EmergencyResponse] Error updating location: $e');
    }
  }

  void _checkAutomaticArrival() {
    if (_hasArrived || _hasNavigatedToArrived) return;
    if (_victimLocation == null || _volunteerLocation == null) return;

    double distanceInMeters = Geolocator.distanceBetween(
      _volunteerLocation!.latitude,
      _volunteerLocation!.longitude,
      _victimLocation!.latitude,
      _victimLocation!.longitude,
    );

    debugPrint('[EmergencyResponse] Distance between volunteer and victim: ${distanceInMeters.toStringAsFixed(2)} meters');

    if (distanceInMeters <= _arrivalThreshold) {
      debugPrint('[EmergencyResponse] Automatic arrival detected! Distance ($distanceInMeters m) <= threshold ($_arrivalThreshold m)');
      _hasArrived = true;
      _markAsArrived();
    }
  }

  void _calculateDistanceAndETA() {
    if (_victimLocation == null || _volunteerLocation == null) return;

    double distanceInMeters = Geolocator.distanceBetween(
      _volunteerLocation!.latitude,
      _volunteerLocation!.longitude,
      _victimLocation!.latitude,
      _victimLocation!.longitude,
    );

    setState(() {
      _distance = distanceInMeters / 1000.0;
      _etaMinutes = (_distance / 30.0 * 60).round();
    });
    debugPrint('[EmergencyResponse] Distance: ${_distance}km, ETA: ${_etaMinutes}min');

    // Check for automatic arrival based on distance
    _checkAutomaticArrival();
  }

  void _updateMapMarkers() {
    List<Marker> markers = [];

    if (_volunteerLocation != null) {
      markers.add(
        Marker(
          point: _volunteerLocation!,
          width: 80,
          height: 100,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: Colors.blue, size: 40),
              Text('Your Location', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (_victimLocation != null) {
      markers.add(
        Marker(
          point: _victimLocation!,
          width: 80,
          height: 100,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
              Text('User in Need', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _updateRoute() async {
    if (_volunteerLocation == null || _victimLocation == null) return;

    debugPrint('[EmergencyResponse] Route generation started');
    
    try {
      final points = await MapService.getRoute(
        origin: _volunteerLocation!,
        destination: _victimLocation!,
      );

      if (points.isNotEmpty) {
        setState(() {
          _routePoints = points;
          _polylines = [
            Polyline(
              points: points,
              color: const Color(0xFF0066CC),
              strokeWidth: 5.0,
            ),
          ];
        });
        debugPrint('[EmergencyResponse] Route generation completed with ${points.length} points');
      } else {
        setState(() {
          _polylines = [
            Polyline(
              points: [_volunteerLocation!, _victimLocation!],
              color: const Color(0xFF0066CC),
              strokeWidth: 5.0,
            ),
          ];
        });
        debugPrint('[EmergencyResponse] Route generation completed (straight line fallback)');
      }
    } catch (e) {
      debugPrint('[EmergencyResponse] Error drawing polyline: $e');
      setState(() {
        _polylines = [
          Polyline(
            points: [_volunteerLocation!, _victimLocation!],
            color: const Color(0xFF0066CC),
            strokeWidth: 5.0,
          ),
        ];
      });
    }
  }

  Future<void> _navigateToVictim() async {
    if (_victimLocation == null) return;

    final Uri launchUri = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/dir/',
      queryParameters: {
        'api': '1',
        'destination': '${_victimLocation!.latitude},${_victimLocation!.longitude}',
        'travelmode': 'driving',
      },
    );

    try {
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('[EmergencyResponse] Error launching maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open Google Maps'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
    }
  }

  Future<void> _markAsArrived() async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      debugPrint('[EmergencyResponse] Marking emergency as arrived: ${widget.emergencyId}');
      bool success = await _volunteerService.updateEmergencyStatus(
        emergencyId: widget.emergencyId,
        status: 'arrived',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as arrived'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[EmergencyResponse] Error marking as arrived: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status. Please try again.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _resolveEmergency() async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      debugPrint('[EmergencyResolved] "I\'ve Reached the Location" button pressed');
      debugPrint('[EmergencyResolved] Emergency ID: ${widget.emergencyId}');
      
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('[EmergencyResolved] Firestore update request started');

      // Update emergency status to resolved
      debugPrint('[EmergencyResolved] Emergency status changed to resolved');
      await _firestore.collection('emergencies').doc(widget.emergencyId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[EmergencyResolved] resolvedAt timestamp set');
      
      // Update volunteer availability to true
      debugPrint('[EmergencyResolved] Volunteer availability changed to true');
      await _firestore.collection('volunteers').doc(currentUser.uid).update({
        'isAvailable': true,
        'isOnline': true,
      });

      debugPrint('[EmergencyResolved] Firestore update completed successfully');

      if (mounted) {
        // Navigate to Emergency Resolved screen
        debugPrint('[EmergencyResolved] Navigation to Emergency Resolved screen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmergencyResolvedScreen(
              emergencyId: widget.emergencyId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[EmergencyResolved] Error resolving emergency: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resolve emergency. Please try again.'),
            backgroundColor: Color(0xFFC62828),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _cancelRequest() async {
    if (_isUpdatingStatus) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cancel Request?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: const Text(
            'Are you sure you want to cancel this emergency response?',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No', style: TextStyle(fontSize: 15, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Yes, Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      debugPrint('[EmergencyResponse] Cancelling emergency: ${widget.emergencyId}');

      await _volunteerService.updateEmergencyStatus(
        emergencyId: widget.emergencyId,
        status: 'waiting',
      );

      await _volunteerService.setVolunteerOnlineStatus(currentUser.uid, true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency response cancelled'),
            backgroundColor: Color(0xFFC62828),
            duration: Duration(seconds: 2),
          ),
        );

        _navigateToDashboard();
      }
    } catch (e) {
      debugPrint('[EmergencyResponse] Error cancelling emergency: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel. Please try again.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  void _navigateToArrived() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VolunteerArrivedScreen(
          emergencyId: widget.emergencyId,
        ),
      ),
    );
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const VolunteerDashboardScreen(),
      ),
    );
  }

  String _getPriorityText(String? priority) {
    switch (priority) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return 'Normal';
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFC62828);
      case 'medium':
        return const Color(0xFFE65100);
      case 'low':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF757575);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => _showBackDialog(),
        ),
        title: const Text(
          'Active Emergency',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
              ),
            )
          : _emergencyData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Emergency not found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7D32),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You accepted the alert',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1B5E20),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Please reach the location as soon as possible.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: const Color(0xFF388E3C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.grey[200],
                                    child: Icon(Icons.person, size: 32, color: Colors.grey[600]),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF00E676),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'User in Need',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _emergencyData?['address'] ?? 'Location not available',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE3F2FD),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Call functionality coming soon'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.phone_in_talk,
                                    color: Color(0xFF0066CC),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                '${_distance.toStringAsFixed(1)} km',
                                'Distance',
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                '$_etaMinutes min',
                                'ETA',
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                _getPriorityText(_emergencyData?['priority']),
                                'Priority',
                                isPriority: true,
                                priorityColor: _getPriorityColor(_emergencyData?['priority']),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey[200],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  options: MapOptions(
                                    initialCenter: _volunteerLocation ?? const latlong2.LatLng(0, 0),
                                    initialZoom: 14.0,
                                  ),
                                  mapController: _mapController,
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.cers.app',
                                    ),
                                    MarkerLayer(markers: _markers),
                                    PolylineLayer(polylines: _polylines),
                                  ],
                                ),
                                if (_volunteerLocation != null)
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Your Location',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Navigate to Location',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Follow the best route to reach the user quickly.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _navigateToVictim,
                              icon: const Icon(Icons.navigation, size: 20),
                              label: const Text('Navigate'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE31E24),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Emergency Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.notifications_active_outlined, size: 20, color: Colors.grey[600]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Alert ID',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '#${widget.emergencyId.substring(0, 8).toUpperCase()}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Alert Time',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _emergencyData?['createdAt'] != null
                                              ? _formatTimestamp(_emergencyData!['createdAt'])
                                              : 'Just now',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isUpdatingStatus ? null : _markAsArrived,
                            icon: _isUpdatingStatus
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline, size: 20),
                            label: Text(_isUpdatingStatus ? 'Updating...' : 'I\'ve Reached the Location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF0F0),
                              foregroundColor: const Color(0xFFE31E24),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isUpdatingStatus ? null : _cancelRequest,
                            icon: const Icon(Icons.cancel_outlined, size: 20),
                            label: const Text('Cancel Request'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC62828),
                              side: const BorderSide(color: Color(0xFFC62828)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatItem(String value, String label, {bool isPriority = false, Color? priorityColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPriority && priorityColor != null ? priorityColor : const Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF74777F),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return 'Just now';
    }

    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String period = dateTime.hour >= 12 ? 'PM' : 'AM';
    String month = dateTime.month.toString().padLeft(2, '0');
    String day = dateTime.day.toString().padLeft(2, '0');
    String year = dateTime.year.toString();

    return '$hour:$minute $period, $month/$day/$year';
  }

  void _showArrivedPopup() {
    if (!mounted) return;
    debugPrint('[EmergencyResponse] Arrival popup shown');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'You\'ve Arrived!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'You have reached the victim\'s location.\nPlease provide assistance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF74777F),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      debugPrint('[EmergencyResponse] Arrival popup dismissed, navigating to Volunteer Arrived screen');
                      Navigator.pop(ctx);
                      _navigateToArrived();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE31E24),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      debugPrint('[EmergencyResponse] Arrival popup dismissed');
    });
  }

  void _showBackDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cancel Response?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: const Text(
            'Are you sure you want to leave? This will cancel your emergency response.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No', style: TextStyle(fontSize: 15, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _cancelRequest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Yes, Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }
}
