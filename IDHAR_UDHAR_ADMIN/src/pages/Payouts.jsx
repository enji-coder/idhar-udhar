import { useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Check, CreditCard, Eye, X } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Modal from '../components/common/Modal';
import Drawer from '../components/common/Drawer';
import EmptyState from '../components/common/EmptyState';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import { payoutStore } from '../services/stores';
import { formatINR } from '../utils/format';
import { useAuth } from '../context/AuthContext';
import { recordAudit } from '../services/auditService';
import { PAYOUT_STATUSES } from '../config/status';

export default function Payouts() {
  const { searchQuery } = useOutletContext() || {};
  const { can, user } = useAuth();
  const loading = useMockLoader();
  const rows = useStore(payoutStore);
  const [view, setView] = useState(null);
  const [action, setAction] = useState(null);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.map((row) => ({
      ...row,
      period: row.period || row.date,
      status: PAYOUT_STATUSES.includes(row.status) ? row.status : row.status === 'Processing' ? 'Approved' : row.status,
    })).filter((row) => `${row.id} ${row.rider}`.toLowerCase().includes(query));
  }, [rows, searchQuery]);

  if (loading) return <TableSkeleton />;

  const columns = [
    { key: 'id', label: 'Payout ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'rider', label: 'Rider', sortable: true },
    { key: 'amount', label: 'Amount', sortable: true, render: (row) => formatINR(row.amount) },
    { key: 'period', label: 'Period' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => setView(row)}>View</ActionButton>
          {can('payouts', 'approve') && row.status === 'Pending' ? <ActionButton icon={Check} tone="approve" onClick={() => setAction({ row, next: 'Approved', verb: 'Approve' })}>Approve</ActionButton> : null}
          {can('payouts', 'reject') && (row.status === 'Pending' || row.status === 'Approved') ? <ActionButton icon={X} tone="danger" onClick={() => setAction({ row, next: 'Rejected', verb: 'Reject' })}>Reject</ActionButton> : null}
          {can('payouts', 'approve') && row.status === 'Approved' ? <ActionButton icon={CreditCard} tone="invoice" onClick={() => setAction({ row, next: 'Paid', verb: 'Mark paid' })}>Mark Paid</ActionButton> : null}
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4 pb-8">
      <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
        {PAYOUT_STATUSES.map((status) => (
          <GlassCard key={status}>
            <p className="text-sm text-ink-muted">{status}</p>
            <p className="text-2xl font-bold">{formatINR(rows.filter((row) => (row.status === 'Processing' ? 'Approved' : row.status) === status).reduce((sum, row) => sum + Number(row.amount || 0), 0))}</p>
          </GlassCard>
        ))}
      </div>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No payouts" description="No settlement batches match this search." /> : <DataTable columns={columns} data={data} pageSize={8} itemLabel="payouts" compact />}
      </GlassCard>
      <Drawer open={Boolean(view)} size="lg" eyebrow="Payout" title={view?.id} onClose={() => setView(null)} footer={<Button onClick={() => setView(null)}>Close</Button>}>
        {view ? (
          <DetailSection title="Details">
            <DetailRow label="Rider" value={view.rider} />
            <DetailRow label="Amount" value={formatINR(view.amount)} />
            <DetailRow label="Period" value={view.period || view.date} />
            <DetailRow label="Method" value={view.method} />
            <DetailRow label="Status" value={view.status} />
          </DetailSection>
        ) : null}
      </Drawer>
      <Modal
        open={Boolean(action)}
        title={`${action?.verb || 'Update'} payout?`}
        onClose={() => setAction(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setAction(null)}>Back</Button>
            <Button onClick={() => {
              payoutStore.patch(action.row.id, { status: action.next });
              recordAudit({
                user,
                action: action.next === 'Rejected' ? 'Reject' : action.next === 'Paid' ? 'Approve' : 'Approve',
                module: 'Finance',
                recordId: action.row.id,
                previousValue: action.row.status,
                newValue: action.next,
              });
              setAction(null);
            }}>{action?.verb || 'Confirm'}</Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">{formatINR(action?.row?.amount || 0)} for {action?.row?.rider}.</p>
      </Modal>
    </PageContainer>
  );
}
