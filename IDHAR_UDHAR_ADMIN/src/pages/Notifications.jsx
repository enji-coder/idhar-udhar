import { useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Eye, Pencil, Plus, Send, Trash2 } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Tabs from '../components/common/Tabs';
import Modal from '../components/common/Modal';
import Drawer from '../components/common/Drawer';
import EmptyState from '../components/common/EmptyState';
import Field, { inputClass } from '../components/common/Field';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import ConfirmDialog from '../components/common/ConfirmDialog';
import Toast from '../components/common/Toast';
import PageHeader from '../components/common/PageHeader';
import { PageSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import usePanelState from '../hooks/usePanelState';
import useQueryAction from '../hooks/useQueryAction';
import { campaignStore } from '../services/stores';
import { notifications as inboxSeed } from '../data/mockData';
import { nextId } from '../utils/ids';
import { compactErrors, required } from '../utils/validation';

const tabs = [
  { value: 'campaigns', label: 'Composer' },
  { value: 'inbox', label: 'Inbox' },
];

const emptyCampaign = {
  id: '',
  title: '',
  message: '',
  target: 'Customers',
  priority: 'Medium',
  date: '17 Aug 2026',
  status: 'Draft',
};

export default function Notifications() {
  const { searchQuery } = useOutletContext() || {};
  const loading = useMockLoader();
  const campaigns = useStore(campaignStore);
  const [tab, setTab] = useState('campaigns');
  const [inbox, setInbox] = useState(inboxSeed);
  const panel = usePanelState(emptyCampaign);
  useQueryAction('add', panel.openCreate);

  const campaignRows = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return campaigns.filter((row) => `${row.title} ${row.message} ${row.target}`.toLowerCase().includes(query));
  }, [campaigns, searchQuery]);

  const inboxRows = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return inbox.filter((row) => row.title.toLowerCase().includes(query));
  }, [inbox, searchQuery]);

  function save(send = false) {
    const issues = compactErrors({
      title: required(panel.form.title, 'Title is required.'),
      message: required(panel.form.message, 'Message is required.'),
    });
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    campaignStore.upsert({
      ...panel.form,
      id: panel.form.id || nextId('NTF', campaigns),
      status: send ? 'Sent' : panel.form.status || 'Draft',
    });
    panel.setToast(send ? 'Notification sent.' : 'Notification saved.');
    panel.closeForm();
  }

  if (loading) return <PageSkeleton />;

  const columns = [
    { key: 'title', label: 'Notification title', sortable: true, render: (row) => <p className="font-semibold">{row.title}</p> },
    { key: 'message', label: 'Message', render: (row) => <p className="max-w-sm truncate text-ink-muted">{row.message}</p> },
    { key: 'target', label: 'Target' },
    { key: 'date', label: 'Date' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => panel.setView(row)}>View</ActionButton>
          <ActionButton icon={Pencil} tone="edit" onClick={() => panel.openEdit(row)}>Edit</ActionButton>
          {row.status !== 'Sent' ? <ActionButton icon={Send} tone="approve" onClick={() => { campaignStore.patch(row.id, { status: 'Sent' }); panel.setToast('Notification sent.'); }}>Send</ActionButton> : null}
          <ActionButton icon={Trash2} tone="danger" onClick={() => panel.setConfirm(row)}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={tab === 'campaigns' ? <Button icon={Plus} onClick={panel.openCreate}>Create Notification</Button> : <Button variant="secondary" onClick={() => setInbox((items) => items.map((item) => ({ ...item, unread: false })))}>Mark all read</Button>} />
      <Tabs tabs={tabs} value={tab} onChange={setTab} />

      {tab === 'campaigns' ? (
        <GlassCard className="overflow-hidden">
          {campaignRows.length === 0 ? <EmptyState title="No notifications found" description="Compose a message for riders or customers." /> : <DataTable columns={columns} data={campaignRows} pageSize={8} compact itemLabel="notifications" mobileTitleKey="title" />}
        </GlassCard>
      ) : (
        <GlassCard>
          {inboxRows.length === 0 ? (
            <EmptyState title="No notifications" description="The inbox is quiet right now." />
          ) : (
            <ul className="space-y-2">
              {inboxRows.map((item) => (
                <li key={item.id}>
                  <button
                    type="button"
                    onClick={() => setInbox((current) => current.map((row) => (row.id === item.id ? { ...row, unread: false } : row)))}
                    className={`flex w-full items-start justify-between gap-3 rounded-2xl px-4 py-3 text-left ${item.unread ? 'bg-brand-50' : 'bg-white/60'}`}
                  >
                    <div>
                      <p className="font-semibold text-ink">{item.title}</p>
                      <p className="mt-1 text-xs text-ink-muted">{item.category} · {item.time}</p>
                    </div>
                    <StatusBadge status={item.priority} />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </GlassCard>
      )}

      <Modal
        open={Boolean(panel.mode)}
        title={panel.mode === 'edit' ? 'Edit notification' : 'Create Notification'}
        onClose={panel.closeForm}
        footer={(
          <>
            <Button variant="ghost" onClick={panel.closeForm}>Cancel</Button>
            <Button variant="secondary" onClick={() => save(false)}>Save draft</Button>
            <Button icon={Send} onClick={() => save(true)}>Send</Button>
          </>
        )}
      >
        <div className="space-y-3">
          <Field label="Title" error={panel.errors.title}><input className={inputClass} value={panel.form.title} onChange={(event) => panel.setForm({ ...panel.form, title: event.target.value })} /></Field>
          <Field label="Message" error={panel.errors.message}><textarea className={`${inputClass} h-24 py-2`} value={panel.form.message} onChange={(event) => panel.setForm({ ...panel.form, message: event.target.value })} /></Field>
          <Field label="Audience">
            <select className={inputClass} value={panel.form.target} onChange={(event) => panel.setForm({ ...panel.form, target: event.target.value })}>
              <option>Customers</option><option>Riders</option><option>All</option>
            </select>
          </Field>
          <Field label="Priority">
            <select className={inputClass} value={panel.form.priority} onChange={(event) => panel.setForm({ ...panel.form, priority: event.target.value })}>
              <option>Low</option><option>Medium</option><option>High</option>
            </select>
          </Field>
        </div>
      </Modal>
      <Drawer open={Boolean(panel.view)} size="lg" eyebrow="Notification" title={panel.view?.title} onClose={() => panel.setView(null)} footer={<Button onClick={() => panel.setView(null)}>Close</Button>}>
        {panel.view ? (
          <DetailSection title="Message">
            <DetailRow label="Target" value={panel.view.target} />
            <DetailRow label="Priority" value={panel.view.priority} />
            <DetailRow label="Date" value={panel.view.date} />
            <DetailRow label="Status" value={panel.view.status} />
            <p className="col-span-2 mt-2 text-sm leading-6 text-ink">{panel.view.message}</p>
          </DetailSection>
        ) : null}
      </Drawer>
      <ConfirmDialog open={Boolean(panel.confirm)} description={`${panel.confirm?.title} will be deleted.`} onClose={() => panel.setConfirm(null)} onConfirm={() => { campaignStore.remove(panel.confirm.id); panel.setConfirm(null); panel.setToast('Notification deleted.'); }} />
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
