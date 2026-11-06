import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';

export function inrText(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return 'Unavailable';
  const text = Math.abs(amount).toLocaleString('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return amount < 0 ? `-INR ${text}` : `INR ${text}`;
}

export function whenText(value) {
  if (!value) return 'Unavailable';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export function storedInvoiceFigures(body) {
  const discount = Number(body.discount || 0);
  const additional = Number(body.additional_charges || 0);
  const figures = [{ label: 'Trip Fare', amount: body.trip_fare }];
  if (discount !== 0) figures.push({ label: 'Discount', amount: body.discount });
  if (additional !== 0) figures.push({ label: 'Additional charges', amount: body.additional_charges });
  figures.push(
    { label: 'Subtotal', amount: body.subtotal },
    { label: 'Rounding', amount: body.rounding },
    { label: 'Net payable', amount: body.net_payable },
  );
  return figures;
}

export function invoiceFromStored(body) {
  return {
    stored: true,
    invoiceNumber: body.invoice_number || '',
    crn: body.crn || '',
    invoiceDate: body.issued_at || null,
    tripAt: body.trip_completed_at || null,
    status: body.status || '',
    pickup: body.pickup || {},
    drop: body.drop || {},
    vehicle: body.vehicle || {},
    lines: storedInvoiceFigures(body),
    detailLines: Array.isArray(body.lines) ? body.lines : [],
    payment: body.payment || {},
    total: body.net_payable,
    logoSrc: '/assets/logo/idhar-udhar-logo.png',
  };
}

export function storedInvoiceText(invoice) {
  const payment = invoice.payment || {};
  return [
    `IDHAR UDHAR invoice ${invoice.invoiceNumber}`,
    `CRN ${invoice.crn || 'Unavailable'}`,
    `Invoice date ${whenText(invoice.invoiceDate)}`,
    `Trip completed ${whenText(invoice.tripAt)}`,
    `Pickup ${invoice.pickup?.address || 'Unavailable'}`,
    `Drop ${invoice.drop?.address || 'Unavailable'}`,
    `Vehicle ${invoice.vehicle?.category || 'Unavailable'} ${invoice.vehicle?.registration || ''}`.trim(),
    ...invoice.lines.map((line) => `${line.label} ${inrText(line.amount)}`),
    `Payment ${payment.status || 'Unavailable'}`,
    `Customer paid ${inrText(payment.customer_paid)}`,
    `Receiver paid ${inrText(payment.receiver_paid)}`,
  ].join('\n');
}

function shownAmount(line) {
  const amount = Number(line.amount);
  if (line.label === 'Discount' && amount > 0) return -amount;
  return line.amount;
}

/**
 * A4 customer invoice. The PNG bytes are the original logo file, embedded
 * as an image XObject. Text is not captured from the page.
 */
export async function buildStoredInvoicePdf(invoice, pngBytes) {
  const doc = await PDFDocument.create();
  const page = doc.addPage([595.28, 841.89]);
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const logo = await doc.embedPng(pngBytes);
  const logoHeight = 52;
  const logoWidth = (logo.width / logo.height) * logoHeight;
  let y = 780;
  page.drawImage(logo, { x: 48, y: y - logoHeight, width: logoWidth, height: logoHeight });
  y -= logoHeight + 18;
  const ink = rgb(0.09, 0.16, 0.29);
  const muted = rgb(0.32, 0.39, 0.48);

  const write = (text, options = {}) => {
    const size = options.size ?? 11;
    const face = options.bold ? bold : font;
    page.drawText(String(text ?? ''), {
      x: options.x ?? 48,
      y,
      size,
      font: face,
      color: options.color ?? ink,
    });
    y -= options.gap ?? size + 6;
  };

  write('IDHAR UDHAR', { size: 18, bold: true, gap: 22 });
  write(`Invoice ${invoice.invoiceNumber}`, { size: 13, bold: true });
  write(`CRN ${invoice.crn || 'Unavailable'}`, { color: muted });
  write(`Invoice date ${whenText(invoice.invoiceDate)}`, { color: muted });
  write(`Trip completed ${whenText(invoice.tripAt)}`, { color: muted, gap: 18 });
  write('Pickup', { bold: true, gap: 14 });
  write(invoice.pickup?.address || 'Unavailable', { color: muted, gap: 16 });
  write('Drop', { bold: true, gap: 14 });
  write(invoice.drop?.address || 'Unavailable', { color: muted, gap: 16 });
  const vehicle = [invoice.vehicle?.category, invoice.vehicle?.registration].filter(Boolean).join(' · ');
  write('Vehicle', { bold: true, gap: 14 });
  write(vehicle || 'Unavailable', { color: muted, gap: 20 });

  for (const line of invoice.lines || []) {
    const amount = inrText(shownAmount(line));
    const face = line.label === 'Net payable' ? bold : font;
    page.drawText(line.label, { x: 48, y, size: 11, font: face, color: ink });
    const width = face.widthOfTextAtSize(amount, 11);
    page.drawText(amount, { x: 547 - width, y, size: 11, font: face, color: ink });
    y -= 18;
  }

  y -= 8;
  const payment = invoice.payment || {};
  write('Payment', { bold: true, gap: 14 });
  write(`Status ${payment.status || 'Unavailable'}`, { color: muted });
  write(`Customer paid ${inrText(payment.customer_paid)}`, { color: muted });
  write(`Receiver paid ${inrText(payment.receiver_paid)}`, { color: muted });
  const planned = [
    ['Customer cash', payment.customer_planned_cash],
    ['Customer online', payment.customer_planned_online],
    ['Receiver cash', payment.receiver_planned_cash],
    ['Receiver online', payment.receiver_planned_online],
  ];
  for (const [label, amount] of planned) {
    write(`${label} ${amount == null ? 'Unavailable' : inrText(amount)}`, { color: muted });
  }

  return doc.save();
}
