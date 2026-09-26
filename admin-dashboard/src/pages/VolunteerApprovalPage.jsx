import { useMemo, useState } from 'react';
import DataTable from '../components/DataTable';
import Modal from '../components/Modal';
import StatusBadge from '../components/StatusBadge';
import { useRealtimeCollection } from '../hooks/useRealtimeCollection';
import { createOrUpdateVolunteerRecord, updateApprovalStatus } from '../services/firestoreService';

const tabs = ['pending', 'approved', 'rejected'];

export default function VolunteerApprovalPage() {
  const { data: applications = [], loading, error } = useRealtimeCollection('volunteer_approval');
  const [activeTab, setActiveTab] = useState('pending');
  const [search, setSearch] = useState('');
  const [selectedApplication, setSelectedApplication] = useState(null);

  const filteredApplications = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();
    return applications.filter((application) => {
      const matchesTab = (application?.status || 'pending').toLowerCase() === activeTab;
      const searchableText = [application?.fullName, application?.email, application?.phone, application?.city]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();

      const matchesSearch = !normalizedSearch || searchableText.includes(normalizedSearch);
      return matchesTab && matchesSearch;
    });
  }, [activeTab, applications, search]);

  const handleDecision = async (application, decision) => {
    try {
      await updateApprovalStatus(application.id, decision, 'admin');
      await createOrUpdateVolunteerRecord(
        {
          ...application,
          id: application.id,
          volunteerId: application.userId || application.id,
        },
        decision === 'approved' ? 'approved' : 'rejected',
      );
      setSelectedApplication(null);
      console.log('[Approval] Applicant decision saved', { applicationId: application.id, decision });
    } catch (decisionError) {
      console.error('[Approval] Failed to update decision', decisionError);
    }
  };

  const columns = [
    { key: 'fullName', label: 'Applicant' },
    { key: 'email', label: 'Email' },
    { key: 'phone', label: 'Phone' },
    { key: 'city', label: 'Location' },
    { key: 'submittedAt', label: 'Applied' },
    {
      key: 'status',
      label: 'Status',
      render: (value) => <StatusBadge status={value} />,
    },
    {
      key: 'action',
      label: 'Action',
      render: (_, row) => (
        <button
          type="button"
          onClick={() => setSelectedApplication(row)}
          className="rounded-lg bg-[#fef4f4] px-3 py-1.5 text-xs font-semibold text-[#d63b3b]"
        >
          Review
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-5">
      <div className="rounded-3xl border border-[#ece8e8] bg-white p-5 shadow-sm">
        <div className="mb-5 flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
          <div>
            <h2 className="text-2xl font-semibold text-[#2d2d2d]">Volunteer Approval</h2>
            <p className="text-sm text-[#7d7d7d]">Review and manage volunteer applicants in real time.</p>
          </div>

          <div className="flex items-center gap-3">
            <input
              type="text"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search applicant"
              className="w-full rounded-xl border border-[#ece6e6] bg-[#faf8f8] px-3 py-2.5 text-sm outline-none xl:w-72"
            />
          </div>
        </div>

        <div className="mb-5 flex gap-2 rounded-2xl bg-[#f8f4f4] p-1">
          {tabs.map((tab) => (
            <button
              key={tab}
              type="button"
              onClick={() => setActiveTab(tab)}
              className={`rounded-xl px-4 py-2 text-sm font-medium capitalize transition ${
                activeTab === tab ? 'bg-white text-[#d63b3b] shadow-sm' : 'text-[#666]'
              }`}
            >
              {tab}
            </button>
          ))}
        </div>

        {error ? (
          <div className="mb-4 rounded-xl bg-[#fff3f3] px-3 py-2 text-sm text-[#d63b3b]">{error}</div>
        ) : null}

        {loading ? (
          <div className="flex min-h-[220px] items-center justify-center text-sm text-[#7d7d7d]">Loading volunteer applications...</div>
        ) : (
          <DataTable
            columns={columns}
            rows={filteredApplications.map((item) => ({
              ...item,
              action: item,
            }))}
            emptyMessage="No volunteer applications in this stage."
          />
        )}
      </div>

      <Modal isOpen={Boolean(selectedApplication)} title="Applicant Details" onClose={() => setSelectedApplication(null)}>
        {selectedApplication ? (
          <div className="space-y-5">
            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <div className="text-xs uppercase tracking-[0.12em] text-[#888]">Full Name</div>
                <div className="mt-1 text-lg font-semibold text-[#2d2d2d]">{selectedApplication.fullName || '—'}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.12em] text-[#888]">Status</div>
                <div className="mt-1"><StatusBadge status={selectedApplication.status} /></div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.12em] text-[#888]">Email</div>
                <div className="mt-1 text-[#2d2d2d]">{selectedApplication.email || '—'}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.12em] text-[#888]">Phone</div>
                <div className="mt-1 text-[#2d2d2d]">{selectedApplication.phone || '—'}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.12em] text-[#888]">City</div>
                <div className="mt-1 text-[#2d2d2d]">{selectedApplication.city || '—'}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.12em] text-[#888]">Submitted</div>
                <div className="mt-1 text-[#2d2d2d]">{selectedApplication.submittedAt || '—'}</div>
              </div>
            </div>

            <div className="rounded-2xl bg-[#faf7f7] p-4 text-sm text-[#5a5a5a]">
              {selectedApplication.notes || 'No additional notes were provided for this application.'}
            </div>

            <div className="flex justify-end gap-3">
              <button type="button" onClick={() => handleDecision(selectedApplication, 'rejected')} className="rounded-xl border border-[#f0cfcf] bg-[#fff0f0] px-4 py-2.5 font-medium text-[#d63b3b]">Reject</button>
              <button type="button" onClick={() => handleDecision(selectedApplication, 'approved')} className="rounded-xl bg-[#d63b3b] px-4 py-2.5 font-medium text-white">Approve</button>
            </div>
          </div>
        ) : null}
      </Modal>
    </div>
  );
}
