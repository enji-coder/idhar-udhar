import { useMemo } from 'react';
import { useNavigate, useOutletContext } from 'react-router-dom';
import { Eye, Package, Repeat, Sparkles, UserPlus, Users } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import KpiCard from '../components/common/KpiCard';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import EmptyState from '../components/common/EmptyState';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import StatusBadge from '../components/common/StatusBadge';
import useStore from '../hooks/useStore';
import { customerStore, orderStore } from '../services/stores';
import { formatINR } from '../utils/format';

const icons = { total: Users, active: Sparkles, new: UserPlus, repeat: Repeat };

export default function Customers() {
  const navigate = useNavigate();
  const { searchQuery } = useOutletContext() || {};
  const customers = useStore(customerStore);
  const orders = useStore(orderStore);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return customers.filter((row) => `${row.name} ${row.phone} ${row.area}`.toLowerCase().includes(query)).map((row) => {
      const last = orders.find((order) => order.customerId === row.id || order.customer === row.name);
      return { ...row, lastOrder: last?.date || row.joined };
    });
  }, [customers, orders, searchQuery]);

  const customerKpis = [
    { id: 'total', title: 'Total Customers', value: String(customers.length), trend: 0, note: 'Directory', spark: [customers.length] },
    { id: 'active', title: 'Active Customers', value: String(customers.filter((row) => (row.account || row.status) !== 'Inactive').length), trend: 0, note: 'Current accounts', spark: [customers.length] },
    { id: 'new', title: 'New Customers', value: String(customers.length), trend: 0, note: 'Loaded from API', spark: [customers.length] },
    { id: 'repeat', title: 'Repeat Customers', value: String(customers.filter((row) => Number(row.orders || 0) >= 2).length), trend: 0, note: '2+ orders', spark: [customers.length] },
  ];

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
          <ActionButton icon={Package} tone="track" onClick={() => navigate(`/orders?customer=${encodeURIComponent(row.name)}`)}>View Orders</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {customerKpis.map((kpi) => (
          <KpiCard key={kpi.id} icon={icons[kpi.id]} {...kpi} />
        ))}
      </section>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No customers found" description="Customers appear here after they register with OTP on the Customer app." /> : <DataTable columns={columns} data={data} mobileTitleKey="name" pageSize={8} itemLabel="customers" compact />}
      </GlassCard>
    </PageContainer>
  );
}
