import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useOutletContext } from 'react-router-dom';
import { Eye, Download, FileText, RotateCcw } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Select from '../components/common/Select';
import Drawer from '../components/common/Drawer';
import Modal from '../components/common/Modal';
import EmptyState from '../components/common/EmptyState';
import Tabs from '../components/common/Tabs';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import { TableSkeleton } from '../components/common/Skeleton';
import ErrorState from '../components/common/ErrorState';
import useStore from '../hooks/useStore';
import { orderStore, paymentStore } from '../services/stores';
import { fetchAdminPayments } from '../api/adminApi';
import { downloadCsv, formatINR } from '../utils/format';
import { formatNumericOrderId, invoiceNumberFor } from '../utils/orderId';
import { useAuth } from '../context/AuthContext';

const tabs = [
  { value: 'All', label: 'All' },
  { value: 'Success', label: 'Paid' },
  { value: 'Pending', label: 'Pending' },
  { value: 'Refunded', label: 'Refunded' },
  { value: 'Failed', label: 'Failed' },
];

export default function Payments() {
  const navigate = useNavigate();
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const stored = useStore(paymentStore);
  const orders = useStore(orderStore);
  const [tab, setTab] = useState('All');
  const [method, setMethod] = useState('All');
  const [selected, setSelected] = useState(null);
  const [refund, setRefund] = useState(null);
  const [fetched, setFetched] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    fetchAdminPayments()
      .then((rows) => {
        if (!cancelled) {
          paymentStore.replace(rows);
          setFetched(rows);
          setLoadError(null);
        }
      })
      .catch((error) => {
        if (!cancelled) {
          paymentStore.replace([]);
          setFetched([]);
          setLoadError(error);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const transactions = useMemo(() => {
    const source = fetched ?? stored;
    return source.map((row) => {
      const order = orders.find((item) => item.backendOrderId === row.backendOrderId || item.id === row.orderId);
      return {
        ...row,
        customer: order?.customer || row.customer,
        orderId: order?.id || row.orderId,
      };
    });
  }, [fetched, stored, orders]);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return transactions.filter((row) => {
      const matchesTab = tab === 'All' || row.status === tab;
      return matchesTab && (method === 'All' || row.method === method) && `${row.id} ${row.orderId} ${row.customer}`.toLowerCase().includes(query);
    });
  }, [tab, method, searchQuery, transactions]);

  if (loading) return <TableSkeleton />;
  if (loadError) {
    return (
      <PageContainer>
        <ErrorState
          title="Couldn't load payments"
          description={loadError.message || 'The payments API did not respond. Dummy transactions are not shown.'}
        />
      </PageContainer>
    );
  }

  const columns = [
    { key: 'orderId', label: 'Order ID', render: (row) => formatNumericOrderId(row.orderId) },
    { key: 'id', label: 'Transaction ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'invoiceNumber', label: 'Invoice Number', render: (row) => invoiceNumberFor(row.orderId), hideBelow: 'lg' },
    { key: 'customer', label: 'Customer', sortable: true },
    { key: 'amount', label: 'Payment Amount', sortable: true, render: (row) => formatINR(row.amount) },
    { key: 'method', label: 'Payment Mode' },
    { key: 'status', label: 'Payment Status', render: (row) => <StatusBadge status={row.status === 'Success' ? 'Paid' : row.status} /> },
    { key: 'gatewayStatus', label: 'Payment Gateway Status', hideBelow: 'lg', render: (row) => row.gatewayStatus || (row.method === 'Cash' ? 'Cash Collection' : row.status) },
    { key: 'cashCollection', label: 'Cash Collection', hideBelow: 'lg', render: (row) => formatINR(row.method === 'Cash' ? row.amount : 0) },
    { key: 'date', label: 'Payment Date', hideBelow: 'lg' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => setSelected(row)}>View</ActionButton>
          <ActionButton icon={FileText} tone="invoice" onClick={() => navigate('/invoices')}>View Invoice</ActionButton>
          {can('payments', 'refund') && row.status === 'Success' ? <ActionButton icon={RotateCcw} tone="danger" onClick={() => setRefund(row)}>Refund</ActionButton> : null}
        </ActionGroup>
      ),
    },
  ];

  const collected = transactions.filter((row) => row.status === 'Success').reduce((sum, row) => sum + row.amount, 0);
  const refunded = transactions.filter((row) => row.status === 'Refunded').reduce((sum, row) => sum + row.amount, 0);

  return (
    <PageContainer className="space-y-4">
      <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
        <GlassCard><p className="text-sm text-ink-muted">Collected</p><p className="text-2xl font-bold">{formatINR(collected)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Refunds</p><p className="text-2xl font-bold">{formatINR(refunded)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Transactions</p><p className="text-2xl font-bold">{transactions.length}</p></GlassCard>
      </div>
      <GlassCard className="flex min-w-0 flex-wrap items-center gap-3 overflow-hidden">
        <Tabs tabs={tabs} value={tab} onChange={setTab} />
        <Select aria-label="Method" value={method} onChange={setMethod} options={['All', 'UPI', 'Cash', 'Card', 'Net Banking', 'Wallet']} />
        {can('payments', 'export') ? <Button variant="export" icon={Download} onClick={() => downloadCsv('payments.csv', data, columns.filter((column) => column.key !== 'actions'))}>Export</Button> : null}
      </GlassCard>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No transactions found" description="Try changing your filters or search criteria." action={<Button variant="secondary" onClick={() => { setTab('All'); setMethod('All'); }}>Clear Filters</Button>} /> : <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="transactions" />}
      </GlassCard>
      <Drawer open={Boolean(selected)} size="lg" eyebrow="Transaction" title={selected?.id} onClose={() => setSelected(null)} footer={<Button onClick={() => setSelected(null)}>Close</Button>}>
        {selected ? (
          <DetailSection title="Payment">
            <DetailRow label="Order" value={formatNumericOrderId(selected.orderId)} />
            <DetailRow label="Invoice" value={invoiceNumberFor(selected.orderId)} />
            <DetailRow label="Customer" value={selected.customer} />
            <DetailRow label="Amount" value={formatINR(selected.amount)} />
            <DetailRow label="Mode" value={selected.method} />
            <DetailRow label="Status" value={selected.status} />
            <DetailRow label="Gateway" value={selected.gatewayStatus || selected.status} />
            <DetailRow label="Date" value={selected.date} />
          </DetailSection>
        ) : null}
      </Drawer>
      <Modal
        open={Boolean(refund)}
        title="Refund this payment?"
        onClose={() => setRefund(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setRefund(null)}>Cancel</Button>
            <Button variant="reject" onClick={() => setRefund(null)}>Close</Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">Refunds are not available on the server yet. {refund ? `${formatINR(refund.amount)} for ${refund.customer}` : ''} remains unchanged.</p>
      </Modal>
    </PageContainer>
  );
}
