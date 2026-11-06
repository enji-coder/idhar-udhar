export const DEMO_BILLING_NOTICE =
  'Demo billing record. Not an official IDHAR UDHAR trip invoice.';

export const DEMO_PURCHASE_NOTICE =
  'Demo purchase record. Not an official IDHAR UDHAR customer trip invoice.';

export function isOfficialTripInvoice(invoice) {
  return invoice?.stored === true && invoice?.demo !== true;
}

/** Local admin sample row. Amounts are copied, not recalculated into a trip invoice. */
export function demoBillingRecord(record = {}) {
  return {
    demo: true,
    stored: false,
    officialTripInvoice: false,
    invoiceNumber: record.invoiceNumber || record.id || '',
    customer: record.customer || '',
    orderId: record.orderId || '',
    amount: record.amount ?? null,
    total: record.total ?? null,
    paymentStatus: record.paymentStatus || '',
    status: record.status || '',
    invoiceDate: record.invoiceDate || '',
    notes: record.notes || '',
  };
}

export function demoBillingText(record = {}) {
  const demo = record.demo ? record : demoBillingRecord(record);
  return [
    'DEMO BILLING RECORD',
    DEMO_BILLING_NOTICE,
    `Invoice number: ${demo.invoiceNumber || 'Unavailable'}`,
    `Customer: ${demo.customer || 'Unavailable'}`,
    `Order reference: ${demo.orderId || 'Unavailable'}`,
    `Amount: ${demo.amount ?? 'Unavailable'}`,
    `Total: ${demo.total ?? 'Unavailable'}`,
    `Payment status: ${demo.paymentStatus || 'Unavailable'}`,
  ].join('\n');
}

export function purchaseDemoText(record = {}) {
  return [
    'DEMO PURCHASE RECORD',
    DEMO_PURCHASE_NOTICE,
    `Invoice number: ${record.invoiceNumber || 'Unavailable'}`,
    `Vendor: ${record.vendor || 'Unavailable'}`,
    `Item: ${record.item || 'Unavailable'}`,
    `Total: ${record.total ?? 'Unavailable'}`,
  ].join('\n');
}
