import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import ErrorState from '../common/ErrorState';

export default function ProtectedRoute({ children }) {
  const { authReady, isAuthenticated, sessionError, retrySession } = useAuth();
  const location = useLocation();

  if (!authReady) {
    return <div className="page-shell min-h-screen" />;
  }

  if (sessionError) {
    return (
      <div className="page-shell flex min-h-screen items-center justify-center p-4">
        <ErrorState
          title="Couldn't reach the API"
          description={sessionError.message || 'The Admin Panel could not restore the session from NestJS.'}
          onRetry={() => retrySession()}
        />
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />;
  }

  return children;
}

export function RoleRoute({ children }) {
  const { canPath } = useAuth();
  const location = useLocation();

  if (!canPath(location.pathname)) {
    return <Navigate to="/dashboard" replace />;
  }

  return children;
}
