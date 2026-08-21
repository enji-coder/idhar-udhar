import { useState } from 'react';
import { Eye, EyeOff } from 'lucide-react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { ASSETS } from '../config/assets';
import { useAuth } from '../context/AuthContext';
import Button from '../components/common/Button';
import Field, { inputClass } from '../components/common/Field';

export default function Login() {
  const { authReady, isAuthenticated, login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  if (!authReady) {
    return <div className="page-shell min-h-screen" />;
  }

  if (isAuthenticated) {
    return <Navigate to={location.state?.from || '/dashboard'} replace />;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login({ email, password });
      navigate(location.state?.from || '/dashboard', { replace: true });
    } catch {
      setError('Invalid email or password.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page-shell flex min-h-screen items-center justify-center p-4">
      <div className="w-full max-w-md rounded-[20px] bg-white p-6 shadow-card sm:p-8">
        <img
          src={ASSETS.LOGO}
          alt="IDHAR UDHAR"
          className="mx-auto h-20 w-auto bg-transparent object-contain"
        />
        <p className="mt-2 text-center text-[11px] font-semibold uppercase tracking-[0.2em] text-ink-muted">Admin</p>
        <h1 className="mt-4 text-center text-2xl font-bold text-ink">Sign in</h1>

        <form className="mt-6 space-y-4" onSubmit={handleSubmit}>
          <Field label="Email">
            <input
              id="admin-email"
              className={inputClass}
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              autoComplete="username"
              aria-label="Email"
            />
          </Field>
          <Field label="Password">
            <div className="relative">
              <input
                id="admin-password"
                className={`${inputClass} pr-12`}
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                autoComplete="current-password"
                aria-label="Password"
              />
              <button
                type="button"
                className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-muted"
                onClick={() => setShowPassword((value) => !value)}
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </Field>
          {error ? <p className="rounded-2xl bg-red-50 px-3 py-2 text-sm text-danger" role="alert">{error}</p> : null}
          <Button type="submit" className="w-full" loading={loading}>Sign in</Button>
        </form>
      </div>
    </div>
  );
}
