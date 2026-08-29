import { Bell, FileText, MapPinned, Package, Plus, Truck, Users, Wallet } from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useOutletContext } from 'react-router-dom';
import BarChart from '../components/charts/BarChart';
import LineChart from '../components/charts/LineChart';
import DataTable from '../components/common/DataTable';
import GlassCard from '../components/common/GlassCard';
import KpiCard from '../components/common/KpiCard';
import QuickActionCard from '../components/common/QuickActionCard';
import StatusBadge from '../components/common/StatusBadge';
import Tabs from '../components/common/Tabs';
import { ASSETS } from '../config/assets';
import { useAuth } from '../context/AuthContext';
import { publishDashboardLive } from '../hooks/dashboardLive';
import usePaymentSettings from '../hooks/usePaymentSettings';
import useStore from '../hooks/useStore';
import PageContainer from '../components/layout/PageContainer';
import { hydrateAdminDirectory } from '../api/hydrate';
import { customerStore, orderStore, riderStore } from '../services/stores';
import { buildDashboardMetrics, REVENUE_PERIODS } from '../services/dashboardMetrics';
import { formatINR } from '../utils/format';

const kpiIcons = {
  customers: Users,
  riders: Truck,
  orders: Package,
  revenue: Wallet,
};

const kpiLinks = {
  customers: '/customers',
  riders: '/riders?status=Active',
  orders: '/orders',
  revenue: '/payments',
};

const liveStatuses = ['Assigned', 'Accepted', 'Rider Arriving', 'Picked Up', 'In Transit'];
const REFRESH_MS = 10000;

const toneStyles = {
  success: { wrap: 'border-emerald-100', label: 'text-emerald-700', dot: 'bg-emerald-500' },
  danger: { wrap: 'border-red-100', label: 'text-danger', dot: 'bg-danger' },
  warning: { wrap: 'border-amber-100', label: 'text-amber-700', dot: 'bg-amber-400' },
  neutral: { wrap: '', label: 'text-ink-muted', dot: 'bg-slate-300' },
};

