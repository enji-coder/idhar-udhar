import { forwardRef } from 'react';
import { ASSETS } from '../../config/assets';
import { formatINRExact } from '../../utils/format';

const InvoicePreview = forwardRef(function InvoicePreview({ invoice }, ref) {
  if (!invoice) return null;
  const { company } = invoice;

  return (
    <article ref={ref} className="invoice-sheet rounded-3xl border border-line p-6 sm:p-8">
      <header className="flex flex-wrap items-start justify-between gap-4 border-b border-line pb-5">
        <div className="flex items-center gap-3">
          <img src={invoice.logoSrc || ASSETS.LOGO} alt="IDHAR UDHAR" className="h-14 w-auto object-contain" />
          <div>
            <h2 className="text-xl font-bold tracking-tight">{company.name}</h2>
            <p className="text-sm text-ink-muted">{company.tagline}</p>
          </div>
        </div>
        <div className="text-right text-xs text-ink-muted">
          <p className="text-sm font-semibold text-ink">TAX INVOICE</p>
          <p>{invoice.invoiceNumber}</p>
          <p>GSTIN {company.gstin}</p>
          {invoice.status ? <p>Status: {invoice.status}</p> : null}
        </div>
      </header>

      <div className="mt-4 grid gap-4 text-xs text-ink-muted sm:grid-cols-2">
        <p>{company.address}<br />{company.phone}<br />{company.email}</p>
        <p className="sm:text-right">
          Invoice Date: {invoice.invoiceDate}<br />
          Due Date: {invoice.dueDate}<br />
          Order ID: {invoice.orderId}
        </p>
      </div>

      <section className="mt-6 grid gap-4 sm:grid-cols-2">
        <div className="rounded-2xl bg-brand-50/70 p-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-soft">Bill To</p>
          <p className="mt-1 font-semibold text-ink">{invoice.billTo.name}</p>
          <p className="text-sm text-ink-muted">{invoice.billTo.phone}</p>
          <p className="text-sm text-ink-muted">{invoice.billTo.email}</p>
          <p className="mt-1 text-sm text-ink-muted">{invoice.billTo.address}</p>
        </div>
        <div className="rounded-2xl bg-slate-50 p-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-soft">Delivery Details</p>
          <p className="mt-1 text-sm"><span className="text-ink-muted">Pickup:</span> {invoice.delivery.pickupAddress}</p>
          <p className="text-sm"><span className="text-ink-muted">Destination:</span> {invoice.delivery.destinationAddress}</p>
          <p className="text-sm"><span className="text-ink-muted">Date:</span> {invoice.delivery.date}</p>
          <p className="text-sm"><span className="text-ink-muted">Rider:</span> {invoice.delivery.rider || 'Unassigned'}</p>
          <p className="text-sm"><span className="text-ink-muted">Vehicle:</span> {invoice.delivery.vehicle} {invoice.delivery.vehicleNumber}</p>
        </div>
      </section>

      <section className="mt-5 rounded-2xl border border-line p-4">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-soft">Package</p>
        <p className="mt-1 text-sm">{invoice.package.type} · Qty {invoice.package.quantity} · {invoice.package.weight}</p>
        <p className="text-sm text-ink-muted">{invoice.package.description}</p>
      </section>

      <table className="mt-5 w-full text-sm">
        <thead>
          <tr className="border-b border-line text-left text-ink-muted">
            <th className="py-2 font-medium">Description</th>
            <th className="py-2 text-right font-medium">Qty</th>
            <th className="py-2 text-right font-medium">Amount</th>
          </tr>
        </thead>
        <tbody>
          {invoice.lines.map((line) => (
            <tr key={line.label} className="border-b border-slate-100">
              <td className="py-2">{line.label}</td>
              <td className="py-2 text-right">{line.quantity ?? invoice.package.quantity ?? 1}</td>
              <td className="py-2 text-right">{formatINRExact(line.amount)}</td>
            </tr>
          ))}
          <tr>
            <td className="py-3 font-bold">Total</td>
            <td className="py-3" />
            <td className="py-3 text-right font-bold">{formatINRExact(invoice.total)}</td>
          </tr>
        </tbody>
      </table>

      <p className="mt-4 text-sm text-ink-muted">Payment Method: {invoice.payment.method} · Status: {invoice.payment.status}</p>
      {invoice.payment.customerResponsibility != null ? (
        <p className="text-sm text-ink-muted">
          Customer Paid {formatINRExact(invoice.payment.customerPaid || 0)}
          {' · '}
          Receiver Paid {formatINRExact(invoice.payment.receiverPaid || 0)}
        </p>
      ) : null}
      <footer className="mt-6 border-t border-line pt-4 text-xs text-ink-soft">
        <p className="font-semibold text-ink">{company.legalName || 'SwiftSend Innovation Private Limited'}</p>
        <p>GSTIN {company.gstin} · CIN {company.cin} · PAN {company.pan}</p>
        <p className="mt-1">This is a computer-generated invoice for IDHAR UDHAR logistics.</p>
      </footer>
    </article>
  );
});

export default InvoicePreview;
