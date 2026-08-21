const listeners = new Set();

let snapshot = {
  phase: 'live',
  updatedAt: Date.now(),
};

export function publishDashboardLive(partial) {
  snapshot = { ...snapshot, ...partial };
  listeners.forEach((listener) => listener(snapshot));
}

export function subscribeDashboardLive(listener) {
  listeners.add(listener);
  listener(snapshot);
  return () => listeners.delete(listener);
}
