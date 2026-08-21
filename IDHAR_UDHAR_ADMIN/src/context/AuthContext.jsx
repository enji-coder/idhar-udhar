import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { can, canAccessPath } from '../config/permissions';
import { fetchSession, loginRequest, logoutRequest } from '../services/authService';
import { recordAudit } from '../services/auditService';
import { adminUserStore, findAdminByEmail } from '../services/adminUsers';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [authReady, setAuthReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    fetchSession()
      .then((session) => {
        if (!cancelled) setUser(session);
      })
      .finally(() => {
        if (!cancelled) setAuthReady(true);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!user?.email) return undefined;
    return adminUserStore.subscribe(() => {
      const latest = findAdminByEmail(user.email);
      if (!latest) return;
      setUser((current) => (current ? {
        ...current,
        name: latest.name || current.name,
        role: latest.role || current.role,
        status: latest.status || current.status,
        financeAccess: latest.financeAccess,
        payoutApprove: Boolean(latest.payoutApprove),
        modules: latest.modules || current.modules,
      } : current));
    });
  }, [user?.email]);

  const value = useMemo(() => ({
    user,
    authReady,
    isAuthenticated: Boolean(user),
    async login(credentials) {
      const session = await loginRequest(credentials);
      setUser(session);
      recordAudit({ user: session, action: 'Login', module: 'System', newValue: session.email });
      return session;
    },
    async logout() {
      recordAudit({ user, action: 'Logout', module: 'System' });
      await logoutRequest();
      setUser(null);
    },
    can(module, action) {
      return can(user, module, action);
    },
    canPath(path) {
      return canAccessPath(user, path);
    },
  }), [user, authReady]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside AuthProvider');
  return context;
}
