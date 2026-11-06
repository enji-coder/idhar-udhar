import { buildStoredInvoicePdf } from '../../services/storedInvoicePdf';

export async function downloadInvoicePdf(invoice) {
  if (!invoice || invoice.blocked) return;
  if (!invoice.stored) {
    throw new Error('Only a stored trip invoice can be downloaded.');
  }
  const response = await fetch(invoice.logoSrc || '/assets/logo/idhar-udhar-logo.png');
  if (!response.ok) {
    throw new Error('The company logo could not be loaded.');
  }
  const png = new Uint8Array(await response.arrayBuffer());
  const bytes = await buildStoredInvoicePdf(invoice, png);
  const blob = new Blob([bytes], { type: 'application/pdf' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${invoice.invoiceNumber || 'invoice'}.pdf`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}
