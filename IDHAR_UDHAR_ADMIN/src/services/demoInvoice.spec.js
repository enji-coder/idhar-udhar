import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { invoiceFromStored } from './storedInvoicePdf.js';
import {
  DEMO_BILLING_NOTICE,
  DEMO_PURCHASE_NOTICE,
  demoBillingRecord,
  demoBillingText,
  isOfficialTripInvoice,
  purchaseDemoText,
} from './demoInvoice.js';

const stored = {
  invoice_number: 'INV-1',
  crn: 'IU-CRN-1',
  trip_fare: '100.00',
  discount: '0.00',
  additional_charges: '0.00',
  subtotal: '100.00',
  rounding: '0.00',
  net_payable: '100.00',
  lines: [],
  payment: { status: 'PAID' },
};

const dummy = {
  invoiceNumber: 'INV-AMD-10421',
  orderId: 'IU-AMD-10421',
  customer: 'Rahul Mehta',
  amount: 249,
  tax: 12.45,
  total: 261.45,
  paymentStatus: 'Paid',
};

test('demo billing records are not official trip invoices', () => {
  const demo = demoBillingRecord(dummy);
  assert.equal(demo.stored, false);
  assert.equal(demo.officialTripInvoice, false);
  assert.equal(isOfficialTripInvoice(demo), false);
  const text = demoBillingText(demo);
  assert.match(text, new RegExp(DEMO_BILLING_NOTICE));
  assert.doesNotMatch(text, /GSTIN|CIN|PAN|Packaging|TAX INVOICE|commission/i);
  assert.equal(isOfficialTripInvoice(invoiceFromStored(stored)), true);
});

test('demo purchase text is not an official customer trip invoice', () => {
  const text = purchaseDemoText({ invoiceNumber: 'PINV-1001', vendor: 'Vendor', item: 'Bike', total: 10 });
  assert.match(text, new RegExp(DEMO_PURCHASE_NOTICE));
  assert.doesNotMatch(text, /GSTIN|TAX INVOICE|Packaging|commission/i);
});

test('Orders uses the stored invoice API and demo pages do not call buildInvoice', async () => {
  const orders = await readFile(new URL('../pages/Orders.jsx', import.meta.url), 'utf8');
  const invoices = await readFile(new URL('../pages/Invoices.jsx', import.meta.url), 'utf8');
  const purchase = await readFile(new URL('../pages/PurchaseInvoices.jsx', import.meta.url), 'utf8');
  const service = await readFile(new URL('./invoiceService.js', import.meta.url), 'utf8');
  const download = await readFile(new URL('../components/orders/downloadInvoicePreview.jsx', import.meta.url), 'utf8');
  const preview = await readFile(new URL('../components/orders/InvoicePreview.jsx', import.meta.url), 'utf8');

  assert.match(orders, /fetchAdminInvoice/);
  assert.match(orders, /invoiceFromStored/);
  assert.doesNotMatch(orders, /buildInvoice/);

  assert.doesNotMatch(invoices, /buildInvoice/);
  assert.doesNotMatch(invoices, /downloadInvoicePdf/);
  assert.match(invoices, /demoBillingText/);

  assert.match(purchase, /DEMO_PURCHASE_NOTICE/);
  assert.doesNotMatch(purchase, /TAX INVOICE|GSTIN/);

  const fromRecord = service.slice(
    service.indexOf('export function invoiceFromRecord'),
    service.indexOf('export function purchaseInvoiceMarkup'),
  );
  assert.doesNotMatch(fromRecord, /buildInvoice/);
  const printMarkup = service.slice(
    service.indexOf('export function invoicePrintMarkup'),
    service.indexOf('function storedInvoiceMarkup'),
  );
  assert.doesNotMatch(printMarkup, /GSTIN|CIN|PAN|TAX INVOICE|Packaging/);
  assert.match(download, /Only a stored trip invoice can be downloaded/);
  assert.doesNotMatch(preview, /GSTIN|TAX INVOICE/);
});
