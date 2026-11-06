import { useCallback, useEffect, useState } from 'react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import EmptyState from '../components/common/EmptyState';
import ErrorState from '../components/common/ErrorState';
import Button from '../components/common/Button';
import Field, { inputClass } from '../components/common/Field';
import { TableSkeleton } from '../components/common/Skeleton';
import { fetchRiderOnlineTime } from '../api/adminApi';

function todayInKolkata() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

function formatSeconds(seconds) {
  const safe = Math.max(0, Number(seconds) || 0);
  const hours = Math.floor(safe / 3600);
  const minutes = Math.floor((safe % 3600) / 60);
  if (hours > 0) return `${hours}h ${String(minutes).padStart(2, '0')}m`;
  if (minutes > 0) return `${minutes}m`;
  if (safe === 0) return '0m';
  return `${safe}s`;
}

function clock(iso, active) {
  if (active || !iso) return 'Now';
  return new Date(iso).toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    hour: 'numeric',
    minute: '2-digit',
  });
}

export default function RiderOnlineTime() {
  const [date, setDate] = useState(todayInKolkata);
  const [query, setQuery] = useState('');
  const [appliedQuery, setAppliedQuery] = useState('');
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async (nextDate, nextQuery) => {
    setLoading(true);
    setError(null);
    try {
      const body = await fetchRiderOnlineTime({ date: nextDate, q: nextQuery });
      setReport(body);
    } catch (err) {
      setReport(null);
      setError(err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load(date, appliedQuery);
  }, [appliedQuery, date, load]);

  const riders = report?.riders || [];

  return (
    <PageContainer>
      <GlassCard className="mb-4">
        <form
          className="grid gap-3 md:grid-cols-[180px_1fr_auto]"
          onSubmit={(event) => {
            event.preventDefault();
            setAppliedQuery(query.trim());
          }}
        >
          <Field label="Date">
            <input
              className={inputClass}
              type="date"
              value={date}
              onChange={(event) => setDate(event.target.value)}
            />
          </Field>
          <Field label="Rider">
            <input
              className={inputClass}
              value={query}
              placeholder="Name or phone"
              onChange={(event) => setQuery(event.target.value)}
            />
          </Field>
          <div className="flex items-end">
            <Button type="submit">Search</Button>
          </div>
        </form>
        <p className="mt-3 text-xs text-ink-muted">
          Times use {report?.time_zone || 'Asia/Kolkata'}. An open shift is still counting.
        </p>
      </GlassCard>

      {loading ? <TableSkeleton /> : null}
      {!loading && error ? (
        <ErrorState
          description="Rider online time could not be loaded."
          onRetry={() => load(date, appliedQuery)}
        />
      ) : null}
      {!loading && !error && riders.length === 0 ? (
        <EmptyState
          title="No online time"
          description="No shifts were recorded for this date."
        />
      ) : null}
      {!loading && !error && riders.length > 0 ? (
        <div className="space-y-3">
          {riders.map((rider) => (
            <GlassCard key={rider.rider_profile_id}>
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h2 className="text-base font-semibold text-ink">
                    {rider.name || 'Rider'}
                  </h2>
                  <p className="text-sm text-ink-muted">{rider.phone || 'No phone'}</p>
                </div>
                <div className="text-right">
                  <p className="text-xs uppercase tracking-wide text-ink-muted">Daily total</p>
                  <p className="text-lg font-semibold text-ink">
                    {formatSeconds(rider.total_seconds)}
                  </p>
                  {rider.active ? (
                    <p className="text-sm text-emerald-700">
                      Active shift {formatSeconds(rider.active.elapsed_seconds)}
                    </p>
                  ) : null}
                </div>
              </div>
              <div className="mt-4 overflow-x-auto">
                <table className="min-w-full text-left text-sm">
                  <thead className="text-xs uppercase text-ink-muted">
                    <tr>
                      <th className="py-2 pr-4 font-medium">Start</th>
                      <th className="py-2 pr-4 font-medium">End</th>
                      <th className="py-2 font-medium">Duration</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(rider.shifts || []).map((shift) => (
                      <tr key={shift.session_id} className="border-t border-slate-100">
                        <td className="py-2 pr-4">{clock(shift.started_at, false)}</td>
                        <td className="py-2 pr-4">{clock(shift.ended_at, shift.active)}</td>
                        <td className="py-2">{formatSeconds(shift.seconds)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </GlassCard>
          ))}
        </div>
      ) : null}
    </PageContainer>
  );
}
