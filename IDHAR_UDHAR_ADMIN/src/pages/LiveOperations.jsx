import { useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Eye } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import Drawer from '../components/common/Drawer';
import Button from '../components/common/Button';
import StatusBadge from '../components/common/StatusBadge';
import { TableSkeleton } from '../components/common/Skeleton';
import EmptyState from '../components/common/EmptyState';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import { orderStore, riderStore } from '../services/stores';
import { mapStops, trackingPins } from '../data/mockData';
import { theme } from '../config/theme';
import { formatINR } from '../utils/format';

const liveStatuses = ['Assigned', 'Accepted', 'Rider Arriving', 'Picked Up', 'In Transit'];

export default function LiveOperations() {
  const { searchQuery } = useOutletContext() || {};
  const loading = useMockLoader();
  const rows = useStore(orderStore);
  const riders = useStore(riderStore);
  const [selected, setSelected] = useState(null);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows
      .filter((row) => liveStatuses.includes(row.status) || row.status === 'Pending')
      .filter((row) => `${row.id} ${row.customer} ${row.rider} ${row.vehicle || ''}`.toLowerCase().includes(query))
      .map((row) => ({
        ...row,
        lastUpdated: row.lastUpdated || `${row.date || '14 Aug 2026'} ${row.time || ''}`.trim(),
        delayed: row.status === 'In Transit' && Number.parseInt(row.eta, 10) > 20,
      }));
  }, [rows, searchQuery]);

  const stats = useMemo(() => ({
    activeOrders: data.filter((row) => liveStatuses.includes(row.status)).length,
    activeRiders: riders.filter((row) => row.status === 'Active' || row.status === 'Busy').length,
    inTransit: data.filter((row) => row.status === 'In Transit').length,
    pickupPending: data.filter((row) => ['Assigned', 'Accepted', 'Rider Arriving', 'Pending'].includes(row.status)).length,
    deliveryPending: data.filter((row) => ['Picked Up', 'In Transit'].includes(row.status)).length,
    delayed: data.filter((row) => row.delayed).length,
  }), [data, riders]);

  if (loading) return <TableSkeleton />;

  const columns = [
    { key: 'id', label: 'Order ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'rider', label: 'Rider', render: (row) => row.rider || 'Unassigned' },
    { key: 'customer', label: 'Customer', sortable: true },
    { key: 'vehicle', label: 'Vehicle', hideBelow: 'lg' },
    { key: 'pickup', label: 'Pickup' },
    { key: 'destination', label: 'Destination' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.delayed ? 'Delayed' : row.status} /> },
    { key: 'eta', label: 'ETA' },
    { key: 'lastUpdated', label: 'Last Updated', hideBelow: 'lg' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => setSelected(row)}>View</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        {[
          ['Active Orders', stats.activeOrders],
          ['Active Riders', stats.activeRiders],
          ['In Transit', stats.inTransit],
          ['Pickup Pending', stats.pickupPending],
          ['Delivery Pending', stats.deliveryPending],
          ['Delayed Orders', stats.delayed],
        ].map(([label, value]) => (
          <GlassCard key={label} className="py-4">
            <p className="text-xs text-ink-muted">{label}</p>
            <p className="text-2xl font-bold">{value}</p>
          </GlassCard>
        ))}
      </div>

      <GlassCard className="overflow-hidden p-0">
        <div className="relative h-[220px] bg-gradient-to-br from-sky-100 via-white to-cyan-50 sm:h-[280px]">
          <svg viewBox="0 0 100 70" className="h-full w-full" role="img" aria-label="Ahmedabad operations panel">
            <path d="M8 40 C22 18, 38 52, 55 28 S82 12, 94 36" fill="none" stroke={theme.primaryLight} strokeWidth="6" />
            <path d="M6 22 C30 48, 48 8, 70 32 S90 54, 98 28" fill="none" stroke={theme.chartTertiary} strokeWidth="3" />
            {mapStops.map((stop) => (
              <rect key={stop.id} x={stop.x - 1.4} y={stop.y - 1.4} width="2.8" height="2.8" rx="0.6" fill={stop.type === 'pickup' ? theme.cyan : theme.primaryDark} />
            ))}
            {trackingPins.map((pin) => (
              <g key={pin.id}>
                <circle cx={pin.x} cy={pin.y} r="3.2" fill={theme.primary} opacity="0.2" />
                <circle cx={pin.x} cy={pin.y} r="1.6" fill={theme.primary} />
                <text x={pin.x + 2.2} y={pin.y - 2} fontSize="2.4" fill="#0F1F3D">{pin.name.split(' ')[0]}</text>
              </g>
            ))}
          </svg>
          <div className="absolute bottom-3 left-3 rounded-2xl bg-white/90 px-3 py-2 text-xs shadow-card">
            Ahmedabad live ops panel · dummy GPS overlay
          </div>
        </div>
      </GlassCard>

      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState title="No live deliveries" description="Nothing is currently moving in Ahmedabad." />
        ) : (
          <DataTable columns={columns} data={data} mobileTitleKey="id" pageSize={8} compact itemLabel="orders" />
        )}
      </GlassCard>
      <Drawer
        open={Boolean(selected)}
        size="lg"
        eyebrow="Live order"
        title={selected?.id}
        onClose={() => setSelected(null)}
        footer={
          selected ? (
            <>
              <Button variant="secondary" onClick={() => { orderStore.patch(selected.id, { status: 'In Transit', lastUpdated: '17 Aug 2026 1:48 PM' }); setSelected({ ...selected, status: 'In Transit' }); }}>Mark In Transit</Button>
              <Button onClick={() => setSelected(null)}>Close</Button>
            </>
          ) : null
        }
      >
        {selected ? (
          <DetailSection title="Delivery">
            <DetailRow label="Customer" value={selected.customer} />
            <DetailRow label="Rider" value={selected.rider} />
            <DetailRow label="Vehicle" value={selected.vehicle} />
            <DetailRow label="Pickup" value={selected.pickup} />
            <DetailRow label="Destination" value={selected.destination} />
            <DetailRow label="Status" value={selected.status} />
            <DetailRow label="ETA" value={selected.eta} />
            <DetailRow label="Last updated" value={selected.lastUpdated} />
            <DetailRow label="Payment" value={`${selected.payment} · ${formatINR(selected.amount)}`} />
          </DetailSection>
        ) : null}
      </Drawer>
    </PageContainer>
  );
}
