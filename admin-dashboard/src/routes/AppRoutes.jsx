import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import DashboardLayout from '../layouts/DashboardLayout';
import LoginPage from '../pages/LoginPage';
import DashboardPage from '../pages/DashboardPage';
import VolunteerApprovalPage from '../pages/VolunteerApprovalPage';
import ActiveEmergenciesPage from '../pages/ActiveEmergenciesPage';
import LiveTrackingPage from '../pages/LiveTrackingPage';

function ProtectedRoute({ children }) {
  const { isAuthenticated, authLoading, profile } = useAuth();

  if (authLoading) {
    return <div className="flex min-h-screen items-center justify-center text-[#666]">Checking admin access...</div>;
  }

  if (!isAuthenticated || profile?.role !== 'admin') {
    return <Navigate to="/login" replace />;
  }

  return children;
}

export default function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <DashboardLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<DashboardPage />} />
        <Route path="volunteer-approval" element={<VolunteerApprovalPage />} />
        <Route path="active-emergencies" element={<ActiveEmergenciesPage />} />
        <Route path="live-tracking" element={<LiveTrackingPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  );
}
