import { useMemo } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Eye, Pencil, Plus, Trash2, Check } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Select from '../components/common/Select';
import Modal from '../components/common/Modal';
import Drawer from '../components/common/Drawer';
import EmptyState from '../components/common/EmptyState';
import Field, { inputClass } from '../components/common/Field';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import ConfirmDialog from '../components/common/ConfirmDialog';
import Toast from '../components/common/Toast';
import PageHeader from '../components/common/PageHeader';
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import usePanelState from '../hooks/usePanelState';
import useQueryAction from '../hooks/useQueryAction';
import { walletStore, orderStore, payoutStore, riderStore } from '../services/stores';
import { walletSummary } from '../data/wallet';
import { nextId } from '../utils/ids';
import { compactErrors, nonNegative, required } from '../utils/validation';
import { formatINR } from '../utils/format';
import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import Tabs from '../components/common/Tabs';
import { buildRiderWallets } from '../services/riderWallet';
import { recordAudit } from '../services/auditService';

const emptyTxn = {
  id: '',
  user: '',
  userType: 'Customer',
  type: 'Credit',
  amount: '',
  balance: '',
  date: '17 Aug 2026',
  status: 'Success',
  description: '',
};

export default function WalletPage() {
  const { searchQuery } = useOutletContext() || {};
  const { can, user } = useAuth();
  const loading = useMockLoader();
  const rows = useStore(walletStore);
  const riders = useStore(riderStore);
  const orders = useStore(orderStore);
  const payouts = useStore(payoutStore);
  const [type, setType] = useState('All');
  const [tab, setTab] = useState('ledger');
  const panel = usePanelState(emptyTxn);
  useQueryAction('add', panel.openCreate);

  const wallets = useMemo(() => buildRiderWallets({ riders, orders, payouts }), [riders, orders, payouts]);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => (type === 'All' || row.type === type) && `${row.id} ${row.user} ${row.description}`.toLowerCase().includes(query));
  }, [rows, searchQuery, type]);

  const collected = useMemo(() => {
    const credit = rows.filter((row) => row.type === 'Credit' && row.status === 'Success').reduce((sum, row) => sum + Number(row.amount || 0), 0);
    const debit = rows.filter((row) => row.type === 'Debit' && row.status === 'Success').reduce((sum, row) => sum + Number(row.amount || 0), 0);
    return {
      total: walletSummary.total,
      available: Math.max(0, walletSummary.available + credit - debit),
      pending: rows.filter((row) => row.status === 'Pending').reduce((sum, row) => sum + Number(row.amount || 0), 0),
      count: rows.length,
    };
  }, [rows]);

  function save() {
    const issues = compactErrors({
      user: required(panel.form.user, 'User is required.'),
      amount: required(panel.form.amount, 'Amount is required.') || nonNegative(panel.form.amount, 'Amount cannot be negative.'),
      description: required(panel.form.description, 'Description is required.'),
    });
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    const id = panel.form.id || nextId('WLT', rows);
    walletStore.upsert({ ...panel.form, id, amount: Number(panel.form.amount), balance: Number(panel.form.balance) || Number(panel.form.amount) });
    panel.setToast(panel.mode === 'edit' ? 'Transaction updated.' : 'Wallet transaction added.');
    panel.closeForm();
  }

  if (loading) return <TableSkeleton />;

  const columns = [
    { key: 'id', label: 'Transaction ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'user', label: 'User', sortable: true, render: (row) => <div><p className="font-semibold">{row.user}</p><p className="text-xs text-ink-muted">{row.userType}</p></div> },
    { key: 'type', label: 'Type', render: (row) => <StatusBadge status={row.type} /> },
    { key: 'amount', label: 'Amount', sortable: true, render: (row) => formatINR(row.amount) },
    { key: 'balance', label: 'Balance', render: (row) => formatINR(row.balance), hideBelow: 'lg' },
    { key: 'date', label: 'Date', hideBelow: 'lg' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    { key: 'description', label: 'Description', hideBelow: 'lg' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => panel.setView(row)}>View</ActionButton>
          <ActionButton icon={Pencil} tone="edit" onClick={() => panel.openEdit(row)}>Edit</ActionButton>
          <ActionButton icon={Trash2} tone="danger" onClick={() => panel.setConfirm(row)}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={tab === 'ledger' ? <Button icon={Plus} onClick={panel.openCreate}>Add Wallet Transaction</Button> : null} />
      <Tabs tabs={[{ value: 'ledger', label: 'Ledger' }, { value: 'riders', label: 'Rider Wallet' }]} value={tab} onChange={setTab} />
      {tab === 'ledger' ? (
        <>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
        <GlassCard><p className="text-sm text-ink-muted">Total Wallet Balance</p><p className="text-2xl font-bold">{formatINR(collected.total)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Available Balance</p><p className="text-2xl font-bold">{formatINR(collected.available)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Pending Balance</p><p className="text-2xl font-bold">{formatINR(collected.pending)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Total Transactions</p><p className="text-2xl font-bold">{collected.count}</p></GlassCard>
      </div>
      <GlassCard className="flex flex-wrap gap-3">
        <Select aria-label="Type" value={type} onChange={setType} options={['All', 'Credit', 'Debit', 'Refund', 'Adjustment']} />
      </GlassCard>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No wallet transactions found" description="Add a credit, debit, refund or adjustment." /> : <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="transactions" />}
      </GlassCard>
      <Modal open={Boolean(panel.mode)} title={panel.mode === 'edit' ? 'Edit transaction' : 'Add Wallet Transaction'} onClose={panel.closeForm} footer={<><Button variant="ghost" onClick={panel.closeForm}>Cancel</Button><Button onClick={save}>Save</Button></>}>
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="User" error={panel.errors.user}><input className={inputClass} value={panel.form.user} onChange={(event) => panel.setForm({ ...panel.form, user: event.target.value })} /></Field>
          <Field label="User type">
            <select className={inputClass} value={panel.form.userType} onChange={(event) => panel.setForm({ ...panel.form, userType: event.target.value })}>
              <option>Customer</option><option>Rider</option>
            </select>
          </Field>
          <Field label="Type">
            <select className={inputClass} value={panel.form.type} onChange={(event) => panel.setForm({ ...panel.form, type: event.target.value })}>
              <option>Credit</option><option>Debit</option><option>Refund</option><option>Adjustment</option>
            </select>
          </Field>
          <Field label="Amount" error={panel.errors.amount}><input type="number" className={inputClass} value={panel.form.amount} onChange={(event) => panel.setForm({ ...panel.form, amount: event.target.value })} /></Field>
          <Field label="Balance"><input type="number" className={inputClass} value={panel.form.balance} onChange={(event) => panel.setForm({ ...panel.form, balance: event.target.value })} /></Field>
          <Field label="Status">
            <select className={inputClass} value={panel.form.status} onChange={(event) => panel.setForm({ ...panel.form, status: event.target.value })}>
              <option>Success</option><option>Pending</option><option>Failed</option>
            </select>
          </Field>
          <Field label="Description" error={panel.errors.description}><input className={inputClass} value={panel.form.description} onChange={(event) => panel.setForm({ ...panel.form, description: event.target.value })} /></Field>
        </div>
      </Modal>
      <Drawer open={Boolean(panel.view)} size="lg" eyebrow="Wallet" title={panel.view?.id} onClose={() => panel.setView(null)} footer={<Button onClick={() => panel.setView(null)}>Close</Button>}>
        {panel.view ? (
          <DetailSection title="Transaction">
            <DetailRow label="User" value={`${panel.view.user} (${panel.view.userType})`} />
            <DetailRow label="Type" value={panel.view.type} />
            <DetailRow label="Amount" value={formatINR(panel.view.amount)} />
            <DetailRow label="Balance" value={formatINR(panel.view.balance)} />
            <DetailRow label="Date" value={panel.view.date} />
            <DetailRow label="Status" value={panel.view.status} />
            <DetailRow label="Description" value={panel.view.description} />
          </DetailSection>
        ) : null}
      </Drawer>
      <ConfirmDialog open={Boolean(panel.confirm)} description={`${panel.confirm?.id} will be removed from the ledger.`} onClose={() => panel.setConfirm(null)} onConfirm={() => { walletStore.remove(panel.confirm.id); panel.setConfirm(null); panel.setToast('Transaction deleted.'); }} />
        </>
      ) : (
        <GlassCard className="overflow-hidden">
          <DataTable
            scroll
            columns={[
              { key: 'rider', label: 'Rider', sortable: true },
              { key: 'availableWallet', label: 'Earning Wallet', render: (row) => formatINR(row.availableWallet ?? row.onlinePayoutBalance) },
              { key: 'codDue', label: 'COD Due', render: (row) => formatINR(row.codDue || 0) },
              { key: 'suspended', label: 'COD status', render: (row) => row.suspended ? 'Suspended' : 'Active' },
              { key: 'totalEarnings', label: 'Total Earnings', render: (row) => formatINR(row.totalEarnings) },
              { key: 'paidAmount', label: 'Paid Amount', render: (row) => formatINR(row.paidAmount) },
              { key: 'pendingPayout', label: 'Pending Payout', render: (row) => formatINR(row.pendingPayout) },
              { key: 'payoutStatus', label: 'Payout Status', render: (row) => <StatusBadge status={row.payoutStatus} /> },
              {
                key: 'actions',
                label: 'Actions',
                className: 'overflow-visible',
                render: (row) => (
                  <ActionGroup>
                    {can('payouts', 'approve') && row.pendingPayout > 0 ? (
                      <ActionButton icon={Check} tone="approve" onClick={() => {
                        payoutStore.upsert({
                          id: `PO-${String(row.riderId).slice(-4)}`,
                          rider: row.rider,
                          riderId: row.riderId,
                          amount: row.pendingPayout,
                          status: 'Approved',
                          method: 'UPI',
                          date: '17 Aug 2026',
                          period: '17 Aug 2026',
                        });
                        recordAudit({ user, action: 'Approve', module: 'Finance', recordId: row.riderId, newValue: `Payout ${row.pendingPayout}` });
                        panel.setToast('Payout approved.');
                      }}>Approve</ActionButton>
                    ) : null}
                  </ActionGroup>
                ),
              },
            ]}
            data={wallets.filter((row) => `${row.rider} ${row.riderId}`.toLowerCase().includes((searchQuery || '').toLowerCase()))}
            pageSize={8}
            compact
            itemLabel="riders"
          />
        </GlassCard>
      )}
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
