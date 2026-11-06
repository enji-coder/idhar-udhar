import { forwardRef } from 'react';
import { ASSETS } from '../../config/assets';
import { DEMO_BILLING_NOTICE } from '../../services/demoInvoice';
import { formatINRExact } from '../../utils/format';

const InvoicePreview = forwardRef(function InvoicePreview({ invoice }, ref) {
  if (!invoice) return null;
  if (invoice.stored) {
    const payment = invoice.payment || {};
    return (
      <article ref={ref} className="invoice-sheet rounded-3xl border border-line p-6 sm:p-8">
        <header className="flex flex-wrap items-start justify-between gap-4 border-b border-line pb-5">
          <div className="flex items-center gap-3">
            <img src={invoice.logoSrc || ASSETS.LOGO} alt="IDHAR UDHAR" className="h-14 w-auto object-contain" />
            <div>
              <h2 className="text-xl font-bold tracking-tight">IDHAR UDHAR</h2>
              <p className="text-sm text-ink-muted">Invoice</p>
            </div>
          </div>
          <div className="text-right text-xs text-ink-muted">
            <p className="text-sm font-semibold text-ink">{invoice.invoiceNumber}</p>
            <p>CRN {invoice.crn || 'Unavailable'}</p>
            {invoice.status ? <p>Status: {invoice.status}</p> : null}
          </div>
        </header>
        <div className="mt-4 grid gap-4 text-xs text-ink-muted sm:grid-cols-2">
          <p>
            Invoice date: {invoice.invoiceDate ? new Date(invoice.invoiceDate).toLocaleString('en-IN') : 'Unavailable'}
            <br />
            Trip completed: {invoice.tripAt ? new Date(invoice.tripAt).toLocaleString('en-IN') : 'Unavailable'}
          </p>
          <p className="sm:text-right">
            Vehicle: {invoice.vehicle?.category || 'Unavailable'} {invoice.vehicle?.registration || ''}
          </p>
        </div>
        <section className="mt-6 grid gap-4 sm:grid-cols-2">
          <div className="rounded-2xl bg-brand-50/70 p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-soft">Pickup</p>
            <p className="mt-1 text-sm text-ink">{invoice.pickup?.address || 'Unavailable'}</p>
          </div>
          <div className="rounded-2xl bg-slate-50 p-4">
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-soft">Drop</p>
            <p className="mt-1 text-sm text-ink">{invoice.drop?.address || 'Unavailable'}</p>
          </div>
        </section>
        <table className="mt-5 w-full text-sm">
          <tbody>
            {invoice.lines.map((line) => (
              <tr key={line.label} className="border-b border-slate-100">
                <td className="py-2">{line.label}</td>
                <td className="py-2 text-right">{formatINRExact(line.label === 'Discount' && Number(line.amount) > 0 ? -Number(line.amount) : line.amount)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <p className="mt-4 text-sm text-ink-muted">Payment status: {payment.status || 'Unavailable'}</p>
        <p className="text-sm text-ink-muted">
          Customer paid {formatINRExact(payment.customer_paid || 0)}
          {' · '}
          Receiver paid {formatINRExact(payment.receiver_paid || 0)}
        </p>
        <footer className="mt-6 border-t border-line pt-4 text-xs text-ink-soft">
          This is a computer-generated invoice for IDHAR UDHAR.
        </footer>
      </article>
    );
  }
  return (
    <article ref={ref} className="invoice-sheet rounded-3xl border border-dashed border-line p-6 sm:p-8">
      <p className="text-sm font-semibold text-ink">Demo billing record</p>
      <p className="mt-1 text-sm text-ink-muted">{DEMO_BILLING_NOTICE}</p>
      <dl className="mt-4 space-y-1 text-sm">
        <div className="flex justify-between gap-4"><dt className="text-ink-muted">Invoice number</dt><dd>{invoice.invoiceNumber || 'Unavailable'}</dd></div>
        <div className="flex justify-between gap-4"><dt className="text-ink-muted">Customer</dt><dd>{invoice.customer || invoice.billTo?.name || 'Unavailable'}</dd></div>
        <div className="flex justify-between gap-4"><dt className="text-ink-muted">Order reference</dt><dd>{invoice.orderId || 'Unavailable'}</dd></div>
        <div className="flex justify-between gap-4"><dt className="text-ink-muted">Amount</dt><dd>{invoice.amount ?? 'Unavailable'}</dd></div>
        <div className="flex justify-between gap-4"><dt className="text-ink-muted">Total</dt><dd>{invoice.total ?? 'Unavailable'}</dd></div>
        <div className="flex justify-between gap-4"><dt className="text-ink-muted">Payment status</dt><dd>{invoice.paymentStatus || invoice.payment?.status || 'Unavailable'}</dd></div>
      </dl>
    </article>
  );
});

export default InvoicePreview;
