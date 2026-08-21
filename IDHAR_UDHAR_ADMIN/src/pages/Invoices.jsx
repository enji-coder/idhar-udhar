import { useMemo } from 'react';
import { useNavigate, useOutletContext } from 'react-router-dom';
import { Download, Eye, FileText, Pencil, Plus, Printer, Trash2 } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Select from '../components/common/Select';
import Modal from '../components/common/Modal';
import EmptyState from '../components/common/EmptyState';
import Field, { inputClass } from '../components/common/Field';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import ConfirmDialog from '../components/common/ConfirmDialog';
import Toast from '../components/common/Toast';
import PageHeader from '../components/common/PageHeader';
import InvoicePreview from '../components/orders/InvoicePreview';
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import usePanelState from '../hooks/usePanelState';
import useQueryAction from '../hooks/useQueryAction';
import { invoiceStore, orderStore } from '../services/stores';
import { downloadInvoicePdf, invoiceFromRecord, invoicePrintMarkup, printInvoiceHtml } from '../services/invoiceService';
import { nextId } from '../utils/ids';
import { compactErrors, nonNegative, required } from '../utils/validation';
import { formatINR } from '../utils/format';
import { useState } from 'react';

const emptyInvoice = {
  id: '',
  invoiceNumber: '',
  orderId: '',
  customer: '',
  amount: '',
  tax: '',
  discount: 0,
  total: '',
  paymentStatus: 'Pending',
  paymentMethod: 'UPI',
  invoiceDate: '17 Aug 2026',
  dueDate: '24 Aug 2026',
  status: 'Draft',
  notes: '',
};

