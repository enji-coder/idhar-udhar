export function isEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value || '').trim());
}

export function required(value, message) {
  return String(value || '').trim() ? '' : message;
}

export function nonNegative(value, message) {
  return Number(value) < 0 ? message : '';
}

export function compactErrors(issues) {
  return Object.fromEntries(Object.entries(issues).filter(([, message]) => Boolean(message)));
}

export function isVehicleRc(value) {
  return /^[A-Z]{2}[\s-]?[0-9]{1,2}[\s-]?[A-Z]{1,3}[\s-]?[0-9]{4}$/i.test(String(value || '').trim());
}
