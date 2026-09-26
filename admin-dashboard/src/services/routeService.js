const backendBaseUrl = 'http://localhost:3000';

export async function fetchRoute(startLat, startLng, endLat, endLng) {
  const params = new URLSearchParams({
    startLat: String(startLat),
    startLng: String(startLng),
    endLat: String(endLat),
    endLng: String(endLng),
  });

  const response = await fetch(`${backendBaseUrl}/api/maps/route?${params.toString()}`);

  if (!response.ok) {
    throw new Error('Unable to fetch route from CERS backend');
  }

  const payload = await response.json();
  return payload?.data || { route: [] };
}

export async function fetchDistanceAndEta(startLat, startLng, endLat, endLng) {
  const params = new URLSearchParams({
    startLat: String(startLat),
    startLng: String(startLng),
    endLat: String(endLat),
    endLng: String(endLng),
  });

  const response = await fetch(`${backendBaseUrl}/api/maps/distance?${params.toString()}`);

  if (!response.ok) {
    throw new Error('Unable to fetch ETA from CERS backend');
  }

  const payload = await response.json();
  return payload?.data || { distance: 0, duration: 0 };
}
