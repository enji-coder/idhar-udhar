import { allocateGst, parsePercent, sumInr } from './gst-math';

describe('allocateGst', () => {
  it('splits a 100.00 trip fare exactly as the business example does', () => {
    // 85/15 comes from the frozen finance snapshot: rider 85.00, commission 15.00,
    // operational cost 7.50 (50% of commission).
    const result = allocateGst({
      companyCommissionAmount: '15.00',
      operationalCostAmount: '7.50',
      gstRate: '18.00',
      basis: 'EXCLUSIVE',
    });
    expect(result.taxable_company_amount).toBe('15.00');
    expect(result.gst_amount).toBe('2.70');
    expect(result.operational_cost_amount).toBe('7.50');
    expect(result.company_profit_amount).toBe('4.80');
  });

  it('treats the same commission differently under INCLUSIVE basis', () => {
    const result = allocateGst({
      companyCommissionAmount: '15.00',
      operationalCostAmount: '7.50',
      gstRate: '18.00',
      basis: 'INCLUSIVE',
    });
    expect(result.taxable_company_amount).toBe('12.71');
    expect(result.gst_amount).toBe('2.29');
    expect(result.company_profit_amount).toBe('5.21');
  });

  it('keeps the basis-specific split invariant at every commission value', () => {
    const commissions = ['0.01', '15.00', '15.01', '99.99', '1234.56', '7.35'];
    const bases = ['NONE', 'INCLUSIVE', 'EXCLUSIVE'] as const;
    for (const commission of commissions) {
      for (const basis of bases) {
        const result = allocateGst({
          companyCommissionAmount: commission,
          operationalCostAmount: '0.00',
          gstRate: basis === 'NONE' ? '0.00' : '18.00',
          basis,
        });
        if (basis === 'INCLUSIVE') {
          // The commission is gross of GST, so the two parts add back to it.
          expect(sumInr([result.taxable_company_amount, result.gst_amount])).toBe(
            result.company_commission_amount,
          );
        } else {
          // The commission IS the taxable value; GST sits notionally on top.
          expect(result.taxable_company_amount).toBe(
            result.company_commission_amount,
          );
        }
        // Profit reconciles against the commission under every basis.
        expect(
          sumInr([
            result.company_profit_amount,
            result.gst_amount,
            result.operational_cost_amount,
          ]),
        ).toBe(result.company_commission_amount);
      }
    }
  });

  it('applies no GST under NONE basis', () => {
    const result = allocateGst({
      companyCommissionAmount: '15.00',
      operationalCostAmount: '7.50',
      gstRate: '0.00',
      basis: 'NONE',
    });
    expect(result.gst_amount).toBe('0.00');
    expect(result.taxable_company_amount).toBe('15.00');
    expect(result.company_profit_amount).toBe('7.50');
  });

  it('rejects a non-zero rate on NONE basis instead of silently ignoring it', () => {
    expect(() =>
      allocateGst({
        companyCommissionAmount: '15.00',
        operationalCostAmount: '7.50',
        gstRate: '18.00',
        basis: 'NONE',
      }),
    ).toThrow(/NONE basis requires a 0 GST rate/);
  });

  it('rounds half away from zero, matching PostgreSQL ROUND', () => {
    // 0.15 * 18% = 0.027 -> 0.03
    expect(
      allocateGst({
        companyCommissionAmount: '0.15',
        operationalCostAmount: '0.00',
        gstRate: '18.00',
        basis: 'EXCLUSIVE',
      }).gst_amount,
    ).toBe('0.03');
    // 0.05 * 18% = 0.009 -> 0.01
    expect(
      allocateGst({
        companyCommissionAmount: '0.05',
        operationalCostAmount: '0.00',
        gstRate: '18.00',
        basis: 'EXCLUSIVE',
      }).gst_amount,
    ).toBe('0.01');
  });

  it('reports a negative profit rather than clamping it', () => {
    const result = allocateGst({
      companyCommissionAmount: '15.00',
      operationalCostAmount: '7.50',
      gstRate: '80.00',
      basis: 'EXCLUSIVE',
    });
    expect(result.gst_amount).toBe('12.00');
    expect(result.company_profit_amount).toBe('-4.50');
  });

  it('never lets GST touch the rider share, because the rider share is not an input', () => {
    const low = allocateGst({
      companyCommissionAmount: '15.00',
      operationalCostAmount: '7.50',
      gstRate: '5.00',
      basis: 'EXCLUSIVE',
    });
    const high = allocateGst({
      companyCommissionAmount: '15.00',
      operationalCostAmount: '7.50',
      gstRate: '28.00',
      basis: 'EXCLUSIVE',
    });
    expect(low.company_commission_amount).toBe('15.00');
    expect(high.company_commission_amount).toBe('15.00');
    expect(low.operational_cost_amount).toBe('7.50');
    expect(high.operational_cost_amount).toBe('7.50');
  });

  it('keeps profit consistent with commission minus gst minus operations', () => {
    const result = allocateGst({
      companyCommissionAmount: '187.43',
      operationalCostAmount: '93.72',
      gstRate: '18.00',
      basis: 'EXCLUSIVE',
    });
    expect(
      sumInr([
        result.company_profit_amount,
        result.gst_amount,
        result.operational_cost_amount,
      ]),
    ).toBe(result.company_commission_amount);
  });
});

describe('parsePercent', () => {
  it('normalises to two decimals', () => {
    expect(parsePercent('18')).toBe('18.00');
    expect(parsePercent('18.5')).toBe('18.50');
    expect(parsePercent('0')).toBe('0.00');
  });

  it('rejects values above 100 and malformed text', () => {
    expect(() => parsePercent('101')).toThrow(/out of range/);
    expect(() => parsePercent('18.005')).toThrow(/Invalid percent/);
    expect(() => parsePercent('-5')).toThrow(/Invalid percent/);
  });
});

describe('sumInr', () => {
  it('adds 2-decimal INR text without floating point drift', () => {
    expect(sumInr(['0.10', '0.20'])).toBe('0.30');
    expect(sumInr(['2.70', '2.70', '2.70'])).toBe('8.10');
    expect(sumInr([])).toBe('0.00');
  });
});
