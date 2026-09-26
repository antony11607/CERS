import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../emergency_service.dart';
import '../../location_service.dart';
import '../../services/backend_api_service.dart';
import 'finding_help_screen.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  String _selectedPreset = 'Medical';
  String _urgencyLevel = 'High';
  String _selectedIncidentType = 'Medical Emergency';
  final TextEditingController _descriptionController = TextEditingController();

  final LocationService _locationService = LocationService();
  final EmergencyService _emergencyService = EmergencyService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSubmitting = false;
  bool _isLoadingLocation = true;
  bool _isLoadingName = true;
  String _userName = '';
  Position? _currentPosition;
  String _addressDisplay = 'Fetching your current location...';
  String _address = '';

  final List<Map<String, dynamic>> _presets = [
    {'icon': Icons.local_fire_department_outlined, 'label': 'Fire', 'color': Colors.red},
    {'icon': Icons.monitor_heart_outlined, 'label': 'Medical', 'color': Colors.blue},
    {'icon': Icons.security_outlined, 'label': 'Crime', 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await Future.wait([
      _getCurrentLocation(),
      _getUserName(),
    ]);
  }

  Future<void> _getUserName() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('[ReportIncident] ❌ User not authenticated for fetching name');
        if (mounted) setState(() => _isLoadingName = false);
        return;
      }

      DocumentSnapshot userDoc = await _firestore
          .collection('user')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        _userName = userData['name'] ?? currentUser.displayName ?? 'Unknown User';
        debugPrint('[ReportIncident] ✅ User name fetched: $_userName');
      } else {
        _userName = currentUser.displayName ?? 'Unknown User';
        debugPrint('[ReportIncident] ⚠️ User doc not found, using display name: $_userName');
      }

      if (mounted) setState(() => _isLoadingName = false);
    } catch (e) {
      debugPrint('[ReportIncident] ❌ Error fetching user name: $e');
      if (mounted) setState(() => _isLoadingName = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      debugPrint('[ReportIncident] 📍 Fetching current location...');

      // Check location services
      bool serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[ReportIncident] ⚠️ Location services disabled');
        if (mounted) {
          setState(() {
            _addressDisplay = 'Location services disabled. Please enable GPS.';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      // Check/request permission
      var permissionStatus = await _locationService.checkLocationPermission();
      if (permissionStatus != PermissionStatus.granted) {
        permissionStatus = await _locationService.requestLocationPermission();
      }

      if (permissionStatus != PermissionStatus.granted) {
        debugPrint('[ReportIncident] ⚠️ Location permission denied');
        if (mounted) {
          setState(() {
            _addressDisplay = 'Location permission denied.';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      // Get current position
      Position? position = await _locationService.getCurrentLocation();
      if (position != null) {
        debugPrint('[ReportIncident] ✅ Current location obtained');
        debugPrint('[ReportIncident] 📍 Lat: ${position.latitude}, Lng: ${position.longitude}');
        _currentPosition = position;

        // Try to reverse geocode to get address
        try {
          String? address = await BackendApiService.reverseGeocode(
            lat: position.latitude,
            lng: position.longitude,
          );
          if (address != null && address.isNotEmpty) {
            _address = address;
            debugPrint('[ReportIncident] 🏠 Address fetched: $address');
          } else {
            _address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
            debugPrint('[ReportIncident] ⚠️ Address not available, using coordinates');
          }
        } catch (e) {
          _address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          debugPrint('[ReportIncident] ❌ Error reverse geocoding: $e');
        }

        if (mounted) {
          setState(() {
            _addressDisplay = _address;
            _isLoadingLocation = false;
          });
        }
      } else {
        debugPrint('[ReportIncident] ❌ Failed to get location');
        if (mounted) {
          setState(() {
            _addressDisplay = 'Unable to retrieve location. Please try again.';
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[ReportIncident] ❌ Error getting location: $e');
      if (mounted) {
        setState(() {
          _addressDisplay = 'Error getting location.';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    // Validate
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your current location. Please enable GPS and try again.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to report an incident.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      debugPrint('[ReportIncident] ==========================================');
      debugPrint('[ReportIncident] 🚀 Submitting report incident...');
      debugPrint('[ReportIncident] User: $currentUser');
      debugPrint('[ReportIncident] Incident Type: $_selectedIncidentType');
      debugPrint('[ReportIncident] Description: ${_descriptionController.text}');
      debugPrint('[ReportIncident] Location: (${_currentPosition!.latitude}, ${_currentPosition!.longitude})');
      debugPrint('[ReportIncident] Address: $_address');

      // Check for active emergency first
      bool hasActive = await _emergencyService.hasActiveEmergency(currentUser.uid);
      if (hasActive) {
        debugPrint('[ReportIncident] ⚠️ User already has an active emergency');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an active emergency request.'),
              backgroundColor: Color(0xFFE65100),
            ),
          );
          setState(() => _isSubmitting = false);
        }
        return;
      }

      // Create the report incident in the existing emergencies collection
      String? emergencyId = await _emergencyService.createReportIncident(
        userId: currentUser.uid,
        userName: _userName,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _address,
        incidentType: _selectedIncidentType,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : '$_selectedPreset incident reported via Report Incident feature',
      );

      if (emergencyId != null && mounted) {
        debugPrint('[ReportIncident] ✅ Report submitted successfully');
        debugPrint('[ReportIncident] 🔥 Emergency ID: $emergencyId');

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report sent successfully. Searching for nearby volunteers...'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to FindingHelpScreen to track the incident lifecycle
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FindingHelpScreen(
              emergencyId: emergencyId,
            ),
          ),
        );
      } else if (mounted) {
        debugPrint('[ReportIncident] ❌ Failed to create report incident');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send report. Please try again.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      debugPrint('[ReportIncident] ❌ Error submitting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
        setState(() => _isSubmitting = false);
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
          'Report Incident',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QUICK REPORT PRESETS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _presets.map((preset) {
                final isSelected = _selectedPreset == preset['label'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPreset = preset['label'];
                      // Map preset to incident type
                      switch (preset['label']) {
                        case 'Fire':
                          _selectedIncidentType = 'Fire Accident';
                          break;
                        case 'Medical':
                          _selectedIncidentType = 'Medical Emergency';
                          break;
                        case 'Crime':
                          _selectedIncidentType = 'Criminal Activity';
                          break;
                      }
                    });
                  },
                  child: Container(
                    width: 90,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF1F3F5) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? preset['color'] as Color : Colors.grey.shade200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          preset['icon'] as IconData,
                          color: preset['color'] as Color,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset['label'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text(
              'Incident Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedIncidentType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'Medical Emergency',
                      child: Text('Medical Emergency'),
                    ),
                    DropdownMenuItem(
                      value: 'Fire Accident',
                      child: Text('Fire Accident'),
                    ),
                    DropdownMenuItem(
                      value: 'Vehicle Crash',
                      child: Text('Vehicle Crash'),
                    ),
                    DropdownMenuItem(
                      value: 'Criminal Activity',
                      child: Text('Criminal Activity'),
                    ),
                    DropdownMenuItem(
                      value: 'Natural Disaster',
                      child: Text('Natural Disaster'),
                    ),
                    DropdownMenuItem(
                      value: 'Other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedIncidentType = value;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Describe the Situation',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Briefly describe what is happening...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                  child: const Text('Refresh', style: TextStyle(color: Color(0xFF0066CC), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFECEFF1),
                      shape: BoxShape.circle,
                    ),
                    child: _isLoadingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
                            ),
                          )
                        : const Icon(Icons.location_on, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _address.isNotEmpty ? _address : 'Fetching location...',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentPosition != null
                              ? 'Auto-detected (within ${_currentPosition!.accuracy.toStringAsFixed(0)} meters)'
                              : 'Unable to detect location',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Attach Evidence (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 100,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.none),
                  ),
                  child: Material(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt_outlined, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('Take Photo', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&q=80&w=200',
                    width: 140,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Urgency Level',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: ['Low', 'Medium', 'High'].map((level) {
                  final isSelected = _urgencyLevel == level;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _urgencyLevel = level;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (level == 'High' ? const Color(0xFFE31E24) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          level,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? (level == 'High' ? Colors.white : Colors.black87)
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE31E24),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Send Alert',
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
    );
  }
}