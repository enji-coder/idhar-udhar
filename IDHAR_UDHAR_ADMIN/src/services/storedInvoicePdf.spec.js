import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { inflateSync } from 'node:zlib';
import { PDFDocument } from 'pdf-lib';
import { invoiceFromStored, storedInvoiceText, buildStoredInvoicePdf } from './storedInvoicePdf.js';

const stored = {
  invoice_number: 'INV-IU-AMD-0000000001',
  crn: 'IU-CRN-AMD-0000000001',
  status: 'ISSUED',
  issued_at: '2026-08-14T10:15:00.000Z',
  trip_completed_at: '2026-08-14T11:00:00.000Z',
  pickup: { address: 'Pickup lane' },
  drop: { address: 'Drop lane' },
  vehicle: { category: 'Bike', registration: 'GJ01AB1234' },
  lines: [{ sequence: 0, line_type: 'TRIP_FARE', label: 'Trip Fare', amount: '135.00' }],
  trip_fare: '135.00',
  discount: '10.00',
  additional_charges: '5.00',
  subtotal: '130.00',
  rounding: '-0.40',
  net_payable: '129.60',
  payment: {
    status: 'PAID',
    customer_paid: '129.60',
    receiver_paid: '0.00',
    customer_planned_cash: '129.60',
    customer_planned_online: '0.00',
    receiver_planned_cash: null,
    receiver_planned_online: null,
  },
};

function pdfText(bytes) {
  const raw = Buffer.from(bytes);
  const latin = raw.toString('latin1');
  let text = '';
  const marker = /\/Length (\d+)\s*>>\s*stream\r?\n/g;
  let match = marker.exec(latin);
  while (match) {
    const length = Number(match[1]);
    const start = match.index + match[0].length;
    try {
      const decoded = inflateSync(raw.subarray(start, start + length)).toString('latin1');
      if (decoded.includes('Tj')) text += decoded.replace(/<([0-9A-Fa-f]+)>/g, (_, hex) => {
        let out = '';
        for (let index = 0; index < hex.length; index += 2) {
          out += String.fromCharCode(Number.parseInt(hex.slice(index, index + 2), 16));
        }
        return out;
      });
    } catch {
      // Not a Flate stream.
    }
    match = marker.exec(latin);
  }
  return { header: latin.slice(0, latin.indexOf('stream')), text };
}

test('view invoice and pdf use the same stored figures', async () => {
  const view = invoiceFromStored(stored);
  assert.equal(view.stored, true);
  assert.deepEqual(
    view.lines.map((line) => line.label),
    ['Trip Fare', 'Discount', 'Additional charges', 'Subtotal', 'Rounding', 'Net payable'],
  );
  assert.equal(view.total, '129.60');
  assert.equal(view.crn, 'IU-CRN-AMD-0000000001');
  const share = storedInvoiceText(view);
  assert.match(share, /IU-CRN-AMD-0000000001/);
  assert.match(share, /129\.60/);
  assert.doesNotMatch(share, /GSTIN|commission|Rider share|Company share/i);

  const logo = await readFile(new URL('../../public/assets/logo/idhar-udhar-logo.png', import.meta.url));
  assert.equal(logo.subarray(0, 4).toString('hex'), '89504e47');
  const pdf = await buildStoredInvoicePdf(view, logo);
  const loaded = await PDFDocument.load(pdf);
  assert.equal(loaded.getPageCount(), 1);
  const parsed = pdfText(pdf);
  assert.match(parsed.header, /\/Subtype \/Image/);
  assert.match(parsed.header, /\/Width 400/);
  assert.match(parsed.header, /\/Height 406/);
  assert.match(parsed.text, /IU-CRN-AMD-0000000001/);
  assert.match(parsed.text, /129\.60/);
  assert.doesNotMatch(parsed.text, /GSTIN/);
  assert.doesNotMatch(parsed.text, /commission/i);
});
