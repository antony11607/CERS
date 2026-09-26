import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user has an active emergency
  Future<bool> hasActiveEmergency(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Checking for active emergency for user: $userId');
      }

      // Check for emergencies with status: waiting, accepted, en_route, or reported
      QuerySnapshot snapshot = await _firestore
          .collection('emergencies')
          .where('victimId', isEqualTo: userId)
          .where('status', whereIn: ['waiting', 'reported', 'accepted', 'en_route'])
          .limit(1)
          .get();

      bool hasActive = snapshot.docs.isNotEmpty;
      if (kDebugMode) {
        debugPrint('[EmergencyService] Active emergency found: $hasActive');
      }
      
      return hasActive;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Error checking active emergency: $e');
      }
      return false;
    }
  }

  /// Create a new emergency directly in Firestore
  Future<String?> createEmergency({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Creating emergency for user: $userId');
        debugPrint('[EmergencyService] Location - Lat: $latitude, Lng: $longitude');
      }

      // Verify user is authenticated
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('[EmergencyService] User not authenticated');
        }
        return null;
      }

      // Verify user ID matches
      if (currentUser.uid != userId) {
        if (kDebugMode) {
          debugPrint('[EmergencyService] User ID mismatch');
        }
        return null;
      }

      // Create emergency directly in Firestore
      if (kDebugMode) {
        debugPrint('[Firestore] Creating emergency document in emergencies collection');
      }
      
      DocumentReference emergencyRef = await _firestore
          .collection('emergencies')
          .add({
        'victimId': userId,
        'victimLatitude': latitude,
        'victimLongitude': longitude,
        'status': 'waiting',
        'assignedVolunteerId': null,
        'assignedVolunteerName': null,
        'assignedVolunteerPhone': null,
        'acceptedAt': null,
        'arrivedAt': null,
        'resolvedAt': null,
        'cancelledAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      String emergencyId = emergencyRef.id;
      
      if (kDebugMode) {
        debugPrint('[EmergencyService] Emergency created with ID: $emergencyId');
        debugPrint('[Firestore] Document created successfully: $emergencyId');
      }
      
      return emergencyId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Error creating emergency: $e');
      }
      return null;
    }
  }

  /// Create emergency with location from LocationService
  Future<String?> createEmergencyWithLocation(Position position) async {
    try {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Creating emergency with location');
      }
      return await createEmergency(
        userId: _auth.currentUser?.uid ?? '',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Error creating emergency with location: $e');
      }
      return null;
    }
  }

  /// Create a report incident in the existing emergencies collection
  Future<String?> createReportIncident({
    required String userId,
    required String userName,
    required double latitude,
    required double longitude,
    required String address,
    required String incidentType,
    required String description,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[ReportIncident] ==========================================');
        debugPrint('[ReportIncident] Creating report incident');
        debugPrint('[ReportIncident] User ID: $userId');
        debugPrint('[ReportIncident] User Name: $userName');
        debugPrint('[ReportIncident] Incident Type: $incidentType');
        debugPrint('[ReportIncident] Location - Lat: $latitude, Lng: $longitude');
        debugPrint('[ReportIncident] Address: $address');
        debugPrint('[ReportIncident] Description: $description');
        debugPrint('[ReportIncident] ==========================================');
      }

      // Verify user is authenticated
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('[ReportIncident] ❌ User not authenticated');
        }
        return null;
      }

      // Verify user ID matches
      if (currentUser.uid != userId) {
        if (kDebugMode) {
          debugPrint('[ReportIncident] ❌ User ID mismatch');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('[ReportIncident] 🔥 Creating document in emergencies collection');
      }

      // Create document using the existing emergency structure
      // Reuses victimId/victimLatitude/victimLongitude for compatibility
      DocumentReference emergencyRef = await _firestore
          .collection('emergencies')
          .add({
        // Reused existing fields
        'victimId': userId,
        'victimLatitude': latitude,
        'victimLongitude': longitude,
        'status': 'reported',
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': null,
        'arrivedAt': null,
        'resolvedAt': null,
        'cancelledAt': null,
        'assignedVolunteerId': null,
        'assignedVolunteerName': null,
        'assignedVolunteerPhone': null,

        // New fields specific to report incidents
        'source': 'report',
        'incidentType': incidentType,
        'description': description,
        'reporterId': userId,
        'reporterName': userName,
        'address': address,
      });

      String emergencyId = emergencyRef.id;

      if (kDebugMode) {
        debugPrint('[ReportIncident] ✅ Report incident created successfully');
        debugPrint('[ReportIncident] 🔥 Firestore Document ID: $emergencyId');
        debugPrint('[ReportIncident] 📋 Incident Type: $incidentType');
        debugPrint('[ReportIncident] 📍 Location: ($latitude, $longitude)');
        debugPrint('[ReportIncident] 🏠 Address: $address');
        debugPrint('[ReportIncident] ==========================================');
      }

      return emergencyId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReportIncident] ❌ Error creating report incident: $e');
        debugPrint('[ReportIncident] ==========================================');
      }
      return null;
    }
  }

  /// Get emergency by ID
  Future<DocumentSnapshot?> getEmergency(String emergencyId) async {
    try {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Getting emergency: $emergencyId');
      }
      DocumentSnapshot doc = await _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .get();

      if (doc.exists) {
        if (kDebugMode) {
          debugPrint('[EmergencyService] Emergency found');
        }
        return doc;
      } else {
        if (kDebugMode) {
          debugPrint('[EmergencyService] Emergency not found');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Error getting emergency: $e');
      }
      return null;
    }
  }

  /// Update emergency status directly in Firestore
  Future<bool> updateEmergencyStatus({
    required String emergencyId,
    required String status,
    String? assignedVolunteerId,
    String? assignedVolunteerName,
    String? assignedVolunteerPhone,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Updating emergency $emergencyId to status: $status');
      }

      // Verify user is authenticated
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('[EmergencyService] User not authenticated');
        }
        return false;
      }

      // Prepare update data
      Map<String, dynamic> updates = {
        'status': status,
      };

      // Add volunteer info if provided
      if (assignedVolunteerId != null) {
        updates['assignedVolunteerId'] = assignedVolunteerId;
      }
      if (assignedVolunteerName != null) {
        updates['assignedVolunteerName'] = assignedVolunteerName;
      }
      if (assignedVolunteerPhone != null) {
        updates['assignedVolunteerPhone'] = assignedVolunteerPhone;
      }

      // Add timestamp fields based on status
      if (status == 'accepted') {
        updates['acceptedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'arrived') {
        updates['arrivedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'resolved') {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }

      // Update emergency directly in Firestore
      if (kDebugMode) {
        debugPrint('[Firestore] Updating emergency document: $emergencyId');
      }
      
      await _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .update(updates);

      if (kDebugMode) {
        debugPrint('[EmergencyService] Emergency status updated successfully');
        debugPrint('[Firestore] Document updated: $emergencyId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Error updating emergency: $e');
      }
      return false;
    }
  }

  /// Cancel emergency directly in Firestore
  Future<bool> cancelEmergency(String emergencyId) async {
    try {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Canceling emergency: $emergencyId');
      }

      // Verify user is authenticated
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('[EmergencyService] User not authenticated');
        }
        return false;
      }

      // Get emergency document first to check status
      DocumentSnapshot emergencyDoc = await _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .get();

      if (!emergencyDoc.exists) {
        if (kDebugMode) {
          debugPrint('[EmergencyService] Emergency not found');
        }
        return false;
      }

      Map<String, dynamic> data = emergencyDoc.data() as Map<String, dynamic>;
      String currentStatus = data['status'] ?? '';

      // Only allow cancellation if status is 'waiting' or 'reported'
      if (currentStatus != 'waiting' && currentStatus != 'reported') {
        if (kDebugMode) {
          debugPrint('[EmergencyService] Cannot cancel emergency with status: $currentStatus');
        }
        return false;
      }

      // Update emergency to cancelled status
      if (kDebugMode) {
        debugPrint('[Firestore] Updating emergency status to cancelled');
      }
      
      await _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('[EmergencyService] Emergency cancelled successfully');
        debugPrint('[Firestore] Document updated: $emergencyId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Error canceling emergency: $e');
      }
      return false;
    }
  }

  /// Stream to listen to emergency updates
  Stream<DocumentSnapshot>? getEmergencyStream(String emergencyId) {
    try {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Creating emergency stream: $emergencyId');
      }
      return _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .snapshots();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Error creating emergency stream: $e');
      }
      return null;
    }
  }

  /// Stream to listen to nearby emergencies (for volunteers)
  /// Includes both SOS (waiting) and Report Incident (reported) emergencies
  Stream<QuerySnapshot>? getNearbyEmergenciesStream(double latitude, double longitude, double radiusInMeters) {
    try {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Creating nearby emergencies stream');
        debugPrint('[EmergencyService] Location - Lat: $latitude, Lng: $longitude, Radius: $radiusInMeters m');
      }

      // Get all waiting and reported emergencies
      // Both SOS (waiting) and Report Incident (reported) emergencies appear here
      return _firestore
          .collection('emergencies')
          .where('status', whereIn: ['waiting', 'reported'])
          .snapshots();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Error creating nearby emergencies stream: $e');
      }
      return null;
    }
  }

  /// Accept emergency directly in Firestore (for volunteers)
  Future<bool> acceptEmergencyDirectly({
    required String emergencyId,
    required String volunteerId,
    required String volunteerName,
    required String volunteerPhone,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[EmergencyService] Accepting emergency directly: $emergencyId');
        debugPrint('[EmergencyService] Volunteer ID: $volunteerId, Name: $volunteerName');
      }

      // Get emergency document
      DocumentSnapshot emergencyDoc = await _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .get();

      if (!emergencyDoc.exists) {
        if (kDebugMode) {
          debugPrint('[EmergencyService] Emergency not found');
        }
        return false;
      }

      Map<String, dynamic> emergencyData = emergencyDoc.data() as Map<String, dynamic>;
      
      // Check if emergency is still waiting or reported
      String currentStatus = emergencyData['status'] ?? '';
      if (currentStatus != 'waiting' && currentStatus != 'reported') {
        if (kDebugMode) {
          debugPrint('[EmergencyService] Emergency status is not actionable: $currentStatus');
          debugPrint('[EmergencyService] Only "waiting" or "reported" emergencies can be accepted');
        }
        return false;
      }

      // Get volunteer document
      DocumentSnapshot volunteerDoc = await _firestore
          .collection('volunteers')
          .doc(volunteerId)
          .get();

      if (!volunteerDoc.exists) {
        if (kDebugMode) {
          debugPrint('[EmergencyService] Volunteer not found');
        }
        return false;
      }

      Map<String, dynamic> volunteerData = volunteerDoc.data() as Map<String, dynamic>;
      bool isApproved = volunteerData['isApproved'] ?? false;

      if (!isApproved) {
        if (kDebugMode) {
          debugPrint('[EmergencyService] Volunteer is not approved');
        }
        return false;
      }

      // Use transaction to ensure atomic update
      if (kDebugMode) {
        debugPrint('[Firestore] Starting transaction to accept emergency');
      }
      
      await _firestore.runTransaction((transaction) async {
        // Read documents again within transaction
        DocumentSnapshot emergencySnapshot = await transaction.get(_firestore.collection('emergencies').doc(emergencyId));
        DocumentSnapshot volunteerSnapshot = await transaction.get(_firestore.collection('volunteers').doc(volunteerId));

        // Check if emergency is still waiting or reported
        Map<String, dynamic> emergencyInTransaction = emergencySnapshot.data() as Map<String, dynamic>;
        String txStatus = emergencyInTransaction['status'] ?? '';
        if (txStatus != 'waiting' && txStatus != 'reported') {
          if (kDebugMode) {
            debugPrint('[EmergencyService] Emergency status changed during transaction: $txStatus');
            debugPrint('[EmergencyService] Only "waiting" or "reported" emergencies can be accepted');
          }
          throw Exception('ALREADY_ACCEPTED');
        }

        // Update emergency document
        if (kDebugMode) {
          debugPrint('[Firestore] Updating emergency with volunteer details');
        }
        
        transaction.update(_firestore.collection('emergencies').doc(emergencyId), {
          'status': 'accepted',
          'assignedVolunteerId': volunteerId,
          'assignedVolunteerName': volunteerName,
          'assignedVolunteerPhone': volunteerPhone,
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // Update volunteer availability
        if (kDebugMode) {
          debugPrint('[Firestore] Updating volunteer availability');
        }
        
        transaction.update(_firestore.collection('volunteers').doc(volunteerId), {
          'isAvailable': false,
        });

        if (kDebugMode) {
          debugPrint('[Firestore] Transaction completed successfully');
        }
      });

      if (kDebugMode) {
        debugPrint('[EmergencyService] ✅ Volunteer acceptance successful');
        debugPrint('[EmergencyService] Volunteer ID: $volunteerId');
        debugPrint('[EmergencyService] Emergency ID: $emergencyId');
        debugPrint('[EmergencyService] Status change: ${emergencyData['status']} → accepted');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EmergencyService] ❌ Error in volunteer acceptance: $e');
        debugPrint('[EmergencyService] Emergency ID: $emergencyId');
        debugPrint('[EmergencyService] Volunteer ID: $volunteerId');
      }
      return false;
    }
  }
}