import { useMemo, useState } from 'react';
import { useNavigate, useOutletContext } from 'react-router-dom';
import { Eye, Pause, Pencil, Package, Plus, Repeat, Sparkles, Trash2, UserPlus, Users } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import KpiCard from '../components/common/KpiCard';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import Button from '../components/common/Button';
import EmptyState from '../components/common/EmptyState';
import Modal from '../components/common/Modal';
import Field, { inputClass } from '../components/common/Field';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import ConfirmDialog from '../components/common/ConfirmDialog';
import Toast from '../components/common/Toast';
import PageHeader from '../components/common/PageHeader';
import StatusBadge from '../components/common/StatusBadge';
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import useQueryAction from '../hooks/useQueryAction';
import { customerStore, orderStore } from '../services/stores';
import { customerMetrics } from '../data/mockData';
import { useAuth } from '../context/AuthContext';
import { formatINR } from '../utils/format';
import { nextId } from '../utils/ids';
import { compactErrors, isEmail, required } from '../utils/validation';

const icons = { total: Users, active: Sparkles, new: UserPlus, repeat: Repeat };

export default function Customers() {
  const navigate = useNavigate();
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const loading = useMockLoader();
  const customers = useStore(customerStore);
  const orders = useStore(orderStore);
  const [edit, setEdit] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [create, setCreate] = useState(false);
  const [draft, setDraft] = useState({ name: '', email: '', phone: '', area: 'Ahmedabad', status: 'Active' });
  const [errors, setErrors] = useState({});
  const [toast, setToast] = useState('');
  useQueryAction('add', () => setCreate(true));

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return customers.filter((row) => `${row.name} ${row.phone} ${row.area}`.toLowerCase().includes(query)).map((row) => {
      const last = orders.find((order) => order.customerId === row.id || order.customer === row.name);
      return { ...row, lastOrder: last?.date || row.joined };
    });
  }, [customers, orders, searchQuery]);

  if (loading) return <TableSkeleton />;

  const columns = [
    { key: 'name', label: 'Customer', sortable: true, render: (row) => <div><p className="font-semibold">{row.name}</p><p className="text-xs text-ink-muted">{row.id}</p></div> },
    { key: 'email', label: 'Email', hideBelow: 'lg' },
    { key: 'phone', label: 'Phone' },
    { key: 'orders', label: 'Total Orders', sortable: true },
    { key: 'spent', label: 'Total Spent', sortable: true, render: (row) => formatINR(row.spent) },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.account || row.status || 'Active'} /> },
    { key: 'joined', label: 'Joined Date', hideBelow: 'lg' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => navigate(`/customers/${row.id}`)}>View</ActionButton>
          {can('customers', 'edit') ? <ActionButton icon={Pencil} tone="edit" onClick={() => setEdit(row)}>Edit</ActionButton> : null}
          <ActionButton icon={Package} tone="track" onClick={() => navigate(`/orders?customer=${encodeURIComponent(row.name)}`)}>View Orders</ActionButton>
          {can('customers', 'deactivate') && row.account !== 'Inactive' ? <ActionButton icon={Pause} tone="danger" onClick={() => setConfirm({ type: 'deactivate', row })}>Deactivate</ActionButton> : null}
          <ActionButton icon={Trash2} tone="danger" onClick={() => setConfirm({ type: 'delete', row })}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={() => { setDraft({ name: '', email: '', phone: '', area: 'Ahmedabad', status: 'Active' }); setErrors({}); setCreate(true); }}>Add Customer</Button>} />
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {customerMetrics.map((kpi) => (
          <KpiCard key={kpi.id} icon={icons[kpi.id]} {...kpi} />
        ))}
      </section>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No customers found" description="Try changing your search criteria." /> : <DataTable columns={columns} data={data} mobileTitleKey="name" pageSize={8} itemLabel="customers" compact />}
      </GlassCard>
      <Modal open={Boolean(edit)} title="Edit customer" onClose={() => setEdit(null)} footer={<><Button variant="ghost" onClick={() => setEdit(null)}>Cancel</Button><Button onClick={() => { customerStore.upsert(edit); setEdit(null); setToast('Customer updated.'); }}>Save</Button></>}>
        {edit ? (
          <div className="space-y-3">
            <Field label="Name"><input className={inputClass} value={edit.name} onChange={(event) => setEdit({ ...edit, name: event.target.value })} /></Field>
            <Field label="Email"><input className={inputClass} value={edit.email || ''} onChange={(event) => setEdit({ ...edit, email: event.target.value })} /></Field>
            <Field label="Phone"><input className={inputClass} value={edit.phone} onChange={(event) => setEdit({ ...edit, phone: event.target.value })} /></Field>
            <Field label="Area"><input className={inputClass} value={edit.area} onChange={(event) => setEdit({ ...edit, area: event.target.value })} /></Field>
          </div>
        ) : null}
      </Modal>
      <Modal open={create} title="Add Customer" onClose={() => setCreate(false)} footer={<><Button variant="ghost" onClick={() => setCreate(false)}>Cancel</Button><Button onClick={() => {
        const issues = compactErrors({
          name: required(draft.name, 'Name is required.'),
          phone: required(draft.phone, 'Phone number cannot be empty.'),
          email: required(draft.email, 'Email is required.') || (!isEmail(draft.email) ? 'Email must have a valid format.' : ''),
        });
        setErrors(issues);
        if (Object.keys(issues).length) return;
        customerStore.upsert({ id: nextId('C', customers), ...draft, orders: 0, spent: 0, account: 'Active', joined: '17 Aug 2026' });
        setCreate(false);
        setToast('Customer added.');
      }}>Save</Button></>}>
        <div className="space-y-3">
          <Field label="Name" error={errors.name}><input className={inputClass} value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></Field>
          <Field label="Email" error={errors.email}><input className={inputClass} type="email" value={draft.email} onChange={(event) => setDraft({ ...draft, email: event.target.value })} /></Field>
          <Field label="Phone" error={errors.phone}><input className={inputClass} value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} /></Field>
          <Field label="Area"><input className={inputClass} value={draft.area} onChange={(event) => setDraft({ ...draft, area: event.target.value })} /></Field>
        </div>
      </Modal>
      <Modal
        open={confirm?.type === 'deactivate'}
        title="Deactivate customer?"
        onClose={() => setConfirm(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirm(null)}>Cancel</Button>
            <Button variant="reject" onClick={() => { customerStore.patch(confirm.row.id, { account: 'Inactive', status: 'Inactive' }); setConfirm(null); setToast('Customer deactivated.'); }}>Deactivate</Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">{confirm?.row?.name} will no longer be able to place bookings once APIs are connected.</p>
      </Modal>
      <ConfirmDialog
        open={confirm?.type === 'delete'}
        description={`${confirm?.row?.name} will be removed from the customer list.`}
        onClose={() => setConfirm(null)}
        onConfirm={() => { customerStore.remove(confirm.row.id); setConfirm(null); setToast('Customer deleted.'); }}
      />
      <Toast open={Boolean(toast)} message={toast} onClose={() => setToast('')} />
    </PageContainer>
  );
}
