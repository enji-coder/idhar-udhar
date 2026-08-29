import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { can, canAccessPath } from '../config/permissions';
import { fetchSession, loginRequest, logoutRequest } from '../services/authService';
import { recordAudit } from '../services/auditService';
import { resetAdminDirectory } from '../api/hydrate';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [authReady, setAuthReady] = useState(false);
  const [sessionError, setSessionError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    fetchSession()
      .then((session) => {
        if (!cancelled) {
          setUser(session);
          setSessionError(null);
        }
      })
      .catch((error) => {
        if (!cancelled) setSessionError(error);
      })
      .finally(() => {
        if (!cancelled) setAuthReady(true);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const value = useMemo(() => ({
    user,
    authReady,
    sessionError,
    isAuthenticated: Boolean(user),
    async retrySession() {
      setAuthReady(false);
      try {
        const session = await fetchSession();
        setUser(session);
        setSessionError(null);
      } catch (error) {
        setSessionError(error);
      } finally {
        setAuthReady(true);
      }
    },
    async login(credentials) {
      const session = await loginRequest(credentials);
      setUser(session);
      setSessionError(null);
      recordAudit({ user: session, action: 'Login', module: 'System', newValue: session.email });
      return session;
    },
    async logout() {
      recordAudit({ user, action: 'Logout', module: 'System' });
      await logoutRequest();
      resetAdminDirectory();
      setUser(null);
      setSessionError(null);
    },
    can(module, action) {
      return can(user, module, action);
    },
    canPath(path) {
      return canAccessPath(user, path);
    },
  }), [user, authReady, sessionError]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside AuthProvider');
  return context;
}
