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
import useQueryAction from '../hooks/useQueryAction';
import { zoneStore } from '../services/stores';
import { nextId } from '../utils/ids';
import { compactErrors, required } from '../utils/validation';

const emptyZone = { id: '', name: '', area: '', activeRiders: 0, orders: 0, status: 'Active' };

export default function Zones() {
  const { searchQuery } = useOutletContext() || {};
  const loading = useMockLoader();
  const rows = useStore(zoneStore);
  const panel = usePanelState(emptyZone);
  useQueryAction('add', panel.openCreate);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => `${row.id} ${row.name} ${row.area}`.toLowerCase().includes(query));
  }, [rows, searchQuery]);

  function save() {
    const issues = compactErrors({
      name: required(panel.form.name, 'Zone name is required.'),
      area: required(panel.form.area, 'Area is required.'),
    });
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    const id = panel.form.id || nextId('ZN', rows);
    zoneStore.upsert({ ...panel.form, id, activeRiders: Number(panel.form.activeRiders) || 0, orders: Number(panel.form.orders) || 0 });
    panel.setToast(panel.mode === 'edit' ? 'Zone updated.' : 'Zone created.');
    panel.closeForm();
  }

  if (loading) return <TableSkeleton />;

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
          <ActionButton icon={Power} tone={row.status === 'Active' ? 'danger' : 'approve'} onClick={() => { zoneStore.patch(row.id, { status: row.status === 'Active' ? 'Inactive' : 'Active' }); panel.setToast(row.status === 'Active' ? 'Zone deactivated.' : 'Zone activated.'); }}>{row.status === 'Active' ? 'Deactivate' : 'Activate'}</ActionButton>
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
      <ConfirmDialog open={Boolean(panel.confirm)} description={`${panel.confirm?.name} will be removed from operations.`} onClose={() => panel.setConfirm(null)} onConfirm={() => { zoneStore.remove(panel.confirm.id); panel.setConfirm(null); panel.setToast('Zone deleted.'); }} />
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
