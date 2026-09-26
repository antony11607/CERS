import { useEffect, useState } from 'react';
import { MapContainer, Marker, Popup, TileLayer, Polyline } from 'react-leaflet';
import L from 'leaflet';
import { fetchRoute } from '../services/routeService';
import { useRealtimeCollection } from '../hooks/useRealtimeCollection';

const victimIcon = L.icon({
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
});

const volunteerIcon = L.divIcon({
  className: 'custom-pin custom-pin-volunteer',
  html: '<div style="background:#1f7ae0;border-radius:9999px;width:18px;height:18px;border:3px solid white;box-shadow:0 0 0 1px rgba(0,0,0,0.15)"></div>',
  iconSize: [18, 18],
  iconAnchor: [9, 9],
});

export default function LiveTrackingPage() {
  const { data: emergencies = [] } = useRealtimeCollection('emergencies');
  const [routePoints, setRoutePoints] = useState([]);
  const [selectedEmergency, setSelectedEmergency] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const emergency = emergencies.find((item) => item.status && ['waiting', 'accepted', 'arrived', 'reported'].includes(String(item.status).toLowerCase())) || emergencies[0];
    setSelectedEmergency(emergency || null);
  }, [emergencies]);

  useEffect(() => {
    const loadRoute = async () => {
      if (!selectedEmergency) return;

      const victimLat = Number(selectedEmergency.latitude || selectedEmergency.lat || 6.5244);
      const victimLng = Number(selectedEmergency.longitude || selectedEmergency.lng || 3.3792);
      const volunteerLat = Number(selectedEmergency.volunteerLatitude || 6.5271);
      const volunteerLng = Number(selectedEmergency.volunteerLongitude || 3.3834);

      if (!Number.isFinite(victimLat) || !Number.isFinite(victimLng) || !Number.isFinite(volunteerLat) || !Number.isFinite(volunteerLng)) {
        return;
      }

      try {
        setLoading(true);
        const result = await fetchRoute(volunteerLat, volunteerLng, victimLat, victimLng);
        const coordinates = result.route || [];
        setRoutePoints(coordinates.map(([lng, lat]) => [lat, lng]));
      } catch (error) {
        console.error('[Tracking] Route fetch failed', error);
      } finally {
        setLoading(false);
      }
    };

    loadRoute();
  }, [selectedEmergency]);

  const victimCoords = [
    Number(selectedEmergency?.latitude || selectedEmergency?.lat || 6.5244),
    Number(selectedEmergency?.longitude || selectedEmergency?.lng || 3.3792),
  ];

  const volunteerCoords = [
    Number(selectedEmergency?.volunteerLatitude || 6.5271),
    Number(selectedEmergency?.volunteerLongitude || 3.3834),
  ];

  const timeline = [
    { label: 'Reported', time: selectedEmergency?.reportedAt || '08:05 AM' },
    { label: 'Accepted', time: selectedEmergency?.acceptedAt || '08:12 AM' },
    { label: 'En Route', time: selectedEmergency?.enRouteAt || '08:18 AM' },
    { label: 'Arrived', time: selectedEmergency?.arrivedAt || '08:26 AM' },
  ];

  return (
    <div className="grid gap-6 xl:grid-cols-[1.6fr_0.9fr]">
      <div className="rounded-3xl border border-[#ece8e8] bg-white p-5 shadow-sm">
        <div className="mb-4 flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-semibold text-[#2d2d2d]">Live Tracking</h2>
            <p className="text-sm text-[#7d7d7d]">Victim and volunteer locations in real time</p>
          </div>
          <div className="rounded-full bg-[#eafaf1] px-3 py-1.5 text-xs font-semibold text-[#1a9f59]">Live</div>
        </div>

        <div className="h-[500px] overflow-hidden rounded-2xl border border-[#ece8e8] bg-[#f7f7f7]">
          <MapContainer center={victimCoords} zoom={14} scrollWheelZoom className="h-full w-full">
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            {routePoints.length > 0 ? <Polyline positions={routePoints} pathOptions={{ color: '#d63b3b', weight: 5 }} /> : null}
            <Marker position={victimCoords} icon={victimIcon}>
              <Popup>{selectedEmergency?.victimName || 'Victim'}</Popup>
            </Marker>
            <Marker position={volunteerCoords} icon={volunteerIcon}>
              <Popup>{selectedEmergency?.assignedVolunteer || 'Volunteer'}</Popup>
            </Marker>
          </MapContainer>
        </div>
      </div>

      <div className="space-y-6">
        <div className="rounded-3xl border border-[#ece8e8] bg-white p-5 shadow-sm">
          <h3 className="mb-4 text-xl font-semibold text-[#2d2d2d]">Emergency Timeline</h3>
          <div className="space-y-4">
            {timeline.map((item, index) => (
              <div key={item.label} className="flex gap-3">
                <div className="flex flex-col items-center">
                  <div className={`flex h-5 w-5 items-center justify-center rounded-full ${index === 0 ? 'bg-[#d63b3b]' : 'bg-[#e9dada]'}`}>
                    <div className="h-2 w-2 rounded-full bg-white" />
                  </div>
                  {index < timeline.length - 1 ? <div className="mt-2 h-8 w-px bg-[#ece8e8]" /> : null}
                </div>
                <div className="flex-1">
                  <div className="font-medium text-[#2d2d2d]">{item.label}</div>
                  <div className="text-sm text-[#7d7d7d]">{item.time}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="rounded-3xl border border-[#ece8e8] bg-white p-5 shadow-sm">
          <h3 className="mb-4 text-xl font-semibold text-[#2d2d2d]">Live Status</h3>
          <div className="space-y-3 text-sm text-[#4d4d4d]">
            <div className="flex items-center justify-between"><span>Victim</span><strong>{selectedEmergency?.victimName || 'Unidentified'}</strong></div>
            <div className="flex items-center justify-between"><span>Volunteer</span><strong>{selectedEmergency?.assignedVolunteer || 'Unassigned'}</strong></div>
            <div className="flex items-center justify-between"><span>Priority</span><strong>{selectedEmergency?.priority || 'Routine'}</strong></div>
            <div className="flex items-center justify-between"><span>Status</span><strong>{selectedEmergency?.status || 'Waiting'}</strong></div>
            <div className="flex items-center justify-between"><span>Distance</span><strong>{selectedEmergency?.distance || '2.4 km'}</strong></div>
          </div>
          {loading ? <div className="mt-4 text-xs text-[#7d7d7d]">Fetching route from backend...</div> : null}
        </div>
      </div>
    </div>
  );
}
