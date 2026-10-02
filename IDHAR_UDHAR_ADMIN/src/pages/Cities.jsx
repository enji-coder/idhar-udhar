import { useEffect, useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Eye, Pencil, Plus, Power } from 'lucide-react';
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
import Toast from '../components/common/Toast';
import PageHeader from '../components/common/PageHeader';
import { TableSkeleton } from '../components/common/Skeleton';
import usePanelState from '../hooks/usePanelState';
import useQueryAction from '../hooks/useQueryAction';
import { compactErrors, required } from '../utils/validation';
import {
  createAdminCity,
  fetchAdminCities,
  fetchAdminStates,
  updateAdminCity,
} from '../api/adminApi';
import { ApiError } from '../api/errors';

const emptyCity = {
  id: '',
  name: '',
  code: '',
  stateId: '',
  stateName: '',
  stateCode: '',
  status: 'Active',
};

export default function Cities() {
  const { searchQuery } = useOutletContext() || {};
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [rows, setRows] = useState([]);
  const [states, setStates] = useState([]);
  const [saving, setSaving] = useState(false);
  const panel = usePanelState(emptyCity);
  useQueryAction('add', panel.openCreate);

  function reload() {
    setLoading(true);
    return Promise.all([fetchAdminCities(), fetchAdminStates()])
      .then(([cities, nextStates]) => {
        setRows(cities);
        setStates(nextStates);
        setLoadError(null);
      })
      .catch((error) => setLoadError(error))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    Promise.all([fetchAdminCities(), fetchAdminStates()])
      .then(([cities, nextStates]) => {
        if (!cancelled) {
          setRows(cities);
          setStates(nextStates);
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

  const activeStates = useMemo(
    () => states.filter((state) => state.status === 'Active' || state.id === panel.form.stateId),
    [states, panel.form.stateId],
  );

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) =>
      `${row.id} ${row.name} ${row.code} ${row.stateName} ${row.stateCode} ${row.status}`
        .toLowerCase()
        .includes(query),
    );
  }, [rows, searchQuery]);

  async function save() {
    const issues = compactErrors({
      stateId: required(panel.form.stateId, 'State is required.'),
      name: required(panel.form.name, 'City name is required.'),
      code: required(panel.form.code, 'City code is required.'),
    });
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    setSaving(true);
    try {
      const payload = {
        state_id: panel.form.stateId,
        name: panel.form.name.trim(),
        city_code: panel.form.code.trim().toUpperCase(),
        active: panel.form.status !== 'Inactive',
      };
      const saved = panel.form.id
        ? await updateAdminCity(panel.form.id, payload)
        : await createAdminCity(payload);
      setRows((current) => {
        const without = current.filter((row) => row.id !== saved.id);
        return [...without, saved].sort((a, b) => a.name.localeCompare(b.name));
      });
      panel.setToast(panel.form.id ? 'City updated.' : 'City created.');
      panel.closeForm();
    } catch (error) {
      if (error instanceof ApiError && error.code === 'CITY_CODE_TAKEN') {
        panel.setErrors({ code: error.message });
        return;
      }
      if (error instanceof ApiError && error.code === 'STATE_INVALID') {
        panel.setErrors({ stateId: error.message });
        return;
      }
      panel.setToast(error.message || 'Could not save city.');
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <TableSkeleton />;
  if (loadError) {
    return (
      <ErrorState
        title="Couldn't load cities"
        description={loadError.message || 'The Admin Panel could not load cities from NestJS.'}
        onRetry={reload}
      />
    );
  }

  const columns = [
    { key: 'name', label: 'City', sortable: true },
    { key: 'code', label: 'Code', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.code}</span> },
    {
      key: 'stateName',
      label: 'State',
      sortable: true,
      render: (row) => `${row.stateName || '—'}${row.stateCode ? ` (${row.stateCode})` : ''}`,
    },
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
                const saved = await updateAdminCity(row.id, { active: row.status !== 'Active' });
                setRows((current) => current.map((item) => (item.id === saved.id ? saved : item)));
                panel.setToast(row.status === 'Active' ? 'City deactivated.' : 'City activated.');
              } catch (error) {
                panel.setToast(error.message || 'Could not update city.');
              }
            }}
          >
            {row.status === 'Active' ? 'Deactivate' : 'Activate'}
          </ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={panel.openCreate}>Add City</Button>} />
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState title="No cities found" description="Add a city under a state before creating zones." />
        ) : (
          <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="cities" mobileTitleKey="name" />
        )}
      </GlassCard>
      <Modal
        open={Boolean(panel.mode)}
        title={panel.mode === 'edit' ? 'Edit city' : 'Add City'}
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
              onChange={(event) => panel.setForm({ ...panel.form, stateId: event.target.value })}
            >
              <option value="">Select state</option>
              {activeStates.map((state) => (
                <option key={state.id} value={state.id}>
                  {state.name} ({state.code})
                </option>
              ))}
            </select>
          </Field>
          <Field label="City name" error={panel.errors.name}>
            <input
              className={inputClass}
              value={panel.form.name}
              onChange={(event) => panel.setForm({ ...panel.form, name: event.target.value })}
            />
          </Field>
          <Field label="City code" error={panel.errors.code}>
            <input
              className={inputClass}
              value={panel.form.code}
              maxLength={5}
              onChange={(event) => panel.setForm({ ...panel.form, code: event.target.value.toUpperCase() })}
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
        eyebrow="City"
        title={panel.view?.name}
        onClose={() => panel.setView(null)}
        footer={<Button onClick={() => panel.setView(null)}>Close</Button>}
      >
        {panel.view ? (
          <DetailSection title="Details">
            <DetailRow label="Name" value={panel.view.name} />
            <DetailRow label="Code" value={panel.view.code} />
            <DetailRow label="State" value={`${panel.view.stateName || '—'} (${panel.view.stateCode || '—'})`} />
            <DetailRow label="Status" value={panel.view.status} />
          </DetailSection>
        ) : null}
      </Drawer>
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
