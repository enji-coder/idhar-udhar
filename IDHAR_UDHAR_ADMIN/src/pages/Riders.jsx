import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useOutletContext, useSearchParams } from 'react-router-dom';
import { Bike, CircleCheck, Eye, Pause, Pencil, Plus, Radio, ShieldAlert, Trash2, Wallet, WifiOff } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import KpiCard from '../components/common/KpiCard';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Select from '../components/common/Select';
import EmptyState from '../components/common/EmptyState';
import Modal from '../components/common/Modal';
import Field, { inputClass } from '../components/common/Field';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import ConfirmDialog from '../components/common/ConfirmDialog';
import Toast from '../components/common/Toast';
import PageHeader from '../components/common/PageHeader';
import Drawer from '../components/common/Drawer';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import useQueryAction from '../hooks/useQueryAction';
import { riderStore, vehicleStore } from '../services/stores';
import { defaultVehicleCategoryName, vehicleCategoryNames, vehicleCategoryStore } from '../services/vehicleCategories';
import { riderMetrics, earnings } from '../data/mockData';
import { useAuth } from '../context/AuthContext';
import { formatINR, initials } from '../utils/format';
import { nextId } from '../utils/ids';
import { compactErrors, required } from '../utils/validation';

const icons = { total: Bike, active: Radio, offline: WifiOff, busy: ShieldAlert, pending: CircleCheck };

