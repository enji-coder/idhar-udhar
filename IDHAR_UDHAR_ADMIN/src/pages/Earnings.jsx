import { useEffect, useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Eye } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import Drawer from '../components/common/Drawer';
import Button from '../components/common/Button';
import Tabs from '../components/common/Tabs';
import EmptyState from '../components/common/EmptyState';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import { TableSkeleton } from '../components/common/Skeleton';
import ErrorState from '../components/common/ErrorState';
import BarChart from '../components/charts/BarChart';
import usePaymentSettings from '../hooks/usePaymentSettings';
import useStore from '../hooks/useStore';
import { riderStore } from '../services/stores';
import { fetchAdminEarnings } from '../api/adminApi';
import { formatINR, formatINRExact } from '../utils/format';
import { theme } from '../config/theme';

const periods = [
  { value: 'daily', label: 'Daily' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'monthly', label: 'Monthly' },
];

function round2(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}

function inPeriod(iso, period) {
  if (!iso) return true;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return true;
  const now = new Date();
  if (period === 'daily') {
    return date.toDateString() === now.toDateString();
  }
  if (period === 'weekly') {
    const from = new Date(now);
    from.setDate(now.getDate() - 6);
    from.setHours(0, 0, 0, 0);
    return date >= from;
  }
  return date.getMonth() === now.getMonth() && date.getFullYear() === now.getFullYear();
}

export default function Earnings() {
  const { searchQuery } = useOutletContext() || {};
  const pay = usePaymentSettings();
  const riders = useStore(riderStore);
  const [view, setView] = useState(null);
  const [period, setPeriod] = useState('daily');
  const [rows, setRows] = useState([]);
  const [loadError, setLoadError] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    fetchAdminEarnings()
      .then((list) => {
        if (!cancelled) {
          setRows(list);
          setLoadError(null);
        }
      })
      .catch((error) => {
        if (!cancelled) {
          setRows([]);
          setLoadError(error);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const named = useMemo(() => rows.map((row) => {
    const rider = riders.find((item) => item.id === row.riderId);
    return {
      ...row,
      rider: rider?.name || row.rider,
      total: row.tripFare,
      commission: row.companyCommission,
      incentive: 0,
      tips: 0,
    };
  }), [rows, riders]);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return named
      .filter((row) => inPeriod(row.date, period))
      .filter((row) => `${row.rider} ${row.id}`.toLowerCase().includes(query));
  }, [named, searchQuery, period]);

  const totals = useMemo(() => data.reduce((acc, row) => ({
    totalAmount: round2(acc.totalAmount + Number(row.tripFare || 0)),
    riderAmount: round2(acc.riderAmount + Number(row.riderEarning || 0)),
    companyCommission: round2(acc.companyCommission + Number(row.companyCommission || 0)),
    operationalCost: round2(acc.operationalCost + Number(row.operationalExpense || 0)),
    actualProfit: round2(acc.actualProfit + Number(row.netCompanyEarnings || 0)),
    refunds: 0,
  }), {
    totalAmount: 0,
    riderAmount: 0,
    companyCommission: 0,
    operationalCost: 0,
    actualProfit: 0,
    refunds: 0,
  }), [data]);

  const chart = useMemo(() => {
    const buckets = new Map();
    data.forEach((row) => {
      const stamp = row.date ? new Date(row.date) : null;
      const label = stamp && !Number.isNaN(stamp.getTime())
        ? stamp.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })
        : '—';
      buckets.set(label, round2((buckets.get(label) || 0) + Number(row.tripFare || 0)));
    });
    const points = [...buckets.entries()].map(([label, value]) => ({ label, value }));
    return points.length ? points : [{ label: 'No data', value: 0 }];
  }, [data]);

  if (loading) return <TableSkeleton />;
  if (loadError) {
    return (
      <PageContainer>
        <ErrorState
          title="Couldn't load earnings"
          description={loadError.message || 'The earnings API did not respond. Dummy figures are not shown.'}
        />
      </PageContainer>
    );
  }

  const columns = [
    { key: 'rider', label: 'Rider', sortable: true },
    { key: 'orders', label: 'Orders', sortable: true },
    { key: 'total', label: 'Total', sortable: true, render: (row) => formatINR(row.total) },
    { key: 'date', label: 'Date', hideBelow: 'lg' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => setView(row)}>View</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <Tabs tabs={periods} value={period} onChange={setPeriod} />
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-6">
        <GlassCard><p className="text-sm text-ink-muted">Total Ride Amount</p><p className="text-2xl font-bold">{formatINRExact(totals.totalAmount)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Rider Payout — {pay.riderSharePercent}%</p><p className="text-2xl font-bold">{formatINRExact(totals.riderAmount)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Company Commission — {pay.companyCommissionPercent}%</p><p className="text-2xl font-bold">{formatINRExact(totals.companyCommission)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Operational Cost — {pay.operationalCostPercent}%</p><p className="text-2xl font-bold">{formatINRExact(totals.operationalCost)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Actual Profit</p><p className="text-2xl font-bold">{formatINRExact(totals.actualProfit)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Refunds</p><p className="text-2xl font-bold">{formatINRExact(totals.refunds)}</p></GlassCard>
      </div>
      <GlassCard className="overflow-hidden">
        <h2 className="mb-3 text-lg font-semibold text-ink">Earnings trend</h2>
        <BarChart data={chart} color={theme.primary} />
      </GlassCard>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No earnings found" description="Frozen order snapshots will appear here." /> : <DataTable columns={columns} data={data} rowKey="id" pageSize={8} itemLabel="records" compact />}
      </GlassCard>
      <Drawer open={Boolean(view)} size="lg" eyebrow="Earnings" title={view?.rider} onClose={() => setView(null)} footer={<Button onClick={() => setView(null)}>Close</Button>}>
        {view ? (
          <DetailSection title="Breakdown">
            <DetailRow label="Orders" value={view.orders} />
            <DetailRow label="Trip fare" value={formatINR(view.tripFare)} />
            <DetailRow label="Rider earning" value={formatINR(view.riderEarning)} />
            <DetailRow label="Company commission" value={formatINR(view.companyCommission)} />
            <DetailRow label="Operational cost" value={formatINR(view.operationalExpense)} />
            <DetailRow label="Profit" value={formatINR(view.netCompanyEarnings)} />
            <DetailRow label="Date" value={view.date} />
          </DetailSection>
        ) : null}
      </Drawer>
    </PageContainer>
  );
}
