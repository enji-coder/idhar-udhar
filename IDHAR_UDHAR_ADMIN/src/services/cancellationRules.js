import { round2 } from './fareEngine.js';

export const CANCELLATION_KEY = 'iu_admin_cancellation_v1';

export const CANCELLATION_STAGES = [
  { id: 'beforeAccept', label: 'Before rider accepts' },
  { id: 'afterAccept', label: 'After rider accepts' },
  { id: 'afterArrivePickup', label: 'After rider reaches pickup' },
  { id: 'afterPickup', label: 'After pickup / parcel collected' },
  { id: 'inTransit', label: 'During delivery / in transit' },
];

function defaultRule(enabled) {
  return {
    enabled: Boolean(enabled),
    fee: 0,
    riderSharePercent: 0,
    companySharePercent: 100,
  };
}

export function defaultCancellationConfig() {
  const later = defaultRule(false);
  const early = defaultRule(true);
  return {
    versionId: 'cancel_v1',
    customer: {
      beforeAccept: { ...early },
      afterAccept: { ...early },
      afterArrivePickup: { ...later },
      afterPickup: { ...later },
      inTransit: { ...later },
    },
    rider: {
      beforeAccept: { ...later },
      afterAccept: { ...later },
      afterArrivePickup: { ...later },
      afterPickup: { ...later },
      inTransit: { ...later },
    },
  };
}

export function normalizeRule(raw = {}) {
  const riderSharePercent = round2(Math.min(100, Math.max(0, Number(raw.riderSharePercent) || 0)));
  const companySharePercent = round2(Math.min(100, Math.max(0, Number(raw.companySharePercent) || 0)));
  return {
    enabled: Boolean(raw.enabled),
    fee: round2(Math.max(0, Number(raw.fee) || 0)),
    riderSharePercent,
    companySharePercent,
  };
}

export function ruleSharesValid(rule) {
  return round2((rule?.riderSharePercent || 0) + (rule?.companySharePercent || 0)) === 100;
}

export function validateCancellationConfig(config) {
  const issues = [];
  ['customer', 'rider'].forEach((actor) => {
    CANCELLATION_STAGES.forEach((stage) => {
      const rule = config?.[actor]?.[stage.id];
      if (!ruleSharesValid(rule)) {
        issues.push(`${actor} · ${stage.label}: Rider % + Company % must equal 100.`);
      }
    });
  });
  return issues;
}

export function loadCancellationConfig() {
  try {
    const stored = JSON.parse(localStorage.getItem(CANCELLATION_KEY) || 'null');
    if (!stored) return defaultCancellationConfig();
    const base = defaultCancellationConfig();
    ['customer', 'rider'].forEach((actor) => {
      CANCELLATION_STAGES.forEach((stage) => {
        base[actor][stage.id] = normalizeRule(stored[actor]?.[stage.id] || base[actor][stage.id]);
      });
    });
    return base;
  } catch {
    return defaultCancellationConfig();
  }
}

export function saveCancellationConfig(config) {
  const issues = validateCancellationConfig(config);
  if (issues.length) return { ok: false, issues };
  localStorage.setItem(CANCELLATION_KEY, JSON.stringify(config));
  return { ok: true, issues: [] };
}

export function quoteCancellation(config, actor, stageId) {
  const rule = normalizeRule(config?.[actor]?.[stageId] || defaultRule(false));
  if (!rule.enabled) {
    return { allowed: false, fee: 0, riderAmount: 0, companyAmount: 0, message: 'Cancellation not available at this stage' };
  }
  const riderAmount = round2(rule.fee * (rule.riderSharePercent / 100));
  return {
    allowed: true,
    fee: rule.fee,
    riderSharePercent: rule.riderSharePercent,
    companySharePercent: rule.companySharePercent,
    riderAmount,
    companyAmount: round2(rule.fee - riderAmount),
    message: rule.fee === 0 ? 'Cancellation Fee: ₹0' : `Cancellation Fee: ₹${rule.fee}`,
  };
}
