import { useMemo, useState } from 'react';
import DataTable from '../components/DataTable';
import StatusBadge from '../components/StatusBadge';
import { useRealtimeCollection } from '../hooks/useRealtimeCollection';

const filters = ['waiting', 'accepted', 'arrived', 'resolved', 'reported'];

export default function ActiveEmergenciesPage() {
  const { data: emergencies = [], loading, error } = useRealtimeCollection('emergencies');
  const [activeFilter, setActiveFilter] = useState('waiting');

  const filteredEmergencies = useMemo(() => {
    return emergencies.filter((emergency) => {
      const status = (emergency?.status || 'waiting').toLowerCase();
      return activeFilter === 'all' ? true : status === activeFilter;
    });
  }, [activeFilter, emergencies]);

  const columns = [
    { key: 'victimName', label: 'Victim' },
    { key: 'assignedVolunteer', label: 'Volunteer' },
    { key: 'eta', label: 'ETA' },
    { key: 'distance', label: 'Distance' },
    { key: 'priority', label: 'Priority' },
    { key: 'status', label: 'Status', render: (value) => <StatusBadge status={value} /> },
  ];

  return (
    <div className="space-y-5">
      <div className="rounded-3xl border border-[#ece8e8] bg-white p-5 shadow-sm">
        <div className="mb-5 flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
          <div>
            <h2 className="text-2xl font-semibold text-[#2d2d2d]">Active Emergencies</h2>
            <p className="text-sm text-[#7d7d7d]">Live incidents and dispatch status</p>
          </div>
          <div className="flex flex-wrap gap-2">
            <button type="button" onClick={() => setActiveFilter('all')} className={`rounded-xl px-3 py-2 text-sm ${activeFilter === 'all' ? 'bg-[#d63b3b] text-white' : 'bg-[#f7f2f2] text-[#666]'}`}>All</button>
            {filters.map((filter) => (
              <button key={filter} type="button" onClick={() => setActiveFilter(filter)} className={`rounded-xl px-3 py-2 text-sm capitalize ${activeFilter === filter ? 'bg-[#d63b3b] text-white' : 'bg-[#f7f2f2] text-[#666]'}`}>
                {filter}
              </button>
            ))}
          </div>
        </div>

        {error ? <div className="mb-4 rounded-xl bg-[#fff3f3] px-3 py-2 text-sm text-[#d63b3b]">{error}</div> : null}

        {loading ? (
          <div className="flex min-h-[220px] items-center justify-center text-sm text-[#7d7d7d]">Loading emergencies...</div>
        ) : (
          <DataTable
            columns={columns}
            rows={filteredEmergencies.map((item) => ({
              ...item,
              victimName: item.victimName || item.userName || 'Unidentified',
              assignedVolunteer: item.assignedVolunteer || item.volunteerName || 'Unassigned',
              eta: item.eta || '—',
              distance: item.distance || '—',
              priority: item.priority || 'Routine',
              status: (item.status || 'waiting').toLowerCase(),
            }))}
            emptyMessage="No emergencies match the selected status."
          />
        )}
      </div>
    </div>
  );
}
