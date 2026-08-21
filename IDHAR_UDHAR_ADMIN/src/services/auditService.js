import { createEntityStore } from './entityStore';

const seed = [
  {
    id: 'AUD-1001',
    timestamp: '14 Aug 2026, 09:12 AM',
    adminId: 'ADM-1001',
    adminName: 'Ananya Sharma',
    role: 'Super Admin',
    action: 'Login',
    module: 'System',
    recordId: '',
    previousValue: '',
    newValue: 'Session started',
  },
];

function makeStore() {
  const store = createEntityStore('audit_v1', seed);
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
