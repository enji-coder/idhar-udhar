import { company } from '../config/company';
import { methodsSummary } from './paymentPlan';

function round2(value) {
  return Math.round(Number(value || 0) * 100) / 100;
}

function packagingFor(order) {
  if (order.packagingFee != null) return round2(order.packagingFee);
  const type = `${order.packageType || ''}`.toLowerCase();
  if (type.includes('document')) return 0;
  if (type.includes('fragile') || type.includes('gift')) return 25;
  const weight = Number(String(order.weight || '0').replace(/[^\d.]/g, ''));
  if (weight >= 10) return 40;
  if (weight >= 5) return 20;
  return 15;
}

export function buildInvoice(order, extras = {}) {
  const deliveryCharge = round2(order.amount || 0);
  const packaging = packagingFor(order);
  const taxRate = 0;
  const taxable = round2(deliveryCharge + packaging);
  const tax = round2(taxable * (taxRate / 100));
  const discount = round2(order.discount ?? extras.discount ?? 0);
  const total = round2(taxable + tax - discount);
  const invoiceNumber = extras.invoiceNumber || `INV-${String(order.id || '').replace('IU-', '')}`;
  const invoiceDate = order.date || extras.invoiceDate || '14 Aug 2026';

  return {
    company,
    invoiceNumber,
    invoiceDate,
    status: order.invoiceStatus || extras.status || (order.status === 'Cancelled' ? 'Cancelled' : 'Issued'),
    dueDate: order.dueDate || extras.dueDate || invoiceDate,
    orderId: order.id,
    billTo: {
      name: order.customer,
      phone: extras.phone || order.customerPhone || '',
      email: extras.email || order.customerEmail || '',
      address: extras.address || order.pickupAddress || order.pickup || '',
    },
    delivery: {
      pickup: order.pickup,
      pickupAddress: order.pickupAddress || order.pickup,
      destination: order.destination,
      destinationAddress: order.destinationAddress || order.destination,
      date: order.deliveredAt || order.date,
      rider: order.rider,
      vehicle: order.vehicle,
      vehicleNumber: order.vehicleNumber || extras.vehicleNumber || '',
    },
    package: {
      type: order.packageType || 'Package',
      weight: order.weight || '—',
      quantity: order.quantity || 1,
      description: order.instructions || 'Standard city delivery',
    },
    payment: {
      method: methodsSummary(order.paymentPlan?.allocation) || order.payment,
      status: order.paymentStatus || 'UNPAID',
      customerResponsibility: round2(order.customerResponsibility ?? deliveryCharge),
      receiverResponsibility: round2(order.receiverResponsibility ?? 0),
      customerPaid: round2(order.customerPaid ?? 0),
      receiverPaid: round2(order.receiverPaid ?? 0),
      outstanding: round2((order.outstandingAmount ?? (total - round2(order.customerPaid || 0) - round2(order.receiverPaid || 0)))),
      transactions: order.paymentPlan?.transactions || order.paymentTransactions || [],
    },
    lines: [
      { label: 'Delivery Charge', amount: deliveryCharge, quantity: 1 },
      { label: 'Packaging', amount: packaging, quantity: 1 },
      ...(discount ? [{ label: 'Discount', amount: -discount, quantity: 1 }] : []),
      { label: `Tax (${taxRate}%)`, amount: tax, quantity: 1 },
    ],
    deliveryCharge,
    packaging,
    discount,
    taxRate,
    tax,
    taxable,
    total,
  };
}

export { downloadInvoicePdf } from '../components/orders/downloadInvoicePreview';

function escapePdf(text) {
  return String(text ?? '')
    .replace(/\\/g, '\\\\')
    .replace(/\(/g, '\\(')
    .replace(/\)/g, '\\)');
}

