import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'home_screen.dart';
import 'volunteer_accepted_screen.dart';
import 'volunteer_arrived_screen.dart';
import 'emergency_completed_screen.dart';
import '../../location_service.dart';

class FindingHelpScreen extends StatefulWidget {
  final String emergencyId;

  const FindingHelpScreen({
    super.key,
    required this.emergencyId,
  });

  @override
  State<FindingHelpScreen> createState() => _FindingHelpScreenState();
}

class _FindingHelpScreenState extends State<FindingHelpScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();

  StreamSubscription<DocumentSnapshot>? _emergencySubscription;
  Map<String, dynamic>? _emergencyData;
  String _status = 'waiting';
  latlong2.LatLng? _userLocation;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isCancelling = false;
  bool _hasNavigated = false;
  final String _currentRoute = 'FindingHelpScreen';

  @override
  void initState() {
    super.initState();
    debugPrint('[FindingHelpScreen] ========================================');
    debugPrint('[FindingHelpScreen] FindingHelpScreen initialized');
    debugPrint('[FindingHelpScreen] Emergency ID: ${widget.emergencyId}');
    debugPrint('[FindingHelpScreen] Current route: $_currentRoute');
    debugPrint('[FindingHelpScreen] ========================================');
    _initializeScreen();
  }

  @override
  void dispose() {
    debugPrint('[FindingHelpScreen] Disposing - cancelling emergency subscription');
    _emergencySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    // Start Firestore listener FIRST to catch status changes immediately
    // This is critical: the listener must be active before any async operations
    await _listenToEmergencyUpdates();
    // Then get location (this doesn't affect status tracking)
    await _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      PermissionStatus permissionStatus = await Permission.location.request();
      
      if (permissionStatus != PermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationServiceEnabled) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = latlong2.LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[FindingHelpScreen] Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            String newStatus = data['status'];
            String previousStatus = _status;

            if (previousStatus != newStatus) {
              debugPrint('[FindingHelpScreen] Previous status: $previousStatus → New status: $newStatus');
            }
            debugPrint('[FindingHelpScreen] Firestore listener received status = "$newStatus"');

            setState(() {
              _emergencyData = data;
              _status = newStatus;
            });

            // Prevent duplicate navigations
            if (_hasNavigated) {
              debugPrint('[FindingHelpScreen] Already navigated, skipping navigation decision');
              return;
            }

            debugPrint('[FindingHelpScreen] Navigation decision: status="$newStatus", route=$_currentRoute');
            
            // Navigate based on status
            if (newStatus == 'accepted' || newStatus == 'en_route') {
              _navigateToVolunteerAccepted();
            } else if (newStatus == 'arrived') {
              _navigateToVolunteerArrived();
            } else if (newStatus == 'resolved') {
              _navigateToEmergencyCompleted();
            } else if (newStatus == 'cancelled') {
              _navigateToHome();
            } else {
              debugPrint('[FindingHelpScreen] No navigation needed for status: $newStatus');
            }
          }, onError: (error) {
            debugPrint('[FindingHelpScreen] Stream error: $error');
            if (mounted) {
              setState(() => _hasError = true);
            }
          });
    } catch (e) {
      debugPrint('[FindingHelpScreen] Error setting up listener: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _navigateToVolunteerAccepted() {
    if (!mounted || _hasNavigated) return;
    
    _hasNavigated = true;
    debugPrint('[FindingHelpScreen] ✅ Navigation: Status accepted → VolunteerAcceptedScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VolunteerAcceptedScreen(
          emergencyId: widget.emergencyId,
        ),
      ),
    );
  }

  void _navigateToVolunteerArrived() {
    if (!mounted || _hasNavigated) return;
    
    _hasNavigated = true;
    debugPrint('[FindingHelpScreen] ✅ Navigation: Status arrived → VolunteerArrivedScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VolunteerArrivedScreen(
          emergencyId: widget.emergencyId,
        ),
      ),
    );
  }

  void _navigateToEmergencyCompleted() {
    if (!mounted || _hasNavigated) return;
    
    _hasNavigated = true;
    debugPrint('[FindingHelpScreen] ✅ Navigation: Status resolved → EmergencyCompletedScreen');
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
    debugPrint('[FindingHelpScreen] ✅ Navigation: Status cancelled → HomeScreen');
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
      debugPrint('[FindingHelpScreen] Cancelling emergency: ${widget.emergencyId}');

      // Cancel the stream subscription
      await _emergencySubscription?.cancel();
      _emergencySubscription = null;

      // Update emergency to cancelled status
      await _firestore
          .collection('emergencies')
          .doc(widget.emergencyId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FindingHelpScreen] Emergency cancelled successfully');

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
      debugPrint('[FindingHelpScreen] Error cancelling emergency: $e');

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
                  'Searching for volunteers...',
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

            const SizedBox(height: 20),

            // Radar pulsing section
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Text(
                        'Finding Help...',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1C1E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Searching for verified volunteers\nnear your location.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF74777F),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Pulsing radar animation
                      SizedBox(
                        height: 260,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const RadarPulse(
                              child: CenterSOSCenterDot(),
                            ),
                            // Positioned nearby volunteer avatars on the rings
                            _buildRadarAvatar(top: 40, left: 80),
                            _buildRadarAvatar(top: 80, right: 40),
                            _buildRadarAvatar(bottom: 60, left: 30),
                            _buildRadarAvatar(bottom: 80, right: 60),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Progress Card
                      Container(
                        width: double.infinity,
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
                            _buildChecklistItem(
                              label: 'Location Acquired',
                              isCompleted: _userLocation != null,
                              isActive: false,
                            ),
                            const SizedBox(height: 16),
                            _buildChecklistItem(
                              label: 'Alert Sent',
                              isCompleted: true,
                              isActive: false,
                            ),
                            const SizedBox(height: 16),
                            _buildChecklistItem(
                              label: 'Searching for Volunteers',
                              subtext: (_status == 'waiting' || _status == 'reported') ? 'This may take a few seconds...' : null,
                              isCompleted: (_status != 'waiting' && _status != 'reported'),
                              isActive: (_status == 'waiting' || _status == 'reported'),
                            ),
                            const SizedBox(height: 16),
                            _buildChecklistItem(
                              label: 'Waiting for Response',
                              subtext: 'Please stay calm',
                              isCompleted: false,
                              isActive: (_status == 'waiting' || _status == 'reported'),
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Map card and Cancel SOS button combined
                      Container(
                        width: double.infinity,
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
                            // Top portion: Map
                            SizedBox(
                              height: 160,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                child: CustomMiniMap(userLocation: _userLocation),
                              ),
                            ),
                            // Bottom portion: Cancel SOS button
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: ElevatedButton(
                                onPressed: _isCancelling ? null : _cancelEmergency,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFF0F0),
                                  foregroundColor: const Color(0xFFE31E24),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
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

  Widget _buildRadarAvatar({double? top, double? left, double? right, double? bottom}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFE31E24),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.person,
            color: Color(0xFFE31E24),
            size: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem({
    required String label,
    String? subtext,
    required bool isCompleted,
    required bool isActive,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator
        if (isCompleted)
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF2E7D32),
            size: 24,
          )
        else if (isActive)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
            ),
          )
        else
          Icon(
            isLast ? Icons.access_time : Icons.radio_button_unchecked,
            color: const Color(0xFF9E9E9E),
            size: 24,
          ),
        const SizedBox(width: 16),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: (isActive || isCompleted) ? FontWeight.w600 : FontWeight.normal,
                  color: (isActive || isCompleted) ? const Color(0xFF1A1C1E) : const Color(0xFF74777F),
                ),
              ),
              if (subtext != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtext,
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

// Custom pulsing radar component
class RadarPulse extends StatefulWidget {
  final Widget child;
  const RadarPulse({super.key, required this.child});

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Three waves
            _buildWave(0.0),
            _buildWave(0.33),
            _buildWave(0.66),
            widget.child,
          ],
        );
      },
    );
  }

  Widget _buildWave(double delay) {
    double value = (_controller.value + delay) % 1.0;
    double size = 110 + (120 * value);
    double opacity = (1.0 - value).clamp(0.0, 1.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE31E24).withValues(alpha: opacity * 0.1),
        border: Border.all(
          color: const Color(0xFFE31E24).withValues(alpha: opacity * 0.2),
          width: 1.0,
        ),
      ),
    );
  }
}

