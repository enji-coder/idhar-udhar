import { Eye, Pencil, Plus, Power, Trash2 } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import Button from '../components/common/Button';
import ConfirmDialog from '../components/common/ConfirmDialog';
import DataTable from '../components/common/DataTable';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import Drawer from '../components/common/Drawer';
import EmptyState from '../components/common/EmptyState';
import ErrorState from '../components/common/ErrorState';
import Field, { inputClass } from '../components/common/Field';
import GlassCard from '../components/common/GlassCard';
import Modal from '../components/common/Modal';
import PageHeader from '../components/common/PageHeader';
import { TableSkeleton } from '../components/common/Skeleton';
import StatusBadge from '../components/common/StatusBadge';
import Toast from '../components/common/Toast';
import PageContainer from '../components/layout/PageContainer';
import usePanelState from '../hooks/usePanelState';
import useQueryAction from '../hooks/useQueryAction';
import useStore from '../hooks/useStore';
import { VEHICLE_CATEGORY_STATUSES } from '../data/vehicleCategories';
import {
  activateVehicleCategory,
  categoryUsage,
  deactivateVehicleCategory,
  deleteVehicleCategory,
  saveVehicleCategory,
  syncVehicleCategories,
  vehicleCategoryStore,
} from '../services/vehicleCategories';
import { formatAppDate, parseAppDate } from '../utils/dates';

const emptyCategory = {
  id: '',
  name: '',
  status: 'Active',
  baseFare: '',
  perKmCharge: '',
  initialMinimum: '',
  waitingCharge: '',
  surgeCharge: '',
  tollCharge: '',
  parkingCharge: '',
  weightCapacityKg: '',
  size: '',
};

