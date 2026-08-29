import { useMemo } from 'react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import StatusBadge from '../components/common/StatusBadge';
import EmptyState from '../components/common/EmptyState';
import { PageSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import { orderStore, riderStore } from '../services/stores';
import { theme } from '../config/theme';

function averageEta(orders) {
  const minutes = orders
    .map((order) => Number.parseInt(order.eta, 10))
    .filter((value) => Number.isFinite(value));
  if (!minutes.length) return '—';
  return `${Math.round(minutes.reduce((sum, value) => sum + value, 0) / minutes.length)} min`;
}

export default function Tracking() {
  const loading = useMockLoader();
  const riders = useStore(riderStore);
  const orders = useStore(orderStore);

  const activeRiders = useMemo(
    () => riders.filter((rider) => rider.status === 'Active' || rider.status === 'Busy'),
    [riders],
  );
  const inTransit = useMemo(() => orders.filter((order) => order.status === 'In Transit'), [orders]);

  const stats = [
    ['Active Riders', String(activeRiders.length)],
    ['In Transit', String(inTransit.length)],
    ['Average ETA', averageEta(inTransit)],
  ];

  if (loading) return <PageSkeleton />;

  return (
    <PageContainer className="space-y-4">
      <GlassCard className="relative overflow-hidden p-0">
        <div className="relative h-[280px] bg-gradient-to-br from-sky-100 via-white to-cyan-50 sm:h-[360px] lg:h-[480px]">
          <svg viewBox="0 0 100 70" className="h-full w-full">
            <path d="M8 40 C22 18, 38 52, 55 28 S82 12, 94 36" fill="none" stroke={theme.primaryLight} strokeWidth="6" />
            <path d="M6 22 C30 48, 48 8, 70 32 S90 54, 98 28" fill="none" stroke={theme.chartTertiary} strokeWidth="3" />
            <path d="M24 38 L72 22" fill="none" stroke={theme.primary} strokeWidth="0.7" strokeDasharray="1.4 1.2" />
          </svg>
          <div className="absolute left-3 top-3 grid max-w-[calc(100%-1.5rem)] gap-2 sm:grid-cols-3">
            {stats.map(([label, value]) => (
              <div key={label} className="glass-panel min-w-0 px-3 py-2 sm:px-4 sm:py-3">
                <p className="text-xs text-ink-muted">{label}</p>
                <p className="text-lg font-bold text-ink sm:text-2xl">{value}</p>
              </div>
            ))}
          </div>
          <div className="absolute bottom-4 left-4 glass-panel px-4 py-3">
            <p className="text-xs text-ink-muted">Ahmedabad service area</p>
            <p className="text-sm font-semibold text-ink">Live GPS overlay not connected yet</p>
          </div>
        </div>
      </GlassCard>

      <GlassCard>
        <h2 className="mb-3 text-lg font-semibold">Active riders</h2>
        {activeRiders.length === 0 ? (
          <EmptyState title="No active riders" description="No rider is currently online in Ahmedabad." />
        ) : (
          <ul className="grid gap-3 md:grid-cols-2">
            {activeRiders.map((rider) => (
              <li key={rider.id} className="flex items-center justify-between rounded-2xl bg-white/70 px-3 py-3">
                <div>
                  <p className="font-semibold">{rider.name}</p>
                  <p className="text-xs text-ink-muted">{rider.zone}</p>
                </div>
                <StatusBadge status={rider.status} />
              </li>
            ))}
          </ul>
        )}
      </GlassCard>
    </PageContainer>
  );
}
