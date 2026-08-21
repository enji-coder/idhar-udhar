import { Link, useParams } from 'react-router-dom';
import { useMemo, useState } from 'react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import StatusBadge from '../components/common/StatusBadge';
import DataTable from '../components/common/DataTable';
import ErrorState from '../components/common/ErrorState';
import Button from '../components/common/Button';
import Modal from '../components/common/Modal';
import Field, { inputClass } from '../components/common/Field';
import { PageSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import { customerStore, orderStore, paymentStore } from '../services/stores';
import { activityTimeline, customerAddresses } from '../data/mockData';
import { useAuth } from '../context/AuthContext';
import { formatINR } from '../utils/format';
import { formatAppDate, formatAppTime, parseAppDate, sortByDateTime } from '../utils/dates';

function orderHistoryColumns() {
  return [
    { key: 'id', label: 'Order ID' },
    { key: 'date', label: 'Date', render: (row) => formatAppDate(parseAppDate(row.date)) },
    { key: 'time', label: 'Time', render: (row) => formatAppTime(row.time || row.deliveredAt || row.date) },
    { key: 'status', label: 'Order Status', render: (row) => <StatusBadge status={row.status} /> },
    { key: 'amount', label: 'Order Amount', render: (row) => formatINR(row.amount) },
    { key: 'paymentStatus', label: 'Payment Status', render: (row) => <StatusBadge status={row.paymentStatus || (row.payment === 'Cash' && row.status !== 'Delivered' ? 'Pending' : 'Paid')} /> },
    { key: 'payment', label: 'Payment Method' },
    { key: 'destination', label: 'Destination', hideBelow: 'lg' },
  ];
}

export default function CustomerDetail() {
  const { id } = useParams();
  const { can } = useAuth();
  const loading = useMockLoader();
  const customers = useStore(customerStore);
  const orders = useStore(orderStore);
  const payments = useStore(paymentStore);
  const customer = customers.find((item) => item.id === id);
  const [edit, setEdit] = useState(false);
  const [draft, setDraft] = useState(null);
  const history = useMemo(
    () => sortByDateTime(orders.filter((order) => order.customerId === id || order.customer === customer?.name)),
    [orders, id, customer?.name],
  );
  const pay = useMemo(
    () => sortByDateTime(
      payments
        .filter((item) => item.customer === customer?.name)
        .map((item) => {
          const order = orders.find((row) => row.id === item.orderId);
          return { ...item, time: item.time || order?.time };
        }),
    ),
    [payments, orders, customer?.name],
  );
  const addresses = customerAddresses[id] || [];

  if (loading) return <PageSkeleton />;
  if (!customer) {
    return <PageContainer><ErrorState title="Customer not found" description="This customer ID is not in the mock directory." /></PageContainer>;
  }

  return (
    <PageContainer className="space-y-4">
      <p className="text-sm"><Link to="/customers" className="font-semibold text-brand-600">← Customers</Link></p>
      <section className="grid gap-4 lg:grid-cols-3">
        <GlassCard>
          <h2 className="text-xl font-bold">{customer.name}</h2>
          <p className="text-sm text-ink-muted">{customer.id} · {customer.area}</p>
          <dl className="mt-4 space-y-2 text-sm">
            <div className="flex justify-between"><dt className="text-ink-muted">Phone</dt><dd>{customer.phone}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-muted">Orders</dt><dd>{customer.orders}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-muted">Spent</dt><dd>{formatINR(customer.spent)}</dd></div>
            <StatusBadge status={customer.account || 'Active'} />
          </dl>
          {can('customers', 'edit') ? <Button className="mt-4" size="sm" variant="edit" onClick={() => { setDraft(customer); setEdit(true); }}>Edit</Button> : null}
        </GlassCard>
        <GlassCard>
          <h3 className="mb-3 text-lg font-semibold">Addresses</h3>
          <ul className="space-y-2 text-sm">
            {addresses.map((address) => <li key={address} className="rounded-2xl bg-white/70 px-3 py-3">{address}</li>)}
          </ul>
        </GlassCard>
        <GlassCard>
          <h3 className="mb-3 text-lg font-semibold">Activity</h3>
          <ul className="space-y-3 text-sm">
            {activityTimeline.map((item) => <li key={item.time}><span className="font-semibold text-brand-600">{item.time}</span> {item.text}</li>)}
          </ul>
        </GlassCard>
      </section>
      <GlassCard className="overflow-hidden">
        <h3 className="mb-3 text-lg font-semibold">Order history</h3>
        <DataTable columns={orderHistoryColumns()} data={history} pageSize={10} compact itemLabel="orders" scroll />
      </GlassCard>
      <GlassCard className="overflow-hidden">
        <h3 className="mb-3 text-lg font-semibold">Payment history</h3>
        <DataTable
          columns={[
            { key: 'id', label: 'Transaction' },
            { key: 'date', label: 'Date', render: (row) => formatAppDate(parseAppDate(row.date)) },
            { key: 'time', label: 'Time', render: (row) => formatAppTime(row.time || row.date) },
            { key: 'method', label: 'Method' },
            { key: 'amount', label: 'Amount', render: (row) => formatINR(row.amount) },
            { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
          ]}
          data={pay}
          pageSize={10}
          compact
          itemLabel="payments"
        />
      </GlassCard>
      <Modal open={edit} title="Edit customer" onClose={() => setEdit(false)} footer={<><Button variant="ghost" onClick={() => setEdit(false)}>Cancel</Button><Button onClick={() => { customerStore.upsert(draft); setEdit(false); }}>Save</Button></>}>
        {draft ? (
          <div className="space-y-3">
            <Field label="Name"><input className={inputClass} value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></Field>
            <Field label="Phone"><input className={inputClass} value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} /></Field>
            <Field label="Area"><input className={inputClass} value={draft.area} onChange={(event) => setDraft({ ...draft, area: event.target.value })} /></Field>
          </div>
        ) : null}
      </Modal>
    </PageContainer>
  );
}