// Center SOS button icon in radar screen
class CenterSOSCenterDot extends StatelessWidget {
  const CenterSOSCenterDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: const BoxDecoration(
        color: Color(0xFFE31E24),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x33E31E24),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone,
            color: Colors.white,
            size: 32,
          ),
          SizedBox(height: 6),
          Text(
            'SOS',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            'Tap for Help',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for drawing street grids on mini maps
class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;

    final roadBorderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13.0;

    // A pattern of streets
    List<Path> paths = [];

    paths.add(Path()
      ..moveTo(0, size.height * 0.35)
      ..lineTo(size.width, size.height * 0.45));

    paths.add(Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.35, size.height));

    paths.add(Path()
      ..moveTo(0, size.height * 0.8)
      ..lineTo(size.width, size.height * 0.7));

    paths.add(Path()
      ..moveTo(size.width * 0.7, 0)
      ..lineTo(size.width * 0.6, size.height));

    // Curved connector
    paths.add(Path()
      ..moveTo(size.width * 0.3, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.5, size.width * 0.65, size.height * 0.75));

    for (var path in paths) {
      canvas.drawPath(path, roadBorderPaint);
      canvas.drawPath(path, roadPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Custom mini map representation
class CustomMiniMap extends StatelessWidget {
  final latlong2.LatLng? userLocation;

  const CustomMiniMap({
    super.key,
    this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F3F5),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: MapPainter(),
          ),
          // Pulsing user location dot at center
          const Center(
            child: PulsingLocationDot(),
          ),
        ],
      ),
    );
  }
}

// Pulsing location dot widget
class PulsingLocationDot extends StatefulWidget {
  const PulsingLocationDot({super.key});

  @override
  State<PulsingLocationDot> createState() => _PulsingLocationDotState();
}

class _PulsingLocationDotState extends State<PulsingLocationDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 3.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 0.0).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            ),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x660066CC),
              ),
            ),
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0066CC),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}