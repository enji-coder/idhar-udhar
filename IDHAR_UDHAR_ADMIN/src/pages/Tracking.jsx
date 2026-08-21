import { mapStops, trackingPins } from '../data/mockData';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import StatusBadge from '../components/common/StatusBadge';
import { PageSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import { theme } from '../config/theme';

const stats = [
  ['Active Riders', '128'],
  ['In Transit', '74'],
  ['Average ETA', '24 min'],
];

export default function Tracking() {
  const loading = useMockLoader();
  if (loading) return <PageSkeleton />;

  return (
    <PageContainer className="space-y-4">
      <GlassCard className="relative overflow-hidden p-0">
        <div className="relative h-[280px] bg-gradient-to-br from-sky-100 via-white to-cyan-50 sm:h-[360px] lg:h-[480px]">
          <svg viewBox="0 0 100 70" className="h-full w-full">
            <path d="M8 40 C22 18, 38 52, 55 28 S82 12, 94 36" fill="none" stroke={theme.primaryLight} strokeWidth="6" />
            <path d="M6 22 C30 48, 48 8, 70 32 S90 54, 98 28" fill="none" stroke={theme.chartTertiary} strokeWidth="3" />
            <path d="M24 38 L72 22" fill="none" stroke={theme.primary} strokeWidth="0.7" strokeDasharray="1.4 1.2" />
            {mapStops.map((stop) => (
              <g key={stop.id}>
                <rect
                  x={stop.x - 1.4}
                  y={stop.y - 1.4}
                  width="2.8"
                  height="2.8"
                  rx="0.6"
                  fill={stop.type === 'pickup' ? theme.cyan : theme.primaryDark}
                />
              </g>
            ))}
            {trackingPins.map((pin) => (
              <g key={pin.id}>
                <circle cx={pin.x} cy={pin.y} r="3.2" fill={theme.primary} opacity="0.2" />
                <circle cx={pin.x} cy={pin.y} r="1.6" fill={theme.primary} />
                <text x={pin.x + 2.2} y={pin.y - 2} fontSize="2.4" fill="#0F1F3D">{pin.name.split(' ')[0]}</text>
              </g>
            ))}
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
            <p className="text-xs text-ink-muted">Ahmedabad mock map</p>
            <p className="text-sm font-semibold text-ink">Architected for live GPS later</p>
          </div>
        </div>
      </GlassCard>

      <GlassCard>
        <h2 className="mb-3 text-lg font-semibold">Active riders</h2>
        <ul className="grid gap-3 md:grid-cols-2">
          {trackingPins.map((pin) => (
            <li key={pin.id} className="flex items-center justify-between rounded-2xl bg-white/70 px-3 py-3">
              <div>
                <p className="font-semibold">{pin.name}</p>
                <p className="text-xs text-ink-muted">{pin.id}</p>
              </div>
              <StatusBadge status={pin.status} />
            </li>
          ))}
        </ul>
      </GlassCard>
    </PageContainer>
  );
}
