import { NavLink, useNavigate } from 'react-router-dom';
import { createPortal } from 'react-dom';
import { LogOut, PanelLeftClose, PanelLeftOpen, X } from 'lucide-react';
import { navSections } from '../../data/navigation';
import { ASSETS } from '../../config/assets';
import { filterNav } from '../../config/permissions';
import { useAuth } from '../../context/AuthContext';

function BrandMark({ collapsed }) {
  if (collapsed) {
    return <img src={ASSETS.LOGO} alt="IDHAR UDHAR" className="h-10 w-10 object-contain" />;
  }

  return (
    <div className="text-center">
      <img src={ASSETS.LOGO} alt="IDHAR UDHAR" className="mx-auto h-[78px] w-auto object-contain" />
      <p className="mt-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-ink-muted">Admin</p>
    </div>
  );
}

function SidebarPanel({ collapsed, showClose, onClose, onToggleCollapse, onLogout, forceExpanded = false }) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const isCollapsed = forceExpanded ? false : collapsed;
  const sections = filterNav(navSections, user);

  return (
    <aside className={`flex h-full flex-col overflow-hidden rounded-[28px] border border-line bg-white/80 shadow-sidebar backdrop-blur-xl ${isCollapsed ? 'w-[84px]' : 'w-[260px]'}`}>
      <div className={`relative px-3 pt-5 ${isCollapsed ? 'flex justify-center' : ''}`}>
        {showClose ? (
          <button type="button" className="absolute right-2 top-3 rounded-xl p-2 text-ink-muted hover:bg-brand-50" onClick={onClose} aria-label="Close menu">
            <X size={18} />
          </button>
        ) : null}
        <BrandMark collapsed={isCollapsed} />
      </div>

      <nav className="mt-4 flex-1 space-y-4 overflow-y-auto px-3 pb-4">
        {sections.map((section, index) => (
          <div key={section.title || `section-${index}`}>
            {section.title && !isCollapsed ? (
              <p className="mb-2 px-3 text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-soft">{section.title}</p>
            ) : null}
            <div className="space-y-1">
              {section.items.map((item) => {
                const Icon = item.icon;
                return (
                  <NavLink
                    key={item.path}
                    to={item.path}
                    end={item.path === '/dashboard'}
                    onClick={onClose}
                    title={isCollapsed ? item.label : undefined}
                    className={({ isActive }) =>
                      `flex items-center gap-3 rounded-2xl px-3 py-2.5 text-sm font-medium transition ${
                        isCollapsed ? 'justify-center' : ''
                      } ${isActive ? 'bg-brand-50 text-ink shadow-card' : 'text-ink-muted hover:bg-brand-50 hover:text-ink'}`
                    }
                  >
                    {({ isActive }) => (
                      <>
                        <Icon size={18} className={isActive ? 'text-brand-500' : ''} />
                        {isCollapsed ? null : <span>{item.label}</span>}
                      </>
                    )}
                  </NavLink>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      <div className="px-3 pb-4">
        {onToggleCollapse ? (
          <button type="button" onClick={onToggleCollapse} className="mb-3 hidden w-full items-center justify-center gap-2 rounded-2xl px-3 py-2 text-xs font-medium text-ink-muted hover:bg-brand-50 md:flex">
            {isCollapsed ? <PanelLeftOpen size={16} /> : <PanelLeftClose size={16} />}
            {isCollapsed ? null : <span>Collapse</span>}
          </button>
        ) : null}

        <button
          type="button"
          onClick={() => { navigate('/profile'); onClose?.(); }}
          className={`mb-2 flex w-full items-center gap-3 rounded-2xl bg-brand-50 p-2.5 text-left ${isCollapsed ? 'justify-center' : ''}`}
        >
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-500 text-sm font-bold text-white">{user?.initials}</span>
          {isCollapsed ? null : (
            <span>
              <span className="block text-sm font-semibold text-ink">{user?.name}</span>
              <span className="block text-xs text-ink-muted">{user?.role}</span>
            </span>
          )}
        </button>

        <button
          type="button"
          onClick={onLogout}
          className={`flex w-full items-center gap-3 rounded-2xl bg-red-50 px-3 py-2.5 text-sm font-semibold text-danger hover:bg-red-100 ${isCollapsed ? 'justify-center' : ''}`}
        >
          <LogOut size={18} />
          {isCollapsed ? null : <span>Logout</span>}
        </button>
      </div>
    </aside>
  );
}

export default function Sidebar({ mobileOpen, onClose, collapsed, onToggleCollapse, onLogout }) {
  return (
    <>
      <div className="hidden h-full min-h-0 py-3 pl-3 md:block">
        <SidebarPanel collapsed={collapsed} onClose={onClose} onToggleCollapse={onToggleCollapse} onLogout={onLogout} />
      </div>
      {mobileOpen
        ? createPortal(
            <div className="fixed inset-0 z-40 md:hidden">
              <button type="button" className="absolute inset-0 bg-slate-900/30" aria-label="Close sidebar" onClick={onClose} />
              <div className="relative h-full max-w-[85vw] p-3">
                <SidebarPanel collapsed={false} forceExpanded showClose onClose={onClose} onLogout={onLogout} />
              </div>
            </div>,
            document.body,
          )
        : null}
    </>
  );
}
