export default function DonutChart({
  segments,
  size = 180,
  thickness = 22,
  centerLabel,
  centerValue,
}) {
  const radius = (size - thickness) / 2;
  const circumference = 2 * Math.PI * radius;
  const total = segments.reduce((sum, item) => sum + item.value, 0) || 1;

  let offset = 0;
  const prepared = segments.map((segment) => {
    const length = (segment.value / total) * circumference;
    const next = { ...segment, length, offset };
    offset += length;
    return next;
  });

  return (
    <div className="relative mx-auto inline-flex">
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        className="-rotate-90"
      >
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="#E8EEF2"
          strokeWidth={thickness}
        />
        {prepared.map((segment) => (
          <circle
            key={segment.label}
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={segment.color}
            strokeWidth={thickness}
            strokeDasharray={`${segment.length} ${circumference - segment.length}`}
            strokeDashoffset={-segment.offset}
            strokeLinecap="butt"
          />
        ))}
      </svg>
      <div className="absolute inset-0 flex rotate-0 flex-col items-center justify-center">
        {centerValue ? (
          <p className="text-xl font-bold text-ink">{centerValue}</p>
        ) : null}
        {centerLabel ? (
          <p className="text-xs text-ink-soft">{centerLabel}</p>
        ) : null}
      </div>
    </div>
  );
}
