import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function LoginPage() {
  const navigate = useNavigate();
  const { signIn } = useAuth();
  const [email, setEmail] = useState('admin@cers.com');
  const [password, setPassword] = useState('admin123');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();
    setLoading(true);
    setError('');

    try {
      const userCredential = await signIn(email, password);
      console.log('[Auth] Admin login success', userCredential.user?.uid);
      navigate('/dashboard', { replace: true });
    } catch (loginError) {
      console.error('[Auth] Login failed', loginError);
      setError(loginError.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#f6f1f1] p-6">
      <div className="w-full max-w-md rounded-[30px] border border-[#f0e6e6] bg-white p-8 shadow-xl">
        <div className="mb-6 text-center">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-[#d63b3b] text-2xl font-bold text-white">C</div>
          <h1 className="text-3xl font-bold text-[#2d2d2d]">CERS Admin</h1>
          <p className="mt-2 text-sm text-[#7d7d7d]">System Controller</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="mb-2 block text-sm font-medium text-[#3e3e3e]">Email</label>
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="w-full rounded-xl border border-[#ece6e6] bg-[#faf8f8] px-3 py-3 text-sm outline-none ring-0 transition focus:border-[#d63b3b]"
              placeholder="admin@cers.com"
            />
          </div>
          <div>
            <label className="mb-2 block text-sm font-medium text-[#3e3e3e]">Password</label>
            <input
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="w-full rounded-xl border border-[#ece6e6] bg-[#faf8f8] px-3 py-3 text-sm outline-none transition focus:border-[#d63b3b]"
              placeholder="••••••••"
            />
          </div>

          {error ? <div className="rounded-xl bg-[#fff2f2] px-3 py-2 text-sm text-[#d63b3b]">{error}</div> : null}

          <button
            type="submit"
            className="w-full rounded-xl bg-[#d63b3b] px-4 py-3 text-sm font-semibold text-white transition hover:bg-[#c93333] disabled:cursor-not-allowed disabled:opacity-70"
            disabled={loading}
          >
            {loading ? 'Signing in...' : 'Login'}
          </button>
        </form>
      </div>
    </div>
  );
}
