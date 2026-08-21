import { theme } from '../../config/theme';

export default function MockRouteMap({ order }) {
  const pickup = { x: 22, y: 58 };
  const drop = { x: 78, y: 24 };
  const rider = {
    x: order.status === 'Delivered' ? drop.x : order.status === 'Assigned' || order.status === 'Rider Arriving' ? pickup.x + 8 : 52,
    y: order.status === 'Delivered' ? drop.y : order.status === 'Assigned' || order.status === 'Rider Arriving' ? pickup.y - 6 : 40,
  };

  return (
    <div className="relative overflow-hidden rounded-3xl border border-line bg-gradient-to-br from-sky-100 via-white to-cyan-50">
      <svg viewBox="0 0 100 70" className="h-56 w-full">
        <path d="M8 42 C24 18, 40 60, 58 32 S84 10, 96 38" fill="none" stroke={theme.primaryLight} strokeWidth="7" />
        <path d="M10 50 C28 28, 44 48, 78 24" fill="none" stroke={theme.primary} strokeWidth="0.9" strokeDasharray="1.6 1.2" />
        <circle cx={pickup.x} cy={pickup.y} r="2.4" fill={theme.cyan} />
        <text x={pickup.x + 3} y={pickup.y + 1} fontSize="3.2" fill="#0F1F3D">Pickup</text>
        <circle cx={drop.x} cy={drop.y} r="2.4" fill={theme.primaryDark} />
        <text x={drop.x - 18} y={drop.y - 3} fontSize="3.2" fill="#0F1F3D">Drop</text>
        <circle cx={rider.x} cy={rider.y} r="3.4" fill={theme.primary} opacity="0.18" />
        <circle cx={rider.x} cy={rider.y} r="1.7" fill={theme.primary} />
      </svg>
      <div className="absolute bottom-3 left-3 right-3 flex flex-wrap gap-2">
        <div className="glass-panel px-3 py-2 text-xs">
          <p className="text-ink-muted">ETA</p>
          <p className="font-semibold text-ink">{order.eta}</p>
        </div>
        <div className="glass-panel px-3 py-2 text-xs">
          <p className="text-ink-muted">Distance</p>
          <p className="font-semibold text-ink">{order.distance}</p>
        </div>
        <div className="glass-panel px-3 py-2 text-xs">
          <p className="text-ink-muted">Live map</p>
          <p className="font-semibold text-ink">Ready for GPS API</p>
        </div>
      </div>
    </div>
  );
}