export function invoicePdfBlob(invoice) {
  const lines = [
    { text: invoice.company.name, size: 18, gap: 16 },
    { text: invoice.company.tagline, size: 10, gap: 14 },
    { text: invoice.company.address, size: 9, gap: 12 },
    { text: `Phone: ${invoice.company.phone}  Email: ${invoice.company.email}`, size: 9, gap: 12 },
    { text: `GSTIN: ${invoice.company.gstin}`, size: 9, gap: 22 },
    { text: `TAX INVOICE  ${invoice.invoiceNumber}`, size: 13, gap: 16 },
    { text: `Invoice Date: ${invoice.invoiceDate}    Order: ${invoice.orderId}`, size: 10, gap: 18 },
    { text: 'Bill To', size: 11, gap: 13 },
    { text: invoice.billTo.name, size: 10, gap: 12 },
    { text: [invoice.billTo.phone, invoice.billTo.email].filter(Boolean).join('  '), size: 9, gap: 12 },
    { text: invoice.billTo.address, size: 9, gap: 18 },
    { text: 'Delivery', size: 11, gap: 13 },
    { text: `Pickup: ${invoice.delivery.pickupAddress}`, size: 9, gap: 12 },
    { text: `Destination: ${invoice.delivery.destinationAddress}`, size: 9, gap: 12 },
    { text: `Rider: ${invoice.delivery.rider || 'Unassigned'}  Vehicle: ${invoice.delivery.vehicle || ''} ${invoice.delivery.vehicleNumber || ''}`.trim(), size: 9, gap: 18 },
    { text: 'Package', size: 11, gap: 13 },
    { text: `${invoice.package.type}  Qty ${invoice.package.quantity}  Weight ${invoice.package.weight}`, size: 9, gap: 12 },
    { text: invoice.package.description, size: 9, gap: 20 },
    { text: `Delivery Charge          Rs. ${invoice.deliveryCharge.toFixed(2)}`, size: 10, gap: 13 },
    { text: `Packaging                Rs. ${invoice.packaging.toFixed(2)}`, size: 10, gap: 13 },
    { text: `Tax (${invoice.taxRate}%)                 Rs. ${invoice.tax.toFixed(2)}`, size: 10, gap: 16 },
    { text: `Total                    Rs. ${invoice.total.toFixed(2)}`, size: 12, gap: 18 },
    { text: `Payment: ${invoice.payment.method}  Status: ${invoice.payment.status}`, size: 10, gap: 16 },
    { text: `Legal entity: ${invoice.company.legalName || 'SwiftSend Innovation Private Limited'}`, size: 8, gap: 12 },
    { text: `${invoice.company.legalName || 'SwiftSend Innovation Private Limited'} | GSTIN ${invoice.company.gstin} | CIN ${invoice.company.cin}`, size: 8, gap: 12 },
    { text: 'This is a computer-generated invoice for IDHAR UDHAR logistics.', size: 8, gap: 12 },
  ];

  let y = 800;
  const commands = lines.map((line) => {
    const cmd = `BT /F1 ${line.size} Tf 48 ${y} Td (${escapePdf(line.text)}) Tj ET`;
    y -= line.gap;
    return cmd;
  }).join('\n');

  const stream = `0.06 0.12 0.24 RG 48 808 500 1.2 re S\n${commands}`;
  const objects = [
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj',
    '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj',
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj',
    `4 0 obj << /Length ${stream.length} >> stream\n${stream}\nendstream endobj`,
    '5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
  ];
  let offset = 9;
  const xref = ['0000000000 65535 f '];
  const body = objects.map((object) => {
    const line = `${object}\n`;
    xref.push(`${String(offset).padStart(10, '0')} 00000 n `);
    offset += line.length;
    return line;
  }).join('');
  const pdf = `%PDF-1.4\n${body}xref\n0 6\n${xref.join('\n')}\ntrailer << /Size 6 /Root 1 0 R >>\nstartxref\n${offset}\n%%EOF`;
  return new Blob([pdf], { type: 'application/pdf' });
}

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
  return [
    `${invoice.company.name} Invoice ${invoice.invoiceNumber}`,
    `Order ${invoice.orderId}`,
    `Bill to: ${invoice.billTo.name}`,
    `Total: Rs. ${invoice.total.toFixed(2)}`,
    `Payment: ${invoice.payment.method} (${invoice.payment.status})`,
  ].join('\n');
}

