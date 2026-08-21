import { theme } from '../../config/theme';

export default function Sparkline({ values = [], color = theme.primary }) {
  const max = Math.max(...values, 1);
  const points = values
    .map((value, index) => {
      const x = (index / Math.max(values.length - 1, 1)) * 80;
      const y = 28 - (value / max) * 22;
      return `${x},${y}`;
    })
    .join(' ');

  return (
    <svg viewBox="0 0 80 32" className="h-8 w-20">
      <polyline points={points} fill="none" stroke={color} strokeWidth="2.4" strokeLinejoin="round" />
    </svg>
  );
}
