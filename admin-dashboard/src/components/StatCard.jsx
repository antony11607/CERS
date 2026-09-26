export default function StatCard({ icon, label, value, subtext, tone = 'neutral', detail = '' }) {
  const toneClasses = {
    red: 'bg-[#fff7f7] text-[#d63b3b]',
    blue: 'bg-[#f3f9ff] text-[#2c7be5]',
    green: 'bg-[#f1fff7] text-[#1a9f59]',
    amber: 'bg-[#fffaf1] text-[#d68d16]',
    neutral: 'bg-[#f5f5f5] text-[#4d4d4d]',
  };

  return (
    <div className="rounded-2xl border border-[#ece8e8] bg-white p-4 shadow-sm">
      <div className="mb-4 flex items-center justify-between">
        <div className={`flex h-11 w-11 items-center justify-center rounded-xl ${toneClasses[tone]}`}>
          {icon}
        </div>
        <div className="text-[10px] text-[#afafaf]">{detail}</div>
      </div>

      <div className="space-y-1">
        <div className="text-4xl font-semibold tracking-tight text-[#2d2d2d]">{value}</div>
        <div className="text-[13px] text-[#7c7c7c]">{label}</div>
      </div>

      {subtext ? <div className="mt-3 text-[11px] text-[#a3a3a3]">{subtext}</div> : null}
    </div>
  );
}
