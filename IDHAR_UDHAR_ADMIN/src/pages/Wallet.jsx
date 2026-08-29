import { useEffect, useMemo, useState } from 'react';
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
import ErrorState from '../components/common/ErrorState';
import useStore from '../hooks/useStore';
import usePanelState from '../hooks/usePanelState';
import useQueryAction from '../hooks/useQueryAction';
import { riderStore } from '../services/stores';
import { formatINR } from '../utils/format';
import { useAuth } from '../context/AuthContext';
import Tabs from '../components/common/Tabs';
import { fetchRiderCod, fetchRiderEarnings, fetchRiderWallet, fetchRiderWalletLedger } from '../api/adminApi';

const emptyTxn = {
  id: '',
  user: '',
  userType: 'Customer',
  type: 'Credit',
  amount: '',
  balance: '',
  date: '',
  status: 'Success',
  description: '',
};

export default function WalletPage() {
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const riders = useStore(riderStore);
  const [type, setType] = useState('All');
  const [tab, setTab] = useState('ledger');
  const [rows, setRows] = useState([]);
  const [wallets, setWallets] = useState([]);
  const [loadError, setLoadError] = useState(null);
  const [loading, setLoading] = useState(true);
  const panel = usePanelState(emptyTxn);
  useQueryAction('add', panel.openCreate);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      const apiRiders = riders.filter((rider) => rider.id);
      const walletRows = await Promise.all(apiRiders.map(async (rider) => {
        try {
          const [wallet, cod, earnings] = await Promise.all([
            fetchRiderWallet(rider.id),
            fetchRiderCod(rider.id),
            fetchRiderEarnings(rider.id),
          ]);
          const available = Number(wallet.available_balance || 0);
          const totalEarnings = earnings.reduce((sum, row) => sum + Number(row.riderEarning || 0), 0);
          return {
            riderId: rider.id,
            rider: rider.name,
            availableWallet: available,
            onlinePayoutBalance: available,
            codDue: Number(cod.cod_due || 0),
            suspended: Boolean(cod.suspended),
            totalEarnings,
            paidAmount: 0,
            pendingPayout: 0,
            payoutStatus: available > 0 ? 'Pending' : 'Paid',
          };
        } catch {
          return null;
        }
      }));
      const ledgerRows = (await Promise.all(apiRiders.map(async (rider) => {
        try {
          const entries = await fetchRiderWalletLedger(rider.id);
          return entries.map((entry) => ({
            id: entry.wallet_ledger_id,
            user: rider.name,
            userType: 'Rider',
            type: entry.direction === 'CREDIT' ? 'Credit' : 'Debit',
            amount: Number(entry.amount || 0),
            balance: Number(entry.amount || 0),
            date: entry.created_at,
            status: 'Success',
            description: entry.entry_type,
          }));
        } catch {
          return [];
        }
      }))).flat();
      if (!cancelled) {
        if (apiRiders.length > 0 && walletRows.every((row) => row == null)) {
          setLoadError(new Error('Could not load wallet or COD data from the API.'));
          setWallets([]);
          setRows([]);
          setLoading(false);
          return;
        }
        setLoadError(null);
        setWallets(walletRows.filter(Boolean));
        setRows(ledgerRows);
        setLoading(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [riders]);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => (type === 'All' || row.type === type) && `${row.id} ${row.user} ${row.description}`.toLowerCase().includes(query));
  }, [rows, searchQuery, type]);

  const collected = useMemo(() => {
    const available = wallets.reduce((sum, row) => sum + Number(row.availableWallet || 0), 0);
    return {
      total: available,
      available,
      pending: 0,
      count: rows.length,
    };
  }, [rows, wallets]);

  function save() {
    panel.setToast('Admin wallet credit/debit is not available on the server yet.');
    panel.closeForm();
  }

  if (loading) return <TableSkeleton />;
  if (loadError) {
    return (
      <PageContainer>
        <ErrorState
          title="Couldn't load wallet"
          description={loadError.message || 'Wallet and COD values from the API are required. Dummy balances are not shown.'}
        />
      </PageContainer>
    );
  }

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
      <ConfirmDialog open={Boolean(panel.confirm)} description={`${panel.confirm?.id} cannot be deleted from Admin. Wallet ledgers are server-owned.`} onClose={() => panel.setConfirm(null)} onConfirm={() => { panel.setConfirm(null); panel.setToast('Wallet ledgers cannot be deleted from Admin.'); }} />
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
                        panel.setToast('Admin payout approval is not available on the server yet.');
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
