export const PAYMENT_SETTINGS_KEY = 'iu_admin_settings';

export const PAYMENT_DEFAULTS = {
  riderSharePercent: 85,
  companyCommissionPercent: 15,
  operationalCostPercent: 50,
};

export const COMMISSION_DEFAULTS = {
  riderRate: PAYMENT_DEFAULTS.riderSharePercent / 100,
  opexRate: (PAYMENT_DEFAULTS.companyCommissionPercent / 100) * (PAYMENT_DEFAULTS.operationalCostPercent / 100),
};

const listeners = new Set();

export function round2(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return 0;
  return Math.round((amount + Number.EPSILON) * 100) / 100;
}

function clampPercent(value, fallback) {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return fallback;
  return round2(Math.min(100, Math.max(0, amount)));
}

export function normalizePaymentSettings(raw = {}) {
  const riderSharePercent = clampPercent(raw.riderSharePercent, PAYMENT_DEFAULTS.riderSharePercent);
  let companyCommissionPercent = clampPercent(raw.companyCommissionPercent, PAYMENT_DEFAULTS.companyCommissionPercent);
  if (round2(riderSharePercent + companyCommissionPercent) !== 100) {
    companyCommissionPercent = round2(100 - riderSharePercent);
  }
  const operationalCostPercent = clampPercent(raw.operationalCostPercent, PAYMENT_DEFAULTS.operationalCostPercent);
  return {
    riderSharePercent,
    companyCommissionPercent,
    operationalCostPercent,
  };
}

export function getPaymentSettings() {
  try {
    const stored = JSON.parse(localStorage.getItem(PAYMENT_SETTINGS_KEY) || '{}');
    return ratesFromSettings(stored);
  } catch {
    return { ...PAYMENT_DEFAULTS };
  }
}

