import { Outlet } from 'react-router-dom';
import Sidebar from '../components/Sidebar';
import Header from '../components/Header';

export default function DashboardLayout() {
  return (
    <div className="flex min-h-screen bg-[#f5f3f3] text-[#2d2d2d]">
      <div className="w-[260px] flex-shrink-0 bg-[#f6f2f2]">
        <Sidebar />
      </div>

      <div className="flex min-w-0 flex-1 flex-col">
        <Header />
        <main className="flex-1 p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
