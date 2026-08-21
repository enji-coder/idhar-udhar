export default function DetailSection({ title, children }) {
  return (
    <section className="rounded-2xl border border-line bg-white/70 p-4">
      {title ? <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-soft">{title}</p> : null}
      <div className="space-y-1 text-sm text-ink">{children}</div>
    </section>
  );
}

export function DetailRow({ label, value }) {
  if (value == null || value === '') return null;
  return (
    <div className="flex items-start justify-between gap-3">
      <dt className="shrink-0 text-ink-muted">{label}</dt>
      <dd className="text-right font-medium">{value}</dd>
    </div>
  );
}
