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
import { couponStore } from '../services/stores';
import { vehicleCategoryNames, vehicleCategoryStore } from '../services/vehicleCategories';
import { useAuth } from '../context/AuthContext';
import { formatINR } from '../utils/format';

const emptyCoupon = {
  code: '',
  title: '',
  description: '',
  discountType: 'Percent',
  discountValue: 10,
  minOrder: 199,
  maxDiscount: 100,
  usageLimit: 500,
  perUserLimit: 1,
  validFrom: '2026-08-14',
  validUntil: '2026-09-30',
  service: 'All',
  customerType: 'All',
  status: 'Active',
  used: 0,
};

function discountLabel(row) {
  return row.discountType === 'Percent' ? `${row.discountValue}%` : formatINR(row.discountValue);
}

export default function Coupons() {
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const loading = useMockLoader();
  const rows = useStore(couponStore);
  useStore(vehicleCategoryStore);
  const [form, setForm] = useState(emptyCoupon);
  const [mode, setMode] = useState(null);
  const [errors, setErrors] = useState({});
  const [confirm, setConfirm] = useState(null);
  const [view, setView] = useState(null);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => `${row.code} ${row.title}`.toLowerCase().includes(query));
  }, [rows, searchQuery]);

  if (loading) return <TableSkeleton />;

  function validate(next) {
    const issues = {};
    const code = next.code.trim().toUpperCase();
    if (!next.code.trim()) issues.code = 'Coupon code is required.';
    if (rows.some((row) => row.code.toUpperCase() === code && (mode === 'create' || row.code !== form.code))) {
      issues.code = 'This coupon code already exists.';
    }
    if (!next.title.trim()) issues.title = 'Title is required.';
    if (!next.discountValue || Number(next.discountValue) <= 0) issues.discountValue = 'Enter a valid discount.';
    if (Number(next.minOrder) < 0) issues.minOrder = 'Minimum order cannot be negative.';
    return issues;
  }

  function save() {
    const issues = validate(form);
    setErrors(issues);
    if (Object.keys(issues).length) return;
    couponStore.upsert({ ...form, code: form.code.trim().toUpperCase(), used: form.used || 0 }, 'code');
    setMode(null);
  }

  const columns = [
    { key: 'code', label: 'Coupon Code', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.code}</span> },
    { key: 'discount', label: 'Discount', render: (row) => discountLabel(row) },
    { key: 'usage', label: 'Usage', render: (row) => `${row.used}/${row.usageLimit}` },
    { key: 'validUntil', label: 'Valid Until' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => setView(row)}>View</ActionButton>
          {can('coupons', 'edit') ? <ActionButton icon={Pencil} tone="edit" onClick={() => { setForm(row); setMode('edit'); setErrors({}); }}>Edit</ActionButton> : null}
          {can('coupons', 'delete') ? <ActionButton icon={Trash2} tone="danger" onClick={() => setConfirm({ type: 'delete', row })}>Delete</ActionButton> : null}
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      {can('coupons', 'create') ? (
        <div className="flex justify-end">
          <Button icon={Plus} onClick={() => { setForm(emptyCoupon); setMode('create'); setErrors({}); }}>Add coupon</Button>
        </div>
      ) : null}
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No coupons found" description="Create a code to start a campaign." /> : <DataTable columns={columns} data={data} rowKey="code" pageSize={8} compact itemLabel="coupons" />}
      </GlassCard>

      <Modal open={Boolean(mode)} title={mode === 'edit' ? 'Edit coupon' : 'Add coupon'} size="lg" onClose={() => setMode(null)} footer={<><Button variant="ghost" onClick={() => setMode(null)}>Cancel</Button><Button onClick={save}>Save</Button></>}>
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Coupon code" error={errors.code}><input className={inputClass} value={form.code} onChange={(event) => setForm({ ...form, code: event.target.value })} disabled={mode === 'edit'} /></Field>
          <Field label="Title" error={errors.title}><input className={inputClass} value={form.title} onChange={(event) => setForm({ ...form, title: event.target.value })} /></Field>
          <Field label="Description"><input className={inputClass} value={form.description} onChange={(event) => setForm({ ...form, description: event.target.value })} /></Field>
          <Field label="Discount type">
            <select className={inputClass} value={form.discountType} onChange={(event) => setForm({ ...form, discountType: event.target.value })}>
              <option>Percent</option>
              <option>Flat</option>
            </select>
          </Field>
          <Field label="Discount value" error={errors.discountValue}><input type="number" className={inputClass} value={form.discountValue} onChange={(event) => setForm({ ...form, discountValue: Number(event.target.value) })} /></Field>
          <Field label="Minimum order"><input type="number" className={inputClass} value={form.minOrder} onChange={(event) => setForm({ ...form, minOrder: Number(event.target.value) })} /></Field>
          <Field label="Maximum discount"><input type="number" className={inputClass} value={form.maxDiscount} onChange={(event) => setForm({ ...form, maxDiscount: Number(event.target.value) })} /></Field>
          <Field label="Usage limit"><input type="number" className={inputClass} value={form.usageLimit} onChange={(event) => setForm({ ...form, usageLimit: Number(event.target.value) })} /></Field>
          <Field label="Per-user limit"><input type="number" className={inputClass} value={form.perUserLimit} onChange={(event) => setForm({ ...form, perUserLimit: Number(event.target.value) })} /></Field>
          <Field label="Valid from"><input type="date" className={inputClass} value={form.validFrom} onChange={(event) => setForm({ ...form, validFrom: event.target.value })} /></Field>
          <Field label="Valid until"><input type="date" className={inputClass} value={form.validUntil} onChange={(event) => setForm({ ...form, validUntil: event.target.value })} /></Field>
          <Field label="Applicable service">
            <select className={inputClass} value={form.service} onChange={(event) => setForm({ ...form, service: event.target.value })}>
              <option>All</option>
              {vehicleCategoryNames().map((item) => <option key={item}>{item}</option>)}
            </select>
          </Field>
          <Field label="Customer type">
            <select className={inputClass} value={form.customerType} onChange={(event) => setForm({ ...form, customerType: event.target.value })}>
              <option>All</option><option>New</option><option>Repeat</option>
            </select>
          </Field>
        </div>
      </Modal>

      <Drawer open={Boolean(view)} size="lg" eyebrow="Coupon" title={view?.code} onClose={() => setView(null)} footer={<Button onClick={() => setView(null)}>Close</Button>}>
        {view ? (
          <DetailSection title="Details">
            <DetailRow label="Title" value={view.title} />
            <DetailRow label="Description" value={view.description} />
            <DetailRow label="Discount" value={`${discountLabel(view)} · max ${formatINR(view.maxDiscount)}`} />
            <DetailRow label="Min order" value={formatINR(view.minOrder)} />
            <DetailRow label="Usage" value={`${view.used}/${view.usageLimit} · ${view.perUserLimit}/user`} />
            <DetailRow label="Validity" value={`${view.validFrom} → ${view.validUntil}`} />
            <DetailRow label="Status" value={view.status} />
          </DetailSection>
        ) : null}
      </Drawer>

      <Modal
        open={Boolean(confirm)}
        title={confirm?.type === 'delete' ? 'Delete coupon?' : confirm?.type === 'deactivate' ? 'Deactivate coupon?' : 'Activate coupon?'}
        onClose={() => setConfirm(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirm(null)}>Cancel</Button>
            <Button
              variant={confirm?.type === 'activate' ? 'approve' : 'reject'}
              onClick={() => {
                if (confirm.type === 'delete') couponStore.remove(confirm.row.code, 'code');
                else couponStore.patch(confirm.row.code, { status: confirm.type === 'activate' ? 'Active' : 'Inactive' }, 'code');
                setConfirm(null);
              }}
            >
              {confirm?.type === 'delete' ? 'Delete coupon' : confirm?.type === 'deactivate' ? 'Deactivate' : 'Activate'}
            </Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">{confirm?.type === 'delete' ? 'This action cannot be undone.' : `${confirm?.row?.code} will change status.`}</p>
      </Modal>
    </PageContainer>
  );
}
