import { useMemo } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Download, Eye, Pencil, Plus, Printer, Trash2 } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Modal from '../components/common/Modal';
import EmptyState from '../components/common/EmptyState';
import Field, { inputClass } from '../components/common/Field';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import ConfirmDialog from '../components/common/ConfirmDialog';
import Toast from '../components/common/Toast';
import PageHeader from '../components/common/PageHeader';
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import usePanelState from '../hooks/usePanelState';
import { purchaseInvoiceStore } from '../services/stores';
import { ASSETS } from '../config/assets';
import { printInvoiceHtml, purchaseInvoiceMarkup } from '../services/invoiceService';
import { nextId } from '../utils/ids';
import { compactErrors, nonNegative, required } from '../utils/validation';
import { formatINR } from '../utils/format';

const emptyPurchase = {
  id: '',
  invoiceNumber: '',
  vendor: '',
  purchaseDate: '17 Aug 2026',
  item: '',
  itemType: 'Vehicle',
  quantity: 1,
  subtotal: '',
  tax: '',
  total: '',
  paymentStatus: 'Pending',
  notes: '',
};

function PurchaseInvoiceSheet({ record }) {
  if (!record) return null;
  return (
    <article className="invoice-sheet rounded-3xl border border-line p-6 sm:p-8">
      <header className="flex flex-wrap items-start justify-between gap-4 border-b border-line pb-5">
        <div className="flex items-center gap-3">
          <img src={ASSETS.LOGO} alt="IDHAR UDHAR" className="h-14 w-auto object-contain" />
          <div>
            <h2 className="text-xl font-bold tracking-tight">IDHAR UDHAR</h2>
            <p className="text-sm text-ink-muted">Purchase Invoice</p>
          </div>
        </div>
        <div className="text-right text-sm">
          <p className="font-semibold">{record.invoiceNumber}</p>
          <p className="text-ink-muted">{record.purchaseDate}</p>
        </div>
      </header>
      <div className="mt-5 grid gap-4 sm:grid-cols-2">
        <div className="rounded-2xl bg-brand-50/70 p-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-soft">Vendor</p>
          <p className="mt-1 font-semibold text-ink">{record.vendor}</p>
          <p className="text-sm text-ink-muted">{record.itemType}</p>
        </div>
        <div className="rounded-2xl bg-white p-4 shadow-card">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-soft">Item</p>
          <p className="mt-1 font-semibold text-ink">{record.item}</p>
          <p className="text-sm text-ink-muted">Qty {record.quantity}</p>
        </div>
      </div>
      <table className="mt-5 w-full text-sm">
        <tbody>
          <tr className="border-b border-slate-100"><td className="py-2">Subtotal</td><td className="py-2 text-right">{formatINR(record.subtotal)}</td></tr>
          <tr className="border-b border-slate-100"><td className="py-2">Tax</td><td className="py-2 text-right">{formatINR(record.tax)}</td></tr>
          <tr><td className="py-3 font-bold">Total</td><td className="py-3 text-right font-bold">{formatINR(record.total)}</td></tr>
        </tbody>
      </table>
      <p className="mt-4 text-sm text-ink-muted">Payment Status: {record.paymentStatus}</p>
      {record.notes ? <p className="mt-2 text-sm text-ink-muted">Notes: {record.notes}</p> : null}
    </article>
  );
}

