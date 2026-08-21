import { adminAccounts, toSessionUser } from '../data/adminAccounts';
import { createEntityStore } from './entityStore';
import { MODULE_KEYS, ROLES } from '../config/permissions';

export const adminUserStore = createEntityStore('admin_users_v2', adminAccounts);

export function findAdminByEmail(email) {
  const value = String(email || '').trim().toLowerCase();
  if (!value) return null;
  return adminUserStore.getAll().find((item) => {
    const emails = [item.email, ...(item.aliases || [])].map((value) => String(value || '').toLowerCase());
    return emails.includes(value);
  }) || null;
}

export function authenticateSubAdmin(email, password) {
  const account = findAdminByEmail(email);
  if (!account || account.status === 'Inactive') return null;
  if (account.role === ROLES.SUPER_ADMIN) return null;
  if (!account.password || account.password !== password) return null;
  return toSessionUser(account, email);
}

export function sessionFromEmail(email) {
  const account = findAdminByEmail(email);
  if (account) return toSessionUser(account, email);
  return toSessionUser({
    id: 'ADM-1001',
    name: 'Admin',
    email,
    role: ROLES.SUPER_ADMIN,
    status: 'Active',
    financeAccess: true,
    payoutApprove: true,
    modules: [...MODULE_KEYS],
    initials: 'AD',
    city: 'Ahmedabad',
  }, email);
}
