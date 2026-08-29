import { Link, useParams } from 'react-router-dom';
import { useEffect, useMemo, useState } from 'react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import StatusBadge from '../components/common/StatusBadge';
import DataTable from '../components/common/DataTable';
import ErrorState from '../components/common/ErrorState';
import { PageSkeleton } from '../components/common/Skeleton';
import useStore from '../hooks/useStore';
import { customerStore, orderStore, paymentStore } from '../services/stores';
import { formatINR } from '../utils/format';
import { formatAppDate, formatAppTime, parseAppDate, sortByDateTime } from '../utils/dates';
import { fetchAdminCustomer } from '../api/adminApi';

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
  const customers = useStore(customerStore);
  const orders = useStore(orderStore);
  const payments = useStore(paymentStore);
  const stored = customers.find((item) => item.id === id);
  const [customer, setCustomer] = useState(stored || null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const history = useMemo(
    () => sortByDateTime(orders.filter((order) => order.customerId === id || order.customer === customer?.name)),
    [orders, id, customer?.name],
  );
  const pay = useMemo(
    () => sortByDateTime(
      payments
        .filter((item) => item.customer === customer?.name || orders.some((order) => order.customerId === id && (order.backendOrderId === item.backendOrderId || order.id === item.orderId)))
        .map((item) => {
          const order = orders.find((row) => row.backendOrderId === item.backendOrderId || row.id === item.orderId);
          return { ...item, time: item.time || order?.time };
        }),
    ),
    [payments, orders, customer?.name, id],
  );
  const addresses = [];

  useEffect(() => {
    if (!id) return undefined;
    let cancelled = false;
    setLoading(true);
    fetchAdminCustomer(id)
      .then((row) => {
        if (!cancelled) {
          setCustomer(row);
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
  }, [id]);

  if (loading) return <PageSkeleton />;
  if (loadError && !customer) {
    return <PageContainer><ErrorState title="Couldn't load customer" description={loadError.message || 'The customer API did not respond. Dummy records are not shown.'} /></PageContainer>;
  }
  if (!customer) {
    return <PageContainer><ErrorState title="Customer not found" description="This customer is not in the current directory." /></PageContainer>;
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
        </GlassCard>
        <GlassCard>
          <h3 className="mb-3 text-lg font-semibold">Addresses</h3>
          <ul className="space-y-2 text-sm">
            {addresses.length ? addresses.map((address) => <li key={address} className="rounded-2xl bg-white/70 px-3 py-3">{address}</li>) : <li className="text-ink-muted">No saved addresses on the server.</li>}
          </ul>
        </GlassCard>
        <GlassCard>
          <h3 className="mb-3 text-lg font-semibold">Activity</h3>
          <ul className="space-y-3 text-sm">
            {history.length ? history.slice(0, 8).map((item) => <li key={item.id}><span className="font-semibold text-brand-600">{item.status}</span> {item.id}</li>) : <li className="text-ink-muted">No recent order activity.</li>}
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
    </PageContainer>
  );
}