export function subscribePaymentSettings(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function notifyPaymentSettings() {
  listeners.forEach((listener) => listener());
}

export function ratesFromSettings(settings = PAYMENT_DEFAULTS) {
  if (settings?.riderSharePercent != null) return normalizePaymentSettings(settings);
  if (settings?.riderRate != null) {
    const riderSharePercent = round2(Number(settings.riderRate) * 100);
    const companyCommissionPercent = round2(100 - riderSharePercent);
    const opexOfTotal = Number(settings.opexRate);
    const operationalCostPercent = companyCommissionPercent > 0 && Number.isFinite(opexOfTotal)
      ? clampPercent((opexOfTotal / (companyCommissionPercent / 100)) * 100, PAYMENT_DEFAULTS.operationalCostPercent)
      : PAYMENT_DEFAULTS.operationalCostPercent;
    return normalizePaymentSettings({ riderSharePercent, companyCommissionPercent, operationalCostPercent });
  }
  return { ...PAYMENT_DEFAULTS };
}

export function calculateDistribution(totalAmount, settings = getPaymentSettings()) {
  const config = ratesFromSettings(settings);
  const total = round2(totalAmount);
  const riderAmount = round2(total * (config.riderSharePercent / 100));
  const companyCommission = round2(total - riderAmount);
  const operationalCost = round2(companyCommission * (config.operationalCostPercent / 100));
  const actualProfit = round2(companyCommission - operationalCost);
  return {
    totalAmount: total,
    riderAmount,
    riderPercentage: config.riderSharePercent,
    companyCommission,
    companyCommissionPercentage: config.companyCommissionPercent,
    operationalCost,
    operationalCostPercentage: config.operationalCostPercent,
    actualProfit,
    actualProfitPercentage: round2(100 - config.operationalCostPercent),
  };
}

export function tripFareOf(order) {
  return round2(order?.tripFare ?? order?.confirmedTripFare ?? order?.amount ?? 0);
}

export function customerPayment(order) {
  return round2(order?.customerPayment ?? order?.netPayable ?? order?.amount ?? 0);
}

function fromSnapshot(snapshot, payment) {
  const total = round2(snapshot.totalAmount ?? payment);
  return {
    totalAmount: total,
    riderAmount: round2(snapshot.riderAmount ?? snapshot.riderCommission ?? snapshot.riderEarning ?? 0),
    riderPercentage: Number(snapshot.riderPercentage ?? snapshot.riderSharePercent ?? 0),
    companyCommission: round2(snapshot.companyCommission ?? 0),
    companyCommissionPercentage: Number(snapshot.companyCommissionPercentage ?? 0),
    operationalCost: round2(snapshot.operationalCost ?? snapshot.operationalExpense ?? 0),
    operationalCostPercentage: Number(snapshot.operationalCostPercentage ?? 0),
    actualProfit: round2(snapshot.actualProfit ?? snapshot.netCompanyEarnings ?? 0),
    actualProfitPercentage: Number(snapshot.actualProfitPercentage ?? 0),
  };
}

function withLegacyAliases(distribution) {
  return {
    ...distribution,
    customerPayment: distribution.totalAmount,
    riderCommission: distribution.riderAmount,
    riderEarning: distribution.riderAmount,
    operationalExpense: distribution.operationalCost,
    netCompanyEarnings: distribution.actualProfit,
  };
}

export function calculateOrderFinance(order, settings = getPaymentSettings()) {
  const payment = customerPayment(order);
  const tripFare = tripFareOf(order);

  if (order?.financeSnapshot) {
    return withLegacyAliases(fromSnapshot(order.financeSnapshot, tripFare || payment));
  }

  if (order?.source === 'api') {
    return withLegacyAliases({
      totalAmount: tripFare || payment,
      riderAmount: 0,
      riderPercentage: 0,
      companyCommission: 0,
      companyCommissionPercentage: 0,
      operationalCost: 0,
      operationalCostPercentage: 0,
      actualProfit: 0,
      actualProfitPercentage: 0,
    });
  }

  const hasStored = order?.riderCommission != null || order?.riderEarning != null;
  const hasCompanyStored = order?.companyCommission != null;
  const hasOpexStored = order?.operationalExpense != null;
  if (hasStored && hasCompanyStored && hasOpexStored) {
    const riderAmount = round2(order.riderCommission ?? order.riderEarning ?? 0);
    const companyCommission = round2(order.companyCommission);
    const operationalCost = round2(order.operationalExpense);
    return withLegacyAliases({
      totalAmount: payment,
      riderAmount,
      riderPercentage: payment ? round2((riderAmount / payment) * 100) : 0,
      companyCommission,
      companyCommissionPercentage: payment ? round2((companyCommission / payment) * 100) : 0,
      operationalCost,
      operationalCostPercentage: companyCommission ? round2((operationalCost / companyCommission) * 100) : 0,
      actualProfit: round2(order.netCompanyEarnings ?? companyCommission - operationalCost),
      actualProfitPercentage: companyCommission ? round2(((order.netCompanyEarnings ?? companyCommission - operationalCost) / companyCommission) * 100) : 0,
    });
  }

  if (order?.status === 'Cancelled') {
    return withLegacyAliases({
      ...calculateDistribution(0, settings),
      totalAmount: payment,
    });
  }

  const distribution = calculateDistribution(tripFare, settings);
  if (!order?.rider || order.rider === 'Unassigned') {
    const companyCommission = payment;
    const operationalCost = round2(companyCommission * (ratesFromSettings(settings).operationalCostPercent / 100));
    return withLegacyAliases({
      totalAmount: payment,
      riderAmount: 0,
      riderPercentage: ratesFromSettings(settings).riderSharePercent,
      companyCommission,
      companyCommissionPercentage: 100,
      operationalCost,
      operationalCostPercentage: ratesFromSettings(settings).operationalCostPercent,
      actualProfit: round2(companyCommission - operationalCost),
      actualProfitPercentage: round2(100 - ratesFromSettings(settings).operationalCostPercent),
    });
  }

  return withLegacyAliases(distribution);
}

export function attachFinanceSnapshot(order, settings = getPaymentSettings()) {
  if (order?.financeSnapshot) {
    return {
      financeSnapshot: order.financeSnapshot,
      riderCommission: order.financeSnapshot.riderAmount,
      riderEarning: order.financeSnapshot.riderAmount,
      companyCommission: order.financeSnapshot.companyCommission,
      operationalExpense: order.financeSnapshot.operationalCost,
      netCompanyEarnings: order.financeSnapshot.actualProfit,
    };
  }
  const tripFare = tripFareOf(order);
  const finance = calculateOrderFinance({
    ...order,
    tripFare,
    financeSnapshot: undefined,
    riderCommission: undefined,
    riderEarning: undefined,
    companyCommission: undefined,
    operationalExpense: undefined,
    netCompanyEarnings: undefined,
  }, settings);
  return {
    tripFare,
    financeSnapshot: { ...finance, frozenAt: new Date().toISOString() },
    riderCommission: finance.riderAmount,
    riderEarning: finance.riderAmount,
    companyCommission: finance.companyCommission,
    operationalExpense: finance.operationalCost,
    netCompanyEarnings: finance.actualProfit,
  };
}

export function sumOrderFinance(orders, settings = getPaymentSettings()) {
  const config = ratesFromSettings(settings);
  const totals = {
    totalAmount: 0,
    riderAmount: 0,
    riderPercentage: config.riderSharePercent,
    companyCommission: 0,
    companyCommissionPercentage: config.companyCommissionPercent,
    operationalCost: 0,
    operationalCostPercentage: config.operationalCostPercent,
    actualProfit: 0,
    actualProfitPercentage: round2(100 - config.operationalCostPercent),
  };
  (orders || []).forEach((order) => {
    const finance = calculateOrderFinance(order, config);
    totals.totalAmount = round2(totals.totalAmount + finance.totalAmount);
    totals.riderAmount = round2(totals.riderAmount + finance.riderAmount);
    totals.companyCommission = round2(totals.companyCommission + finance.companyCommission);
    totals.operationalCost = round2(totals.operationalCost + finance.operationalCost);
    totals.actualProfit = round2(totals.actualProfit + finance.actualProfit);
  });
  return withLegacyAliases(totals);
}

export function riderCommissionFor(order, rates = getPaymentSettings()) {
  return calculateOrderFinance(order, rates).riderAmount;
}

export function operationalExpenseFor(order, rates = getPaymentSettings()) {
  return calculateOrderFinance(order, rates).operationalCost;
}

export function companyCommissionFor(customerPay, riderCommission) {
  return round2(Math.max(0, round2(customerPay) - round2(riderCommission)));
}

export function netCompanyEarningsFor(companyCommission, operationalExpense) {
  return round2(round2(companyCommission) - round2(operationalExpense));
}
