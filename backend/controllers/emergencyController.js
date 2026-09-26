const admin = require('firebase-admin');

/**
 * Create a new emergency
 * POST /api/emergencies
 */
exports.createEmergency = async (req, res) => {
  try {
    const { latitude, longitude } = req.body;
    const userId = req.user.uid;

    console.log(`[EmergencyController] Creating emergency for user: ${userId}`);
    console.log(`[EmergencyController] Location - Lat: ${latitude}, Lng: ${longitude}`);

    // Verify user is authenticated
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User not authenticated',
      });
    }

    // Create emergency document
    const emergencyRef = await admin.firestore().collection('emergencies').add({
      victimId: userId,
      victimLatitude: latitude,
      victimLongitude: longitude,
      status: 'waiting',
      assignedVolunteerId: null,
      assignedVolunteerName: null,
      assignedVolunteerPhone: null,
      acceptedAt: null,
      arrivedAt: null,
      resolvedAt: null,
      cancelledAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[EmergencyController] Emergency created with ID: ${emergencyRef.id}`);
    console.log(`[Firestore] Document created in emergencies collection: ${emergencyRef.id}`);

    res.status(201).json({
      success: true,
      message: 'Emergency created successfully',
      data: {
        emergencyId: emergencyRef.id,
      },
    });
  } catch (error) {
    console.error('[EmergencyController] Error creating emergency:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to create emergency',
      error: error.message,
    });
  }
};

/**
 * Accept an emergency
 * POST /api/emergencies/accept
 */
exports.acceptEmergency = async (req, res) => {
  try {
    const { emergencyId, volunteerId, volunteerName, volunteerPhone } = req.body;

    console.log(`[EmergencyController] Accepting emergency: ${emergencyId}`);
    console.log(`[EmergencyController] Volunteer ID: ${volunteerId}`);
    console.log(`[EmergencyController] Volunteer Name: ${volunteerName}`);

    // Step 1: Verify volunteer exists and is approved
    console.log('[EmergencyController] Step 1: Checking volunteer document...');
    const volunteerDoc = await admin.firestore().collection('volunteers').doc(volunteerId).get();
    
    if (!volunteerDoc.exists) {
      console.log('[EmergencyController] ERROR: Volunteer document does not exist');
      return res.status(404).json({
        success: false,
        message: 'Volunteer profile not found. Please contact support.',
      });
    }

    const volunteerData = volunteerDoc.data();
    const isApproved = volunteerData.isApproved ?? false;
    
    console.log(`[EmergencyController] Volunteer exists. isApproved: ${isApproved}`);

    if (!isApproved) {
      console.log('[EmergencyController] ERROR: Volunteer is not approved');
      return res.status(403).json({
        success: false,
        message: 'Your volunteer account is not approved yet.',
      });
    }

    // Step 2: Check emergency exists and is waiting
    console.log('[EmergencyController] Step 2: Checking emergency document...');
    const emergencyRef = admin.firestore().collection('emergencies').doc(emergencyId);
    const emergencySnapshot = await emergencyRef.get();
    
    if (!emergencySnapshot.exists) {
      console.log('[EmergencyController] ERROR: Emergency document does not exist');
      return res.status(404).json({
        success: false,
        message: 'Emergency not found.',
      });
    }

    const emergencyData = emergencySnapshot.data();
    const currentStatus = emergencyData.status ?? 'unknown';
    
    console.log(`[EmergencyController] Emergency exists. Current status: ${currentStatus}`);

    if (currentStatus !== 'waiting') {
      console.log('[EmergencyController] ERROR: Emergency is not in waiting status');
      return res.status(409).json({
        success: false,
        message: 'This emergency has already been accepted by another volunteer.',
      });
    }

    // Step 3: Use transaction to ensure atomic update
    console.log('[EmergencyController] Step 3: Starting transaction...');
    const volunteerRef = admin.firestore().collection('volunteers').doc(volunteerId);

    await admin.firestore().runTransaction(async (transaction) => {
      // Read emergency document again within transaction
      const emergencySnapshotInTransaction = await transaction.get(emergencyRef);
      
      if (!emergencySnapshotInTransaction.exists) {
        throw new Error('Emergency not found in transaction');
      }

      const emergencyDataInTransaction = emergencySnapshotInTransaction.data();
      
      // Check if emergency is still waiting
      if (emergencyDataInTransaction.status !== 'waiting') {
        console.log(`[EmergencyController] ERROR: Emergency status changed during transaction: ${emergencyDataInTransaction.status}`);
        throw new Error('ALREADY_ACCEPTED');
      }

      // Update emergency document with volunteer details
      console.log('[EmergencyController] Updating emergency document with volunteer details...');
      transaction.update(emergencyRef, {
        status: 'accepted',
        assignedVolunteerId: volunteerId,
        assignedVolunteerName: volunteerName,
        assignedVolunteerPhone: volunteerPhone,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update volunteer availability
      console.log('[EmergencyController] Updating volunteer availability...');
      transaction.update(volunteerRef, {
        isAvailable: false,
      });
      
      console.log('[EmergencyController] Transaction completed successfully');
    });

    console.log('[EmergencyController] =========================================');
    console.log('[EmergencyController] Emergency accepted successfully!');
    console.log('[EmergencyController] =========================================');
    
    res.status(200).json({
      success: true,
      message: 'Emergency accepted successfully',
    });
  } catch (error) {
    console.error('[EmergencyController] Error accepting emergency:', error.message);
    
    let errorMessage = 'Failed to accept emergency. Please try again.';
    if (error.message === 'ALREADY_ACCEPTED') {
      errorMessage = 'This emergency has already been accepted by another volunteer.';
    }

    res.status(500).json({
      success: false,
      message: errorMessage,
    });
  }
};

/**
 * Cancel an emergency
 * POST /api/emergencies/cancel
 */
exports.cancelEmergency = async (req, res) => {
  try {
    const { emergencyId } = req.body;
    const userId = req.user.uid;

    console.log(`[EmergencyController] Cancelling emergency: ${emergencyId}`);

    // Get emergency document
    const emergencyRef = admin.firestore().collection('emergencies').doc(emergencyId);
    const emergencyDoc = await emergencyRef.get();

    if (!emergencyDoc.exists) {
      console.log('[EmergencyController] Emergency not found');
      return res.status(404).json({
        success: false,
        message: 'Emergency not found.',
      });
    }

    const emergencyData = emergencyDoc.data();
    const currentStatus = emergencyData.status ?? '';

    // Only allow cancellation if status is 'waiting'
    if (currentStatus !== 'waiting') {
      console.log(`[EmergencyController] Cannot cancel emergency with status: ${currentStatus}`);
      return res.status(400).json({
        success: false,
        message: `Cannot cancel emergency with status: ${currentStatus}. Only waiting emergencies can be cancelled.`,
      });
    }

    // Update emergency to cancelled status
    await emergencyRef.update({
      status: 'cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('[Firestore] Emergency status updated to cancelled');
    console.log('[EmergencyController] Emergency cancelled successfully');

    res.status(200).json({
      success: true,
      message: 'Emergency cancelled successfully',
    });
  } catch (error) {
    console.error('[EmergencyController] Error cancelling emergency:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to cancel emergency',
      error: error.message,
    });
  }
};

/**
 * Update emergency status
 * POST /api/emergencies/status
 */
exports.updateEmergencyStatus = async (req, res) => {
  try {
    const { emergencyId, status } = req.body;

    console.log(`[EmergencyController] Updating emergency ${emergencyId} to status: ${status}`);

    const emergencyRef = admin.firestore().collection('emergencies').doc(emergencyId);
    const emergencyDoc = await emergencyRef.get();

    if (!emergencyDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Emergency not found.',
      });
    }

    const updates = {
      status: status,
    };

    // Add timestamp fields based on status
    if (status === 'accepted') {
      updates.acceptedAt = admin.firestore.FieldValue.serverTimestamp();
    } else if (status === 'arrived') {
      updates.arrivedAt = admin.firestore.FieldValue.serverTimestamp();
    } else if (status === 'resolved') {
      updates.resolvedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await emergencyRef.update(updates);

    console.log('[Firestore] Emergency status updated successfully');
    console.log(`[EmergencyController] Emergency ${emergencyId} status updated to ${status}`);

    res.status(200).json({
      success: true,
      message: 'Emergency status updated successfully',
    });
  } catch (error) {
    console.error('[EmergencyController] Error updating emergency status:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to update emergency status',
      error: error.message,
    });
  }
};

/**
 * Get nearby emergencies
 * GET /api/emergencies/nearby
 */
exports.getNearbyEmergencies = async (req, res) => {
  try {
    const { latitude, longitude, radius = 1000 } = req.query;
    const userId = req.user?.uid;

    console.log(`[EmergencyController] Fetching nearby emergencies for user: ${userId}`);
    console.log(`[EmergencyController] Location - Lat: ${latitude}, Lng: ${longitude}, Radius: ${radius}m`);

    // Get all waiting emergencies
    const snapshot = await admin.firestore()
      .collection('emergencies')
      .where('status', '==', 'waiting')
      .get();

    const nearbyEmergencies = [];
    const volunteerLat = parseFloat(latitude);
    const volunteerLng = parseFloat(longitude);
    const radiusMeters = parseFloat(radius);

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const victimLat = data.victimLatitude;
      const victimLng = data.victimLongitude;

      // Calculate distance using Haversine formula
      const distance = calculateDistance(volunteerLat, volunteerLng, victimLat, victimLng);

      // Only include if within radius
      if (distance <= radiusMeters) {
        console.log(`[EmergencyController] Emergency ${doc.id} is ${distance.toFixed(2)}m away - INCLUDED`);
        nearbyEmergencies.push({
          emergencyId: doc.id,
          victimId: data.victimId,
          victimLatitude: victimLat,
          victimLongitude: victimLng,
          distance: distance,
          createdAt: data.createdAt,
          status: data.status,
        });
      } else {
        console.log(`[EmergencyController] Emergency ${doc.id} is ${distance.toFixed(2)}m away - EXCLUDED`);
      }
    }

    // Sort by distance (nearest first)
    nearbyEmergencies.sort((a, b) => a.distance - b.distance);

    console.log(`[EmergencyController] Found ${nearbyEmergencies.length} nearby emergencies`);

    res.status(200).json({
      success: true,
      data: nearbyEmergencies,
    });
  } catch (error) {
    console.error('[EmergencyController] Error fetching nearby emergencies:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch nearby emergencies',
      error: error.message,
    });
  }
};

/**
 * Helper function to calculate distance between two coordinates (Haversine formula)
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}