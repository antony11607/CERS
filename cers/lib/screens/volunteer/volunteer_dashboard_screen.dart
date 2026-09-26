import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../location_service.dart';
import 'volunteer_service.dart';
import 'emergency_response_screen.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  State<VolunteerDashboardScreen> createState() => _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  bool _isOnline = true;
  int _currentNavIndex = 0;
  final LocationService _locationService = LocationService();
  final VolunteerService _volunteerService = VolunteerService();
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _emergenciesStreamSubscription;
  List<Map<String, dynamic>> _nearbyEmergencies = [];
  bool _isLoadingLocation = true;
  String _locationStatus = 'Fetching your current location...';

  final List<Map<String, dynamic>> _recentAlerts = [
    {
      'type': 'Traffic Accident',
      'distance': '1.2 km',
      'location': 'Sector 2, West Gate',
      'time': '45 mins ago',
      'status': 'Completed',
      'icon': Icons.directions_car,
      'iconColor': Color(0xFF0066CC),
    },
    {
      'type': 'Medical Assistance',
      'distance': '3 km',
      'location': 'Hills Park Entrance',
      'time': '2 hrs ago',
      'status': 'Dismissed',
      'icon': Icons.favorite,
      'iconColor': Color(0xFFE31E24),
    },
    {
      'type': 'Breathless Incident',
      'distance': '0.8 km',
      'location': 'North Plaza',
      'time': 'Yesterday',
      'status': 'Completed',
      'icon': Icons.favorite,
      'iconColor': Color(0xFFE31E24),
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocationAndEmergencies();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _emergenciesStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocationAndEmergencies() async {
    await _handleLocationPermission();
  }

  Future<void> _handleLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationStatus = 'Location services are disabled. Please enable GPS.';
            _isLoadingLocation = false;
          });
          _showLocationServiceDialog();
        }
        return;
      }

      // Check permission status
      PermissionStatus permissionStatus = await _locationService.checkLocationPermission();

      // If not granted, request permission
      if (permissionStatus != PermissionStatus.granted) {
        permissionStatus = await _locationService.requestLocationPermission();

        // Check if permanently denied
        if (_locationService.isPermanentlyDenied(permissionStatus)) {
          if (mounted) {
            setState(() {
              _locationStatus = 'Location permission permanently denied.';
              _isLoadingLocation = false;
            });
            _showPermanentlyDeniedDialog();
          }
          return;
        }

        // Check if denied
        if (permissionStatus != PermissionStatus.granted) {
          if (mounted) {
            setState(() {
              _locationStatus = 'Location permission denied.';
              _isLoadingLocation = false;
            });
            _showPermissionDeniedDialog();
          }
          return;
        }
      }

      // Permission granted, start location tracking
      await _startLocationTracking();
    } catch (e) {
      debugPrint('[VolunteerDashboard] Error handling location permission: $e');
      if (mounted) {
        setState(() {
          _locationStatus = 'Unable to retrieve your current location.';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      // Get current location first
      Position? position = await _locationService.getCurrentLocation();
      
      if (position != null && mounted) {
        setState(() {
          _locationStatus = _locationService.getFormattedLocation(position);
          _isLoadingLocation = false;
        });

        // Update volunteer location in Firestore
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _volunteerService.updateVolunteerLocation(
            volunteerId: currentUser.uid,
            latitude: position.latitude,
            longitude: position.longitude,
          );

          // Start listening to emergencies
          _listenToEmergencies(position.latitude, position.longitude);

          // Start continuous location tracking
          _startContinuousTracking();
        }
      } else {
        if (mounted) {
          setState(() {
            _locationStatus = 'Unable to retrieve your current location.';
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[VolunteerDashboard] Error starting location tracking: $e');
      if (mounted) {
        setState(() {
          _locationStatus = 'Unable to retrieve your current location.';
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _startContinuousTracking() {
    _positionStreamSubscription = _locationService.startLocationTracking(distanceFilter: 20.0)?.listen(
      (Position position) async {
        debugPrint('[VolunteerDashboard] Location updated - Lat: ${position.latitude}, Lng: ${position.longitude}');
        
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _volunteerService.updateVolunteerLocation(
            volunteerId: currentUser.uid,
            latitude: position.latitude,
            longitude: position.longitude,
          );

          // Update emergencies stream with new location
          _listenToEmergencies(position.latitude, position.longitude);
        }
      },
    );
  }

  void _listenToEmergencies(double volunteerLatitude, double volunteerLongitude) {
    _emergenciesStreamSubscription?.cancel();
    
    _emergenciesStreamSubscription = _volunteerService.getEmergenciesStream(
      volunteerLatitude: volunteerLatitude,
      volunteerLongitude: volunteerLongitude,
      radiusInMeters: 1000.0,
    )?.listen((List<Map<String, dynamic>> emergencies) {
      if (mounted) {
        setState(() {
          _nearbyEmergencies = emergencies;
        });
      }
    });
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Location Services Disabled', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: const Text(
            'Location services are disabled. Please enable GPS to receive emergency alerts.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 15, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _locationService.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE31E24),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Open Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Location Permission Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: const Text(
            'Location access is required to receive emergency alerts. Please grant permission to continue.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 15, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _handleLocationPermission();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE31E24),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Permission Permanently Denied', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: const Text(
            'Location permission has been permanently denied. Please enable it in app settings to receive emergency alerts.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 15, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _locationService.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE31E24),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Open Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptEmergency(Map<String, dynamic> emergency) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get volunteer details
      DocumentSnapshot volunteerDoc = await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(currentUser.uid)
          .get();

      if (volunteerDoc.exists) {
        Map<String, dynamic> volunteerData = volunteerDoc.data() as Map<String, dynamic>;
        String volunteerName = volunteerData['name'] ?? 'Unknown';
        String volunteerPhone = volunteerData['phone'] ?? 'N/A';

        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
              ),
            ),
          );
        }

        // Accept emergency via backend API
        Map<String, dynamic> result = await _volunteerService.acceptEmergencyWithTransaction(
          emergencyId: emergency['emergencyId'],
          volunteerId: currentUser.uid,
          volunteerName: volunteerName,
          volunteerPhone: volunteerPhone,
        );

        // Hide loading indicator
        if (mounted) {
          Navigator.pop(context);
        }

        if (result['success'] && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigate to emergency response screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyResponseScreen(
                emergencyId: emergency['emergencyId'],
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: const Color(0xFFC62828),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[VolunteerDashboard] Error accepting emergency: $e');
      // Hide loading indicator if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept emergency. Please try again.'),
            backgroundColor: Color(0xFFC62828),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: const BoxDecoration(color: Color(0xFFE31E24), borderRadius: BorderRadius.all(Radius.circular(8))),
                        child: const Icon(Icons.shield, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('CERS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.1)),
                          Text('Stay Protected', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
                        child: const Icon(Icons.notifications_outlined, color: Colors.black87, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey[200]!)),
                        child: const Icon(Icons.settings_outlined, color: Colors.black87, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentNavIndex,
                children: [
                  _buildHomeScreen(),
                  _buildHistoryScreen(),
                  _buildProfileScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, -2))]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, 'Home', 0, _currentNavIndex == 0),
            _buildNavItem(Icons.history_outlined, 'History', 1, _currentNavIndex == 1),
            _buildNavItem(Icons.person_outlined, 'Profile', 2, _currentNavIndex == 2),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Status Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isLoadingLocation ? Colors.grey[100] : const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _isLoadingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24))),
                        )
                      : const Icon(Icons.location_on, color: Color(0xFFE31E24), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(
                        _locationStatus,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(color: _isOnline ? Color(0xFF00E676) : Colors.grey, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_isOnline ? 'Online & Available' : 'Offline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                const SizedBox(height: 2),
                                Text(_isOnline ? 'Ready for emergency response' : 'You are currently offline', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Station 4', style: TextStyle(fontSize: 12, color: Color(0xFF1967D2), fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Nearby Emergencies Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFE31E24)), const SizedBox(width: 8), Text('Nearby Emergencies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))]),
                        if (_nearbyEmergencies.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(12)),
                            child: Text('${_nearbyEmergencies.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE31E24))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_nearbyEmergencies.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('No nearby emergencies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Text('You will be notified when emergencies occur nearby', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                      shrinkWrap: true, physics: NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
                      itemCount: _nearbyEmergencies.length,
                      itemBuilder: (context, index) {
                        final emergency = _nearbyEmergencies[index];
                        double distanceInMeters = emergency['distance'] as double;
                        String distanceText = distanceInMeters < 1000 
                            ? '${distanceInMeters.toStringAsFixed(0)} m' 
                            : '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
                        
                        final String source = emergency['source'] ?? '';
                        final String incidentType = emergency['incidentType'] ?? '';
                        final String emergencyTitle = source == 'report' 
                            ? (incidentType.isNotEmpty ? incidentType : 'Reported Incident')
                            : 'Emergency Alert';
                        final String addressText = emergency['address'] ?? '';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(
                                      source == 'report' ? Icons.flag_outlined : Icons.warning_amber_rounded,
                                      color: const Color(0xFFE31E24),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              emergencyTitle,
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(6)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (source == 'report')
                                                    Container(
                                                      width: 6, height: 6,
                                                      margin: const EdgeInsets.only(right: 4),
                                                      decoration: const BoxDecoration(color: Color(0xFFE31E24), shape: BoxShape.circle),
                                                    ),
                                                  Text(distanceText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE31E24))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (addressText.isNotEmpty)
                                          Text(addressText, style: TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)
                                        else
                                          Text('Lat: ${emergency['victimLatitude'].toStringAsFixed(6)}, Lng: ${emergency['victimLongitude'].toStringAsFixed(6)}', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _acceptEmergency(emergency),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE31E24),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text('Accept Emergency', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Recent Alerts Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(Icons.history_outlined, size: 20, color: Colors.grey[600]), const SizedBox(width: 8), Text('Recent Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))]),
                        TextButton(onPressed: () {}, child: const Text('View History', style: TextStyle(fontSize: 13, color: Color(0xFF0066CC), fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true, physics: NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
                      itemCount: _recentAlerts.length,
                      itemBuilder: (context, index) {
                        final alert = _recentAlerts[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                          child: Row(
                            children: [
                              Container(width: 44, height: 44, decoration: BoxDecoration(color: alert['iconColor'].withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(alert['icon'], color: alert['iconColor'], size: 24)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(alert['type'], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)), const SizedBox(height: 4), Text(alert['location'], style: TextStyle(fontSize: 12, color: Colors.grey))])),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(alert['time'], style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: alert['status'] == 'Completed' ? Color(0xFFE8F5E9) : Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(6)),
                                  child: Text(alert['status'], style: TextStyle(fontSize: 10, color: alert['status'] == 'Completed' ? Color(0xFF2E7D32) : Color(0xFFC62828), fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=120')),
                              Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Officer John Doe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 2), Text('Active Responder', style: TextStyle(fontSize: 13, color: Colors.grey))])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('LVL 12', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE31E24))),
                            Container(
                              width: 60, height: 6,
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(3)),
                              child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 0.75, child: Container(decoration: BoxDecoration(color: Color(0xFFE31E24), borderRadius: BorderRadius.circular(3)))),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.phone, size: 20), label: const Text('Call Dispatch'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0066CC), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0))),
                        const SizedBox(width: 12),
                        Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _isOnline = !_isOnline), icon: const Icon(Icons.power_settings_new, size: 20), label: const Text('Toggle Status'), style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
  }

  Widget _buildHistoryScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Response History',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Your past emergency responses will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Icon(Icons.person_outline, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            'Volunteer Profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your profile and settings',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? const Color(0xFFE31E24) : Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: isActive ? const Color(0xFFE31E24) : Colors.grey, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}