export default function Invoices() {
  const navigate = useNavigate();
  const { searchQuery } = useOutletContext() || {};
  const loading = useMockLoader();
  const rows = useStore(invoiceStore);
  const orders = useStore(orderStore);
  const [status, setStatus] = useState('All');
  const panel = usePanelState(emptyInvoice);
  useQueryAction('add', panel.openCreate);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => (status === 'All' || row.paymentStatus === status || row.status === status) && `${row.invoiceNumber} ${row.orderId} ${row.customer}`.toLowerCase().includes(query));
  }, [rows, searchQuery, status]);

  function previewFor(row) {
    const order = orders.find((item) => item.id === row.orderId);
    return invoiceFromRecord(row, order);
  }

  function save() {
    const amount = Number(panel.form.amount);
    const tax = Number(panel.form.tax || 0);
    const discount = Number(panel.form.discount || 0);
    const issues = compactErrors({
      customer: required(panel.form.customer, 'Customer is required.'),
      amount: required(panel.form.amount, 'Amount is required.') || nonNegative(panel.form.amount, 'Amount cannot be negative.'),
    });
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    const id = panel.form.id || nextId('INV-AMD', rows).replace('INV-AMD-', 'INV-AMD-');
    const invoiceNumber = panel.form.invoiceNumber || id;
    invoiceStore.upsert({
      ...panel.form,
      id,
      invoiceNumber,
      amount,
      tax,
      discount,
      total: Number(panel.form.total) || amount + tax - discount,
    });
    panel.setToast(panel.mode === 'edit' ? 'Invoice updated.' : 'Invoice created.');
    panel.closeForm();
  }

  if (loading) return <TableSkeleton />;

  const columns = [
    { key: 'invoiceNumber', label: 'Invoice Number', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.invoiceNumber}</span> },
    { key: 'orderId', label: 'Order ID' },
    { key: 'customer', label: 'Customer', sortable: true },
    { key: 'amount', label: 'Amount', render: (row) => formatINR(row.amount) },
    { key: 'tax', label: 'Tax', render: (row) => formatINR(row.tax), hideBelow: 'lg' },
    { key: 'total', label: 'Total', sortable: true, render: (row) => formatINR(row.total) },
    { key: 'paymentStatus', label: 'Payment Status', render: (row) => <StatusBadge status={row.paymentStatus} /> },
    { key: 'invoiceDate', label: 'Invoice Date', hideBelow: 'lg' },
    { key: 'dueDate', label: 'Due Date', hideBelow: 'lg' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => panel.setView(row)}>View Invoice</ActionButton>
          <ActionButton icon={Pencil} tone="edit" onClick={() => panel.openEdit(row)}>Edit Invoice</ActionButton>
          <ActionButton icon={Download} tone="export" onClick={() => downloadInvoicePdf(previewFor(row))}>Download Invoice</ActionButton>
          <ActionButton icon={Printer} tone="invoice" onClick={() => printInvoiceHtml(invoicePrintMarkup(previewFor(row)), row.invoiceNumber)}>Print Invoice</ActionButton>
          <ActionButton icon={Trash2} tone="danger" onClick={() => panel.setConfirm(row)}>Delete Invoice</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  const invoice = panel.view ? previewFor(panel.view) : null;

  return (
    <PageContainer className="space-y-4">
      <PageHeader
        action={(
          <div className="flex flex-wrap gap-2">
            <Button variant="secondary" icon={FileText} onClick={() => navigate('/purchase-invoices')}>Purchase Invoices</Button>
            <Button icon={Plus} onClick={panel.openCreate}>Create Invoice</Button>
          </div>
        )}
      />
      <GlassCard className="flex flex-wrap gap-3">
        <Select aria-label="Payment status" value={status} onChange={setStatus} options={['All', 'Paid', 'Pending', 'Refunded', 'Draft', 'Issued']} />
      </GlassCard>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No invoices found." description="Create an invoice or change the payment filter." /> : <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="invoices" mobileTitleKey="invoiceNumber" />}
      </GlassCard>

      <Modal
        open={Boolean(panel.view)}
        title={`Invoice ${panel.view?.invoiceNumber || ''}`}
        size="xl"
        onClose={() => panel.setView(null)}
        footer={(
          <>
            <Button variant="ghost" onClick={() => panel.setView(null)}>Close</Button>
            <Button variant="secondary" icon={Printer} onClick={() => invoice && printInvoiceHtml(invoicePrintMarkup(invoice), invoice.invoiceNumber)}>Print</Button>
            <Button icon={Download} onClick={() => invoice && downloadInvoicePdf(invoice)}>Download</Button>
          </>
        )}
      >
        <InvoicePreview invoice={invoice} />
      </Modal>

      <Modal open={Boolean(panel.mode)} title={panel.mode === 'edit' ? 'Edit invoice' : 'Create Invoice'} size="lg" onClose={panel.closeForm} footer={<><Button variant="ghost" onClick={panel.closeForm}>Cancel</Button><Button onClick={save}>Save</Button></>}>
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Customer" error={panel.errors.customer}><input className={inputClass} value={panel.form.customer} onChange={(event) => panel.setForm({ ...panel.form, customer: event.target.value })} /></Field>
          <Field label="Order ID"><input className={inputClass} value={panel.form.orderId} onChange={(event) => panel.setForm({ ...panel.form, orderId: event.target.value })} /></Field>
          <Field label="Amount" error={panel.errors.amount}><input type="number" className={inputClass} value={panel.form.amount} onChange={(event) => panel.setForm({ ...panel.form, amount: event.target.value })} /></Field>
          <Field label="Tax"><input type="number" className={inputClass} value={panel.form.tax} onChange={(event) => panel.setForm({ ...panel.form, tax: event.target.value })} /></Field>
          <Field label="Discount"><input type="number" className={inputClass} value={panel.form.discount} onChange={(event) => panel.setForm({ ...panel.form, discount: event.target.value })} /></Field>
          <Field label="Payment method">
            <select className={inputClass} value={panel.form.paymentMethod} onChange={(event) => panel.setForm({ ...panel.form, paymentMethod: event.target.value })}>
              <option>UPI</option><option>Cash</option><option>Card</option><option>Wallet</option>
            </select>
          </Field>
          <Field label="Payment status">
            <select className={inputClass} value={panel.form.paymentStatus} onChange={(event) => panel.setForm({ ...panel.form, paymentStatus: event.target.value })}>
              <option>Paid</option><option>Pending</option><option>Refunded</option>
            </select>
          </Field>
          <Field label="Status">
            <select className={inputClass} value={panel.form.status} onChange={(event) => panel.setForm({ ...panel.form, status: event.target.value })}>
              <option>Draft</option><option>Issued</option><option>Cancelled</option>
            </select>
          </Field>
          <Field label="Invoice date"><input className={inputClass} value={panel.form.invoiceDate} onChange={(event) => panel.setForm({ ...panel.form, invoiceDate: event.target.value })} /></Field>
          <Field label="Due date"><input className={inputClass} value={panel.form.dueDate} onChange={(event) => panel.setForm({ ...panel.form, dueDate: event.target.value })} /></Field>
          <Field label="Notes"><input className={inputClass} value={panel.form.notes} onChange={(event) => panel.setForm({ ...panel.form, notes: event.target.value })} /></Field>
        </div>
      </Modal>
      <ConfirmDialog open={Boolean(panel.confirm)} description={`${panel.confirm?.invoiceNumber} will be deleted from billing.`} onClose={() => panel.setConfirm(null)} onConfirm={() => { invoiceStore.remove(panel.confirm.id); panel.setConfirm(null); panel.setToast('Invoice deleted.'); }} />
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
