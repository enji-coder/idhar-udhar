import { useMemo, useState } from 'react';
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
import BarChart from '../components/charts/BarChart';
import useMockLoader from '../hooks/useMockLoader';
import usePaymentSettings from '../hooks/usePaymentSettings';
import { earnings } from '../data/mockData';
import { earningsSeries } from '../data/earnings';
import { calculateDistribution } from '../services/commission';
import { formatINR, formatINRExact } from '../utils/format';
import { theme } from '../config/theme';

const periods = [
  { value: 'daily', label: 'Daily' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'monthly', label: 'Monthly' },
];

export default function Earnings() {
  const { searchQuery } = useOutletContext() || {};
  const loading = useMockLoader();
  const [view, setView] = useState(null);
  const [period, setPeriod] = useState('daily');
  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return earnings.filter((row) => row.rider.toLowerCase().includes(query));
  }, [searchQuery]);

  const series = earningsSeries[period] || earningsSeries.daily;
  const pay = usePaymentSettings();
  const chart = series.map((item) => ({ label: item.label, value: item.rider + item.company }));
  const raw = series.reduce((acc, item) => ({
    rider: acc.rider + item.rider,
    company: acc.company + item.company,
    refunds: acc.refunds + item.refunds,
  }), { rider: 0, company: 0, refunds: 0 });
  const finance = calculateDistribution(raw.rider + raw.company, pay);
  const totals = {
    totalAmount: finance.totalAmount,
    riderAmount: finance.riderAmount,
    companyCommission: finance.companyCommission,
    operationalCost: finance.operationalCost,
    actualProfit: finance.actualProfit,
    refunds: raw.refunds,
  };

  if (loading) return <TableSkeleton />;

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
        {data.length === 0 ? <EmptyState title="No earnings found" description="Try changing your search criteria." /> : <DataTable columns={columns} data={data} rowKey="id" pageSize={8} itemLabel="records" compact />}
      </GlassCard>
      <Drawer open={Boolean(view)} size="lg" eyebrow="Earnings" title={view?.rider} onClose={() => setView(null)} footer={<Button onClick={() => setView(null)}>Close</Button>}>
        {view ? (
          <DetailSection title="Breakdown">
            <DetailRow label="Orders" value={view.orders} />
            <DetailRow label="Commission" value={formatINR(view.commission)} />
            <DetailRow label="Incentive" value={formatINR(view.incentive)} />
            <DetailRow label="Tips" value={formatINR(view.tips)} />
            <DetailRow label="Total" value={formatINR(view.total)} />
            <DetailRow label="Date" value={view.date} />
          </DetailSection>
        ) : null}
      </Drawer>
    </PageContainer>
  );
}
