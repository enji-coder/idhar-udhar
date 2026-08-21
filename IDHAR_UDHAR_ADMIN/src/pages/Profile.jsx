import { useState } from 'react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import Button from '../components/common/Button';
import StatusBadge from '../components/common/StatusBadge';
import Modal from '../components/common/Modal';
import Field, { inputClass } from '../components/common/Field';
import Toast from '../components/common/Toast';
import { PageSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import { useAuth } from '../context/AuthContext';

const PROFILE_KEY = 'iu_admin_profile';

export default function Profile() {
  const loading = useMockLoader();
  const { user } = useAuth();
  const [edit, setEdit] = useState(false);
  const [toast, setToast] = useState('');
  const [draft, setDraft] = useState({ name: user?.name || 'Admin', city: user?.city || 'Ahmedabad' });
  const [overlay, setOverlay] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem(PROFILE_KEY) || '{}');
    } catch {
      return {};
    }
  });

  if (loading) return <PageSkeleton />;

  const name = overlay.name || user?.name;
  const city = overlay.city || user?.city;
  const initials = String(name || 'AD').split(' ').filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase();

  function save() {
    const next = { name: draft.name, city: draft.city };
    localStorage.setItem(PROFILE_KEY, JSON.stringify(next));
    setOverlay(next);
    setEdit(false);
    setToast('Profile updated.');
  }

  return (
    <PageContainer>
      <GlassCard className="max-w-xl">
        <div className="flex items-center gap-4">
          <span className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-500 text-xl font-bold text-white">{initials}</span>
          <div>
            <h2 className="text-xl font-bold">{name}</h2>
            <p className="text-sm text-ink-muted">{user?.role} · {city}</p>
          </div>
        </div>
        <dl className="mt-5 space-y-3 text-sm">
          <div className="flex justify-between"><dt className="text-ink-muted">Email</dt><dd>{user?.email}</dd></div>
          <div className="flex justify-between"><dt className="text-ink-muted">Role</dt><dd>{user?.role}</dd></div>
          <div className="flex justify-between items-center"><dt className="text-ink-muted">Status</dt><dd><StatusBadge status="Active" /></dd></div>
          <div className="flex justify-between"><dt className="text-ink-muted">Workspace</dt><dd>IDHAR UDHAR Admin</dd></div>
        </dl>
        <Button className="mt-5" onClick={() => { setDraft({ name, city }); setEdit(true); }}>Edit Profile</Button>
      </GlassCard>
      <Modal open={edit} title="Edit Profile" onClose={() => setEdit(false)} footer={<><Button variant="ghost" onClick={() => setEdit(false)}>Cancel</Button><Button onClick={save}>Save</Button></>}>
        <div className="space-y-3">
          <Field label="Admin name"><input className={inputClass} value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></Field>
          <Field label="City"><input className={inputClass} value={draft.city} onChange={(event) => setDraft({ ...draft, city: event.target.value })} /></Field>
          <Field label="Email"><input className={inputClass} value={user?.email || ''} disabled /></Field>
        </div>
      </Modal>
      <Toast open={Boolean(toast)} message={toast} onClose={() => setToast('')} />
    </PageContainer>
  );
}
