import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import StatCard from '../components/StatCard';
import DataTable from '../components/DataTable';
import StatusBadge from '../components/StatusBadge';
import { useRealtimeCollection } from '../hooks/useRealtimeCollection';

const volunteerStats = [
  { name: 'Mon', total: 240 },
  { name: 'Tue', total: 180 },
  { name: 'Wed', total: 280 },
  { name: 'Thu', total: 260 },
  { name: 'Fri', total: 210 },
  { name: 'Sat', total: 320 },
  { name: 'Sun', total: 260 },
];

const dashboardColumns = [
  { key: 'time', label: 'Time' },
  { key: 'victim', label: 'Victim' },
  { key: 'location', label: 'Location' },
  { key: 'priority', label: 'Priority' },
  { key: 'volunteer', label: 'Assigned Volunteer' },
  { key: 'status', label: 'Status', render: (value) => <StatusBadge status={value} /> },
];

const seedRows = [
  {
    id: '1',
    time: '10:42 AM',
    victim: 'Sarah Jenkins',
    location: 'PSA 8 / 3rd St',
    priority: 'Critical',
    volunteer: 'David Millar',
    status: 'critical',
  },
  {
    id: '2',
    time: '10:38 AM',
    victim: 'Marcus Thorne',
    location: 'Westside Community Center',
    priority: 'Urgent',
    volunteer: 'Elena Rodriguez',
    status: 'accepted',
  },
  {
    id: '3',
    time: '10:25 AM',
    victim: 'Unidentified',
    location: 'Acr A',
    priority: 'Critical',
    volunteer: 'Waiting',
    status: 'waiting',
  },
  {
    id: '4',
    time: '10:12 AM',
    victim: 'Robert Chen',
    location: 'Central Hospital',
    priority: 'Routine',
    volunteer: 'Sam Wilson',
    status: 'resolved',
  },
];

