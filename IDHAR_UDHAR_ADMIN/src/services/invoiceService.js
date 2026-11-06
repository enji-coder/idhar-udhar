import { DEMO_BILLING_NOTICE, DEMO_PURCHASE_NOTICE, demoBillingRecord, demoBillingText } from './demoInvoice.js';
import { inrText, invoiceFromStored, storedInvoiceText, whenText } from './storedInvoicePdf.js';

export { demoBillingRecord, demoBillingText, DEMO_BILLING_NOTICE, DEMO_PURCHASE_NOTICE };

export { invoiceFromStored, storedInvoiceText };

export { downloadInvoicePdf } from '../components/orders/downloadInvoicePreview';

export function printInvoiceHtml(html, title) {
  const win = window.open('', '_blank', 'noopener,noreferrer,width=900,height=1100');
  if (!win) return false;
  win.document.write(`<!doctype html><html><head><title>${title}</title>
    <style>
      body { margin: 0; background: #f3f7ff; font-family: Inter, Arial, sans-serif; color: #0F1F3D; }
      .sheet { width: 780px; margin: 24px auto; background: white; padding: 36px 40px; }
      @media print { body { background: white; } .sheet { margin: 0; width: auto; box-shadow: none; } }
    </style></head><body>${html}</body></html>`);
  win.document.close();
  win.focus();
  win.print();
  return true;
}

export function invoiceShareText(invoice) {
  if (invoice?.stored) {
    return storedInvoiceText(invoice);
  }
  return demoBillingText(invoice || {});
}

/** Local demo rows are not official trip invoices. */
export function invoiceFromRecord(record) {
  return demoBillingRecord(record);
}

export function purchaseInvoiceMarkup(record) {
  return `<div class="sheet">
    <p><strong>${DEMO_PURCHASE_NOTICE}</strong></p>
    <h1 style="margin:0">IDHAR UDHAR</h1>
    <p>Purchase Invoice</p>
    <h2>${record.invoiceNumber}</h2>
    <p>Vendor: ${record.vendor}<br/>Purchase Date: ${record.purchaseDate}</p>
    <p>Item: ${record.item} (${record.itemType})<br/>Quantity: ${record.quantity}</p>
    <table style="width:100%;border-collapse:collapse" border="1" cellpadding="8">
      <tr><td>Subtotal</td><td style="text-align:right">Rs. ${Number(record.subtotal).toFixed(2)}</td></tr>
      <tr><td>Tax</td><td style="text-align:right">Rs. ${Number(record.tax).toFixed(2)}</td></tr>
      <tr><td><strong>Total</strong></td><td style="text-align:right"><strong>Rs. ${Number(record.total).toFixed(2)}</strong></td></tr>
    </table>
    <p>Payment Status: ${record.paymentStatus}</p>
    <p>${record.notes || ''}</p>
  </div>`;
}

export function invoicePrintMarkup(invoice) {
  if (!invoice) return '';
  if (invoice.stored) return storedInvoiceMarkup(invoice);
  const demo = invoice.demo ? invoice : demoBillingRecord(invoice);
  return `<div class="sheet">
    <p><strong>${DEMO_BILLING_NOTICE}</strong></p>
    <h1 style="margin:0">Demo billing record</h1>
    <p>${demoBillingText(demo).replaceAll('\n', '<br/>')}</p>
  </div>`;
}

function storedInvoiceMarkup(invoice) {
  const rows = invoice.lines.map((line) => `<tr><td>${line.label}</td><td style="text-align:right">${inrText(line.amount)}</td></tr>`).join('');
  const payment = invoice.payment || {};
  return `<div class="sheet">
    <img src="/assets/logo/idhar-udhar-logo.png" alt="IDHAR UDHAR" style="height:56px" />
    <h1 style="margin:8px 0 0">IDHAR UDHAR</h1>
    <h2>Invoice ${invoice.invoiceNumber}</h2>
    <p>CRN: ${invoice.crn || 'Unavailable'}<br/>Invoice date: ${whenText(invoice.invoiceDate)}<br/>Trip completed: ${whenText(invoice.tripAt)}</p>
    <p><strong>Pickup</strong><br/>${invoice.pickup?.address || 'Unavailable'}</p>
    <p><strong>Drop</strong><br/>${invoice.drop?.address || 'Unavailable'}</p>
    <p><strong>Vehicle</strong><br/>${invoice.vehicle?.category || 'Unavailable'} ${invoice.vehicle?.registration || ''}</p>
    <table style="width:100%;border-collapse:collapse" border="1" cellpadding="8">${rows}</table>
    <p>Payment status: ${payment.status || 'Unavailable'}<br/>Customer paid: ${inrText(payment.customer_paid)}<br/>Receiver paid: ${inrText(payment.receiver_paid)}</p>
    <p>This is a computer-generated invoice for IDHAR UDHAR.</p>
  </div>`;
}
