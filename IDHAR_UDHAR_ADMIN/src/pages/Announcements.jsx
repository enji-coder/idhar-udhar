import { useMemo } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Eye, Pencil, Plus, Power, Trash2 } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Modal from '../components/common/Modal';
import Drawer from '../components/common/Drawer';
import EmptyState from '../components/common/EmptyState';
import Field, { inputClass } from '../components/common/Field';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import ConfirmDialog from '../components/common/ConfirmDialog';
import Toast from '../components/common/Toast';
import PageHeader from '../components/common/PageHeader';
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import usePanelState from '../hooks/usePanelState';
import { announcementStore } from '../services/stores';
import { nextId } from '../utils/ids';
import { compactErrors, required } from '../utils/validation';

const emptyAnnouncement = {
  id: '',
  title: '',
  description: '',
  audience: 'All',
  created: '17 Aug 2026',
  status: 'Draft',
};

export default function Announcements() {
  const { searchQuery } = useOutletContext() || {};
  const loading = useMockLoader();
  const rows = useStore(announcementStore);
  const panel = usePanelState(emptyAnnouncement);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => `${row.title} ${row.description} ${row.audience}`.toLowerCase().includes(query));
  }, [rows, searchQuery]);

  function save() {
    const issues = compactErrors({
      title: required(panel.form.title, 'Title is required.'),
      description: required(panel.form.description, 'Description is required.'),
    });
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    announcementStore.upsert({ ...panel.form, id: panel.form.id || nextId('ANN', rows) });
    panel.setToast(panel.mode === 'edit' ? 'Announcement updated.' : 'Announcement saved.');
    panel.closeForm();
  }

  if (loading) return <TableSkeleton />;

  const columns = [
    { key: 'title', label: 'Announcement title', sortable: true, render: (row) => <p className="font-semibold">{row.title}</p> },
    { key: 'description', label: 'Description', render: (row) => <p className="max-w-sm truncate text-ink-muted">{row.description}</p> },
    { key: 'audience', label: 'Audience' },
    { key: 'created', label: 'Created Date' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => panel.setView(row)}>View</ActionButton>
          <ActionButton icon={Pencil} tone="edit" onClick={() => panel.openEdit(row)}>Edit</ActionButton>
          <ActionButton icon={Power} tone={row.status === 'Published' ? 'danger' : 'approve'} onClick={() => { announcementStore.patch(row.id, { status: row.status === 'Published' ? 'Draft' : 'Published' }); panel.setToast(row.status === 'Published' ? 'Unpublished.' : 'Published.'); }}>{row.status === 'Published' ? 'Unpublish' : 'Publish'}</ActionButton>
          <ActionButton icon={Trash2} tone="danger" onClick={() => panel.setConfirm(row)}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={panel.openCreate}>Create Announcement</Button>} />
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No announcements found" description="Publish a notice for riders, customers or operations." /> : <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="announcements" mobileTitleKey="title" />}
      </GlassCard>
      <Modal open={Boolean(panel.mode)} title={panel.mode === 'edit' ? 'Edit announcement' : 'Create Announcement'} onClose={panel.closeForm} footer={<><Button variant="ghost" onClick={panel.closeForm}>Cancel</Button><Button onClick={save}>Save</Button></>}>
        <div className="space-y-3">
          <Field label="Title" error={panel.errors.title}><input className={inputClass} value={panel.form.title} onChange={(event) => panel.setForm({ ...panel.form, title: event.target.value })} /></Field>
          <Field label="Description" error={panel.errors.description}><textarea className={`${inputClass} h-24 py-2`} value={panel.form.description} onChange={(event) => panel.setForm({ ...panel.form, description: event.target.value })} /></Field>
          <Field label="Audience">
            <select className={inputClass} value={panel.form.audience} onChange={(event) => panel.setForm({ ...panel.form, audience: event.target.value })}>
              <option>All</option><option>Riders</option><option>Customers</option><option>Operations</option>
            </select>
          </Field>
        </div>
      </Modal>
      <Drawer open={Boolean(panel.view)} size="lg" eyebrow="Announcement" title={panel.view?.title} onClose={() => panel.setView(null)} footer={<Button onClick={() => panel.setView(null)}>Close</Button>}>
        {panel.view ? (
          <div className="space-y-4">
            <DetailSection title="Details">
              <DetailRow label="Audience" value={panel.view.audience} />
              <DetailRow label="Created" value={panel.view.created} />
              <DetailRow label="Status" value={panel.view.status} />
            </DetailSection>
            <GlassCard className="shadow-none">
              <p className="text-sm leading-6 text-ink">{panel.view.description}</p>
            </GlassCard>
          </div>
        ) : null}
      </Drawer>
      <ConfirmDialog open={Boolean(panel.confirm)} description={`${panel.confirm?.title} will be deleted.`} onClose={() => panel.setConfirm(null)} onConfirm={() => { announcementStore.remove(panel.confirm.id); panel.setConfirm(null); panel.setToast('Announcement deleted.'); }} />
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
