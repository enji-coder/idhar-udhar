import { useMemo } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Eye, Pencil, Plus, Trash2, UserPlus } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Select from '../components/common/Select';
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
import useQueryAction from '../hooks/useQueryAction';
import { riderStore, vehicleStore } from '../services/stores';
import { VEHICLE_STATUSES, TWO_WHEELER_TYPES } from '../data/vehicles';
import { defaultVehicleCategoryName, isTwoWheelerCategory, vehicleCategoryNames, vehicleCategoryStore } from '../services/vehicleCategories';
import { nextId } from '../utils/ids';
import { compactErrors, isVehicleRc, required } from '../utils/validation';
import { enrichVehicleRecord } from '../services/profileEnrichment';
import { useState } from 'react';

const emptyVehicle = {
  id: '',
  number: '',
  rcNumber: '',
  type: defaultVehicleCategoryName(),
  category: defaultVehicleCategoryName(),
  twoWheelerType: 'Bike',
  brand: '',
  model: '',
  variant: '',
  color: '',
  rider: 'Unassigned',
  riderId: '',
  status: 'Available',
  capacity: '',
  registered: '17 Aug 2026',
  lastService: '17 Aug 2026',
  insurance: 'Valid',
  rcExpiry: '17 Aug 2028',
  insuranceExpiry: '17 Aug 2027',
};

