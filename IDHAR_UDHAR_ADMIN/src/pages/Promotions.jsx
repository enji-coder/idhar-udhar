import { useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Eye, Pencil, Plus, Trash2 } from 'lucide-react';
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
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import { promotionStore } from '../services/stores';
import { useAuth } from '../context/AuthContext';

const emptyPromo = {
  id: '',
  name: '',
  title: '',
  description: '',
  banner: 'campaign',
  type: 'Campaign',
  discount: '',
  start: '2026-08-14',
  end: '2026-09-30',
  usageLimit: 1000,
  used: 0,
  minOrder: 199,
  maxDiscount: 100,
  audience: 'Customers',
  status: 'Active',
};

export default function Promotions() {
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const loading = useMockLoader();
  const rows = useStore(promotionStore);
  const [form, setForm] = useState(emptyPromo);
  const [mode, setMode] = useState(null);
  const [errors, setErrors] = useState({});
  const [view, setView] = useState(null);
  const [confirm, setConfirm] = useState(null);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => `${row.name} ${row.title} ${row.type}`.toLowerCase().includes(query));
  }, [rows, searchQuery]);

  if (loading) return <TableSkeleton />;

  function save() {
    const issues = {};
    if (!form.name.trim()) issues.name = 'Promotion name is required.';
    if (!form.title.trim()) issues.title = 'Title is required.';
    if (!form.discount.trim()) issues.discount = 'Discount is required.';
    setErrors(issues);
    if (Object.keys(issues).length) return;
    const id = form.id || `PR-${Date.now().toString().slice(-4)}`;
    promotionStore.upsert({ ...form, id });
    setMode(null);
  }

  const columns = [
    { key: 'name', label: 'Promotion', sortable: true, render: (row) => <div><p className="font-semibold">{row.name}</p></div> },
    { key: 'discount', label: 'Discount' },
    { key: 'start', label: 'Start Date' },
    { key: 'end', label: 'End Date' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => setView(row)}>View</ActionButton>
          {can('promotions', 'edit') ? <ActionButton icon={Pencil} tone="edit" onClick={() => { setForm(row); setMode('edit'); }}>Edit</ActionButton> : null}
          {can('promotions', 'delete') ? <ActionButton icon={Trash2} tone="danger" onClick={() => setConfirm({ type: 'delete', row })}>Delete</ActionButton> : null}
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      {can('promotions', 'create') ? (
        <div className="flex justify-end">
          <Button icon={Plus} onClick={() => { setForm(emptyPromo); setMode('create'); setErrors({}); }}>Add promotion</Button>
        </div>
      ) : null}
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No promotions found" description="Create a campaign to grow bookings." /> : <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="promotions" />}
      </GlassCard>

      <Modal open={Boolean(mode)} title={mode === 'edit' ? 'Edit promotion' : 'Add promotion'} size="lg" onClose={() => setMode(null)} footer={<><Button variant="ghost" onClick={() => setMode(null)}>Cancel</Button><Button onClick={save}>Save</Button></>}>
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Promotion name" error={errors.name}><input className={inputClass} value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} /></Field>
          <Field label="Title" error={errors.title}><input className={inputClass} value={form.title} onChange={(event) => setForm({ ...form, title: event.target.value })} /></Field>
          <Field label="Description"><input className={inputClass} value={form.description} onChange={(event) => setForm({ ...form, description: event.target.value })} /></Field>
          <Field label="Type"><select className={inputClass} value={form.type} onChange={(event) => setForm({ ...form, type: event.target.value })}><option>Campaign</option><option>Referral</option><option>Discount</option></select></Field>
          <Field label="Discount" error={errors.discount}><input className={inputClass} value={form.discount} onChange={(event) => setForm({ ...form, discount: event.target.value })} /></Field>
          <Field label="Banner / image"><input className={inputClass} value={form.banner} onChange={(event) => setForm({ ...form, banner: event.target.value })} /></Field>
          <Field label="Start date"><input type="date" className={inputClass} value={form.start} onChange={(event) => setForm({ ...form, start: event.target.value })} /></Field>
          <Field label="End date"><input type="date" className={inputClass} value={form.end} onChange={(event) => setForm({ ...form, end: event.target.value })} /></Field>
          <Field label="Usage limit"><input type="number" className={inputClass} value={form.usageLimit} onChange={(event) => setForm({ ...form, usageLimit: Number(event.target.value) })} /></Field>
          <Field label="Minimum order"><input type="number" className={inputClass} value={form.minOrder} onChange={(event) => setForm({ ...form, minOrder: Number(event.target.value) })} /></Field>
          <Field label="Maximum discount"><input type="number" className={inputClass} value={form.maxDiscount} onChange={(event) => setForm({ ...form, maxDiscount: Number(event.target.value) })} /></Field>
          <Field label="Audience"><select className={inputClass} value={form.audience} onChange={(event) => setForm({ ...form, audience: event.target.value })}><option>Customers</option><option>Riders</option><option>All</option></select></Field>
        </div>
      </Modal>

      <Drawer open={Boolean(view)} size="lg" eyebrow="Promotion" title={view?.name} onClose={() => setView(null)} footer={<Button onClick={() => setView(null)}>Close</Button>}>
        {view ? (
          <div className="space-y-3">
            <DetailSection title="Summary">
              <DetailRow label="Title" value={view.title} />
              <DetailRow label="Type" value={view.type} />
              <DetailRow label="Discount" value={view.discount} />
              <DetailRow label="Window" value={`${view.start} → ${view.end}`} />
              <DetailRow label="Audience" value={view.audience} />
              <DetailRow label="Usage" value={`${view.used}/${view.usageLimit}`} />
              <DetailRow label="Status" value={view.status} />
            </DetailSection>
            <DetailSection title="Description"><p>{view.description}</p></DetailSection>
          </div>
        ) : null}
      </Drawer>

      <Modal
        open={Boolean(confirm)}
        title={confirm?.type === 'delete' ? 'Delete promotion?' : confirm?.type === 'deactivate' ? 'Deactivate promotion?' : 'Activate promotion?'}
        onClose={() => setConfirm(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirm(null)}>Cancel</Button>
            <Button
              variant={confirm?.type === 'activate' ? 'approve' : 'reject'}
              onClick={() => {
                if (confirm.type === 'delete') promotionStore.remove(confirm.row.id);
                else promotionStore.patch(confirm.row.id, { status: confirm.type === 'activate' ? 'Active' : 'Inactive' });
                setConfirm(null);
              }}
            >
              {confirm?.type === 'delete' ? 'Delete promotion' : confirm?.type === 'deactivate' ? 'Deactivate' : 'Activate'}
            </Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">{confirm?.type === 'delete' ? 'This action cannot be undone.' : `${confirm?.row?.name} will change status.`}</p>
      </Modal>
    </PageContainer>
  );
}
