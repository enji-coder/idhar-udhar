import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';

export default function ProtectedRoute({ children }) {
  const { authReady, isAuthenticated } = useAuth();
  const location = useLocation();

  if (!authReady) {
    return <div className="page-shell min-h-screen" />;
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