export default function PurchaseInvoices() {
  const { searchQuery } = useOutletContext() || {};
  const loading = useMockLoader();
  const rows = useStore(purchaseInvoiceStore);
  const panel = usePanelState(emptyPurchase);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => `${row.invoiceNumber} ${row.vendor} ${row.item}`.toLowerCase().includes(query));
  }, [rows, searchQuery]);

  function save() {
    const subtotal = Number(panel.form.subtotal);
    const tax = Number(panel.form.tax || 0);
    const issues = compactErrors({
      vendor: required(panel.form.vendor, 'Vendor is required.'),
      item: required(panel.form.item, 'Item / vehicle is required.'),
      subtotal: required(panel.form.subtotal, 'Subtotal is required.') || nonNegative(panel.form.subtotal, 'Amount cannot be negative.'),
    });
    panel.setErrors(issues);
    if (Object.keys(issues).length) return;
    const id = panel.form.id || nextId('PINV', rows);
    purchaseInvoiceStore.upsert({
      ...panel.form,
      id,
      invoiceNumber: panel.form.invoiceNumber || id,
      quantity: Number(panel.form.quantity) || 1,
      subtotal,
      tax,
      total: Number(panel.form.total) || subtotal + tax,
    });
    panel.setToast(panel.mode === 'edit' ? 'Purchase invoice updated.' : 'Purchase invoice created.');
    panel.closeForm();
  }

  function download(row) {
    const blob = new Blob([`Invoice ${row.invoiceNumber}\nVendor: ${row.vendor}\nItem: ${row.item}\nTotal: ${row.total}`], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${row.invoiceNumber}.txt`;
    link.click();
    URL.revokeObjectURL(url);
  }

  if (loading) return <TableSkeleton />;

  const columns = [
    { key: 'invoiceNumber', label: 'Invoice Number', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.invoiceNumber}</span> },
    { key: 'vendor', label: 'Vendor', sortable: true },
    { key: 'purchaseDate', label: 'Purchase Date' },
    { key: 'item', label: 'Item / Vehicle' },
    { key: 'quantity', label: 'Qty' },
    { key: 'subtotal', label: 'Subtotal', render: (row) => formatINR(row.subtotal), hideBelow: 'lg' },
    { key: 'tax', label: 'Tax', render: (row) => formatINR(row.tax), hideBelow: 'lg' },
    { key: 'total', label: 'Total', sortable: true, render: (row) => formatINR(row.total) },
    { key: 'paymentStatus', label: 'Payment Status', render: (row) => <StatusBadge status={row.paymentStatus} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => panel.setView(row)}>View</ActionButton>
          <ActionButton icon={Pencil} tone="edit" onClick={() => panel.openEdit(row)}>Edit</ActionButton>
          <ActionButton icon={Printer} tone="invoice" onClick={() => printInvoiceHtml(purchaseInvoiceMarkup(row), row.invoiceNumber)}>Print</ActionButton>
          <ActionButton icon={Download} tone="export" onClick={() => download(row)}>Download</ActionButton>
          <ActionButton icon={Trash2} tone="danger" onClick={() => panel.setConfirm(row)}>Delete</ActionButton>
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <PageHeader action={<Button icon={Plus} onClick={panel.openCreate}>Create Purchase Invoice</Button>} />
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? <EmptyState title="No purchase invoices found." description="Add a vendor or vehicle purchase invoice." /> : <DataTable columns={columns} data={data} pageSize={8} compact itemLabel="invoices" mobileTitleKey="invoiceNumber" />}
      </GlassCard>
      <Modal
        open={Boolean(panel.view)}
        title={`Purchase Invoice ${panel.view?.invoiceNumber || ''}`}
        size="xl"
        onClose={() => panel.setView(null)}
        footer={(
          <>
            <Button variant="ghost" onClick={() => panel.setView(null)}>Close</Button>
            <Button variant="secondary" icon={Printer} onClick={() => panel.view && printInvoiceHtml(purchaseInvoiceMarkup(panel.view), panel.view.invoiceNumber)}>Print</Button>
            <Button icon={Download} onClick={() => panel.view && download(panel.view)}>Download</Button>
          </>
        )}
      >
        <PurchaseInvoiceSheet record={panel.view} />
      </Modal>
      <Modal open={Boolean(panel.mode)} title={panel.mode === 'edit' ? 'Edit purchase invoice' : 'Create Purchase Invoice'} size="lg" onClose={panel.closeForm} footer={<><Button variant="ghost" onClick={panel.closeForm}>Cancel</Button><Button onClick={save}>Save</Button></>}>
        <div className="grid gap-3 sm:grid-cols-2">
          <Field label="Vendor" error={panel.errors.vendor}><input className={inputClass} value={panel.form.vendor} onChange={(event) => panel.setForm({ ...panel.form, vendor: event.target.value })} /></Field>
          <Field label="Purchase date"><input className={inputClass} value={panel.form.purchaseDate} onChange={(event) => panel.setForm({ ...panel.form, purchaseDate: event.target.value })} /></Field>
          <Field label="Item / Vehicle" error={panel.errors.item}><input className={inputClass} value={panel.form.item} onChange={(event) => panel.setForm({ ...panel.form, item: event.target.value })} /></Field>
          <Field label="Item type">
            <select className={inputClass} value={panel.form.itemType} onChange={(event) => panel.setForm({ ...panel.form, itemType: event.target.value })}>
              <option>Vehicle</option><option>Maintenance</option><option>Insurance</option><option>Parts</option><option>Expense</option>
            </select>
          </Field>
          <Field label="Quantity"><input type="number" className={inputClass} value={panel.form.quantity} onChange={(event) => panel.setForm({ ...panel.form, quantity: event.target.value })} /></Field>
          <Field label="Subtotal" error={panel.errors.subtotal}><input type="number" className={inputClass} value={panel.form.subtotal} onChange={(event) => panel.setForm({ ...panel.form, subtotal: event.target.value })} /></Field>
          <Field label="Tax"><input type="number" className={inputClass} value={panel.form.tax} onChange={(event) => panel.setForm({ ...panel.form, tax: event.target.value })} /></Field>
          <Field label="Payment status">
            <select className={inputClass} value={panel.form.paymentStatus} onChange={(event) => panel.setForm({ ...panel.form, paymentStatus: event.target.value })}>
              <option>Paid</option><option>Pending</option>
            </select>
          </Field>
          <Field label="Notes"><input className={inputClass} value={panel.form.notes} onChange={(event) => panel.setForm({ ...panel.form, notes: event.target.value })} /></Field>
        </div>
      </Modal>
      <ConfirmDialog open={Boolean(panel.confirm)} description={`${panel.confirm?.invoiceNumber} will be deleted.`} onClose={() => panel.setConfirm(null)} onConfirm={() => { purchaseInvoiceStore.remove(panel.confirm.id); panel.setConfirm(null); panel.setToast('Purchase invoice deleted.'); }} />
      <Toast open={Boolean(panel.toast)} message={panel.toast} onClose={() => panel.setToast('')} />
    </PageContainer>
  );
}
