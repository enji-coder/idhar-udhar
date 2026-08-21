import { useEffect, useState } from 'react';
import { Navigate, Outlet, useLocation, useNavigate } from 'react-router-dom';
import Header from './Header';
import Sidebar from './Sidebar';
import CommandPalette from './CommandPalette';
import Modal from '../common/Modal';
import Button from '../common/Button';
import { useAuth } from '../../context/AuthContext';

export default function AdminLayout() {
  const { canPath, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(typeof window !== 'undefined' ? window.innerWidth < 1280 : false);
  const [searchQuery, setSearchQuery] = useState('');
  const [logoutOpen, setLogoutOpen] = useState(false);
  const [commandOpen, setCommandOpen] = useState(false);

  useEffect(() => {
    setSearchQuery('');
  }, [location.pathname]);

  useEffect(() => {
    function onKey(event) {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        setCommandOpen((value) => !value);
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  if (!canPath(location.pathname)) {
    return <Navigate to="/dashboard" replace />;
  }

  async function confirmLogout() {
    await logout();
    setLogoutOpen(false);
    navigate('/login', { replace: true });
  }

  return (
    <div className="page-shell admin-app">
      <Sidebar
        mobileOpen={mobileOpen}
        onClose={() => setMobileOpen(false)}
        collapsed={collapsed}
        onToggleCollapse={() => setCollapsed((value) => !value)}
        onLogout={() => setLogoutOpen(true)}
      />
      <div className="admin-workspace px-3 pb-3 md:px-4 lg:pr-4 lg:pt-0">
        <Header
          searchQuery={searchQuery}
          onSearch={setSearchQuery}
          onMenuClick={() => setMobileOpen(true)}
          onLogout={() => setLogoutOpen(true)}
          onOpenCommand={() => setCommandOpen(true)}
        />
        <main className="admin-main pt-3">
          <Outlet context={{ searchQuery }} />
        </main>
      </div>

      <CommandPalette open={commandOpen} onClose={() => setCommandOpen(false)} />

      <Modal
        open={logoutOpen}
        title="Are you sure you want to logout?"
        onClose={() => setLogoutOpen(false)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setLogoutOpen(false)}>Cancel</Button>
            <Button variant="reject" onClick={confirmLogout}>Logout</Button>
          </>
        }
      >
        <p className="text-sm leading-6 text-ink-muted">You will need to sign in again to access the Admin Panel.</p>
      </Modal>
    </div>
  );
}
