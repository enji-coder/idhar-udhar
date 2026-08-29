let lastError = null;
let loading = true;
const listeners = new Set();

function emit() {
  const snapshot = { error: lastError, loading };
  listeners.forEach((listener) => listener(snapshot));
}

export function getDirectoryError() {
  return lastError;
}

export function isDirectoryLoading() {
  return loading;
}

export function subscribeDirectory(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function setDirectoryError(error) {
  lastError = error || null;
  emit();
}

export function setDirectoryLoading(next) {
  loading = Boolean(next);
  emit();
}
