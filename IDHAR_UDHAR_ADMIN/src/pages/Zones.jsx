import { useEffect, useMemo, useState } from 'react';
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
import ErrorState from '../components/common/ErrorState';
import Field, { inputClass } from '../components/common/Field';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import ConfirmDialog from '../components/common/ConfirmDialog';
import Toast from '../components/common/Toast';
import PageHeader from '../components/common/PageHeader';
import { TableSkeleton } from '../components/common/Skeleton';
import useStore from '../hooks/useStore';
import usePanelState from '../hooks/usePanelState';
import useQueryAction from '../hooks/useQueryAction';
import { zoneStore } from '../services/stores';
import { compactErrors, required } from '../utils/validation';
import { createAdminZone, deleteAdminZone, fetchAdminZones, updateAdminZone } from '../api/adminApi';
import { ApiError } from '../api/errors';

const emptyZone = { id: '', name: '', area: '', activeRiders: 0, orders: 0, status: 'Active' };

export default function Zones() {
  const { searchQuery } = useOutletContext() || {};
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const rows = useStore(zoneStore);
  const panel = usePanelState(emptyZone);
  useQueryAction('add', panel.openCreate);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    fetchAdminZones()
      .then((next) => {
        if (!cancelled) {
          zoneStore.replace(next);
          setLoadError(null);
        }
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
    return rows.filter((row) => `${row.id} ${row.name} ${row.area}`.toLowerCase().includes(query));
  }, [rows, searchQuery]);

  async function save() {
    const issues = compactErrors({
      name: required(panel.form.name, 'Zone name is required.'),
    });
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    try {
      const payload = { name: panel.form.name, active: panel.form.status !== 'Inactive' };
      if (panel.form.id) {
        zoneStore.upsert(await updateAdminZone(panel.form.id, payload));
        panel.setToast('Zone updated.');
      } else {
        zoneStore.upsert(await createAdminZone(payload));
        panel.setToast('Zone created.');
      }
      panel.closeForm();
    } catch (error) {
      if (error instanceof ApiError && error.code === 'ZONE_NAME_TAKEN') {
        panel.setErrors({ name: error.message });
        return;
      }
      panel.setToast(error.message || 'Could not save zone.');
    }
  }

  if (loading) return <TableSkeleton />;
  if (loadError) {
    return (
      <ErrorState
        title="Couldn't load zones"
        description={loadError.message || 'The Admin Panel could not load zones from NestJS. Dummy records are not shown.'}
        onRetry={() => {
          setLoading(true);
          fetchAdminZones()
            .then((next) => {
              zoneStore.replace(next);
              setLoadError(null);
            })
            .catch((error) => setLoadError(error))
            .finally(() => setLoading(false));
        }}
      />
    );
  }

  const columns = [
    { key: 'id', label: 'Zone ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'name', label: 'Zone Name', sortable: true },
    { key: 'area', label: 'Area' },
    { key: 'activeRiders', label: 'Active Riders', sortable: true },
    { key: 'orders', label: 'Orders', sortable: true },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => panel.setView(row)}>View</ActionButton>
          <ActionButton icon={Pencil} tone="edit" onClick={() => panel.openEdit(row)}>Edit</ActionButton>
          <ActionButton icon={Power} tone={row.status === 'Active' ? 'danger' : 'approve'} onClick={async () => {
            try {
              zoneStore.upsert(await updateAdminZone(row.id, { active: row.status === 'Active' ? false : true }));
              panel.setToast(row.status === 'Active' ? 'Zone deactivated.' : 'Zone activated.');
            } catch (error) {
              panel.setToast(error.message || 'Could not update zone.');
            }
          }}>{row.status === 'Active' ? 'Deactivate' : 'Activate'}</ActionButton>
          <ActionButton icon={Trash2} tone="danger" onClick={() => panel.setConfirm(row)}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={panel.openCreate}>Create Zone</Button>} />
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No zones found" description="Create a service zone to start assigning riders." /> : <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="zones" mobileTitleKey="name" />}
      </GlassCard>
      <Modal open={Boolean(panel.mode)} title={panel.mode === 'edit' ? 'Edit zone' : 'Create Zone'} onClose={panel.closeForm} footer={<><Button variant="ghost" onClick={panel.closeForm}>Cancel</Button><Button onClick={save}>Save</Button></>}>
        <div className="space-y-3">
          <Field label="Zone name" error={panel.errors.name}><input className={inputClass} value={panel.form.name} onChange={(event) => panel.setForm({ ...panel.form, name: event.target.value })} /></Field>
          <Field label="Area" error={panel.errors.area}><input className={inputClass} value={panel.form.area} onChange={(event) => panel.setForm({ ...panel.form, area: event.target.value })} /></Field>
          <Field label="Active riders"><input type="number" className={inputClass} value={panel.form.activeRiders} onChange={(event) => panel.setForm({ ...panel.form, activeRiders: event.target.value })} /></Field>
          <Field label="Orders"><input type="number" className={inputClass} value={panel.form.orders} onChange={(event) => panel.setForm({ ...panel.form, orders: event.target.value })} /></Field>
          <Field label="Status">
            <select className={inputClass} value={panel.form.status} onChange={(event) => panel.setForm({ ...panel.form, status: event.target.value })}>
              <option>Active</option><option>Inactive</option>
            </select>
          </Field>
        </div>
      </Modal>
      <Drawer open={Boolean(panel.view)} size="lg" eyebrow="Zone" title={panel.view?.name} onClose={() => panel.setView(null)} footer={<Button onClick={() => panel.setView(null)}>Close</Button>}>
        {panel.view ? (
          <DetailSection title="Coverage">
            <DetailRow label="Zone ID" value={panel.view.id} />
            <DetailRow label="Area" value={panel.view.area} />
            <DetailRow label="Active riders" value={panel.view.activeRiders} />
            <DetailRow label="Orders" value={panel.view.orders} />
            <DetailRow label="Status" value={panel.view.status} />
          </DetailSection>
        ) : null}
      </Drawer>
      <ConfirmDialog open={Boolean(panel.confirm)} description={`${panel.confirm?.name} will be removed from operations.`} onClose={() => panel.setConfirm(null)} onConfirm={async () => {
        try {
          await deleteAdminZone(panel.confirm.id);
          zoneStore.remove(panel.confirm.id);
          panel.setConfirm(null);
          panel.setToast('Zone deleted.');
        } catch (error) {
          panel.setToast(error.message || 'Could not delete zone.');
          panel.setConfirm(null);
        }
      }} />
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