export default function Vehicles() {
  const { searchQuery } = useOutletContext() || {};
  const loading = useMockLoader();
  const rows = useStore(vehicleStore);
  const riders = useStore(riderStore);
  useStore(vehicleCategoryStore);
  const [status, setStatus] = useState('All');
  const [type, setType] = useState('All');
  const panel = usePanelState(emptyVehicle);
  useQueryAction('add', panel.openCreate);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.map((row) => enrichVehicleRecord(row, riders.find((item) => item.id === row.riderId || item.name === row.rider))).filter((row) => {
      const blob = `${row.id} ${row.number} ${row.rcNumber} ${row.type} ${row.brand} ${row.model} ${row.rider}`.toLowerCase();
      return blob.includes(query) && (status === 'All' || row.status === status) && (type === 'All' || row.category === type || row.type === type);
    });
  }, [rows, searchQuery, status, type, riders]);

  function save() {
    const rc = panel.form.rcNumber || panel.form.number;
    const issues = compactErrors({
      number: required(rc, 'Vehicle RC number cannot be empty.') || (isVehicleRc(rc) ? '' : 'Enter a valid RC number (e.g. GJ 01 RX 2145).'),
      capacity: required(panel.form.capacity, 'Capacity is required.'),
    });
    const duplicate = rows.some((row) => (row.rcNumber || row.number).replace(/\s/g, '').toUpperCase() === String(rc).replace(/\s/g, '').toUpperCase() && row.id !== panel.form.id);
    if (duplicate) issues.number = 'A vehicle with this RC number already exists.';
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    const rider = riders.find((item) => item.name === panel.form.rider);
    const id = panel.form.id || nextId('VH', rows);
    const category = panel.form.category || panel.form.type;
    vehicleStore.upsert({
      ...panel.form,
      id,
      number: rc,
      rcNumber: rc,
      type: category,
      category,
      riderId: rider?.id || '',
      rider: panel.form.rider || 'Unassigned',
    });
    panel.setToast(panel.mode === 'edit' ? 'Vehicle updated.' : 'Vehicle added.');
    panel.closeForm();
  }

  if (loading) return <TableSkeleton />;

  const columns = [
    { key: 'id', label: 'Vehicle ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'rcNumber', label: 'Vehicle RC Number', sortable: true, render: (row) => row.rcNumber || row.number },
    { key: 'category', label: 'Category', render: (row) => row.category || row.type },
    { key: 'brand', label: 'Brand', hideBelow: 'lg' },
    { key: 'model', label: 'Model', hideBelow: 'lg' },
    { key: 'rider', label: 'Assigned Rider', render: (row) => row.rider || 'Unassigned' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    { key: 'capacity', label: 'Capacity', hideBelow: 'lg' },
    { key: 'registered', label: 'Registration Date', hideBelow: 'lg' },
    { key: 'lastService', label: 'Last Service', hideBelow: 'lg' },
    { key: 'insurance', label: 'Insurance', render: (row) => <StatusBadge status={row.insurance} />, hideBelow: 'lg' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => panel.setView(row)}>View</ActionButton>
          <ActionButton icon={Pencil} tone="edit" onClick={() => panel.openEdit(row)}>Edit</ActionButton>
          <ActionButton icon={UserPlus} tone="reassign" onClick={() => panel.openEdit({ ...row, _assign: true })}>Assign Rider</ActionButton>
          <ActionButton icon={Trash2} tone="danger" onClick={() => panel.setConfirm(row)}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={panel.openCreate}>Add Vehicle</Button>} />
      <GlassCard className="flex flex-wrap gap-3">
        <Select aria-label="Status" value={status} onChange={setStatus} options={['All', ...VEHICLE_STATUSES]} />
        <Select aria-label="Type" value={type} onChange={setType} options={['All', ...vehicleCategoryNames({ includeInactive: true })]} />
      </GlassCard>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState title="No vehicles found" description="Add a fleet vehicle or clear filters." action={<Button variant="secondary" onClick={() => { setStatus('All'); setType('All'); }}>Clear Filters</Button>} />
        ) : (
          <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="vehicles" mobileTitleKey="number" />
        )}
      </GlassCard>

      <Modal
        open={Boolean(panel.mode)}
        title={panel.mode === 'edit' ? (panel.form._assign ? 'Assign rider' : 'Edit vehicle') : 'Add Vehicle'}
        onClose={panel.closeForm}
        footer={<><Button variant="ghost" onClick={panel.closeForm}>Cancel</Button><Button onClick={save}>Save</Button></>}
      >
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Vehicle RC number" error={panel.errors.number}><input className={inputClass} value={panel.form.rcNumber || panel.form.number} onChange={(event) => panel.setForm({ ...panel.form, rcNumber: event.target.value, number: event.target.value })} /></Field>
          <Field label="Vehicle category">
            <select className={inputClass} value={panel.form.category || panel.form.type} onChange={(event) => panel.setForm({ ...panel.form, category: event.target.value, type: event.target.value })}>
              {vehicleCategoryNames({ current: panel.form.category || panel.form.type }).map((item) => <option key={item}>{item}</option>)}
            </select>
          </Field>
          {isTwoWheelerCategory(panel.form.category || panel.form.type) ? (
            <Field label="Bike / Scooter">
              <select className={inputClass} value={panel.form.twoWheelerType || 'Bike'} onChange={(event) => panel.setForm({ ...panel.form, twoWheelerType: event.target.value })}>
                {TWO_WHEELER_TYPES.map((item) => <option key={item}>{item}</option>)}
              </select>
            </Field>
          ) : null}
          <Field label="Brand / company name"><input className={inputClass} value={panel.form.brand || ''} onChange={(event) => panel.setForm({ ...panel.form, brand: event.target.value })} /></Field>
          <Field label="Model"><input className={inputClass} value={panel.form.model || ''} onChange={(event) => panel.setForm({ ...panel.form, model: event.target.value })} /></Field>
          <Field label="Variant"><input className={inputClass} value={panel.form.variant || ''} onChange={(event) => panel.setForm({ ...panel.form, variant: event.target.value })} /></Field>
          <Field label="Vehicle color"><input className={inputClass} value={panel.form.color || ''} onChange={(event) => panel.setForm({ ...panel.form, color: event.target.value })} /></Field>
          <Field label="Assigned rider">
            <select className={inputClass} value={panel.form.rider} onChange={(event) => panel.setForm({ ...panel.form, rider: event.target.value })}>
              <option>Unassigned</option>
              {riders.map((item) => <option key={item.id}>{item.name}</option>)}
            </select>
          </Field>
          <Field label="Status">
            <select className={inputClass} value={panel.form.status} onChange={(event) => panel.setForm({ ...panel.form, status: event.target.value })}>
              {VEHICLE_STATUSES.map((item) => <option key={item}>{item}</option>)}
            </select>
          </Field>
          <Field label="Capacity" error={panel.errors.capacity}><input className={inputClass} value={panel.form.capacity} onChange={(event) => panel.setForm({ ...panel.form, capacity: event.target.value })} /></Field>
          <Field label="Insurance">
            <select className={inputClass} value={panel.form.insurance} onChange={(event) => panel.setForm({ ...panel.form, insurance: event.target.value })}>
              <option>Valid</option><option>Expiring</option><option>Pending</option><option>Expired</option>
            </select>
          </Field>
          <Field label="Registration date"><input className={inputClass} value={panel.form.registered} onChange={(event) => panel.setForm({ ...panel.form, registered: event.target.value })} /></Field>
          <Field label="RC expiry"><input className={inputClass} value={panel.form.rcExpiry || ''} onChange={(event) => panel.setForm({ ...panel.form, rcExpiry: event.target.value })} /></Field>
          <Field label="Insurance expiry"><input className={inputClass} value={panel.form.insuranceExpiry || ''} onChange={(event) => panel.setForm({ ...panel.form, insuranceExpiry: event.target.value })} /></Field>
          <Field label="Last service"><input className={inputClass} value={panel.form.lastService} onChange={(event) => panel.setForm({ ...panel.form, lastService: event.target.value })} /></Field>
        </div>
      </Modal>

      <Drawer open={Boolean(panel.view)} size="lg" eyebrow="Vehicle" title={panel.view?.number} onClose={() => panel.setView(null)} footer={<Button onClick={() => panel.setView(null)}>Close</Button>}>
        {panel.view ? (
          <DetailSection title="Fleet record">
            <DetailRow label="Vehicle ID" value={panel.view.id} />
            <DetailRow label="RC Number" value={panel.view.rcNumber || panel.view.number} />
            <DetailRow label="Category" value={panel.view.category || panel.view.type} />
            <DetailRow label="Brand" value={panel.view.brand || 'N/A'} />
            <DetailRow label="Model" value={panel.view.model || 'N/A'} />
            <DetailRow label="Variant" value={panel.view.variant || 'N/A'} />
            <DetailRow label="Color" value={panel.view.color || 'N/A'} />
            <DetailRow label="Bike/Scooter" value={panel.view.twoWheelerType || 'N/A'} />
            <DetailRow label="Assigned rider" value={panel.view.rider || 'Unassigned'} />
            <DetailRow label="Status" value={panel.view.status} />
            <DetailRow label="Capacity" value={panel.view.capacity} />
            <DetailRow label="Registered" value={panel.view.registered} />
            <DetailRow label="Last service" value={panel.view.lastService} />
            <DetailRow label="Insurance" value={panel.view.insurance} />
          </DetailSection>
        ) : null}
      </Drawer>

      <ConfirmDialog
        open={Boolean(panel.confirm)}
        description={`${panel.confirm?.number} will be removed from the fleet list.`}
        onClose={() => panel.setConfirm(null)}
        onConfirm={() => { vehicleStore.remove(panel.confirm.id); panel.setConfirm(null); panel.setToast('Vehicle deleted.'); }}
      />
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
