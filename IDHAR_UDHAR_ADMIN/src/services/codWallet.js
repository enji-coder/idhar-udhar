import { round2 } from './fareEngine.js';

export const COD_SUSPEND_THRESHOLD = 100;

export function applyCodEarning({ availableWallet = 0, codDue = 0, grossEarning = 0 } = {}) {
  const gross = round2(Math.max(0, Number(grossEarning) || 0));
  const due = round2(Math.max(0, Number(codDue) || 0));
  const wallet = round2(Math.max(0, Number(availableWallet) || 0));
  const settled = round2(Math.min(gross, due));
  return {
    grossEarning: gross,
    settledAgainstCod: settled,
    availableCredit: round2(gross - settled),
    availableWallet: round2(wallet + (gross - settled)),
    codDue: round2(due - settled),
  };
}

export function isCodSuspended(codDue) {
  return round2(codDue) >= COD_SUSPEND_THRESHOLD;
}
