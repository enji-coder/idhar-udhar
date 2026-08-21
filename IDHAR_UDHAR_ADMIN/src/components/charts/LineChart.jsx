import { useState } from 'react';
import { formatCompactINR, formatINR } from '../../utils/format';
import { theme } from '../../config/theme';

export default function LineChart({ data = [], color = theme.primary }) {
  const [hover, setHover] = useState(null);
  const width = 720;
  const height = 260;
  const pad = { t: 20, r: 16, b: 40, l: 54 };
  const values = data.map((item) => Number(item.value) || 0);
  const max = Math.max(...values, 1);
  const innerW = width - pad.l - pad.r;
  const innerH = height - pad.t - pad.b;

  const points = data.map((item, index) => {
    const x = pad.l + (index / Math.max(data.length - 1, 1)) * innerW;
    const y = pad.t + innerH - (item.value / max) * innerH;
    return { ...item, x, y };
  });
  const polyline = points.map((point) => `${point.x},${point.y}`).join(' ');
  const area = `${pad.l},${pad.t + innerH} ${polyline} ${pad.l + innerW},${pad.t + innerH}`;

  return (
    <div className="relative w-full overflow-visible">
      <svg viewBox={`0 0 ${width} ${height}`} className="h-[220px] w-full min-h-[200px] sm:h-[260px]">
        {[0, 0.25, 0.5, 0.75, 1].map((step) => {
          const y = pad.t + innerH * (1 - step);
          return (
            <g key={step}>
              <line x1={pad.l} x2={width - pad.r} y1={y} y2={y} stroke="#E6EEF8" />
              <text x={pad.l - 8} y={y + 4} textAnchor="end" fontSize="11" fill="#8A97AB">
                {formatCompactINR(max * step)}
              </text>
            </g>
          );
        })}
        <polygon points={area} fill={color} opacity="0.12" />
        <polyline points={polyline} fill="none" stroke={color} strokeWidth="3" strokeLinejoin="round" strokeLinecap="round" />
        {points.map((point) => (
          <g key={point.label} onMouseEnter={() => setHover(point)} onMouseLeave={() => setHover(null)}>
            <circle cx={point.x} cy={point.y} r="12" fill="transparent" />
            <circle cx={point.x} cy={point.y} r="5" fill="#fff" stroke={color} strokeWidth="3" />
            <text x={point.x} y={height - 12} textAnchor="middle" fontSize="11" fill="#64748B">{point.label}</text>
          </g>
        ))}
      </svg>
      {hover ? (
        <div className="pointer-events-none absolute left-1/2 top-2 -translate-x-1/2 rounded-xl bg-ink px-3 py-2 text-xs text-white shadow-floating">
          {hover.label}: {formatINR(hover.value)}
        </div>
      ) : null}
    </div>
  );
}
