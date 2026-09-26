import { NavLink } from 'react-router-dom';

const navItems = [
  { label: 'Dashboard', path: '/dashboard', icon: '◫' },
  { label: 'Volunteer Approval', path: '/volunteer-approval', icon: '◌' },
  { label: 'Active Emergencies', path: '/active-emergencies', icon: '△' },
  { label: 'Live Tracking', path: '/live-tracking', icon: '◎' },
];

export default function Sidebar() {
  return (
    <aside className="flex h-full min-h-screen flex-col justify-between border-r border-[#e9e4e4] bg-[#f9f6f6] p-4">
      <div>
        <div className="mb-8 flex items-center gap-3 px-2 py-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-md bg-[#d63b3b] text-sm font-bold text-white">C</div>
          <div>
            <div className="text-xl font-bold text-[#2d2d2d]">CERS</div>
            <div className="text-[10px] uppercase tracking-[0.2em] text-[#8d8d8d]">Control</div>
          </div>
        </div>

        <nav className="space-y-2">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) =>
                `flex items-center justify-between rounded-xl px-3 py-3 text-sm font-medium transition ${
                  isActive
                    ? 'bg-[#fff1f1] text-[#d63b3b] shadow-sm ring-1 ring-[#f3d1d1]'
                    : 'text-[#4d4d4d] hover:bg-white'
                }`
              }
            >
              <span className="flex items-center gap-3">
                <span className="text-base">{item.icon}</span>
                <span>{item.label}</span>
              </span>
              <span className="text-xs text-[#9a9a9a]">›</span>
            </NavLink>
          ))}
        </nav>
      </div>

      <div className="border-t border-[#ebe4e4] pt-4">
        <button type="button" className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm text-[#4d4d4d] hover:bg-white">
          <span>↩</span>
          <span>Logout</span>
        </button>
      </div>
    </aside>
  );
}
