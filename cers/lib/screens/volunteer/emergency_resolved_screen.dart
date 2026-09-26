import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'volunteer_service.dart';
import 'volunteer_dashboard_screen.dart';

class EmergencyResolvedScreen extends StatefulWidget {
  final String emergencyId;

  const EmergencyResolvedScreen({
    super.key,
    required this.emergencyId,
  });

  @override
  State<EmergencyResolvedScreen> createState() => _EmergencyResolvedScreenState();
}

class _EmergencyResolvedScreenState extends State<EmergencyResolvedScreen> {
  final VolunteerService _volunteerService = VolunteerService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _emergencyData;
  Map<String, dynamic>? _volunteerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      debugPrint('[EmergencyResolved] Loading data for emergency: ${widget.emergencyId}');
      
      // Get emergency details
      DocumentSnapshot emergencyDoc = await _firestore
          .collection('emergencies')
          .doc(widget.emergencyId)
          .get();

      if (!emergencyDoc.exists) {
        debugPrint('[EmergencyResolved] Emergency document not found');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      Map<String, dynamic> emergencyData = emergencyDoc.data() as Map<String, dynamic>;

      // Get volunteer details
      User? currentUser = _auth.currentUser;
      Map<String, dynamic>? volunteerData;
      
      if (currentUser != null) {
        DocumentSnapshot volunteerDoc = await _firestore
            .collection('volunteers')
            .doc(currentUser.uid)
            .get();

        if (volunteerDoc.exists) {
          volunteerData = volunteerDoc.data() as Map<String, dynamic>;
        }
      }

      if (mounted) {
        setState(() {
          _emergencyData = emergencyData;
          _volunteerData = volunteerData;
          _isLoading = false;
        });
      }

      debugPrint('[EmergencyResolved] Data loaded successfully');
    } catch (e) {
      debugPrint('[EmergencyResolved] Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return 'N/A';
    }

    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String period = dateTime.hour >= 12 ? 'PM' : 'AM';
    String month = dateTime.month.toString().padLeft(2, '0');
    String day = dateTime.day.toString().padLeft(2, '0');
    String year = dateTime.year.toString();

    return '$hour:$minute $period, $month/$day/$year';
  }

  String _calculateResponseDuration() {
    if (_emergencyData == null) return 'N/A';

    dynamic acceptedAt = _emergencyData!['acceptedAt'];
    dynamic resolvedAt = _emergencyData!['resolvedAt'];

    if (acceptedAt == null || resolvedAt == null) return 'N/A';

    DateTime acceptedDateTime;
    DateTime resolvedDateTime;

    if (acceptedAt is Timestamp) {
      acceptedDateTime = acceptedAt.toDate();
    } else {
      return 'N/A';
    }

    if (resolvedAt is Timestamp) {
      resolvedDateTime = resolvedAt.toDate();
    } else {
      return 'N/A';
    }

    Duration duration = resolvedDateTime.difference(acceptedDateTime);
    
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '$hours hr $minutes min';
    } else {
      return '$minutes mins';
    }
  }

  void _navigateToDashboard() {
    debugPrint('[EmergencyResolved] Navigating to Volunteer Dashboard');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const VolunteerDashboardScreen(),
      ),
    );
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
          'Emergency Resolved',
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
                      Text(
                        'Emergency not found',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Success Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFF5F5),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 80,
                          color: Color(0xFFE31E24),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Request Completed Title
                      const Text(
                        'Request Completed',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48.0),
                        child: Text(
                          'The emergency alert has been successfully resolved and marked as closed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Volunteer Info Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _volunteerData?['photoUrl'] != null
                                    ? NetworkImage(_volunteerData!['photoUrl'])
                                    : null,
                                child: _volunteerData?['photoUrl'] == null
                                    ? Icon(Icons.person, size: 32, color: Colors.grey[600])
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // Volunteer info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _volunteerData?['name'] ?? 'Volunteer',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE31E24),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Lead Responder',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Stats Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.access_time,
                                label: 'Completion Time',
                                value: _formatTimestamp(_emergencyData?['resolvedAt']),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.timer,
                                label: 'Response Duration',
                                value: _calculateResponseDuration(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Incident Report Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.description_outlined, size: 20, color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Incident Report',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Final summary & logs',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Availability Status Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 20, color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your availability status has been reset to Online.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'You are ready to receive new nearby alerts.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Done Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _navigateToDashboard,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE31E24),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Report an Issue Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              // TODO: Implement report issue functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Report issue functionality coming soon'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE31E24),
                              side: const BorderSide(color: Color(0xFFE31E24)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Report an Issue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}