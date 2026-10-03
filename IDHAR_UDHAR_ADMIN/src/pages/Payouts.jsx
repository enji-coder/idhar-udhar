import { useCallback, useEffect, useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Check, Eye, RefreshCw, X } from 'lucide-react';
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
import ErrorState from '../components/common/ErrorState';
import Toast from '../components/common/Toast';
import { formatINR } from '../utils/format';
import { useAuth } from '../context/AuthContext';
import {
  fetchAdminWithdrawal,
  fetchAdminWithdrawals,
  markAdminWithdrawalProcessing,
  reconcileAdminWithdrawal,
  rejectAdminWithdrawal,
} from '../api/adminApi';

const STATUS_LABEL = {
  REQUESTED: 'Pending',
  PENDING: 'Pending',
  PROCESSING: 'Approved',
  SUCCESSFUL: 'Paid',
  FAILED: 'Rejected',
  REJECTED: 'Rejected',
  CANCELLED: 'Rejected',
};

const SUMMARY_STATUSES = ['Pending', 'Approved', 'Paid', 'Rejected'];

function mapRow(row) {
  return {
    id: row.withdrawal_id,
    rider: row.rider_profile_id,
    amount: Number(row.amount || 0),
    method: row.payout_method,
    status: STATUS_LABEL[row.status] || row.status,
    rawStatus: row.status,
    period: row.requested_at ? new Date(row.requested_at).toLocaleString() : '—',
    providerRef: row.provider_transfer_id || row.merchant_transfer_id || '—',
    failureReason: row.failure_reason || '',
    providerStatus: row.provider_status || '',
  };
}

export default function Payouts() {
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [view, setView] = useState(null);
  const [action, setAction] = useState(null);
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState('');

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const withdrawals = await fetchAdminWithdrawals();
      setRows(withdrawals.map(mapRow));
      setLoadError(null);
    } catch (error) {
      setLoadError(error);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    reload();
  }, [reload]);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => `${row.id} ${row.rider} ${row.rawStatus}`.toLowerCase().includes(query));
  }, [rows, searchQuery]);

  async function openView(row) {
    try {
      const detail = await fetchAdminWithdrawal(row.id);
      setView({
        ...mapRow(detail),
        destination: detail.destination_masked || '—',
      });
    } catch {
      setView(row);
    }
  }

  async function confirmAction() {
    if (!action?.row) return;
    setBusy(true);
    try {
      if (action.next === 'reject') {
        await rejectAdminWithdrawal(action.row.id, action.reason || 'Rejected by finance');
        setToast('Withdrawal rejected and wallet restored.');
      } else if (action.next === 'process') {
        const result = await markAdminWithdrawalProcessing(action.row.id);
        setToast(`Withdrawal moved to ${result.status}.`);
      } else if (action.next === 'reconcile') {
        const result = await reconcileAdminWithdrawal(action.row.id);
        setToast(`Reconcile result: ${result.status} (${result.result}).`);
      }
      setAction(null);
      await reload();
    } catch (error) {
      setToast(error?.message || 'Withdrawal action failed.');
    } finally {
      setBusy(false);
    }
  }

  if (loading) return <TableSkeleton />;
  if (loadError) {
    return (
      <PageContainer>
        <ErrorState
          title="Couldn't load withdrawals"
          description={loadError.message || 'Wallet withdrawal APIs are required. Dummy payouts are not shown.'}
        />
      </PageContainer>
    );
  }

  const columns = [
    { key: 'id', label: 'Payout ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'rider', label: 'Rider', sortable: true },
    { key: 'amount', label: 'Amount', sortable: true, render: (row) => formatINR(row.amount) },
    { key: 'period', label: 'Requested' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => openView(row)}>View</ActionButton>
          {can('payouts', 'approve') && row.rawStatus === 'REQUESTED' ? (
            <ActionButton icon={Check} tone="approve" onClick={() => setAction({ row, next: 'process', verb: 'Process payout' })}>Process</ActionButton>
          ) : null}
          {can('payouts', 'reject') && (row.rawStatus === 'REQUESTED' || row.rawStatus === 'PENDING') ? (
            <ActionButton icon={X} tone="danger" onClick={() => setAction({ row, next: 'reject', verb: 'Reject' })}>Reject</ActionButton>
          ) : null}
          {can('payouts', 'approve') && row.rawStatus === 'PROCESSING' ? (
            <ActionButton icon={RefreshCw} tone="invoice" onClick={() => setAction({ row, next: 'reconcile', verb: 'Reconcile' })}>Reconcile</ActionButton>
          ) : null}
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4 pb-8">
      <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
        {SUMMARY_STATUSES.map((status) => (
          <GlassCard key={status}>
            <p className="text-sm text-ink-muted">{status}</p>
            <p className="text-2xl font-bold">
              {formatINR(rows.filter((row) => row.status === status).reduce((sum, row) => sum + Number(row.amount || 0), 0))}
            </p>
          </GlassCard>
        ))}
      </div>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState title="No payouts" description="No rider withdrawal requests match this search." />
        ) : (
          <DataTable columns={columns} data={data} pageSize={8} itemLabel="payouts" compact />
        )}
      </GlassCard>
      <Drawer open={Boolean(view)} size="lg" eyebrow="Withdrawal" title={view?.id} onClose={() => setView(null)} footer={<Button onClick={() => setView(null)}>Close</Button>}>
        {view ? (
          <DetailSection title="Details">
            <DetailRow label="Rider" value={view.rider} />
            <DetailRow label="Amount" value={formatINR(view.amount)} />
            <DetailRow label="Requested" value={view.period} />
            <DetailRow label="Method" value={view.method} />
            <DetailRow label="Status" value={`${view.status} (${view.rawStatus})`} />
            <DetailRow label="Destination" value={view.destination || '—'} />
            <DetailRow label="Provider ref" value={view.providerRef} />
            <DetailRow label="Provider status" value={view.providerStatus || '—'} />
            <DetailRow label="Failure reason" value={view.failureReason || '—'} />
          </DetailSection>
        ) : null}
      </Drawer>
      <Modal
        open={Boolean(action)}
        title={`${action?.verb || 'Update'} withdrawal?`}
        onClose={() => setAction(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setAction(null)}>Back</Button>
            <Button loading={busy} disabled={busy} onClick={confirmAction}>{action?.verb || 'Confirm'}</Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">
          {formatINR(action?.row?.amount || 0)} for rider {action?.row?.rider}.
          {action?.next === 'process'
            ? ' This starts the Cashfree payout. Success is confirmed only by provider status.'
            : null}
          {action?.next === 'reconcile'
            ? ' Queries Cashfree for authoritative status. Does not refund on unknown/timeout.'
            : null}
        </p>
      </Modal>
      <Toast message={toast} onClose={() => setToast('')} />
    </PageContainer>
  );
}