export default function VehicleCategories() {
  const { searchQuery } = useOutletContext() || {};
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const rows = useStore(vehicleCategoryStore);
  const panel = usePanelState(emptyCategory);
  useQueryAction('add', panel.openCreate);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    syncVehicleCategories()
      .then(() => {
        if (!cancelled) setLoadError(null);
      })
      .catch((error) => {
        if (!cancelled) setLoadError(error);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => `${row.id} ${row.name} ${row.status}`.toLowerCase().includes(query));
  }, [rows, searchQuery]);

  async function save() {
    try {
      const result = await saveVehicleCategory(panel.form);
      panel.setErrors(result.issues || {});
      if (!result.ok) return;
      panel.setToast(panel.mode === 'edit' ? 'Vehicle category updated.' : 'Vehicle category added.');
      panel.closeForm();
    } catch (error) {
      panel.setToast(error.message || 'Could not save vehicle category.');
    }
  }

  async function confirmDelete() {
    try {
      const result = await deleteVehicleCategory(panel.confirm.id);
      if (!result.ok) {
        panel.setToast(result.message);
        panel.setConfirm(null);
        return;
      }
      panel.setConfirm(null);
      panel.setToast('Vehicle category deleted.');
    } catch (error) {
      panel.setToast(error.message || 'Could not delete vehicle category.');
      panel.setConfirm(null);
    }
  }

  if (loading) return <TableSkeleton />;
  if (loadError) {
    return (
      <ErrorState
        title="Couldn't load vehicle categories"
        description={loadError.message || 'The Admin Panel could not load vehicle categories from NestJS. Dummy records are not shown.'}
        onRetry={() => {
          setLoading(true);
          syncVehicleCategories()
            .then(() => setLoadError(null))
            .catch((error) => setLoadError(error))
            .finally(() => setLoading(false));
        }}
      />
    );
  }

  const columns = [
    { key: 'id', label: 'Category ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'name', label: 'Vehicle Category', sortable: true },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    { key: 'updatedAt', label: 'Updated', hideBelow: 'lg', render: (row) => formatAppDate(parseAppDate(row.updatedAt) || new Date(row.updatedAt)) },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => panel.setView(row)}>View</ActionButton>
          <ActionButton icon={Pencil} tone="edit" onClick={() => panel.openEdit(row)}>Edit</ActionButton>
          <ActionButton
            icon={Power}
            tone={row.status === 'Active' ? 'danger' : 'approve'}
            onClick={async () => {
              try {
                if (row.status === 'Active') await deactivateVehicleCategory(row.id);
                else await activateVehicleCategory(row.id);
                panel.setToast(row.status === 'Active' ? 'Vehicle category deactivated.' : 'Vehicle category activated.');
              } catch (error) {
                panel.setToast(error.message || 'Could not update vehicle category.');
              }
            }}
          >
            {row.status === 'Active' ? 'Deactivate' : 'Activate'}
          </ActionButton>
          <ActionButton icon={Trash2} tone="danger" onClick={() => panel.setConfirm(row)}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  const confirmUsage = panel.confirm ? categoryUsage(panel.confirm) : null;

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={panel.openCreate}>Add Vehicle Category</Button>} />
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState title="No records found" description="Add a vehicle category for riders and customers to select." action={<Button icon={Plus} variant="secondary" onClick={panel.openCreate}>Add Vehicle Category</Button>} />
        ) : (
          <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="categories" mobileTitleKey="name" />
        )}
      </GlassCard>

      <Modal
        open={Boolean(panel.mode)}
        title={panel.mode === 'edit' ? 'Edit vehicle category' : 'Add Vehicle Category'}
        onClose={panel.closeForm}
        footer={<><Button variant="ghost" onClick={panel.closeForm}>Cancel</Button><Button onClick={save}>Save</Button></>}
      >
        <div className="space-y-3">
          <Field label="Vehicle Category" error={panel.errors.name}>
            <input className={inputClass} value={panel.form.name} onChange={(event) => panel.setForm({ ...panel.form, name: event.target.value })} placeholder="Truck" />
          </Field>
          <Field label="Status">
            <select className={inputClass} value={panel.form.status || 'Active'} onChange={(event) => panel.setForm({ ...panel.form, status: event.target.value })}>
              {VEHICLE_CATEGORY_STATUSES.map((item) => <option key={item}>{item}</option>)}
            </select>
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Base Fare"><input type="number" className={inputClass} value={panel.form.baseFare ?? ''} onChange={(event) => panel.setForm({ ...panel.form, baseFare: event.target.value })} /></Field>
            <Field label="Per KM Charge"><input type="number" className={inputClass} value={panel.form.perKmCharge ?? ''} onChange={(event) => panel.setForm({ ...panel.form, perKmCharge: event.target.value })} /></Field>
            <Field label="Initial Minimum"><input type="number" className={inputClass} value={panel.form.initialMinimum ?? ''} onChange={(event) => panel.setForm({ ...panel.form, initialMinimum: event.target.value })} /></Field>
            <Field label="Waiting Charge"><input type="number" className={inputClass} value={panel.form.waitingCharge ?? ''} onChange={(event) => panel.setForm({ ...panel.form, waitingCharge: event.target.value })} /></Field>
            <Field label="Surge Charge"><input type="number" className={inputClass} value={panel.form.surgeCharge ?? ''} onChange={(event) => panel.setForm({ ...panel.form, surgeCharge: event.target.value })} /></Field>
            <Field label="Toll Charge"><input type="number" className={inputClass} value={panel.form.tollCharge ?? ''} onChange={(event) => panel.setForm({ ...panel.form, tollCharge: event.target.value })} /></Field>
            <Field label="Parking Charge"><input type="number" className={inputClass} value={panel.form.parkingCharge ?? ''} onChange={(event) => panel.setForm({ ...panel.form, parkingCharge: event.target.value })} /></Field>
            <Field label="Weight Capacity"><input className={inputClass} value={panel.form.weightCapacityKg ?? ''} onChange={(event) => panel.setForm({ ...panel.form, weightCapacityKg: event.target.value })} /></Field>
          </div>
          <Field label="Size"><input className={inputClass} value={panel.form.size ?? ''} onChange={(event) => panel.setForm({ ...panel.form, size: event.target.value })} /></Field>
        </div>
      </Modal>

      <Drawer open={Boolean(panel.view)} size="lg" eyebrow="Vehicle Category" title={panel.view?.name} onClose={() => panel.setView(null)} footer={<Button onClick={() => panel.setView(null)}>Close</Button>}>
        {panel.view ? (
          <DetailSection title="Category record">
            <DetailRow label="Category ID" value={panel.view.id} />
            <DetailRow label="Name" value={panel.view.name} />
            <DetailRow label="Status" value={panel.view.status} />
            <DetailRow label="Created" value={formatAppDate(parseAppDate(panel.view.createdAt) || new Date(panel.view.createdAt))} />
            <DetailRow label="Updated" value={formatAppDate(parseAppDate(panel.view.updatedAt) || new Date(panel.view.updatedAt))} />
            <DetailRow label="Base Fare" value={panel.view.baseFare} />
            <DetailRow label="Per KM Charge" value={panel.view.perKmCharge} />
            <DetailRow label="Initial Minimum" value={panel.view.initialMinimum} />
            <DetailRow label="Waiting Charge" value={panel.view.waitingCharge} />
            <DetailRow label="Surge Charge" value={panel.view.surgeCharge} />
            <DetailRow label="Toll Charge" value={panel.view.tollCharge} />
            <DetailRow label="Parking Charge" value={panel.view.parkingCharge} />
            <DetailRow label="Weight Capacity" value={panel.view.weightCapacityKg} />
            <DetailRow label="Size" value={panel.view.size} />
          </DetailSection>
        ) : null}
      </Drawer>

      <ConfirmDialog
        open={Boolean(panel.confirm)}
        title={confirmUsage?.total ? 'Cannot delete this vehicle category' : 'Delete vehicle category?'}
        description={
          confirmUsage?.total
            ? 'Cannot delete this vehicle category because it is already used by published fare data or other protected records. Please deactivate it instead.'
            : `${panel.confirm?.name} will be removed from selectable vehicle types.`
        }
        confirmLabel={confirmUsage?.total ? 'Deactivate instead' : 'Delete'}
        onClose={() => panel.setConfirm(null)}
        onConfirm={async () => {
          if (confirmUsage?.total) {
            try {
              await deactivateVehicleCategory(panel.confirm.id);
              panel.setConfirm(null);
              panel.setToast('Vehicle category deactivated.');
            } catch (error) {
              panel.setToast(error.message || 'Could not deactivate vehicle category.');
            }
            return;
          }
          confirmDelete();
        }}
      />
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
