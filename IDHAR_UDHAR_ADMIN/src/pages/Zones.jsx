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
import {
  createAdminZone,
  deleteAdminZone,
  fetchAdminCities,
  fetchAdminStates,
  fetchAdminZones,
  updateAdminZone,
} from '../api/adminApi';
import { ApiError } from '../api/errors';

const emptyZone = {
  id: '',
  name: '',
  area: '',
  activeRiders: 0,
  orders: 0,
  status: 'Active',
  stateId: '',
  cityId: '',
  cityName: '',
  stateName: '',
  stateCode: '',
  cityCode: '',
};

export default function Zones() {
  const { searchQuery } = useOutletContext() || {};
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [states, setStates] = useState([]);
  const [cities, setCities] = useState([]);
  const [saving, setSaving] = useState(false);
  const rows = useStore(zoneStore);
  const panel = usePanelState(emptyZone);
  useQueryAction('add', panel.openCreate);

  function loadAll() {
    setLoading(true);
    return Promise.all([fetchAdminZones(), fetchAdminStates(), fetchAdminCities()])
      .then(([zones, nextStates, nextCities]) => {
        zoneStore.replace(zones);
        setStates(nextStates);
        setCities(nextCities);
        setLoadError(null);
      })
      .catch((error) => setLoadError(error))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    Promise.all([fetchAdminZones(), fetchAdminStates(), fetchAdminCities()])
      .then(([zones, nextStates, nextCities]) => {
        if (!cancelled) {
          zoneStore.replace(zones);
          setStates(nextStates);
          setCities(nextCities);
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

  const formCities = useMemo(() => {
    if (!panel.form.stateId) return [];
    return cities.filter(
      (city) =>
        city.stateId === panel.form.stateId
        && (city.status === 'Active' || city.id === panel.form.cityId),
    );
  }, [cities, panel.form.stateId, panel.form.cityId]);

  const selectedCity = useMemo(
    () => cities.find((city) => city.id === panel.form.cityId) || null,
    [cities, panel.form.cityId],
  );

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) =>
      `${row.id} ${row.name} ${row.area} ${row.stateName || ''} ${row.cityName || ''}`
        .toLowerCase()
        .includes(query),
    );
  }, [rows, searchQuery]);

  function onStateChange(stateId) {
    panel.setForm({
      ...panel.form,
      stateId,
      cityId: '',
      area: '',
      cityName: '',
      cityCode: '',
    });
  }

  function onCityChange(cityId) {
    const city = cities.find((item) => item.id === cityId);
    panel.setForm({
      ...panel.form,
      cityId,
      area: city?.name || '',
      cityName: city?.name || '',
      cityCode: city?.code || '',
    });
  }

  async function save() {
    const issues = compactErrors({
      stateId: required(panel.form.stateId, 'State is required.'),
      cityId: required(panel.form.cityId, 'City is required.'),
      name: required(panel.form.name, 'Zone name is required.'),
    });
    if (panel.form.stateId && panel.form.cityId) {
      const city = cities.find((item) => item.id === panel.form.cityId);
      if (!city || city.stateId !== panel.form.stateId) {
        issues.cityId = 'Select a city that belongs to the selected state.';
      }
    }
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    setSaving(true);
    try {
      const payload = {
        city_id: panel.form.cityId,
        name: panel.form.name.trim(),
        active: panel.form.status !== 'Inactive',
      };
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
      if (error instanceof ApiError && error.code === 'CITY_INVALID') {
        panel.setErrors({ cityId: error.message });
        return;
      }
      panel.setToast(error.message || 'Could not save zone.');
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <TableSkeleton />;
  if (loadError) {
    return (
      <ErrorState
        title="Couldn't load zones"
        description={loadError.message || 'The Admin Panel could not load zones from NestJS. Dummy records are not shown.'}
        onRetry={loadAll}
      />
    );
  }

  const columns = [
    { key: 'id', label: 'Zone ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'name', label: 'Zone Name', sortable: true },
    {
      key: 'area',
      label: 'Area',
      render: (row) => row.area || row.cityName || '—',
    },
    {
      key: 'stateName',
      label: 'State',
      sortable: true,
      render: (row) => row.stateName || row.stateCode || '—',
    },
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
          <ActionButton
            icon={Power}
            tone={row.status === 'Active' ? 'danger' : 'approve'}
            onClick={async () => {
              try {
                zoneStore.upsert(await updateAdminZone(row.id, { active: row.status !== 'Active' }));
                panel.setToast(row.status === 'Active' ? 'Zone deactivated.' : 'Zone activated.');
              } catch (error) {
                panel.setToast(error.message || 'Could not update zone.');
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

  const activeStates = states.filter(
    (state) => state.status === 'Active' || state.id === panel.form.stateId,
  );

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={panel.openCreate}>Create Zone</Button>} />
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState title="No zones found" description="Create a service zone under a city to start assigning riders." />
        ) : (
          <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="zones" mobileTitleKey="name" />
        )}
      </GlassCard>
      <Modal
        open={Boolean(panel.mode)}
        title={panel.mode === 'edit' ? 'Edit zone' : 'Create Zone'}
        onClose={panel.closeForm}
        footer={(
          <>
            <Button variant="ghost" onClick={panel.closeForm}>Cancel</Button>
            <Button onClick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</Button>
          </>
        )}
      >
        <div className="space-y-3">
          <Field label="State" error={panel.errors.stateId}>
            <select
              className={inputClass}
              value={panel.form.stateId}
              onChange={(event) => onStateChange(event.target.value)}
            >
              <option value="">Select state</option>
              {activeStates.map((state) => (
                <option key={state.id} value={state.id}>
                  {state.name} ({state.code})
                </option>
              ))}
            </select>
          </Field>
          <Field label="City" error={panel.errors.cityId}>
            <select
              className={inputClass}
              value={panel.form.cityId}
              disabled={!panel.form.stateId}
              onChange={(event) => onCityChange(event.target.value)}
            >
              <option value="">{panel.form.stateId ? 'Select city' : 'Select a state first'}</option>
              {formCities.map((city) => (
                <option key={city.id} value={city.id}>
                  {city.name} ({city.code})
                </option>
              ))}
            </select>
          </Field>
          <Field label="Zone name" error={panel.errors.name}>
            <input
              className={inputClass}
              value={panel.form.name}
              onChange={(event) => panel.setForm({ ...panel.form, name: event.target.value })}
            />
          </Field>
          <Field label="Area">
            <input
              className={inputClass}
              value={selectedCity?.name || panel.form.area || ''}
              readOnly
              placeholder="Filled from selected city"
            />
          </Field>
          <Field label="Status">
            <select
              className={inputClass}
              value={panel.form.status}
              onChange={(event) => panel.setForm({ ...panel.form, status: event.target.value })}
            >
              <option>Active</option>
              <option>Inactive</option>
            </select>
          </Field>
        </div>
      </Modal>
      <Drawer
        open={Boolean(panel.view)}
        size="lg"
        eyebrow="Zone"
        title={panel.view?.name}
        onClose={() => panel.setView(null)}
        footer={<Button onClick={() => panel.setView(null)}>Close</Button>}
      >
        {panel.view ? (
          <DetailSection title="Coverage">
            <DetailRow label="Zone ID" value={panel.view.id} />
            <DetailRow label="State" value={`${panel.view.stateName || '—'} (${panel.view.stateCode || '—'})`} />
            <DetailRow label="City" value={`${panel.view.cityName || '—'} (${panel.view.cityCode || '—'})`} />
            <DetailRow label="Area" value={panel.view.area || panel.view.cityName || '—'} />
            <DetailRow label="Active riders" value={panel.view.activeRiders} />
            <DetailRow label="Orders" value={panel.view.orders} />
            <DetailRow label="Status" value={panel.view.status} />
          </DetailSection>
        ) : null}
      </Drawer>
      <ConfirmDialog
        open={Boolean(panel.confirm)}
        description={`${panel.confirm?.name} will be removed from operations.`}
        onClose={() => panel.setConfirm(null)}
        onConfirm={async () => {
          try {
            await deleteAdminZone(panel.confirm.id);
            zoneStore.remove(panel.confirm.id);
            panel.setConfirm(null);
            panel.setToast('Zone deleted.');
          } catch (error) {
            panel.setToast(error.message || 'Could not delete zone.');
            panel.setConfirm(null);
          }
        }}
      />
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
