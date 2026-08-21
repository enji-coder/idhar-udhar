import { useState } from 'react';
import { formatCompactINR, formatINR } from '../../utils/format';
import { theme } from '../../config/theme';

export default function BarChart({ data = [], color = theme.primary }) {
  const [hover, setHover] = useState(null);
  const width = 720;
  const height = 280;
  const pad = { t: 24, r: 16, b: 42, l: 58 };
  const values = data.map((item) => Number(item.value) || 0);
  const max = Math.max(...values, 1);
  const innerW = width - pad.l - pad.r;
  const innerH = height - pad.t - pad.b;
  const gap = 10;
  const barW = Math.max((innerW - gap * data.length) / Math.max(data.length, 1), 18);

  return (
    <div className="relative w-full overflow-visible">
      <svg viewBox={`0 0 ${width} ${height}`} className="h-[240px] w-full min-h-[220px] sm:h-[280px]" role="img">
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
        {data.map((item, index) => {
          const barH = Math.max((item.value / max) * innerH, 4);
          const x = pad.l + index * (barW + gap) + gap / 2;
          const y = pad.t + innerH - barH;
          const fill = item.color || color;
          return (
            <g key={item.label} onMouseEnter={() => setHover({ ...item, x: x + barW / 2, y })} onMouseLeave={() => setHover(null)}>
              <rect x={x} y={y} width={barW} height={barH} rx="10" fill={fill} opacity={hover?.label === item.label ? 1 : 0.88} />
              <text x={x + barW / 2} y={height - 14} textAnchor="middle" fontSize="11" fill="#64748B">{item.label}</text>
            </g>
          );
        })}
      </svg>
      {hover ? (
        <div
          className="pointer-events-none absolute rounded-xl bg-ink px-3 py-2 text-xs text-white shadow-floating"
          style={{ left: `${(hover.x / width) * 100}%`, top: 8, transform: 'translateX(-50%)' }}
        >
          <p className="font-semibold">{hover.label}</p>
          <p>{formatINR(hover.value)}</p>
        </div>
      ) : null}
    </div>
  );
}