export function invoiceFromRecord(record, order) {
  if (order) {
    return buildInvoice({
      ...order,
      amount: record.amount ?? order.amount,
      payment: record.paymentMethod || order.payment,
      paymentStatus: record.paymentStatus || order.paymentStatus,
      date: record.invoiceDate || order.date,
      dueDate: record.dueDate,
      discount: record.discount,
      invoiceStatus: record.status,
    }, {
      invoiceNumber: record.invoiceNumber,
      status: record.status,
      dueDate: record.dueDate,
      discount: record.discount,
    });
  }
  const amount = Number(record.amount || 0);
  const tax = Number(record.tax || 0);
  const discount = Number(record.discount || 0);
  const total = Number(record.total || amount + tax - discount);
  return {
    company,
    invoiceNumber: record.invoiceNumber || record.id,
    invoiceDate: record.invoiceDate,
    dueDate: record.dueDate || record.invoiceDate,
    orderId: record.orderId || '—',
    billTo: {
      name: record.customer || record.vendor || '—',
      phone: record.phone || '',
      email: record.email || '',
      address: record.notes || '',
    },
    delivery: {
      pickup: '',
      pickupAddress: '',
      destination: '',
      destinationAddress: '',
      date: record.invoiceDate || record.purchaseDate,
      rider: '',
      vehicle: record.item || '',
      vehicleNumber: '',
    },
    package: {
      type: record.item || record.itemType || 'Service',
      weight: '—',
      quantity: record.quantity || 1,
      description: record.notes || 'IDHAR UDHAR invoice',
    },
    payment: {
      method: record.paymentMethod || 'UPI',
      status: record.paymentStatus || 'Paid',
    },
    status: record.status || 'Issued',
    discount,
    lines: [
      { label: 'Subtotal', amount, quantity: record.quantity || 1 },
      { label: 'Tax', amount: tax, quantity: 1 },
      ...(discount ? [{ label: 'Discount', amount: -discount, quantity: 1 }] : []),
    ],
    deliveryCharge: amount,
    packaging: 0,
    taxRate: amount ? Math.round((tax / amount) * 100) : 0,
    tax,
    taxable: amount,
    total,
  };
}

export function purchaseInvoiceMarkup(record) {
  return `<div class="sheet">
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
  const { company } = invoice;
  const rows = invoice.lines.map((line) => `<tr><td>${line.label}</td><td style="text-align:right">Rs. ${line.amount.toFixed(2)}</td></tr>`).join('');
  return `<div class="sheet">
    <h1 style="margin:0">${company.name}</h1>
    <p>${company.tagline}<br/>${company.address}<br/>${company.phone} · ${company.email}<br/>GSTIN ${company.gstin}</p>
    <h2>Tax Invoice ${invoice.invoiceNumber}</h2>
    <p>Invoice Date: ${invoice.invoiceDate} · Order: ${invoice.orderId}</p>
    <p><strong>Bill To</strong><br/>${invoice.billTo.name}<br/>${invoice.billTo.phone}<br/>${invoice.billTo.email}<br/>${invoice.billTo.address}</p>
    <p><strong>Delivery</strong><br/>Pickup: ${invoice.delivery.pickupAddress}<br/>Destination: ${invoice.delivery.destinationAddress}<br/>Rider: ${invoice.delivery.rider || 'Unassigned'} · ${invoice.delivery.vehicle} ${invoice.delivery.vehicleNumber}</p>
    <p><strong>Package</strong><br/>${invoice.package.type} · Qty ${invoice.package.quantity} · ${invoice.package.weight}<br/>${invoice.package.description}</p>
    <table style="width:100%;border-collapse:collapse" border="1" cellpadding="8">${rows}<tr><td><strong>Total</strong></td><td style="text-align:right"><strong>Rs. ${invoice.total.toFixed(2)}</strong></td></tr></table>
    <p>Payment: ${invoice.payment.method} (${invoice.payment.status})</p>
    <footer style="margin-top:28px;padding-top:12px;border-top:1px solid #d7e4f5;font-size:12px;color:#64748B">
      <strong>${company.legalName || 'SwiftSend Innovation Private Limited'}</strong><br/>
      GSTIN ${company.gstin} · CIN ${company.cin} · PAN ${company.pan}<br/>
      This is a computer-generated invoice for IDHAR UDHAR logistics.
    </footer>
  </div>`;
}
