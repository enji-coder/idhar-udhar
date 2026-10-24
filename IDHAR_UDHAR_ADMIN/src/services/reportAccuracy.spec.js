import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { isRecognizedDelivery, recognizedTripFare } from './commission.js';
import { reportCrn, reportInvoiceNumber, reportTransactionId } from './reportIdentifiers.js';
import { inDateRange, rangeForPreset } from '../utils/dates.js';
import { spreadsheetText } from '../utils/format.js';

describe('report accuracy', () => {
  it('excludes cancelled orders from recognized trip-fare revenue', () => {
    assert.equal(recognizedTripFare({ status: 'Cancelled', tripFare: 250, financeSnapshot: { totalAmount: 250 } }), 0);
    assert.equal(isRecognizedDelivery({ status: 'Delivered' }), true);
    assert.equal(recognizedTripFare({
      status: 'Delivered',
      source: 'api',
      tripFare: 250,
      financeSnapshot: { totalAmount: 200 },
    }), 200);
  });

  it('keeps the immutable CRN and does not invent an invoice or transaction id', () => {
    assert.equal(reportCrn({ crn: 'IU-CRN-AMD-0000000001' }), 'IU-CRN-AMD-0000000001');
    assert.equal(reportCrn({ crn: '123' }), 'N/A');
    assert.equal(reportCrn({ id: 'IU-AMD-0000000001' }), 'N/A');
    assert.equal(reportInvoiceNumber(null), 'N/A');
    assert.equal(reportInvoiceNumber({ invoiceNumber: 'INV-1' }), 'INV-1');
    assert.equal(reportTransactionId(null), 'N/A');
    assert.equal(reportTransactionId({ id: 'pay-1' }), 'pay-1');
  });

  it('includes the last local calendar day of a range', () => {
    assert.equal(inDateRange('24 Oct 2026', '2026-10-24', '2026-10-24'), true);
    assert.equal(inDateRange('25 Oct 2026', '2026-10-01', '2026-10-24'), false);
    const range = rangeForPreset('custom', '2026', 'October', '2026-10-01', '2026-10-24');
    assert.equal(range.from, '2026-10-01');
    assert.equal(range.to, '2026-10-24');
  });

  it('neutralises spreadsheet formulas', () => {
    assert.equal(spreadsheetText('=CMD()'), "'=CMD()");
    assert.equal(spreadsheetText('+1'), "'+1");
    assert.equal(spreadsheetText('IU-CRN-AMD-0000000001'), 'IU-CRN-AMD-0000000001');
  });
});
