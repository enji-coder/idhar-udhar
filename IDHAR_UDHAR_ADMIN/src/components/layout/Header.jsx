import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Bell, LogOut, Menu, Search, Settings, UserRound, Zap } from 'lucide-react';
import SearchBar from '../common/SearchBar';
import { resolvePageMeta } from '../../data/navigation';
import { useAuth } from '../../context/AuthContext';
import { subscribeDashboardLive } from '../../hooks/dashboardLive';
import { fetchAdminNotices, markAllNoticesRead } from '../../api/adminApi';

function DashboardLiveBadge() {
  const [live, setLive] = useState({ phase: 'live', updatedAt: Date.now() });
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => subscribeDashboardLive(setLive), []);

  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(id);
  }, []);

  const ago = Math.max(0, Math.round((now - (live.updatedAt || now)) / 1000));
  const updating = live.phase === 'updating';
  const stamp = ago < 3 ? 'Updated just now' : `Updated ${ago} sec ago`;

  return (
    <div className="hidden shrink-0 text-right sm:block" aria-live="polite">
      {updating ? (
        <p className="text-[11px] font-semibold text-brand-600">↻ Updating...</p>
      ) : (
        <p className="inline-flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-emerald-700">
          <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulseDot" />
          Live Now
        </p>
      )}
      <p className="mt-0.5 text-[11px] text-ink-muted">{updating ? 'Refreshing dashboard data' : stamp}</p>
    </div>
  );
}

export default function Header({ searchQuery, onSearch, onMenuClick, onLogout, onOpenCommand }) {
  const { user, canPath } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [showNotes, setShowNotes] = useState(false);
  const [showProfile, setShowProfile] = useState(false);
  const [notes, setNotes] = useState([]);
  const notesRef = useRef(null);
  const profileRef = useRef(null);

  const meta = resolvePageMeta(location.pathname);
  const unread = notes.filter((item) => item.unread).length;
  const crumbs = meta.crumbs || ['Dashboard'];

  useEffect(() => {
    let cancelled = false;
    fetchAdminNotices()
      .then((rows) => {
        if (!cancelled) setNotes(rows);
      })
      .catch(() => {
        if (!cancelled) setNotes([]);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    function handleClick(event) {
      if (notesRef.current && !notesRef.current.contains(event.target)) setShowNotes(false);
      if (profileRef.current && !profileRef.current.contains(event.target)) setShowProfile(false);
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  return (
    <header className="admin-header py-3">
      <div className="flex min-w-0 items-center justify-between gap-3">
        <div className="flex min-w-0 flex-1 items-center gap-3">
          <button type="button" className="shrink-0 rounded-2xl glass-card p-2.5 md:hidden" onClick={onMenuClick} aria-label="Open menu">
            <Menu size={18} />
          </button>
          <div className="flex min-w-0 flex-1 items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="hidden text-xs text-ink-soft sm:block">{crumbs.join(' / ')}</p>
              <h1 className="truncate text-lg font-bold tracking-tight text-ink sm:text-xl lg:text-2xl">{meta.title}</h1>
              <p className="mt-0.5 hidden truncate text-sm text-ink-muted lg:block">{meta.subtitle}</p>
            </div>
            {location.pathname === '/dashboard' || location.pathname === '/' ? <DashboardLiveBadge /> : null}
          </div>
        </div>

        <div className="flex min-w-0 items-center gap-2 sm:gap-3">
          <div className="hidden min-w-0 flex-1 md:block xl:w-[280px] xl:flex-none">
            <SearchBar value={searchQuery} onChange={onSearch} />
          </div>
          <button type="button" onClick={onOpenCommand} className="hidden items-center gap-2 rounded-full glass-card px-3 py-2 text-xs font-semibold text-ink-muted md:inline-flex">
            <Search size={14} />
            Ctrl + K
          </button>
          <button type="button" onClick={() => navigate('/live')} className="hidden items-center gap-2 rounded-full bg-brand-500 px-3 py-2 text-xs font-semibold text-white shadow-floating lg:inline-flex">
            <Zap size={14} />
            Live
          </button>

          <div className="relative" ref={notesRef}>
            <button
              type="button"
              onClick={() => { setShowNotes((value) => !value); setShowProfile(false); }}
              className="relative rounded-2xl glass-card p-2.5"
              aria-label="Notifications"
            >
              <Bell size={18} />
              {unread > 0 ? (
                <span className="absolute -right-1 -top-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-danger px-1 text-[10px] font-bold text-white">{unread}</span>
              ) : null}
            </button>
            {showNotes ? (
              <div className="absolute right-0 z-30 mt-3 w-[min(22rem,calc(100vw-2rem))] glass-panel p-3">
                <div className="mb-2 flex items-center justify-between px-2">
                  <p className="text-sm font-semibold text-ink">Notifications</p>
                  <button type="button" onClick={async () => {
                    try {
                      await markAllNoticesRead();
                      setNotes((items) => items.map((item) => ({ ...item, unread: false })));
                    } catch {
                      /* keep unread until the API confirms */
                    }
                  }} className="text-xs font-medium text-brand-600">Mark all read</button>
                </div>
                <ul className="max-h-80 space-y-1 overflow-y-auto">
                  {notes.map((item) => (
                    <li key={item.id} className={`rounded-2xl px-3 py-2.5 ${item.unread ? 'bg-brand-50' : ''}`}>
                      <p className="text-sm font-medium text-ink">{item.title}</p>
                      <p className="mt-0.5 text-xs text-ink-soft">{item.category} · {item.time}</p>
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
          </div>

          <div className="relative" ref={profileRef}>
            <button
              type="button"
              onClick={() => { setShowProfile((value) => !value); setShowNotes(false); }}
              className="flex items-center gap-2 rounded-2xl glass-card p-1.5 pr-3"
            >
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-500 text-xs font-bold text-white">{user?.initials}</span>
              <span className="hidden text-left sm:block">
                <span className="block text-sm font-semibold text-ink">{user?.name}</span>
                <span className="block text-xs text-ink-muted">{user?.role}</span>
              </span>
            </button>
            {showProfile ? (
              <div className="absolute right-0 z-30 mt-3 w-60 glass-panel p-2">
                <div className="border-b border-line px-3 py-2">
                  <p className="font-semibold text-ink">{user?.name}</p>
                  <p className="text-xs text-ink-muted">{user?.role}</p>
                </div>
                <button type="button" onClick={() => navigate('/profile')} className="mt-1 flex w-full items-center gap-2 rounded-2xl px-3 py-2.5 text-sm text-ink hover:bg-brand-50">
                  <UserRound size={16} /> Profile
                </button>
                {canPath('/settings') ? (
                  <button type="button" onClick={() => navigate('/settings')} className="flex w-full items-center gap-2 rounded-2xl px-3 py-2.5 text-sm text-ink hover:bg-brand-50">
                    <Settings size={16} /> Settings
                  </button>
                ) : null}
                <button type="button" onClick={onLogout} className="mt-1 flex w-full items-center gap-2 rounded-2xl px-3 py-2.5 text-sm font-semibold text-danger hover:bg-red-50">
                  <LogOut size={16} /> Logout
                </button>
              </div>
            ) : null}
          </div>
        </div>
      </div>
      <div className="mt-3 md:hidden">
        <SearchBar value={searchQuery} onChange={onSearch} placeholder="Search..." />
      </div>
    </header>
  );
}
