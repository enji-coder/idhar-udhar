import { TrendingDown, TrendingUp } from 'lucide-react';

export default function StatCard({ icon: Icon, title, value, trend, note }) {
  const isUp = trend >= 0;

  return (
    <article className="flex items-center gap-4 rounded-[20px] border border-line bg-white p-5 shadow-card transition hover:shadow-card-hover">
      <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-brand-50 text-brand-500">
        {Icon ? <Icon size={22} /> : null}
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-medium text-ink-muted">{title}</p>
        <div className="mt-1 flex items-end justify-between gap-2">
          <p className="text-2xl font-bold tracking-tight text-ink md:text-[26px]">{value}</p>
          <span
            className={`inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs font-semibold ${
              isUp ? 'bg-emerald-50 text-success' : 'bg-red-50 text-danger'
            }`}
          >
            {isUp ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
            {isUp ? '+' : ''}
            {Math.abs(trend)}%
          </span>
        </div>
        {note ? <p className="mt-1 text-xs text-ink-soft">{note}</p> : null}
      </div>
    </article>
  );
}
