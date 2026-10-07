import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useOutletContext, useSearchParams } from 'react-router-dom';
import { Bike, CircleCheck, Eye, Pause, Plus, Radio, ShieldAlert, Trash2, Wallet, WifiOff } from 'lucide-react';
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
import useStore from '../hooks/useStore';
import useQueryAction from '../hooks/useQueryAction';
import { riderStore } from '../services/stores';
import { defaultVehicleCategoryName, vehicleCategoryNames, vehicleCategoryStore } from '../services/vehicleCategories';
import { useAuth } from '../context/AuthContext';
import { formatINR, initials } from '../utils/format';
import { compactErrors, required } from '../utils/validation';
import { approveAdminDocument, deleteAdminRider, fetchAdminRiderDocuments, fetchAdminRiders } from '../api/adminApi';

const icons = { total: Bike, active: Radio, offline: WifiOff, busy: ShieldAlert, pending: CircleCheck };

export default function Riders() {
  const navigate = useNavigate();
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const [params, setParams] = useSearchParams();
  const riders = useStore(riderStore);
  useStore(vehicleCategoryStore);
  const categoryOptions = vehicleCategoryNames();
  const [status, setStatus] = useState(params.get('status') || 'All');
  const [confirm, setConfirm] = useState(null);
  const [workingId, setWorkingId] = useState('');
  const workingRef = useRef(false);
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

  const riderKpis = [
    { id: 'total', title: 'Total Riders', value: String(riders.length), trend: 0, note: 'Directory', spark: [riders.length] },
    { id: 'active', title: 'Active', value: String(riders.filter((row) => row.status === 'Active').length), trend: 0, note: 'On duty', spark: [riders.filter((row) => row.status === 'Active').length] },
    { id: 'offline', title: 'Offline', value: String(riders.filter((row) => row.status === 'Offline').length), trend: 0, note: 'Not online', spark: [riders.filter((row) => row.status === 'Offline').length] },
    { id: 'busy', title: 'Busy', value: String(riders.filter((row) => row.status === 'Busy').length), trend: 0, note: 'On a delivery', spark: [riders.filter((row) => row.status === 'Busy').length] },
    { id: 'pending', title: 'Pending Verification', value: String(riders.filter((row) => row.status === 'Pending').length), trend: 0, note: 'KYC queue', spark: [riders.filter((row) => row.status === 'Pending').length] },
  ];

  async function refreshRiders() {
    riderStore.replace(await fetchAdminRiders());
  }

  async function approveRider(row) {
    if (!row?.id || workingRef.current) return;
    workingRef.current = true;
    setWorkingId(row.id);
    try {
      const listed = await fetchAdminRiderDocuments(row.id);
      const pending = (listed?.documents || []).filter(
        (doc) => doc?.is_current !== false && doc.rider_document_id && doc.status !== 'APPROVED',
      );
      let approvalStatus = listed?.approval_status || row.approval || 'PENDING';
      if (pending.length === 0) {
        try {
          await refreshRiders();
        } catch {
          // The document list already reported the stored approval state.
        }
        setToast(
          approvalStatus === 'APPROVED'
            ? 'This rider is already approved.'
            : 'This rider cannot be approved until the required documents are uploaded.',
        );
        return;
      }
      for (const doc of pending) {
        const result = await approveAdminDocument(doc.rider_document_id);
        approvalStatus = result?.approval_status || approvalStatus;
      }
      try {
        await refreshRiders();
      } catch (error) {
        setToast(error?.message || 'The decision was saved, but the rider list could not be refreshed.');
        return;
      }
      setToast(
        approvalStatus === 'APPROVED'
          ? 'Rider approved.'
          : 'Documents were saved, but the rider stays pending until every required document is approved.',
      );
    } catch (error) {
      try {
        await refreshRiders();
      } catch {
        // Keep the approval error. A later refresh still reads the stored decision.
      }
      setToast(error?.message || 'Could not approve the rider.');
    } finally {
      workingRef.current = false;
      setWorkingId('');
    }
  }

  async function deleteRider(row) {
    if (!row?.id || workingRef.current) return;
    workingRef.current = true;
    setWorkingId(row.id);
    try {
      await deleteAdminRider(row.id);
      try {
        await refreshRiders();
      } catch {
        riderStore.remove(row.id);
      }
      setToast('Rider deleted.');
    } catch (error) {
      setToast(error?.message || 'Could not delete the rider.');
    } finally {
      workingRef.current = false;
      setWorkingId('');
    }
  }

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
    { key: 'joined', label: 'Joined Date', hideBelow: 'lg', render: (row) => row.joined || 'N/A' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => navigate(`/riders/${row.id}`)}>View</ActionButton>
          <ActionButton icon={Wallet} tone="invoice" onClick={() => setEarningsRow(row)}>View Earnings</ActionButton>
          {can('riders', 'approve') && row.verification !== 'Approved' ? <ActionButton icon={CircleCheck} tone="approve" loading={workingId === row.id} disabled={Boolean(workingId)} onClick={() => approveRider(row)}>Approve</ActionButton> : null}
          {can('riders', 'suspend') && row.status !== 'Suspended' && row.status !== 'Pending' ? <ActionButton icon={Pause} tone="danger" onClick={() => setConfirm({ type: 'suspend', row })}>Deactivate</ActionButton> : null}
          {can('riders', 'activate') && (row.status === 'Suspended' || row.status === 'Offline') ? <ActionButton icon={CircleCheck} tone="approve" onClick={() => setToast('Rider activation is not available on the server yet.')}>Activate</ActionButton> : null}
          <ActionButton icon={Trash2} tone="danger" disabled={Boolean(workingId)} onClick={() => setConfirm({ type: 'delete', row })}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={() => { setDraft({ name: '', phone: '', vehicle: defaultVehicleCategoryName(), zone: 'Navrangpura', status: 'Pending' }); setErrors({}); setCreate(true); }}>Add Rider</Button>} />
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-5">
        {riderKpis.map((kpi) => (
          <KpiCard key={kpi.id} icon={icons[kpi.id]} {...kpi} onClick={kpi.id === 'active' ? () => setStatusFilter('Active') : undefined} />
        ))}
      </section>
      <GlassCard className="flex flex-wrap gap-3">
        <Select aria-label="Status" value={status} onChange={setStatusFilter} options={['All', 'Active', 'Busy', 'Offline', 'Pending', 'Suspended']} />
      </GlassCard>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No riders found" description="Try changing your filters or search criteria." action={<Button variant="secondary" onClick={() => setStatusFilter('All')}>Clear Filters</Button>} /> : <DataTable columns={columns} data={data} mobileTitleKey="name" pageSize={8} itemLabel="riders" compact />}
      </GlassCard>

      <Modal open={create} title="Add Rider" onClose={() => setCreate(false)} footer={<><Button variant="ghost" onClick={() => setCreate(false)}>Cancel</Button><Button onClick={() => {
        const issues = compactErrors({ name: required(draft.name, 'Name is required.'), phone: required(draft.phone, 'Phone number cannot be empty.') });
        setErrors(issues);
        if (Object.keys(issues).length) return;
        setCreate(false);
        setToast('Adding riders from Admin is not available on the server yet.');
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
            <DetailRow label="Today" value={formatINR(0)} />
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
              setConfirm(null);
              setToast('Changing rider access from Admin is not available on the server yet.');
            }}>{confirm?.type === 'suspend' ? 'Deactivate' : 'Reject'}</Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">This would change {confirm?.row?.name}'s access. Rider status is owned by the server.</p>
      </Modal>
      <ConfirmDialog
        open={confirm?.type === 'delete'}
        description={`${confirm?.row?.name} will be removed from the rider list.`}
        onClose={() => setConfirm(null)}
        onConfirm={() => {
          const row = confirm?.row;
          setConfirm(null);
          if (row) deleteRider(row);
        }}
      />
      <Toast open={Boolean(toast)} message={toast} onClose={() => setToast('')} />
    </PageContainer>
  );
}
