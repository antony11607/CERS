import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;
import '../../location_service.dart';
import '../../emergency_service.dart';
import 'finding_help_screen.dart';
import 'emergency_contacts_screen.dart';
import 'nearby_volunteers_screen.dart';
import 'report_incident_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTrackingLocation = false;

  @override
  void initState() {
    super.initState();
    _checkVolunteerStatusAndStartTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkVolunteerStatusAndStartTracking() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      DocumentSnapshot volunteerDoc = await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(currentUser.uid)
          .get();

      if (volunteerDoc.exists) {
        Map<String, dynamic> volunteerData = volunteerDoc.data() as Map<String, dynamic>;
        bool isApproved = volunteerData['isApproved'] ?? false;

        if (isApproved) {
          await _startLocationTracking();
        }
      }
    } catch (e) {
      // Silently handle error
    }
  }

  Future<void> _startLocationTracking() async {
    PermissionStatus permissionStatus = await Permission.location.request();

    if (permissionStatus != PermissionStatus.granted) {
      return;
    }

    bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      return;
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _updateVolunteerLocation(position);
    });

    setState(() {
      _isTrackingLocation = true;
    });
  }

  Future<void> _updateVolunteerLocation(Position position) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(currentUser.uid)
          .update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'locationUpdatedAt': FieldValue.serverTimestamp(),
            'isOnline': true,
          });
    } catch (e) {
      // Silently handle error
    }
  }

  Future<void> _stopLocationTracking() async {
    await _positionStreamSubscription?.cancel();
    setState(() {
      _isTrackingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            const ContactsScreen(),
            const EmergencyContactsScreen(),
            const NearbyVolunteersScreen(),
            const ReportIncidentScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              index: 0,
              isActive: _currentIndex == 0,
            ),
            _buildNavItem(
              icon: Icons.contacts_outlined,
              label: 'Emergency\nContacts',
              index: 1,
              isActive: _currentIndex == 1,
            ),
            _buildNavItem(
              icon: Icons.volunteer_activism_outlined,
              label: 'Volunteer',
              index: 2,
              isActive: _currentIndex == 2,
            ),
            _buildNavItem(
              icon: Icons.flag_outlined,
              label: 'Report',
              index: 3,
              isActive: _currentIndex == 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFFE31E24) : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? const Color(0xFFE31E24) : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderScreen(String title) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// Custom painter for dotted circle
class DottedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const dotSpacing = 15.0;
    const dotRadius = 2.0;

    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    for (double angle = 0; angle < 2 * math.pi; angle += dotSpacing / radius) {
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Home / Contacts screen – SOS hub
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final LocationService _locationService = LocationService();
  String _locationStatus = 'Fetching your current location...';
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeLocation() async {
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
        if (mounted) {
          setState(() {
            _isLoadingLocation = true;
          });
        }

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

      // Permission granted, get location
      await _fetchCurrentLocation();
    } catch (e) {
      debugPrint('[HomeScreen] Error handling location permission: $e');
      if (mounted) {
        setState(() {
          _locationStatus = 'Unable to retrieve your current location.';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingLocation = true;
          _locationStatus = 'Fetching your current location...';
        });
      }

      Position? position = await _locationService.getCurrentLocation();

      if (mounted) {
        if (position != null) {
          debugPrint('[HomeScreen] Location received - Lat: ${position.latitude}, Lng: ${position.longitude}');
          setState(() {
            _locationStatus = _locationService.getFormattedLocation(position);
            _isLoadingLocation = false;
          });
        } else {
          debugPrint('[HomeScreen] Failed to get location');
          setState(() {
            _locationStatus = 'Unable to retrieve your current location.';
            _isLoadingLocation = false;
          });
          _showLocationErrorDialog();
        }
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error fetching location: $e');
      if (mounted) {
        setState(() {
          _locationStatus = 'Unable to retrieve your current location.';
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Location Services Disabled', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: const Text(
            'Location services are disabled. Please enable GPS to use emergency services.',
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
            'Location access is required for emergency services. Please grant permission to continue.',
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
            'Location permission has been permanently denied. Please enable it in app settings to use emergency services.',
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

  void _showLocationErrorDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Location Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: const Text(
            'Unable to retrieve your current location. Please try again.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontSize: 15, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _fetchCurrentLocation();
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
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE31E24),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: const Icon(Icons.shield, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CERS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.2)),
                          Text('Stay Protected', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_outlined, color: Colors.black87, size: 24),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Color(0xFFE31E24), shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(size: const Size(280, 280), painter: DottedCirclePainter()),
                  Positioned(
                    top: 20, left: 20,
                    child: _buildActionButton(icon: Icons.location_on_outlined, label: 'My\nLocation', iconColor: const Color(0xFFE31E24)),
                  ),
                  Positioned(
                    top: 20, right: 20,
                    child: _buildActionButton(icon: Icons.people_outline, label: 'Nearby\nVolunteers', iconColor: const Color(0xFF0066CC)),
                  ),
                  Positioned(
                    bottom: 80, left: 20,
                    child: _buildActionButton(icon: Icons.flag_outlined, label: 'Report\nIncident', iconColor: const Color(0xFF0066CC)),
                  ),
                  Positioned(
                    bottom: 80, right: 20,
                    child: _buildActionButton(icon: Icons.contacts_outlined, label: 'Emergency\nContacts', iconColor: const Color(0xFFE31E24)),
                  ),
                  GestureDetector(
                    onTap: _showSOSDialog,
                    child: Container(
                      width: 140, height: 140,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE31E24),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0x33E31E24), blurRadius: 20, spreadRadius: 10)],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone, color: Colors.white, size: 40),
                          SizedBox(height: 8),
                          Text('SOS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                          Text('Tap for Help', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.location_on, color: Color(0xFFE31E24), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text(
                            _locationStatus,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoadingLocation)
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _fetchCurrentLocation,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(color: Color(0xFFFFF5F5), shape: BoxShape.circle),
                          child: const Icon(Icons.refresh, color: Color(0xFFE31E24), size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color iconColor}) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.2)),
        ],
      ),
    );
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Emergency SOS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: const Text(
            'Are you sure you want to send an emergency alert? This will notify all nearby volunteers and emergency contacts.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 15, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _handleSOSButton();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE31E24),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Send SOS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSOSButton() async {
    try {
      debugPrint('[HomeScreen] SOS button pressed');

      // Show loading dialog
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

      // Get current user
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('[HomeScreen] User not authenticated');
        if (mounted) {
          Navigator.pop(context); // Hide loading
          _showErrorDialog('Error', 'You must be logged in to send an SOS.');
        }
        return;
      }

      // Check for active emergency
      EmergencyService emergencyService = EmergencyService();
      bool hasActive = await emergencyService.hasActiveEmergency(currentUser.uid);
      
      if (hasActive) {
        debugPrint('[HomeScreen] User already has an active emergency');
        if (mounted) {
          Navigator.pop(context); // Hide loading
          _showErrorDialog('Active Emergency', 'You already have an active emergency request.');
        }
        return;
      }

      // Get current location
      Position? position = await _locationService.getCurrentLocation();
      
      // If location is not available, try to refresh
      if (position == null) {
        debugPrint('[HomeScreen] Location not available, refreshing...');
        position = await _locationService.refreshLocation();
      }

      // If still no location, show error
      if (position == null) {
        debugPrint('[HomeScreen] Failed to get location');
        if (mounted) {
          Navigator.pop(context); // Hide loading
          _showErrorDialog('Location Error', 'Unable to retrieve your current location. Please enable location services and try again.');
        }
        return;
      }

      debugPrint('[HomeScreen] Location obtained - Lat: ${position.latitude}, Lng: ${position.longitude}');

      // Create emergency
      String? emergencyId = await emergencyService.createEmergencyWithLocation(position);

      if (mounted) {
        Navigator.pop(context); // Hide loading
      }

      if (emergencyId != null) {
        debugPrint('[HomeScreen] Emergency created successfully: $emergencyId');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS alert sent successfully. Searching for nearby volunteers...'),
              backgroundColor: Color(0xFF2E7D32),
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Navigate to FindingHelpScreen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => FindingHelpScreen(
                emergencyId: emergencyId,
              ),
            ),
          );
        }
      } else {
        debugPrint('[HomeScreen] Failed to create emergency');
        if (mounted) {
          _showErrorDialog('Error', 'Failed to send SOS alert. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error in SOS handler: $e');
      if (mounted) {
        Navigator.pop(context); // Hide loading
        _showErrorDialog('Error', 'An unexpected error occurred. Please try again.');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: Text(
            message,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontSize: 15, color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }
}