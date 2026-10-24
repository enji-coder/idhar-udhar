const CRN_PATTERN = /^IU-CRN-[A-Z]{2,5}-[0-9]{10}$/;

export function reportCrn(order) {
  const crn = String(order?.crn || '').trim();
  return CRN_PATTERN.test(crn) ? crn : 'N/A';
}

export function reportInvoiceNumber(invoice) {
  const number = String(invoice?.invoiceNumber || '').trim();
  return number || 'N/A';
}

export function reportTransactionId(payment) {
  const id = String(payment?.id || '').trim();
  return id || 'N/A';
}
