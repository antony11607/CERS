const statusClassMap = {
  critical: 'bg-[#fdd7d7] text-[#c93a3a] border-[#f0afaf]',
  urgent: 'bg-[#ffe6d7] text-[#d8741b] border-[#f0c29f]',
  waiting: 'bg-[#f3effd] text-[#7158d8] border-[#d7cffd]',
  accepted: 'bg-[#dff7ea] text-[#1a9f59] border-[#bfead2]',
  arrived: 'bg-[#e0f0ff] text-[#2484d6] border-[#bfe0ff]',
  resolved: 'bg-[#dff7ea] text-[#1a9f59] border-[#bfead2]',
  reported: 'bg-[#f7e7d7] text-[#c77d2a] border-[#f0d7b4]',
  pending: 'bg-[#f8e8d6] text-[#c77d2a] border-[#f0d5a7]',
  approved: 'bg-[#dff7ea] text-[#1a9f59] border-[#bfead2]',
  rejected: 'bg-[#ffd8d8] text-[#d43a3a] border-[#f0b3b3]',
  online: 'bg-[#dff7ea] text-[#1a9f59] border-[#bfead2]',
  offline: 'bg-[#f1f3f4] text-[#7a7a7a] border-[#dfe2e4]',
};

export default function StatusBadge({ status, text }) {
  const normalized = (status || '').toString().toLowerCase();
  const classes = statusClassMap[normalized] || 'bg-[#f3f3f3] text-[#666] border-[#e5e5e5]';

  return (
    <span className={`inline-flex items-center rounded-full border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.1em] ${classes}`}>
      {text || status || 'Unknown'}
    </span>
  );
}
