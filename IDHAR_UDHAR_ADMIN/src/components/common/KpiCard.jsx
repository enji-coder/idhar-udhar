import { ArrowUpRight, TrendingDown, TrendingUp } from 'lucide-react';
import Sparkline from '../charts/Sparkline';
import { theme } from '../../config/theme';

export default function KpiCard({ icon: Icon, title, value, trend, note, spark, onClick }) {
  const isUp = trend >= 0;
  const Wrapper = onClick ? 'button' : 'article';

  return (
    <Wrapper
      type={onClick ? 'button' : undefined}
      onClick={onClick}
      title={onClick ? `Open ${title}` : undefined}
      className={`glass-card group w-full p-4 text-left transition duration-300 hover:-translate-y-0.5 hover:shadow-card-hover sm:p-5 ${onClick ? 'cursor-pointer' : ''}`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-brand-50 text-brand-500">
          {Icon ? <Icon size={20} /> : null}
        </div>
        <div className="flex items-center gap-2">
          <Sparkline values={spark} color={isUp ? theme.primary : theme.error} />
          {onClick ? <ArrowUpRight size={16} className="text-brand-400 opacity-0 transition group-hover:opacity-100" /> : null}
        </div>
      </div>
      <p className="mt-4 text-sm font-medium text-ink-muted">{title}</p>
      <div className="mt-1 flex items-end justify-between gap-2">
        <p className="text-xl font-bold tracking-tight text-ink sm:text-2xl">{value}</p>
        <span className={`inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs font-semibold ${isUp ? 'bg-emerald-50 text-success' : 'bg-red-50 text-danger'}`}>
          {isUp ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
          {isUp ? '+' : ''}
          {Math.abs(trend)}%
        </span>
      </div>
      <p className="mt-1 text-xs text-ink-soft">{note}</p>
    </Wrapper>
  );
}
