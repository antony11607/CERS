const admin = require('firebase-admin');

/**
 * Update volunteer location
 * POST /api/volunteers/location
 */
exports.updateVolunteerLocation = async (req, res) => {
  try {
    const { volunteerId, latitude, longitude } = req.body;

    console.log(`[VolunteerController] Updating location for volunteer: ${volunteerId}`);
    console.log(`[VolunteerController] Location - Lat: ${latitude}, Lng: ${longitude}`);

    // Update volunteer document
    const volunteerRef = admin.firestore().collection('volunteers').doc(volunteerId);
    const volunteerDoc = await volunteerRef.get();

    if (!volunteerDoc.exists) {
      console.log('[VolunteerController] Volunteer document does not exist');
      return res.status(404).json({
        success: false,
        message: 'Volunteer profile not found.',
      });
    }

    await volunteerRef.update({
      latitude: latitude,
      longitude: longitude,
      locationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isOnline: true,
    });

    console.log('[Firestore] Volunteer location updated successfully');

    res.status(200).json({
      success: true,
      message: 'Volunteer location updated successfully',
    });
  } catch (error) {
    console.error('[VolunteerController] Error updating volunteer location:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to update volunteer location',
      error: error.message,
    });
  }
};

/**
 * Get nearby volunteers
 * GET /api/volunteers/nearby
 */
exports.getNearbyVolunteers = async (req, res) => {
  try {
    const { latitude, longitude, radius = 1000 } = req.query;

    console.log(`[VolunteerController] Fetching nearby volunteers`);
    console.log(`[VolunteerController] Location - Lat: ${latitude}, Lng: ${longitude}, Radius: ${radius}m`);

    // Get all online and approved volunteers
    const snapshot = await admin.firestore()
      .collection('volunteers')
      .where('isOnline', '==', true)
      .where('isApproved', '==', true)
      .get();

    const nearbyVolunteers = [];
    const userLat = parseFloat(latitude);
    const userLng = parseFloat(longitude);
    const radiusMeters = parseFloat(radius);

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const volunteerLat = data.latitude;
      const volunteerLng = data.longitude;

      if (volunteerLat && volunteerLng) {
        // Calculate distance using Haversine formula
        const distance = calculateDistance(userLat, userLng, volunteerLat, volunteerLng);

        // Only include if within radius
        if (distance <= radiusMeters) {
          console.log(`[VolunteerController] Volunteer ${doc.id} is ${distance.toFixed(2)}m away - INCLUDED`);
          nearbyVolunteers.push({
            volunteerId: doc.id,
            name: data.name,
            phone: data.phone,
            latitude: volunteerLat,
            longitude: volunteerLng,
            distance: distance,
            isAvailable: data.isAvailable ?? true,
          });
        } else {
          console.log(`[VolunteerController] Volunteer ${doc.id} is ${distance.toFixed(2)}m away - EXCLUDED`);
        }
      }
    }

    // Sort by distance (nearest first)
    nearbyVolunteers.sort((a, b) => a.distance - b.distance);

    console.log(`[VolunteerController] Found ${nearbyVolunteers.length} nearby volunteers`);

    res.status(200).json({
      success: true,
      data: nearbyVolunteers,
    });
  } catch (error) {
    console.error('[VolunteerController] Error fetching nearby volunteers:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch nearby volunteers',
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