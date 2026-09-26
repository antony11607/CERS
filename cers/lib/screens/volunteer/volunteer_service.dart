import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../../emergency_service.dart';

class VolunteerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EmergencyService _emergencyService = EmergencyService();

  /// Creates a volunteer approval application in Firestore
  /// Returns true if successful, false otherwise
  Future<bool> createVolunteerApplication({
    required String name,
    required String email,
    required String phone,
    required String documentType,
    required String documentNumber,
    required String documentUrl,
  }) async {
    try {
      // Get current user
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      String uid = currentUser.uid;

      // Create document in volunteer_approval collection
      await _firestore.collection('volunteer_approval').doc(uid).set({
        'uid': uid,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'documentType': documentType,
        'documentNumber': documentNumber.trim(),
        'documentUrl': documentUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } on FirebaseException catch (e) {
      throw Exception('Firestore error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create application: $e');
    }
  }

  /// Checks if a volunteer application exists for the current user
  Future<bool> hasPendingApplication() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      DocumentSnapshot doc = await _firestore
          .collection('volunteer_approval')
          .doc(currentUser.uid)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Gets the status of the current user's volunteer application
  Future<String?> getApplicationStatus() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      DocumentSnapshot doc = await _firestore
          .collection('volunteer_approval')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['status'] as String?;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update volunteer location in Firestore
  Future<bool> updateVolunteerLocation({
    required String volunteerId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Updating location for volunteer: $volunteerId');
      }
      
      await _firestore.collection('volunteers').doc(volunteerId).update({
        'latitude': latitude,
        'longitude': longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'isOnline': true,
      });

      if (kDebugMode) {
        debugPrint('[VolunteerService] Location updated successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Error updating location: $e');
      }
      return false;
    }
  }

  /// Set volunteer online status
  Future<bool> setVolunteerOnlineStatus(String volunteerId, bool isOnline) async {
    try {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Setting online status: $isOnline for volunteer: $volunteerId');
      }
      
      await _firestore.collection('volunteers').doc(volunteerId).update({
        'isOnline': isOnline,
      });

      if (kDebugMode) {
        debugPrint('[VolunteerService] Online status updated');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Error updating online status: $e');
      }
      return false;
    }
  }

  /// Calculate distance between two coordinates in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    try {
      double distance = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
      if (kDebugMode) {
        debugPrint('[VolunteerService] Distance calculated: ${distance.toStringAsFixed(2)}m');
      }
      return distance;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Error calculating distance: $e');
      }
      return double.infinity;
    }
  }

  /// Get nearby emergencies within specified radius (default 1000 meters)
  /// Includes both SOS (waiting) and Report Incident (reported) emergencies
  Future<List<Map<String, dynamic>>> getNearbyEmergencies({
    required double volunteerLatitude,
    required double volunteerLongitude,
    double radiusInMeters = 1000.0,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Fetching nearby emergencies within ${radiusInMeters}m');
      }

      // Get all waiting AND reported emergencies
      QuerySnapshot snapshot = await _firestore
          .collection('emergencies')
          .where('status', whereIn: ['waiting', 'reported'])
          .get();

      List<Map<String, dynamic>> nearbyEmergencies = [];

      for (DocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        double victimLat = data['victimLatitude'] as double;
        double victimLng = data['victimLongitude'] as double;

        // Calculate distance
        double distance = calculateDistance(
          volunteerLatitude,
          volunteerLongitude,
          victimLat,
          victimLng,
        );

        // Only include if within radius
        if (distance <= radiusInMeters) {
          if (kDebugMode) {
            debugPrint('[VolunteerService] Emergency ${doc.id} is ${distance.toStringAsFixed(2)}m away - INCLUDED');
          }
          
          nearbyEmergencies.add({
            'emergencyId': doc.id,
            'victimId': data['victimId'],
            'victimLatitude': victimLat,
            'victimLongitude': victimLng,
            'distance': distance,
            'createdAt': data['createdAt'],
            'status': data['status'],
            'source': data['source'], // 'report' for reported incidents
            'incidentType': data['incidentType'], // Only for reported incidents
            'address': data['address'], // Only for reported incidents
          });
        } else {
          if (kDebugMode) {
            debugPrint('[VolunteerService] Emergency ${doc.id} is ${distance.toStringAsFixed(2)}m away - EXCLUDED');
          }
        }
      }

      // Sort by distance (nearest first)
      nearbyEmergencies.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      if (kDebugMode) {
        debugPrint('[VolunteerService] Found ${nearbyEmergencies.length} nearby emergencies');
      }
      return nearbyEmergencies;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Error fetching nearby emergencies: $e');
      }
      return [];
    }
  }

  /// Stream to listen for waiting/reported emergencies in real-time
  /// Includes both SOS (waiting) and Report Incident (reported) emergencies
  Stream<List<Map<String, dynamic>>>? getEmergenciesStream({
    required double volunteerLatitude,
    required double volunteerLongitude,
    double radiusInMeters = 1000.0,
  }) {
    try {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Creating emergencies stream (waiting + reported)');
      }
      
      return _firestore
          .collection('emergencies')
          .where('status', whereIn: ['waiting', 'reported'])
          .snapshots()
          .map((snapshot) {
            List<Map<String, dynamic>> nearbyEmergencies = [];

            for (DocumentSnapshot doc in snapshot.docs) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              
              double victimLat = data['victimLatitude'] as double;
              double victimLng = data['victimLongitude'] as double;

              // Calculate distance
              double distance = calculateDistance(
                volunteerLatitude,
                volunteerLongitude,
                victimLat,
                victimLng,
              );

              // Only include if within radius
              if (distance <= radiusInMeters) {
                nearbyEmergencies.add({
                  'emergencyId': doc.id,
                  'victimId': data['victimId'],
                  'victimLatitude': victimLat,
                  'victimLongitude': victimLng,
                  'distance': distance,
                  'createdAt': data['createdAt'],
                  'status': data['status'],
                  'source': data['source'], // 'report' for reported incidents
                  'incidentType': data['incidentType'], // Only for reported incidents
                  'address': data['address'], // Only for reported incidents
                });
              }
            }

            // Sort by distance (nearest first)
            nearbyEmergencies.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

            if (kDebugMode) {
              debugPrint('[VolunteerService] Stream update: ${nearbyEmergencies.length} nearby emergencies');
            }
            return nearbyEmergencies;
          });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Error creating emergencies stream: $e');
      }
      return null;
    }
  }

  /// Accept an emergency directly in Firestore
  Future<Map<String, dynamic>> acceptEmergencyWithTransaction({
    required String emergencyId,
    required String volunteerId,
    required String volunteerName,
    required String volunteerPhone,
  }) async {
    if (kDebugMode) {
      debugPrint('[VolunteerService] =========================================');
      debugPrint('[VolunteerService] Accepting emergency: $emergencyId');
      debugPrint('[VolunteerService] Volunteer ID: $volunteerId');
      debugPrint('[VolunteerService] Volunteer Name: $volunteerName');
      debugPrint('[VolunteerService] =========================================');
    }

    try {
      // Accept emergency directly in Firestore
      bool success = await _emergencyService.acceptEmergencyDirectly(
        emergencyId: emergencyId,
        volunteerId: volunteerId,
        volunteerName: volunteerName,
        volunteerPhone: volunteerPhone,
      );

      if (kDebugMode) {
        debugPrint('[VolunteerService] =========================================');
        debugPrint('[VolunteerService] ✅ Accept emergency result: $success');
        debugPrint('[VolunteerService] =========================================');
      }

      if (success) {
        return {
          'success': true,
          'message': 'Emergency accepted successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to accept emergency. Please try again.',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VolunteerService] =========================================');
        debugPrint('[VolunteerService] ❌ Error accepting emergency:');
        debugPrint('[VolunteerService] Error: $e');
        debugPrint('[VolunteerService] Type: ${e.runtimeType}');
        debugPrint('[VolunteerService] =========================================');
      }
      
      return {
        'success': false,
        'message': 'Failed to accept emergency. Please try again.',
      };
    }
  }

  /// Get emergency details by ID
  Future<Map<String, dynamic>?> getEmergencyDetails(String emergencyId) async {
    try {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Getting emergency details: $emergencyId');
      }
      
      DocumentSnapshot doc = await _firestore.collection('emergencies').doc(emergencyId).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['emergencyId'] = doc.id;
        
        if (kDebugMode) {
          debugPrint('[VolunteerService] Emergency details retrieved');
        }
        return data;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Error getting emergency details: $e');
      }
      return null;
    }
  }

  /// Update emergency status (for en_route, arrived, resolved)
  Future<bool> updateEmergencyStatus({
    required String emergencyId,
    required String status,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Updating emergency status: $emergencyId to $status');
      }
      
      Map<String, dynamic> updates = {
        'status': status,
      };

      if (status == 'arrived') {
        updates['arrivedAt'] = FieldValue.serverTimestamp();
      } else if (status == 'resolved') {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('emergencies').doc(emergencyId).update(updates);

      if (kDebugMode) {
        debugPrint('[VolunteerService] Emergency status updated successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Error updating emergency status: $e');
      }
      return false;
    }
  }

  /// Get stream for a specific emergency
  Stream<DocumentSnapshot>? getEmergencyStream(String emergencyId) {
    try {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Creating emergency stream: $emergencyId');
      }
      
      return _firestore
          .collection('emergencies')
          .doc(emergencyId)
          .snapshots();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VolunteerService] Error creating emergency stream: $e');
      }
      return null;
    }
  }
}