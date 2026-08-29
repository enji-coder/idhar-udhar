import { createEntityStore } from './entityStore';

const seed = [];

function makeStore() {
  const store = createEntityStore('audit_v2', seed, { persist: false });
  return {
    ...store,
    remove() {
      return false;
    },
    replace(next) {
      if (!Array.isArray(next)) return;
      store.replace(next);
    },
  };
}

export const auditStore = makeStore();

export function recordAudit({ user, action, module, recordId = '', previousValue = '', newValue = '' }) {
  const now = new Date();
  const timestamp = now.toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
  const id = `AUD-${Date.now()}`;
  auditStore.upsert({
    id,
    timestamp,
    adminId: user?.id || user?.email || 'N/A',
    adminName: user?.name || 'Admin',
    role: user?.role || 'N/A',
    action,
    module,
    recordId: recordId == null ? '' : String(recordId),
    previousValue: previousValue == null ? '' : String(previousValue),
    newValue: newValue == null ? '' : String(newValue),
  });
}
