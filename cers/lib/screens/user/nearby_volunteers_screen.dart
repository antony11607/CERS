import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import '../../location_service.dart';

class NearbyVolunteersScreen extends StatefulWidget {
  const NearbyVolunteersScreen({super.key});

  @override
  State<NearbyVolunteersScreen> createState() => _NearbyVolunteersScreenState();
}

class _NearbyVolunteersScreenState extends State<NearbyVolunteersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  StreamSubscription<QuerySnapshot>? _volunteersSubscription;
  List<Map<String, dynamic>> _volunteers = [];
  latlong2.LatLng? _userLocation;
  bool _isLoading = true;
  bool _hasError = false;
  String _activeFilter = 'All Active';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _volunteersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _getUserLocation();
    if (_userLocation != null) {
      _listenToVolunteers();
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _getUserLocation() async {
    try {
      PermissionStatus permissionStatus = await Permission.location.request();
      
      if (permissionStatus != PermissionStatus.granted) {
        debugPrint('[NearbyVolunteersScreen] Location permission denied');
        return;
      }

      bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationServiceEnabled) {
        debugPrint('[NearbyVolunteersScreen] Location services disabled');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = latlong2.LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('[NearbyVolunteersScreen] Error getting location: $e');
    }
  }

  void _listenToVolunteers() {
    try {
      // Listen to all approved volunteers in real-time
      _volunteersSubscription = _firestore
          .collection('volunteers')
          .where('isApproved', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .snapshots()
          .listen((QuerySnapshot snapshot) {
            if (!mounted) return;

            List<Map<String, dynamic>> allVolunteers = [];
            
            for (var doc in snapshot.docs) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              
              // Check if volunteer has location
              if (data['latitude'] != null && data['longitude'] != null) {
                // Calculate distance from user
                double distance = _calculateDistance(
                  _userLocation!.latitude,
                  _userLocation!.longitude,
                  data['latitude'],
                  data['longitude'],
                );

                // Only include volunteers within 1000 meters (1 km)
                if (distance <= 1000) {
                  data['distance'] = distance;
                  data['volunteerId'] = doc.id;
                  allVolunteers.add(data);
                }
              }
            }

            // Sort by distance (nearest first)
            allVolunteers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

            // Calculate ETA for each volunteer (assuming 30 km/h average speed)
            for (var volunteer in allVolunteers) {
              double distanceKm = (volunteer['distance'] as double) / 1000.0;
              int etaMinutes = (distanceKm / 30.0 * 60).round();
              volunteer['eta'] = etaMinutes;
            }

            setState(() {
              _volunteers = allVolunteers;
              _isLoading = false;
              _hasError = false;
            });

            debugPrint('[NearbyVolunteersScreen] Found ${allVolunteers.length} nearby volunteers');
          }, onError: (error) {
            debugPrint('[NearbyVolunteersScreen] Stream error: $error');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          });
    } catch (e) {
      debugPrint('[NearbyVolunteersScreen] Error setting up listener: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  String _formatETA(int minutes) {
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

  Future<void> _callVolunteer(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('[NearbyVolunteersScreen] Error launching phone: $e');
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nearby Volunteers',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black87),
            onPressed: () {
              // TODO: Implement filter functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Filter functionality coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Map Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&q=80&w=600'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black.withValues(alpha: 0.15),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_volunteers.length} Active Near You',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fullscreen, size: 20, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filters row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All Active'),
                const SizedBox(width: 8),
                _buildFilterChip('Under 1km'),
                const SizedBox(width: 8),
                _buildFilterChip('Medical Professionals'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Available Responders Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Responders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Sorted by Distance',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Volunteer List
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
        ),
      );
    }

    if (_hasError) {
      return Center(
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
      );
    }

    if (_volunteers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 20),
              Text(
                'No Nearby Volunteers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Don\'t see who you need? Expand the map for a wider search.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _volunteers.length,
      itemBuilder: (context, index) {
        final vol = _volunteers[index];
        return _buildVolunteerCard(vol);
      },
    );
  }

  Widget _buildVolunteerCard(Map<String, dynamic> vol) {
    String name = vol['name'] ?? 'Unknown Volunteer';
    String role = vol['role'] ?? 'Volunteer';
    String phone = vol['phone'] ?? '';
    String? photoUrl = vol['photoUrl'];
    bool isOnline = vol['isOnline'] ?? false;
    double distance = vol['distance'] ?? 0.0;
    int eta = vol['eta'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with online indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF00E676) : Colors.grey,
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
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFECEFF1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOnline ? 'online' : 'offline',
                            style: TextStyle(
                              fontSize: 10,
                              color: isOnline ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          role,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.navigation_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text(
                          _formatDistance(distance),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text(
                          _formatETA(eta),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: phone.isNotEmpty ? () => _callVolunteer(phone) : null,
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0066CC),
                    side: const BorderSide(color: Color(0xFF0066CC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement request help functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request Help functionality coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE31E24),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Request Help'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
        // TODO: Implement filter logic
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1967D2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1967D2) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}