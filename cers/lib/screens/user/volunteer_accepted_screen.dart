import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_map/flutter_map.dart';
import 'home_screen.dart';
import 'volunteer_arrived_screen.dart';
import 'emergency_completed_screen.dart';
import '../../services/map_service.dart';

class VolunteerAcceptedScreen extends StatefulWidget {
  final String emergencyId;

  const VolunteerAcceptedScreen({
    super.key,
    required this.emergencyId,
  });

  @override
  State<VolunteerAcceptedScreen> createState() => _VolunteerAcceptedScreenState();
}

class _VolunteerAcceptedScreenState extends State<VolunteerAcceptedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot>? _emergencySubscription;
  StreamSubscription<DocumentSnapshot>? _volunteerSubscription;
  bool _isCancelling = false;

  // Emergency data
  Map<String, dynamic>? _emergencyData;
  String? _assignedVolunteerId;
  String _status = 'accepted';

  // Volunteer data
  Map<String, dynamic>? _volunteerData;
  String _volunteerName = 'Volunteer';
  String _volunteerPhone = 'N/A';
  String? _volunteerPhotoUrl;

  // Location data
  latlong2.LatLng? _victimLocation;
  latlong2.LatLng? _volunteerLocation;
  double _distance = 0.0; // in km
  int _etaMinutes = 0;

  // Map
  final MapController _mapController = MapController();
  List<latlong2.LatLng> _routePoints = [];
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  // UI state
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[VolunteerAcceptedScreen] ========================================');
    debugPrint('[VolunteerAcceptedScreen] VolunteerAcceptedScreen initialized');
    debugPrint('[VolunteerAcceptedScreen] Emergency ID: ${widget.emergencyId}');
    debugPrint('[VolunteerAcceptedScreen] ========================================');
    _initializeScreen();
  }

  @override
  void dispose() {
    debugPrint('[VolunteerAcceptedScreen] Disposing - cancelling subscriptions');
    _emergencySubscription?.cancel();
    _volunteerSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _getVictimLocation();
    await _listenToEmergencyUpdates();
  }

  Future<void> _getVictimLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _victimLocation = latlong2.LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('[VolunteerAcceptedScreen] Error getting victim location: $e');
    }
  }

  Future<void> _listenToEmergencyUpdates() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Listen to the specific emergency document
      _emergencySubscription = _firestore
          .collection('emergencies')
          .doc(widget.emergencyId)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
        if (!snapshot.exists || !mounted) return;

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        String previousStatus = _status;
        String newStatus = data['status'] ?? 'accepted';
        
        if (previousStatus != newStatus) {
          debugPrint('[VolunteerAcceptedScreen] Previous status: $previousStatus → New status: $newStatus');
        }
        debugPrint('[VolunteerAcceptedScreen] Firestore read: emergency update received, status = "$newStatus"');
        
        setState(() {
          _emergencyData = data;
          _status = newStatus;
          _assignedVolunteerId = data['assignedVolunteerId'];
        });

        debugPrint('[VolunteerAcceptedScreen] Emergency status: $_status');

        // Update volunteer info if assigned
        if (_assignedVolunteerId != null && _assignedVolunteerId!.isNotEmpty) {
          _volunteerName = data['assignedVolunteerName'] ?? 'Volunteer';
          _volunteerPhone = data['assignedVolunteerPhone'] ?? 'N/A';
          _listenToVolunteerUpdates(_assignedVolunteerId!);
        }

        // Update locations from emergency document
        if (data['victimLatitude'] != null && data['victimLongitude'] != null) {
          _victimLocation = latlong2.LatLng(
            data['victimLatitude'],
            data['victimLongitude'],
          );
        }

        if (data['volunteerLatitude'] != null && data['volunteerLongitude'] != null) {
          _volunteerLocation = latlong2.LatLng(
            data['volunteerLatitude'],
            data['volunteerLongitude'],
          );
          _calculateDistanceAndETA();
        }

        // Update UI
        _updateMapMarkers();
        _updateRoute();

        // Prevent duplicate navigations
        if (_hasNavigated) {
          debugPrint('[VolunteerAcceptedScreen] Already navigated, skipping navigation decision');
          return;
        }

        debugPrint('[VolunteerAcceptedScreen] Navigation decision: status="$newStatus", previous="$previousStatus"');
        
        // Navigate based on status
        if (_status == 'arrived') {
          _navigateToArrived();
        } else if (_status == 'resolved') {
          _navigateToCompleted();
        } else if (_status == 'cancelled') {
          _navigateToHome();
        } else {
          debugPrint('[VolunteerAcceptedScreen] No navigation needed for status: $_status');
        }
      }, onError: (error) {
        debugPrint('[VolunteerAcceptedScreen] Emergency stream error: $error');
        if (mounted) {
          setState(() => _hasError = true);
        }
      });
    } catch (e) {
      debugPrint('[VolunteerAcceptedScreen] Error setting up emergency listener: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  Future<void> _listenToVolunteerUpdates(String volunteerId) async {
    // Cancel existing subscription
    await _volunteerSubscription?.cancel();

    try {
      _volunteerSubscription = _firestore
          .collection('volunteers')
          .doc(volunteerId)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
        if (!snapshot.exists || !mounted) return;

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        debugPrint('[VolunteerAcceptedScreen] Volunteer update received');
        
        setState(() {
          _volunteerData = data;
          _volunteerName = data['name'] ?? _volunteerName;
          _volunteerPhone = data['phone'] ?? _volunteerPhone;
          _volunteerPhotoUrl = data['photoUrl'];
        });

        // Update volunteer location if available
        if (data['latitude'] != null && data['longitude'] != null) {
          _volunteerLocation = latlong2.LatLng(
            data['latitude'],
            data['longitude'],
          );
          debugPrint('[VolunteerAcceptedScreen] Volunteer location updated: (${data['latitude']}, ${data['longitude']})');
          _calculateDistanceAndETA();
          _updateMapMarkers();
          _updateRoute();
        }

        setState(() => _isLoading = false);
      }, onError: (error) {
        debugPrint('[VolunteerAcceptedScreen] Volunteer stream error: $error');
      });
    } catch (e) {
      debugPrint('[VolunteerAcceptedScreen] Error setting up volunteer listener: $e');
    }
  }

  void _calculateDistanceAndETA() {
    if (_victimLocation == null || _volunteerLocation == null) return;

    // Calculate distance in meters using Geolocator
    double distanceInMeters = Geolocator.distanceBetween(
      _victimLocation!.latitude,
      _victimLocation!.longitude,
      _volunteerLocation!.latitude,
      _volunteerLocation!.longitude,
    );

    setState(() {
      _distance = distanceInMeters / 1000.0; // Convert to km
      // Assume average speed of 30 km/h in city traffic
      _etaMinutes = (_distance / 30.0 * 60).round();
    });
    
    debugPrint('[VolunteerAcceptedScreen] Distance: ${_distance}km, ETA: ${_etaMinutes}min');
  }

  void _updateMapMarkers() {
    List<Marker> markers = [];

    // Victim marker (blue)
    if (_victimLocation != null) {
      markers.add(
        Marker(
          point: _victimLocation!,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
              Text(_volunteerName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
    if (_victimLocation == null || _volunteerLocation == null) return;

    debugPrint('[VolunteerAcceptedScreen] Route generation started');
    
    try {
      // Get route from Firebase Functions via MapService
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
        debugPrint('[VolunteerAcceptedScreen] Route generation completed with ${points.length} points');
      } else {
        // Fallback to straight line
        setState(() {
          _polylines = [
            Polyline(
              points: [_volunteerLocation!, _victimLocation!],
              color: const Color(0xFF0066CC),
              strokeWidth: 5.0,
            ),
          ];
        });
        debugPrint('[VolunteerAcceptedScreen] Route generation completed (straight line fallback)');
      }
    } catch (e) {
      debugPrint('[VolunteerAcceptedScreen] Error drawing polyline: $e');
      // Fallback to straight line
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

  void _navigateToArrived() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    debugPrint('[VolunteerAcceptedScreen] ✅ Navigation: Status arrived → VolunteerArrivedScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VolunteerArrivedScreen(
          emergencyId: widget.emergencyId,
        ),
      ),
    );
  }

  void _navigateToCompleted() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    debugPrint('[VolunteerAcceptedScreen] ✅ Navigation: Status resolved → EmergencyCompletedScreen');
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
    debugPrint('[VolunteerAcceptedScreen] ✅ Navigation: Status cancelled → HomeScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  Future<void> _cancelEmergency() async {
    if (widget.emergencyId.isEmpty || _isCancelling) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      debugPrint('[VolunteerAcceptedScreen] Cancelling emergency: ${widget.emergencyId}');

      // Cancel the stream subscriptions first
      await _emergencySubscription?.cancel();
      _emergencySubscription = null;
      await _volunteerSubscription?.cancel();
      _volunteerSubscription = null;

      // Update emergency to cancelled status
      await _firestore
          .collection('emergencies')
          .doc(widget.emergencyId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('[VolunteerAcceptedScreen] Emergency cancelled successfully via Firestore');

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency request cancelled successfully'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('[VolunteerAcceptedScreen] Error cancelling emergency: $e');

      // Restart listening on error
      _listenToEmergencyUpdates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel emergency. Please try again.'),
            backgroundColor: Color(0xFFC62828),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _callVolunteer() async {
    if (_volunteerPhone == 'N/A') return;

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: _volunteerPhone,
    );

    try {
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('[VolunteerAcceptedScreen] Error launching phone: $e');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFC),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading volunteer details...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFC),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Color(0xFFC62828),
                ),
                const SizedBox(height: 20),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                    });
                    _initializeScreen();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE31E24),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Standard CERS Header
            _buildHeader(context),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    children: [
                      // Top Green Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Volunteer Found!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1B5E20),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getStatusText(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF388E3C),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Volunteer Info Card
                      Container(
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
                            // Avatar with green indicator
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: _volunteerPhotoUrl != null
                                      ? Image.network(
                                          _volunteerPhotoUrl!,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 56,
                                              height: 56,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.person, color: Colors.grey),
                                            );
                                          },
                                        )
                                      : Container(
                                          width: 56,
                                          height: 56,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.person, color: Colors.grey),
                                        ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E676),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Name and description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _volunteerName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1C1E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _volunteerPhone,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF74777F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Phone icon button
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F5E9),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: _callVolunteer,
                                icon: const Icon(
                                  Icons.phone_in_talk,
                                  color: Color(0xFF2E7D32),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stats Row
                      Container(
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
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              '${_distance.toStringAsFixed(1)} km',
                              'Distance',
                            ),
                            _buildStatItem(
                              '$_etaMinutes min',
                              'ETA',
                            ),
                            _buildStatItem(
                              _getStatusText(),
                              'Status',
                              isGreen: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Map Card
                      Container(
                        height: 200,
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              FlutterMap(
                                options: MapOptions(
                                  initialCenter: _victimLocation ??
                                      const latlong2.LatLng(0, 0),
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
                              // Live Tracking Indicator
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const BlinkingDot(),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Live Tracking',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Status Timeline Checklist Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildTimelineStep(
                              title: 'SOS Sent',
                              subtitle: null,
                              time: _getTimeAgo('createdAt'),
                              isCompleted: true,
                              isActive: false,
                              lineColor: const Color(0xFF2E7D32),
                            ),
                            _buildTimelineStep(
                              title: 'Volunteer Selected',
                              subtitle: _volunteerName.isNotEmpty
                                  ? '$_volunteerName is on the way'
                                  : null,
                              time: _getTimeAgo('acceptedAt'),
                              isCompleted: _status != 'waiting',
                              isActive: _status == 'accepted',
                              lineColor: const Color(0xFF0066CC),
                            ),
                            _buildTimelineStep(
                              title: 'Arriving Soon',
                              subtitle: null,
                              time: _status == 'en_route' || _status == 'accepted'
                                  ? '$_etaMinutes min (ETA)'
                                  : null,
                              isCompleted: _status == 'arrived' || _status == 'resolved',
                              isActive: _status == 'en_route',
                              isSpecialDot: _status == 'en_route',
                              lineColor: const Color(0xFFE0E2EC),
                            ),
                            _buildTimelineStep(
                              title: 'Help on the Way',
                              subtitle: 'Stay calm and wait for help',
                              time: '',
                              isCompleted: _status == 'resolved',
                              isActive: _status == 'arrived',
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Bottom Cancel SOS Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isCancelling ? null : _cancelEmergency,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF0F0),
                            foregroundColor: const Color(0xFFE31E24),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isCancelling
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
                                  ),
                                )
                              : const Text(
                                  'Cancel SOS',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, {bool isGreen = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isGreen ? const Color(0xFF2E7D32) : const Color(0xFF1A1C1E),
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
    );
  }

  Widget _buildTimelineStep({
    required String title,
    String? subtitle,
    String? time,
    required bool isCompleted,
    required bool isActive,
    bool isLast = false,
    bool isSpecialDot = false,
    Color? lineColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicator dot and line
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? const Color(0xFF2E7D32)
                    : (isActive ? const Color(0xFF0066CC) : Colors.white),
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFF2E7D32)
                      : (isActive ? const Color(0xFF0066CC) : const Color(0xFFE0E2EC)),
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
                height: 46,
                color: lineColor ?? const Color(0xFFE0E2EC),
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Step info details
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
                      fontWeight: (isCompleted || isActive) ? FontWeight.bold : FontWeight.normal,
                      color: (isCompleted || isActive) ? const Color(0xFF1A1C1E) : const Color(0xFF9E9E9E),
                    ),
                  ),
                  if (time != null && time.isNotEmpty)
                    Row(
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? const Color(0xFF0066CC) : const Color(0xFF74777F),
                          ),
                        ),
                        if (isSpecialDot) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0066CC),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF74777F),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusText() {
    switch (_status) {
      case 'waiting':
        return 'Searching for nearby volunteers...';
      case 'accepted':
        return 'Help is on the way.';
      case 'en_route':
        return 'Volunteer is heading to your location.';
      case 'arrived':
        return 'Volunteer has arrived.';
      case 'resolved':
        return 'Emergency resolved.';
      case 'cancelled':
        return 'Emergency cancelled.';
      default:
        return 'Help is on the way.';
    }
  }

  String _getTimeAgo(String field) {
    if (_emergencyData == null || _emergencyData![field] == null) return '';
    
    dynamic timestamp = _emergencyData![field];
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFE31E24),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Icon(
                  Icons.shield,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'CERS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'Stay Protected',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Blinking dot for live tracking indicator
class BlinkingDot extends StatefulWidget {
  const BlinkingDot({super.key});

  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF2E7D32),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}