export default function DashboardPage() {
  const { data: emergencies = [], loading: emergencyLoading } = useRealtimeCollection('emergencies');
  const { data: volunteers = [], loading: volunteersLoading } = useRealtimeCollection('volunteers');
  const { data: approvalApps = [], loading: approvalsLoading } = useRealtimeCollection('volunteer_approval');

  const totalVolunteers = volunteers.length;
  const onlineVolunteers = volunteers.filter((volunteer) => volunteer.status === 'online').length;
  const activeEmergencies = emergencies.filter((item) => ['waiting', 'accepted', 'arrived', 'reported'].includes((item?.status || '').toLowerCase())).length;
  const resolvedToday = emergencies.filter((item) => (item?.status || '').toLowerCase() === 'resolved').length;
  const pendingApprovals = approvalApps.filter((application) => (application?.status || '').toLowerCase() === 'pending').length;

  const recentRows = (emergencies.length > 0 ? emergencies : seedRows).slice(0, 5).map((emergency, index) => ({
    id: emergency.id || index,
    time: emergency.time || new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    victim: emergency.victimName || emergency.userName || emergency.victim || 'Unidentified',
    location: emergency.location || emergency.address || 'Unknown location',
    priority: emergency.priority || 'Routine',
    volunteer: emergency.volunteerName || emergency.assignedVolunteer || 'Waiting',
    status: (emergency.status || 'waiting').toLowerCase(),
  }));

  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
        <StatCard icon="👤" label="Total Volunteers" value={totalVolunteers || 1284} subtext="↑ 15 this week" tone="neutral" detail="1 week" />
        <StatCard icon="🧑‍🤝‍🧑" label="Pending Approvals" value={pendingApprovals || 14} subtext="Action required" tone="amber" detail="1 week" />
        <StatCard icon="🟢" label="Online Volunteers" value={onlineVolunteers || 342} subtext="Active in field" tone="blue" detail="Live" />
        <StatCard icon="🚨" label="Active Emergencies" value={activeEmergencies || 6} subtext="Critical response" tone="red" detail="Now" />
        <StatCard icon="✅" label="Resolved Today" value={resolvedToday || 28} subtext="Avg time 16m" tone="green" detail="Today" />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.7fr_0.9fr]">
        <div className="rounded-3xl border border-[#ece8e8] bg-white p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h2 className="text-xl font-semibold text-[#2d2d2d]">Recent SOS Alerts</h2>
              <p className="text-sm text-[#8a8a8a]">Real-time emergency signals received</p>
            </div>
            <button type="button" className="text-sm text-[#d63b3b]">View All</button>
          </div>

          {emergencyLoading || approvalsLoading || volunteersLoading ? (
            <div className="flex min-h-[220px] items-center justify-center text-sm text-[#8a8a8a]">Loading live dashboard data...</div>
          ) : (
            <DataTable columns={dashboardColumns} rows={recentRows} emptyMessage="No recent SOS alerts." />
          )}
        </div>

        <div className="rounded-3xl border border-[#ece8e8] bg-white p-5 shadow-sm">
          <div className="mb-3 flex items-center justify-between">
            <h3 className="text-xl font-semibold text-[#2d2d2d]">Emergency Statistics</h3>
            <span className="text-sm text-[#d63b3b]">Live Feed</span>
          </div>

          <div className="h-64 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={volunteerStats}>
                <defs>
                  <linearGradient id="signalColor" x1="0" x2="0" y1="0" y2="1">
                    <stop offset="0%" stopColor="#d63b3b" stopOpacity={0.45} />
                    <stop offset="100%" stopColor="#d63b3b" stopOpacity={0.05} />
                  </linearGradient>
                </defs>
                <CartesianGrid stroke="#f1ecec" vertical={false} />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#888', fontSize: 11 }} />
                <YAxis hidden />
                <Tooltip />
                <Area type="monotone" dataKey="total" stroke="#d63b3b" strokeWidth={2.5} fill="url(#signalColor)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          <div className="mt-6 rounded-2xl bg-[#faf7f7] p-4">
            <div className="flex items-center justify-between text-sm">
              <span className="text-[#7d7d7d]">Last update</span>
              <span className="font-semibold text-[#2d2d2d]">20:00 (08:00)</span>
            </div>
            <div className="mt-3 flex items-end justify-between gap-3">
              <div>
                <div className="text-[11px] uppercase tracking-[0.16em] text-[#8d8d8d]">Response time</div>
                <div className="text-3xl font-semibold text-[#2d2d2d]">4.2 min</div>
              </div>
              <div className="rounded-full bg-[#f8dfdf] px-2.5 py-1 text-[11px] font-semibold text-[#d63b3b]">Avg response</div>
            </div>
          </div>
        </div>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.5fr_0.9fr]">
        <div className="rounded-3xl border border-[#ece8e8] bg-white p-5 shadow-sm">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h3 className="text-xl font-semibold text-[#2d2d2d]">Volunteer Activity</h3>
              <p className="text-sm text-[#868686]">Activity by day</p>
            </div>
            <button type="button" className="rounded-full bg-[#f3f3f3] px-3 py-1 text-xs uppercase tracking-[0.12em] text-[#666]">Weekly</button>
          </div>

          <div className="h-44 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={volunteerStats}>
                <defs>
                  <linearGradient id="barBlue" x1="0" x2="0" y1="0" y2="1">
                    <stop offset="0%" stopColor="#2d7ae9" stopOpacity={0.45} />
                    <stop offset="100%" stopColor="#2d7ae9" stopOpacity={0.08} />
                  </linearGradient>
                </defs>
                <CartesianGrid stroke="#f1ecec" vertical={false} />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#888', fontSize: 11 }} />
                <YAxis hidden />
                <Tooltip />
                <Area type="monotone" dataKey="total" stroke="#2d7ae9" strokeWidth={2.5} fill="url(#barBlue)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="space-y-4">
          <div className="rounded-3xl border border-[#ece8e8] bg-[#f4f1f1] p-5 shadow-sm">
            <h4 className="mb-3 text-lg font-semibold text-[#2d2d2d]">System Quick Launch</h4>
            <div className="space-y-3">
              {[
                { title: 'Review Volunteers', text: 'Manage onboarding and approve applicants.', accent: 'bg-[#e8f3ff] text-[#1d6fe4]' },
                { title: 'Emergency Registry', text: 'Monitor active and reported incidents.', accent: 'bg-[#ffe7e7] text-[#d63b3b]' },
                { title: 'Global Tracking', text: 'Open the dispatch and route overview.', accent: 'bg-[#f3f3f3] text-[#2d2d2d]' },
              ].map((item) => (
                <div key={item.title} className="flex items-center gap-3 rounded-2xl bg-white p-3">
                  <div className={`flex h-12 w-12 items-center justify-center rounded-xl ${item.accent}`}>•</div>
                  <div>
                    <div className="font-semibold text-[#2d2d2d]">{item.title}</div>
                    <div className="text-xs text-[#767676]">{item.text}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
