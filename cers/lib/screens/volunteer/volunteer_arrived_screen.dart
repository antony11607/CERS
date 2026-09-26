import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_map/flutter_map.dart';
import 'volunteer_service.dart';
import 'volunteer_dashboard_screen.dart';
import 'emergency_resolved_screen.dart';
import '../../location_service.dart';

class VolunteerArrivedScreen extends StatefulWidget {
  final String emergencyId;

  const VolunteerArrivedScreen({
    super.key,
    required this.emergencyId,
  });

  @override
  State<VolunteerArrivedScreen> createState() => _VolunteerArrivedScreenState();
}

class _VolunteerArrivedScreenState extends State<VolunteerArrivedScreen> {
  final VolunteerService _volunteerService = VolunteerService();
  final LocationService _locationService = LocationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot>? _emergencyStreamSubscription;
  Map<String, dynamic>? _emergencyData;
  bool _isLoading = true;
  bool _isResolving = false;
  bool _hasNavigatedToResolved = false;

  // Map
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  latlong2.LatLng? _victimLocation;
  latlong2.LatLng? _volunteerLocation;

  @override
  void initState() {
    super.initState();
    debugPrint('[VolunteerArrivedScreen] ========================================');
    debugPrint('[VolunteerArrivedScreen] Volunteer Arrived Screen initialized');
    debugPrint('[VolunteerArrivedScreen] Emergency ID: ${widget.emergencyId}');
    debugPrint('[VolunteerArrivedScreen] ========================================');
    _initializeScreen();
  }

  @override
  void dispose() {
    _emergencyStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _getVolunteerLocation();
    _listenToEmergencyUpdates();
  }

  Future<void> _getVolunteerLocation() async {
    try {
      Position? position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _volunteerLocation = latlong2.LatLng(position.latitude, position.longitude);
        });
        debugPrint('[VolunteerArrivedScreen] Volunteer location obtained: (${position.latitude}, ${position.longitude})');
      }
    } catch (e) {
      debugPrint('[VolunteerArrivedScreen] Error getting volunteer location: $e');
    }
  }

  void _listenToEmergencyUpdates() {
    _emergencyStreamSubscription = _volunteerService.getEmergencyStream(widget.emergencyId)?.listen(
      (DocumentSnapshot snapshot) {
        if (!snapshot.exists || !mounted) return;

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        String previousStatus = _emergencyData?['status'] ?? 'unknown';
        String newStatus = data['status'] ?? 'unknown';

        debugPrint('[VolunteerArrivedScreen] Firestore listener received status = "$newStatus"');
        debugPrint('[VolunteerArrivedScreen] Previous status: $previousStatus → New status: $newStatus');

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
          _updateMapMarkers();
        }

        // Navigate to resolved screen if status changes to resolved
        if (newStatus == 'resolved' && !_hasNavigatedToResolved) {
          debugPrint('[VolunteerArrivedScreen] Navigation to Emergency Resolved screen');
          _hasNavigatedToResolved = true;
          _navigateToResolved();
        } else if (newStatus == 'cancelled') {
          debugPrint('[VolunteerArrivedScreen] Emergency cancelled, navigating to dashboard');
          _navigateToDashboard();
        }
      },
      onError: (error) {
        debugPrint('[VolunteerArrivedScreen] Error listening to emergency: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
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
              Text('User Location', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  Future<void> _completeEmergency() async {
    if (_isResolving || _hasNavigatedToResolved) return;

    setState(() {
      _isResolving = true;
    });

    try {
      debugPrint('[VolunteerArrivedScreen] Volunteer completing emergency: ${widget.emergencyId}');

      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('[VolunteerArrivedScreen] Firestore update: setting status to resolved');
      debugPrint('[VolunteerArrivedScreen] Emergency ID: ${widget.emergencyId}');

      // Update emergency status to resolved
      await _firestore.collection('emergencies').doc(widget.emergencyId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[VolunteerArrivedScreen] Firestore update successful - status changed to resolved');

      // Update volunteer availability
      await _firestore.collection('volunteers').doc(currentUser.uid).update({
        'isAvailable': true,
        'isOnline': true,
      });

      debugPrint('[VolunteerArrivedScreen] Volunteer availability reset to true');

      if (mounted) {
        debugPrint('[VolunteerArrivedScreen] Navigation to Emergency Resolved screen');
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
      debugPrint('[VolunteerArrivedScreen] Error completing emergency: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete emergency. Please try again.'),
            backgroundColor: Color(0xFFC62828),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  void _navigateToResolved() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyResolvedScreen(
          emergencyId: widget.emergencyId,
        ),
      ),
    );
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const VolunteerDashboardScreen(),
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

    return '$hour:$minute $period';
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
          onPressed: _navigateToDashboard,
        ),
        title: const Text(
          'Arrived at Location',
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
                      // Success Banner
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
                                    'You have arrived!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1B5E20),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'You\'ve reached the user\'s location. Please assist them.',
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

                      // Map
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
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: _victimLocation ?? _volunteerLocation ?? const latlong2.LatLng(0, 0),
                                initialZoom: 15.0,
                              ),
                              mapController: _mapController,
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.cers.app',
                                ),
                                MarkerLayer(markers: _markers),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Emergency Details
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
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
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.notifications_active_outlined, size: 20, color: Colors.grey[600]),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Alert ID', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            const SizedBox(height: 2),
                                            Text(
                                              '#${widget.emergencyId.substring(0, 8).toUpperCase()}',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Arrived At', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatTimestamp(_emergencyData?['arrivedAt']),
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Complete Emergency Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isResolving ? null : _completeEmergency,
                            icon: _isResolving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline, size: 20),
                            label: Text(_isResolving ? 'Completing...' : 'Complete Emergency'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE31E24),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
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
}