import { useMemo, useState } from 'react';
import { Search, Star } from 'lucide-react';
import Drawer from '../common/Drawer';
import Button from '../common/Button';
import StatusBadge from '../common/StatusBadge';
import { initials } from '../../utils/format';
import {
  countActiveAssignments,
  estimatePickupDistance,
  groupEligibleRiders,
  riderDutyLabel,
  searchRiders,
} from '../../services/riderEligibility';

function RiderOption({ rider, selected, onSelect, distance, activeOrders, currentEta }) {
  const duty = riderDutyLabel(rider);
  return (
    <button
      type="button"
      onClick={() => onSelect(rider)}
      className={`flex w-full items-start gap-3 rounded-2xl border px-3 py-3 text-left transition ${selected ? 'border-brand-400 bg-brand-50' : 'border-line bg-white/80 hover:border-brand-200'}`}
    >
      <span className={`mt-1 h-4 w-4 rounded-full border ${selected ? 'border-brand-500 bg-brand-500' : 'border-slate-300'}`} />
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-500 text-xs font-bold text-white">{initials(rider.name)}</span>
      <span className="min-w-0 flex-1">
        <span className="flex items-center justify-between gap-2">
          <span className="font-semibold text-ink">{rider.name}</span>
          <StatusBadge status={duty} />
        </span>
        <span className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-ink-muted">
          <span className="inline-flex items-center gap-1"><Star size={12} className="text-amber-500" /> {rider.rating}</span>
          <span>{rider.vehicle} · {rider.vehicleNumber || '—'}</span>
          {distance != null ? <span>{distance} km away</span> : null}
          {duty === 'Busy' ? <span>{activeOrders || 1} ongoing delivery</span> : null}
          {currentEta ? <span>ETA {currentEta}</span> : null}
        </span>
      </span>
    </button>
  );
}

export default function ReassignRiderDrawer({ open, order, riders, orders, onClose, onAssign }) {
  const [query, setQuery] = useState('');
  const [selectedId, setSelectedId] = useState('');

  const grouped = useMemo(() => {
    const { available, busy } = groupEligibleRiders(riders);
    return {
      available: searchRiders(available, query),
      busy: searchRiders(busy, query),
    };
  }, [riders, query]);

  const current = riders.find((rider) => rider.id === order?.riderId || rider.name === order?.rider);

  function assign() {
    const rider = riders.find((item) => item.id === selectedId);
    if (!rider || !order) return;
    onAssign(rider);
    setSelectedId('');
    setQuery('');
  }

  return (
    <Drawer
      open={open}
      size="lg"
      eyebrow="Fleet"
      title={order?.rider && order.rider !== 'Unassigned' ? 'Reassign Rider' : 'Assign Rider'}
      subtitle={order?.id}
      onClose={() => { setQuery(''); setSelectedId(''); onClose(); }}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button disabled={!selectedId} onClick={assign}>Assign Rider</Button>
        </>
      }
    >
      {order ? (
        <div className="space-y-4">
          <section className="rounded-2xl border border-line bg-white/70 p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-soft">Current rider</p>
            <p className="mt-1 font-semibold text-ink">{order.rider || 'Unassigned'}</p>
            {current ? <p className="text-sm text-ink-muted">Status: {riderDutyLabel(current)}</p> : null}
          </section>

          <label className="relative block">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-muted" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search by name / phone / vehicle"
              className="h-11 w-full rounded-2xl border border-line bg-white pl-10 pr-3 text-sm outline-none focus:border-brand-300 focus:ring-2 focus:ring-brand-200"
            />
          </label>

          <section className="space-y-2">
            <p className="text-sm font-semibold text-ink">Available ({grouped.available.length})</p>
            {grouped.available.map((rider) => (
              <RiderOption
                key={rider.id}
                rider={rider}
                selected={selectedId === rider.id}
                onSelect={(item) => setSelectedId(item.id)}
                distance={estimatePickupDistance(rider, order)}
                activeOrders={countActiveAssignments(orders, rider.id)}
              />
            ))}
            {grouped.available.length === 0 ? <p className="text-sm text-ink-muted">No available riders match this search.</p> : null}
          </section>

          <section className="space-y-2">
            <p className="text-sm font-semibold text-ink">Busy ({grouped.busy.length})</p>
            {grouped.busy.map((rider) => (
              <RiderOption
                key={rider.id}
                rider={rider}
                selected={selectedId === rider.id}
                onSelect={(item) => setSelectedId(item.id)}
                distance={estimatePickupDistance(rider, order)}
                activeOrders={countActiveAssignments(orders, rider.id)}
                currentEta={order.eta}
              />
            ))}
            {grouped.busy.length === 0 ? <p className="text-sm text-ink-muted">No busy riders are eligible right now.</p> : null}
          </section>
        </div>
      ) : null}
    </Drawer>
  );
}
