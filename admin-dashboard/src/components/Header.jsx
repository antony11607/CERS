export default function Header({ title = 'Dashboard' }) {
  return (
    <header className="flex items-center justify-between border-b border-[#ece7e7] bg-[#f8f5f5] px-6 py-4">
      <div className="text-2xl font-semibold text-[#2d2d2d]">{title}</div>

      <div className="flex items-center gap-4">
        <div className="relative hidden md:block">
          <input
            type="text"
            placeholder="Search incidents, volunteers..."
            className="w-80 rounded-xl border border-[#ece6e6] bg-white px-4 py-2.5 text-sm text-[#666] outline-none placeholder:text-[#a1a1a1]"
          />
        </div>

        <div className="flex items-center gap-3 rounded-xl border border-[#ece8e8] bg-white px-3 py-2 shadow-sm">
          <div className="text-lg">◫</div>
          <div className="text-right">
            <div className="text-xs uppercase tracking-[0.18em] text-[#888]">Today</div>
            <div className="text-sm font-semibold text-[#2e2e2e]">Jul 7, 2028</div>
          </div>
        </div>

        <div className="flex items-center gap-3 rounded-xl border border-[#ece8e8] bg-white p-2 shadow-sm">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-[#d63b3b] text-xs font-bold text-white">A</div>
          <div>
            <div className="text-sm font-semibold text-[#2d2d2d]">Admin User</div>
            <div className="text-[11px] text-[#8d8d8d]">System Controller</div>
          </div>
        </div>
      </div>
    </header>
  );
}
