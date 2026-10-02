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
  createAdminState,
  fetchAdminStates,
  updateAdminState,
} from '../api/adminApi';
import { ApiError } from '../api/errors';

const emptyState = { id: '', name: '', code: '', status: 'Active' };

export default function States() {
  const { searchQuery } = useOutletContext() || {};
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [rows, setRows] = useState([]);
  const [saving, setSaving] = useState(false);
  const panel = usePanelState(emptyState);
  useQueryAction('add', panel.openCreate);

  function reload() {
    setLoading(true);
    return fetchAdminStates()
      .then((next) => {
        setRows(next);
        setLoadError(null);
      })
      .catch((error) => setLoadError(error))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    fetchAdminStates()
      .then((next) => {
        if (!cancelled) {
          setRows(next);
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
    return rows.filter((row) =>
      `${row.id} ${row.name} ${row.code} ${row.status}`.toLowerCase().includes(query),
    );
  }, [rows, searchQuery]);

  async function save() {
    const issues = compactErrors({
      name: required(panel.form.name, 'State name is required.'),
      code: required(panel.form.code, 'State code is required.'),
    });
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    setSaving(true);
    try {
      const payload = {
        name: panel.form.name.trim(),
        code: panel.form.code.trim().toUpperCase(),
        active: panel.form.status !== 'Inactive',
      };
      const saved = panel.form.id
        ? await updateAdminState(panel.form.id, payload)
        : await createAdminState(payload);
      setRows((current) => {
        const without = current.filter((row) => row.id !== saved.id);
        return [...without, saved].sort((a, b) => a.name.localeCompare(b.name));
      });
      panel.setToast(panel.form.id ? 'State updated.' : 'State created.');
      panel.closeForm();
    } catch (error) {
      if (error instanceof ApiError && error.code === 'STATE_CODE_TAKEN') {
        panel.setErrors({ code: error.message });
        return;
      }
      panel.setToast(error.message || 'Could not save state.');
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <TableSkeleton />;
  if (loadError) {
    return (
      <ErrorState
        title="Couldn't load states"
        description={loadError.message || 'The Admin Panel could not load states from NestJS.'}
        onRetry={reload}
      />
    );
  }

  const columns = [
    { key: 'name', label: 'State', sortable: true },
    { key: 'code', label: 'Code', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.code}</span> },
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
                const saved = await updateAdminState(row.id, { active: row.status !== 'Active' });
                setRows((current) => current.map((item) => (item.id === saved.id ? saved : item)));
                panel.setToast(row.status === 'Active' ? 'State deactivated.' : 'State activated.');
              } catch (error) {
                panel.setToast(error.message || 'Could not update state.');
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
      <PageHeader action={<Button icon={Plus} onClick={panel.openCreate}>Add State</Button>} />
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState title="No states found" description="Add a state to start configuring cities and zones." />
        ) : (
          <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="states" mobileTitleKey="name" />
        )}
      </GlassCard>
      <Modal
        open={Boolean(panel.mode)}
        title={panel.mode === 'edit' ? 'Edit state' : 'Add State'}
        onClose={panel.closeForm}
        footer={(
          <>
            <Button variant="ghost" onClick={panel.closeForm}>Cancel</Button>
            <Button onClick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</Button>
          </>
        )}
      >
        <div className="space-y-3">
          <Field label="State name" error={panel.errors.name}>
            <input
              className={inputClass}
              value={panel.form.name}
              onChange={(event) => panel.setForm({ ...panel.form, name: event.target.value })}
            />
          </Field>
          <Field label="State code" error={panel.errors.code}>
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
        eyebrow="State"
        title={panel.view?.name}
        onClose={() => panel.setView(null)}
        footer={<Button onClick={() => panel.setView(null)}>Close</Button>}
      >
        {panel.view ? (
          <DetailSection title="Details">
            <DetailRow label="Name" value={panel.view.name} />
            <DetailRow label="Code" value={panel.view.code} />
            <DetailRow label="Status" value={panel.view.status} />
          </DetailSection>
        ) : null}
      </Drawer>
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