export default function Riders() {
  const navigate = useNavigate();
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const [params, setParams] = useSearchParams();
  const loading = useMockLoader();
  const riders = useStore(riderStore);
  const vehicles = useStore(vehicleStore);
  useStore(vehicleCategoryStore);
  const categoryOptions = vehicleCategoryNames();
  const [status, setStatus] = useState(params.get('status') || 'All');
  const [edit, setEdit] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [create, setCreate] = useState(false);
  const [draft, setDraft] = useState({ name: '', phone: '', vehicle: defaultVehicleCategoryName(), zone: 'Navrangpura', status: 'Pending' });
  const [errors, setErrors] = useState({});
  const [toast, setToast] = useState('');
  const [earningsRow, setEarningsRow] = useState(null);
  useQueryAction('add', () => setCreate(true));

  useEffect(() => {
    const next = params.get('status');
    if (next) setStatus(next);
  }, [params]);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return riders.filter((row) => {
      const matches = `${row.name} ${row.phone} ${row.vehicle} ${row.zone}`.toLowerCase().includes(query);
      return matches && (status === 'All' || row.status === status);
    });
  }, [riders, searchQuery, status]);

  if (loading) return <TableSkeleton />;

  function setStatusFilter(value) {
    setStatus(value);
    const next = new URLSearchParams(params);
    if (value === 'All') next.delete('status');
    else next.set('status', value);
    setParams(next, { replace: true });
  }

  const columns = [
    {
      key: 'name',
      label: 'Rider',
      sortable: true,
      render: (row) => (
        <div className="flex items-center gap-3">
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-brand-500 text-xs font-bold text-white">{initials(row.name)}</span>
          <div>
            <p className="font-semibold">{row.name}</p>
            <p className="text-xs text-ink-muted">{row.id}</p>
          </div>
        </div>
      ),
    },
    { key: 'phone', label: 'Phone' },
    { key: 'vehicle', label: 'Vehicle' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    { key: 'deliveries', label: 'Total Deliveries', sortable: true, hideBelow: 'lg' },
    { key: 'rating', label: 'Rating', sortable: true },
    { key: 'earnings', label: 'Earnings', sortable: true, render: (row) => formatINR(row.earnings), hideBelow: 'lg' },
    { key: 'joined', label: 'Joined Date', hideBelow: 'lg', render: (row) => row.joined || '12 Jan 2026' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => navigate(`/riders/${row.id}`)}>View</ActionButton>
          {can('riders', 'edit') ? <ActionButton icon={Pencil} tone="edit" onClick={() => setEdit(row)}>Edit</ActionButton> : null}
          {can('riders', 'edit') ? <ActionButton icon={Bike} tone="reassign" onClick={() => setEdit({ ...row, _assign: true })}>Assign Vehicle</ActionButton> : null}
          <ActionButton icon={Wallet} tone="invoice" onClick={() => setEarningsRow(row)}>View Earnings</ActionButton>
          {can('riders', 'approve') && row.verification !== 'Approved' ? <ActionButton icon={CircleCheck} tone="approve" onClick={() => riderStore.patch(row.id, { verification: 'Approved', status: 'Active' })}>Approve</ActionButton> : null}
          {can('riders', 'suspend') && row.status !== 'Suspended' && row.status !== 'Pending' ? <ActionButton icon={Pause} tone="danger" onClick={() => setConfirm({ type: 'suspend', row })}>Deactivate</ActionButton> : null}
          {can('riders', 'activate') && (row.status === 'Suspended' || row.status === 'Offline') ? <ActionButton icon={CircleCheck} tone="approve" onClick={() => riderStore.patch(row.id, { status: 'Active' })}>Activate</ActionButton> : null}
          <ActionButton icon={Trash2} tone="danger" onClick={() => setConfirm({ type: 'delete', row })}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={() => { setDraft({ name: '', phone: '', vehicle: defaultVehicleCategoryName(), zone: 'Navrangpura', status: 'Pending' }); setErrors({}); setCreate(true); }}>Add Rider</Button>} />
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-5">
        {riderMetrics.map((kpi) => (
          <KpiCard key={kpi.id} icon={icons[kpi.id]} {...kpi} onClick={kpi.id === 'active' ? () => setStatusFilter('Active') : undefined} />
        ))}
      </section>
      <GlassCard className="flex flex-wrap gap-3">
        <Select aria-label="Status" value={status} onChange={setStatusFilter} options={['All', 'Active', 'Busy', 'Offline', 'Pending', 'Suspended']} />
      </GlassCard>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No riders found" description="Try changing your filters or search criteria." action={<Button variant="secondary" onClick={() => setStatusFilter('All')}>Clear Filters</Button>} /> : <DataTable columns={columns} data={data} mobileTitleKey="name" pageSize={8} itemLabel="riders" compact />}
      </GlassCard>

      <Modal open={Boolean(edit)} title={edit?._assign ? 'Assign vehicle' : 'Edit rider'} onClose={() => setEdit(null)} footer={<><Button variant="ghost" onClick={() => setEdit(null)}>Cancel</Button><Button onClick={() => { if (!edit.phone?.trim()) return; riderStore.upsert(edit); setEdit(null); setToast('Rider updated.'); }}>Save</Button></>}>
        {edit ? (
          <div className="space-y-3">
            <Field label="Name"><input className={inputClass} value={edit.name} onChange={(event) => setEdit({ ...edit, name: event.target.value })} /></Field>
            <Field label="Phone"><input className={inputClass} value={edit.phone} onChange={(event) => setEdit({ ...edit, phone: event.target.value })} /></Field>
            <Field label="Vehicle"><select className={inputClass} value={edit.vehicle} onChange={(event) => setEdit({ ...edit, vehicle: event.target.value })}>{vehicleCategoryNames({ current: edit.vehicle }).map((item) => <option key={item}>{item}</option>)}</select></Field>
            <Field label="Vehicle number">
              <select className={inputClass} value={edit.vehicleNumber || ''} onChange={(event) => setEdit({ ...edit, vehicleNumber: event.target.value })}>
                <option value="">Unassigned</option>
                {vehicles.map((item) => <option key={item.id} value={item.number}>{item.number}</option>)}
              </select>
            </Field>
            <Field label="Zone"><input className={inputClass} value={edit.zone} onChange={(event) => setEdit({ ...edit, zone: event.target.value })} /></Field>
          </div>
        ) : null}
      </Modal>

      <Modal open={create} title="Add Rider" onClose={() => setCreate(false)} footer={<><Button variant="ghost" onClick={() => setCreate(false)}>Cancel</Button><Button onClick={() => {
        const issues = compactErrors({ name: required(draft.name, 'Name is required.'), phone: required(draft.phone, 'Phone number cannot be empty.') });
        setErrors(issues);
        if (Object.keys(issues).length) return;
        riderStore.upsert({ id: nextId('R', riders), ...draft, rating: 0, deliveries: 0, earnings: 0, verification: 'Pending', onTime: 0, cancelRate: 0, score: 0, monthDeliveries: 0, joined: '17 Aug 2026' });
        setCreate(false);
        setToast('Rider added.');
      }}>Save</Button></>}>
        <div className="space-y-3">
          <Field label="Name" error={errors.name}><input className={inputClass} value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></Field>
          <Field label="Phone" error={errors.phone}><input className={inputClass} value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} /></Field>
          <Field label="Vehicle"><select className={inputClass} value={draft.vehicle} onChange={(event) => setDraft({ ...draft, vehicle: event.target.value })}>{categoryOptions.map((item) => <option key={item}>{item}</option>)}</select></Field>
          <Field label="Zone"><input className={inputClass} value={draft.zone} onChange={(event) => setDraft({ ...draft, zone: event.target.value })} /></Field>
        </div>
      </Modal>

      <Drawer open={Boolean(earningsRow)} size="lg" eyebrow="Earnings" title={earningsRow?.name} onClose={() => setEarningsRow(null)} footer={<Button onClick={() => setEarningsRow(null)}>Close</Button>}>
        {earningsRow ? (
          <DetailSection title="Rider earnings">
            <DetailRow label="Lifetime" value={formatINR(earningsRow.earnings)} />
            <DetailRow label="Deliveries" value={earningsRow.deliveries} />
            <DetailRow label="Today" value={formatINR(earnings.find((item) => item.rider === earningsRow.name)?.total || 0)} />
          </DetailSection>
        ) : null}
      </Drawer>

      <Modal
        open={Boolean(confirm) && confirm?.type !== 'delete'}
        title={confirm?.type === 'suspend' ? 'Deactivate rider?' : 'Reject rider?'}
        onClose={() => setConfirm(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirm(null)}>Cancel</Button>
            <Button variant="reject" onClick={() => {
              if (confirm.type === 'suspend') riderStore.patch(confirm.row.id, { status: 'Suspended' });
              else riderStore.patch(confirm.row.id, { verification: 'Rejected', status: 'Offline' });
              setConfirm(null);
              setToast('Rider updated.');
            }}>{confirm?.type === 'suspend' ? 'Deactivate' : 'Reject'}</Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">This will immediately change {confirm?.row?.name}'s access in the mock fleet.</p>
      </Modal>
      <ConfirmDialog
        open={confirm?.type === 'delete'}
        description={`${confirm?.row?.name} will be removed from the rider list.`}
        onClose={() => setConfirm(null)}
        onConfirm={() => { riderStore.remove(confirm.row.id); setConfirm(null); setToast('Rider deleted.'); }}
      />
      <Toast open={Boolean(toast)} message={toast} onClose={() => setToast('')} />
    </PageContainer>
  );
}