export default function Dashboard() {
  const navigate = useNavigate();
  const { searchQuery } = useOutletContext() || {};
  const { user } = useAuth();
  const orders = useStore(orderStore);
  const riders = useStore(riderStore);
  const customers = useStore(customerStore);
  const pay = usePaymentSettings();
  const [tick, setTick] = useState(0);
  const [revenuePeriod, setRevenuePeriod] = useState('weekly');
  const timerRef = useRef(null);
  const settleRef = useRef(null);
  const inFlightRef = useRef(false);

  useEffect(() => {
    async function refresh() {
      if (document.hidden || inFlightRef.current) return;
      inFlightRef.current = true;
      publishDashboardLive({ phase: 'updating' });
      try {
        await hydrateAdminDirectory({ silent: true });
        setTick((value) => value + 1);
        window.clearTimeout(settleRef.current);
        settleRef.current = window.setTimeout(() => {
          publishDashboardLive({ phase: 'live', updatedAt: Date.now() });
          inFlightRef.current = false;
        }, 280);
      } catch {
        inFlightRef.current = false;
      }
    }

    function onVisibility() {
      if (!document.hidden) refresh();
    }

    publishDashboardLive({ phase: 'live', updatedAt: Date.now() });
    timerRef.current = window.setInterval(refresh, REFRESH_MS);
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      window.clearInterval(timerRef.current);
      window.clearTimeout(settleRef.current);
      document.removeEventListener('visibilitychange', onVisibility);
      timerRef.current = null;
      inFlightRef.current = false;
    };
  }, []);

  const metrics = useMemo(
    () => buildDashboardMetrics(orders, riders, customers, pay),
    [orders, riders, customers, pay, tick],
  );
  const revenue = metrics.periods[revenuePeriod] || metrics.periods.weekly;

  const recentOrders = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return orders.filter((order) => `${order.id} ${order.customer} ${order.rider}`.toLowerCase().includes(query)).slice(0, 6);
  }, [orders, searchQuery, tick]);

  const operational = useMemo(() => {
    const live = orders.filter((row) => liveStatuses.includes(row.status));
    return {
      activeOrders: live.length,
      activeRiders: riders.filter((row) => row.status === 'Active' || row.status === 'Busy').length,
      inTransit: orders.filter((row) => row.status === 'In Transit').length,
      pickupPending: orders.filter((row) => ['Assigned', 'Accepted', 'Rider Arriving'].includes(row.status)).length,
      delayed: orders.filter((row) => row.status === 'In Transit' && Number.parseInt(row.eta, 10) > 20).length,
    };
  }, [orders, riders, tick]);

  const highlightKpis = metrics.kpis;

  return (
    <PageContainer className="space-y-5">
      <section className="relative overflow-hidden rounded-[20px] border border-line bg-gradient-to-r from-white to-brand-50 px-5 py-6 shadow-card sm:px-8">
        <div className="flex items-start gap-4">
          <img src={ASSETS.LOGO} alt="IDHAR UDHAR" className="h-14 w-auto object-contain sm:h-16" />
          <div>
            <h2 className="text-xl font-bold tracking-tight text-ink sm:text-2xl">Welcome back, {user?.name || 'Admin'}</h2>
            <p className="mt-2 max-w-xl text-sm leading-6 text-ink-muted">Ahmedabad operations snapshot for today. Use Quick Actions to add riders, vehicles, orders and invoices.</p>
          </div>
        </div>
      </section>

      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {highlightKpis.map((kpi) => (
          <KpiCard key={kpi.id} icon={kpiIcons[kpi.id]} {...kpi} onClick={() => navigate(kpiLinks[kpi.id])} />
        ))}
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold text-ink">Operational Summary</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
          {[
            ['Active Orders', operational.activeOrders, '/live', 'warning'],
            ['Active Riders', operational.activeRiders, '/riders?status=Active', 'success'],
            ['In Transit', operational.inTransit, '/live', 'warning'],
            ['Pickup Pending', operational.pickupPending, '/orders?status=Assigned', 'warning'],
            ['Delayed', operational.delayed, '/live', 'danger'],
          ].map(([label, value, path, tone]) => {
            const style = toneStyles[tone] || toneStyles.neutral;
            return (
              <button key={label} type="button" onClick={() => navigate(path)} className={`rounded-[20px] border border-line bg-white px-4 py-4 text-left shadow-card ${style.wrap}`}>
                <p className={`flex items-center gap-1.5 text-xs ${style.label}`}>
                  <span className={`h-1.5 w-1.5 rounded-full ${style.dot}`} />
                  {label}
                </p>
                <p className="mt-1 text-2xl font-bold text-ink">{value}</p>
              </button>
            );
          })}
        </div>
        <div className="mt-3 grid gap-3 sm:grid-cols-4">
          {metrics.delivery.map((item) => {
            const style = toneStyles[item.tone] || toneStyles.neutral;
            return (
              <GlassCard key={item.label} className={`py-4 ${style.wrap}`}>
                <p className={`flex items-center gap-1.5 text-xs ${style.label}`}>
                  <span className={`h-1.5 w-1.5 rounded-full ${style.dot}`} />
                  {item.label}
                </p>
                <p className="text-lg font-semibold text-ink">{item.value}</p>
              </GlassCard>
            );
          })}
        </div>
      </section>

      <section className="grid grid-cols-1 gap-4 xl:grid-cols-12">
        <GlassCard className="overflow-hidden xl:col-span-7">
          <h2 className="text-lg font-semibold text-ink">Orders Overview</h2>
          <p className="mb-4 text-sm text-ink-muted">Delivery volume this week</p>
          <LineChart data={metrics.weeklyOrders} />
        </GlassCard>
        <GlassCard className="overflow-hidden xl:col-span-5">
          <h2 className="mb-3 text-lg font-semibold text-ink">Recent Orders</h2>
          <DataTable
            columns={[
              { key: 'id', label: 'Order ID', render: (row) => <button type="button" className="font-semibold text-brand-600" onClick={() => navigate('/orders')}>{row.id}</button> },
              { key: 'customer', label: 'Customer' },
              { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
              { key: 'amount', label: 'Amount', render: (row) => formatINR(row.amount), hideBelow: 'lg' },
            ]}
            data={recentOrders}
            pageSize={6}
            compact
            pageNumbers={false}
            itemLabel="orders"
            mobileTitleKey="id"
          />
        </GlassCard>
      </section>

      <GlassCard className="overflow-hidden">
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-lg font-semibold text-ink">Revenue Overview</h2>
              <span className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-semibold ${revenue.performance.bgClass} ${revenue.performance.textClass}`}>
                <span className={`h-1.5 w-1.5 rounded-full ${revenue.performance.dotClass}`} />
                {revenue.performance.label} performance
              </span>
            </div>
            <p className={`mt-1 text-sm font-semibold ${revenue.change >= 0 ? 'text-success' : 'text-danger'}`}>{revenue.trendLabel}</p>
          </div>
          <Tabs tabs={REVENUE_PERIODS} value={revenuePeriod} onChange={setRevenuePeriod} />
        </div>
        <BarChart data={revenue.chart} />
      </GlassCard>

      <section>
        <h2 className="mb-3 text-lg font-semibold text-ink">Quick Actions</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-4">
          <QuickActionCard icon={Plus} label="+ Add Rider" onClick={() => navigate('/riders?action=add')} />
          <QuickActionCard icon={Truck} label="+ Add Vehicle" onClick={() => navigate('/vehicles?action=add')} />
          <QuickActionCard icon={Package} label="+ Create Order" onClick={() => navigate('/orders?action=add')} />
          <QuickActionCard icon={MapPinned} label="+ Create Zone" onClick={() => navigate('/zones?action=add')} />
          <QuickActionCard icon={Bell} label="+ Send Notification" onClick={() => navigate('/notifications?action=add')} />
          <QuickActionCard icon={FileText} label="+ Create Invoice" onClick={() => navigate('/invoices?action=add')} />
          <QuickActionCard icon={Wallet} label="+ Add Wallet Transaction" onClick={() => navigate('/wallet?action=add')} />
        </div>
      </section>
    </PageContainer>
  );
}
