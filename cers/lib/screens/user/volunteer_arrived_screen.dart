import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_map/flutter_map.dart';
import 'home_screen.dart';
import 'emergency_completed_screen.dart';
import '../../location_service.dart';
import '../../emergency_service.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();
  final EmergencyService _emergencyService = EmergencyService();

  StreamSubscription<DocumentSnapshot>? _emergencySubscription;
  StreamSubscription<DocumentSnapshot>? _volunteerSubscription;
  
  Map<String, dynamic>? _emergencyData;
  Map<String, dynamic>? _volunteerData;
  
  latlong2.LatLng? _userLocation;
  latlong2.LatLng? _volunteerLocation;
  
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _hasNavigated = false;

  // Map
  final MapController _mapController = MapController();
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    debugPrint('[VolunteerArrivedScreen] ========================================');
    debugPrint('[VolunteerArrivedScreen] VolunteerArrivedScreen initialized');
    debugPrint('[VolunteerArrivedScreen] Emergency ID: ${widget.emergencyId}');
    debugPrint('[VolunteerArrivedScreen] ========================================');
    _initializeScreen();
  }

  @override
  void dispose() {
    debugPrint('[VolunteerArrivedScreen] Disposing - cancelling subscriptions');
    _emergencySubscription?.cancel();
    _volunteerSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _getUserLocation();
    await _listenToEmergencyUpdates();
    if (_emergencyData?['assignedVolunteerId'] != null) {
      await _listenToVolunteerUpdates(_emergencyData!['assignedVolunteerId']);
    }
  }

  Future<void> _getUserLocation() async {
    try {
      Position? position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _userLocation = latlong2.LatLng(position.latitude, position.longitude);
        });
        _updateMapMarkers();
      }
    } catch (e) {
      debugPrint('[VolunteerArrivedScreen] Error getting user location: $e');
    }
  }

  Future<void> _listenToEmergencyUpdates() async {
    try {
      _emergencySubscription = _firestore
          .collection('emergencies')
          .doc(widget.emergencyId)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
            if (!snapshot.exists || !mounted) return;

            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
            String newStatus = data['status'] ?? 'unknown';
            debugPrint('[VolunteerArrivedScreen] Firestore listener received status = "$newStatus"');
            debugPrint('[VolunteerArrivedScreen] Firestore read: emergency update received');
            
            setState(() {
              _emergencyData = data;
              _isLoading = false;
            });

            // Update volunteer location if available
            if (data['volunteerLatitude'] != null && data['volunteerLongitude'] != null) {
              _volunteerLocation = latlong2.LatLng(
                data['volunteerLatitude'],
                data['volunteerLongitude'],
              );
              _updateMapMarkers();
            }

            // Prevent duplicate navigations
            if (_hasNavigated) {
              debugPrint('[VolunteerArrivedScreen] Already navigated, skipping navigation decision');
              return;
            }

            debugPrint('[VolunteerArrivedScreen] Navigation decision: status="$newStatus"');
            
            // Navigate to completed screen if emergency is resolved
            if (newStatus == 'resolved') {
              _navigateToCompleted();
            } else if (newStatus == 'cancelled') {
              _navigateToHome();
            } else {
              debugPrint('[VolunteerArrivedScreen] No navigation needed for status: $newStatus');
            }
          }, onError: (error) {
            debugPrint('[VolunteerArrivedScreen] Error listening to emergency: $error');
            if (mounted) {
              setState(() => _isLoading = false);
            }
          });
    } catch (e) {
      debugPrint('[VolunteerArrivedScreen] Error setting up emergency listener: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _listenToVolunteerUpdates(String volunteerId) async {
    try {
      _volunteerSubscription = _firestore
          .collection('volunteers')
          .doc(volunteerId)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
            if (!snapshot.exists || !mounted) return;

            setState(() {
              _volunteerData = snapshot.data() as Map<String, dynamic>;
            });
            debugPrint('[VolunteerArrivedScreen] Volunteer update received');
          }, onError: (error) {
            debugPrint('[VolunteerArrivedScreen] Error listening to volunteer: $error');
          });
    } catch (e) {
      debugPrint('[VolunteerArrivedScreen] Error setting up volunteer listener: $e');
    }
  }

  void _updateMapMarkers() {
    List<Marker> markers = [];

    // User marker (blue)
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
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

    // Volunteer marker (red)
    if (_volunteerLocation != null) {
      markers.add(
        Marker(
          point: _volunteerLocation!,
          width: 80,
          height: 100,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
              Text('Volunteer Location', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _callVolunteer() async {
    String? phoneNumber = _volunteerData?['phone'];
    if (phoneNumber == null || phoneNumber.isEmpty) return;

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('[VolunteerArrivedScreen] Error launching phone: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to make phone call'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
    }
  }

  Future<void> _markAsResolved() async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      debugPrint('[VolunteerArrivedScreen] Marking emergency as resolved: ${widget.emergencyId}');

      // Update emergency status to resolved
      await _emergencyService.updateEmergencyStatus(
        emergencyId: widget.emergencyId,
        status: 'resolved',
      );

      // Set volunteer back to available
      String? volunteerId = _emergencyData?['assignedVolunteerId'];
      if (volunteerId != null) {
        await _firestore.collection('volunteers').doc(volunteerId).update({
          'isAvailable': true,
        });
        debugPrint('[VolunteerArrivedScreen] Volunteer set back to available');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency resolved successfully'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ),
        );

        _navigateToCompleted();
      }
    } catch (e) {
      debugPrint('[VolunteerArrivedScreen] Error resolving emergency: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resolve emergency. Please try again.'),
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

  void _navigateToCompleted() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    debugPrint('[VolunteerArrivedScreen] ✅ Navigation: Status resolved → EmergencyCompletedScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyCompletedScreen(
          emergencyId: widget.emergencyId,
        ),
      ),
    );
  }

  void _navigateToHome() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    debugPrint('[VolunteerArrivedScreen] ✅ Navigation: Status cancelled → HomeScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '';
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
          onPressed: () => _navigateToHome(),
        ),
        title: const Text(
          'Volunteer Arrived',
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
                                    'Volunteer Arrived',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1B5E20),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Your volunteer has reached your location.',
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

                      // Volunteer Info Card
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
                              // Avatar with online indicator
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundImage: _volunteerData?['photoUrl'] != null
                                        ? NetworkImage(_volunteerData!['photoUrl'])
                                        : null,
                                    child: _volunteerData?['photoUrl'] == null
                                        ? Icon(Icons.person, size: 32, color: Colors.grey[600])
                                        : null,
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
                              // Volunteer info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _volunteerData?['name'] ?? 'Volunteer',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, size: 16, color: Color(0xFFFFC107)),
                                            const SizedBox(width: 4),
                                            Text(
                                              _volunteerData?['rating']?.toString() ?? '4.9',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F5E9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _volunteerData?['role'] ?? 'Volunteer',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF2E7D32),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${_volunteerData?['distance'] ?? '0'} m away',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
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
                      ),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _callVolunteer,
                                icon: const Icon(Icons.message_outlined, size: 18),
                                label: const Text('Message'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0066CC),
                                  side: const BorderSide(color: Color(0xFF0066CC)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _callVolunteer,
                                icon: const Icon(Icons.phone_outlined, size: 18),
                                label: const Text('Call'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0066CC),
                                  side: const BorderSide(color: Color(0xFF0066CC)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Map Card with flutter_map
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
                                initialCenter: _userLocation ?? const latlong2.LatLng(0, 0),
                                initialZoom: 14.0,
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

                      // Progress Timeline
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  _buildTimelineItem(
                                    title: 'SOS Sent',
                                    time: _formatTimestamp(_emergencyData?['createdAt']),
                                    isCompleted: true,
                                  ),
                                  _buildTimelineItem(
                                    title: 'Volunteer Selected',
                                    time: _formatTimestamp(_emergencyData?['acceptedAt']),
                                    isCompleted: true,
                                  ),
                                  _buildTimelineItem(
                                    title: 'Arrived',
                                    time: _formatTimestamp(_emergencyData?['arrivedAt']),
                                    isCompleted: true,
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Done Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isUpdatingStatus ? null : _markAsResolved,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF0F0),
                              foregroundColor: const Color(0xFFE31E24),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isUpdatingStatus
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
                                    ),
                                  )
                                : const Text(
                                    'Done',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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

  Widget _buildTimelineItem({
    required String title,
    required String time,
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? const Color(0xFF2E7D32) : Colors.white,
                border: Border.all(
                  color: isCompleted ? const Color(0xFF2E7D32) : const Color(0xFFE0E2EC),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: const Color(0xFFE0E2EC),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? const Color(0xFF1A1C1E) : const Color(0xFF9E9E9E),
                    ),
                  ),
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}