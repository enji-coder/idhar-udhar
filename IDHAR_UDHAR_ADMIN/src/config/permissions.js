export const MODULES = [
  { key: 'dashboard', label: 'Dashboard', paths: ['/dashboard'] },
  { key: 'orders', label: 'Orders', paths: ['/orders', '/live', '/tracking'] },
  { key: 'customers', label: 'Customers', paths: ['/customers'] },
  { key: 'riders', label: 'Riders', paths: ['/riders', '/verification'] },
  { key: 'vehicles', label: 'Vehicles', paths: ['/vehicles', '/vehicle-categories'] },
  { key: 'deliveries', label: 'Deliveries', paths: ['/live', '/tracking'] },
  { key: 'payments', label: 'Payments', paths: ['/payments'] },
  { key: 'revenue', label: 'Revenue', paths: ['/reports'] },
  { key: 'finance', label: 'Finance', paths: ['/payments', '/wallet', '/invoices', '/purchase-invoices', '/earnings', '/payouts'] },
  { key: 'invoices', label: 'Invoices', paths: ['/invoices', '/purchase-invoices'] },
  { key: 'reports', label: 'Reports', paths: ['/reports'] },
  { key: 'masterReport', label: 'Master Report', paths: ['/reports'] },
  { key: 'settings', label: 'Settings', paths: ['/settings'] },
];

export const MODULE_KEYS = MODULES.map((item) => item.key);

export const FINANCE_PATHS = ['/payments', '/wallet', '/invoices', '/purchase-invoices', '/earnings', '/payouts'];

export const ROLES = {
  SUPER_ADMIN: 'Super Admin',
  SUB_ADMIN: 'Sub Admin',
  OPERATIONS: 'Operations',
  FINANCE: 'Finance',
  SUPPORT: 'Support',
  MANAGER: 'Manager',
};

const ALL = Object.values(ROLES);

const pathRoles = {
  '/': ALL,
  '/dashboard': ALL,
  '/live': [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/orders': [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.MANAGER, ROLES.SUPPORT, ROLES.SUB_ADMIN],
  '/tracking': [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/riders': [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/customers': [ROLES.SUPER_ADMIN, ROLES.SUPPORT, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/verification': [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.SUB_ADMIN],
  '/payments': [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/earnings': [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.SUB_ADMIN],
  '/payouts': [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.SUB_ADMIN],
  '/coupons': [ROLES.SUPER_ADMIN, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/promotions': [ROLES.SUPER_ADMIN, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/notifications': ALL,
  '/support': [ROLES.SUPER_ADMIN, ROLES.SUPPORT, ROLES.SUB_ADMIN],
  '/reports': [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/settings': [ROLES.SUPER_ADMIN],
  '/profile': ALL,
  '/vehicles': [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/vehicle-categories': [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/wallet': [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/zones': [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/invoices': [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.MANAGER, ROLES.SUPPORT, ROLES.SUB_ADMIN],
  '/purchase-invoices': [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.MANAGER, ROLES.SUB_ADMIN],
  '/announcements': [ROLES.SUPER_ADMIN, ROLES.MANAGER, ROLES.OPERATIONS, ROLES.SUB_ADMIN],
};

const actions = {
  orders: {
    view: ALL,
    track: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.MANAGER, ROLES.SUPPORT, ROLES.SUB_ADMIN],
    edit: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.SUB_ADMIN],
    assign: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.SUB_ADMIN],
    cancel: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.SUB_ADMIN],
    refund: [ROLES.SUPER_ADMIN, ROLES.FINANCE],
    invoice: [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.SUPPORT, ROLES.MANAGER, ROLES.SUB_ADMIN],
  },
  riders: {
    view: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.MANAGER, ROLES.SUB_ADMIN],
    edit: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS, ROLES.SUB_ADMIN],
    approve: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS],
    reject: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS],
    suspend: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS],
    activate: [ROLES.SUPER_ADMIN, ROLES.OPERATIONS],
  },
  customers: {
    view: [ROLES.SUPER_ADMIN, ROLES.SUPPORT, ROLES.MANAGER, ROLES.SUB_ADMIN],
    edit: [ROLES.SUPER_ADMIN, ROLES.SUPPORT, ROLES.SUB_ADMIN],
    activate: [ROLES.SUPER_ADMIN, ROLES.SUPPORT],
    deactivate: [ROLES.SUPER_ADMIN, ROLES.SUPPORT],
  },
  coupons: {
    view: [ROLES.SUPER_ADMIN, ROLES.MANAGER, ROLES.SUB_ADMIN],
    create: [ROLES.SUPER_ADMIN, ROLES.MANAGER],
    edit: [ROLES.SUPER_ADMIN, ROLES.MANAGER],
    delete: [ROLES.SUPER_ADMIN],
    activate: [ROLES.SUPER_ADMIN, ROLES.MANAGER],
  },
  promotions: {
    view: [ROLES.SUPER_ADMIN, ROLES.MANAGER, ROLES.SUB_ADMIN],
    create: [ROLES.SUPER_ADMIN, ROLES.MANAGER],
    edit: [ROLES.SUPER_ADMIN, ROLES.MANAGER],
    delete: [ROLES.SUPER_ADMIN],
    activate: [ROLES.SUPER_ADMIN, ROLES.MANAGER],
  },
  payments: {
    view: [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.MANAGER, ROLES.SUB_ADMIN],
    export: [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.MANAGER, ROLES.SUB_ADMIN],
    refund: [ROLES.SUPER_ADMIN, ROLES.FINANCE],
  },
  support: {
    view: [ROLES.SUPER_ADMIN, ROLES.SUPPORT, ROLES.SUB_ADMIN],
    assign: [ROLES.SUPER_ADMIN, ROLES.SUPPORT],
    reply: [ROLES.SUPER_ADMIN, ROLES.SUPPORT, ROLES.SUB_ADMIN],
    resolve: [ROLES.SUPER_ADMIN, ROLES.SUPPORT],
  },
  reports: {
    view: [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.MANAGER, ROLES.SUB_ADMIN],
    export: [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.MANAGER, ROLES.SUB_ADMIN],
  },
  payouts: {
    view: [ROLES.SUPER_ADMIN, ROLES.FINANCE, ROLES.SUB_ADMIN],
    approve: [ROLES.SUPER_ADMIN, ROLES.FINANCE],
    reject: [ROLES.SUPER_ADMIN, ROLES.FINANCE],
  },
};

function asUser(userOrRole) {
  if (!userOrRole) return null;
  if (typeof userOrRole === 'string') return { role: userOrRole };
  return userOrRole;
}

function isFinancePath(pathname) {
  return FINANCE_PATHS.some((path) => pathname === path || pathname.startsWith(`${path}/`));
}

function moduleAllowsPath(modules = [], pathname) {
  return MODULES.some((item) => modules.includes(item.key) && item.paths.some((path) => pathname === path || pathname.startsWith(`${path}/`)));
}

export function can(userOrRole, module, action) {
  const user = asUser(userOrRole);
  const role = user?.role;
  if (!role) return false;
  if (role === ROLES.SUPER_ADMIN) return true;
  if (role === ROLES.SUB_ADMIN) {
    if (module === 'payouts' && (action === 'approve' || action === 'reject')) {
      return Boolean(user.payoutApprove) && user.financeAccess !== false && (user.modules || []).includes('finance');
    }
    if (module === 'payments' && action === 'refund') return false;
    if (module === 'settings') return false;
    const mapped = {
      orders: 'orders',
      riders: 'riders',
      customers: 'customers',
      payments: 'payments',
      reports: 'reports',
      payouts: 'finance',
      coupons: 'dashboard',
      promotions: 'dashboard',
      support: 'dashboard',
    };
    return (user.modules || []).includes(mapped[module] || module);
  }
  return Boolean(actions[module]?.[action]?.includes(role));
}

export function canAccessPath(userOrRole, pathname) {
  const user = asUser(userOrRole);
  const role = user?.role;
  if (!role) return false;
  if (role === ROLES.SUPER_ADMIN) return true;
  if (pathname === '/profile' || pathname === '/notifications') return user.status !== 'Inactive';
  if (user.status === 'Inactive') return false;
  if (isFinancePath(pathname) && user.financeAccess === false) return false;
  if (role === ROLES.SUB_ADMIN) {
    if (pathname === '/settings') return false;
    return moduleAllowsPath(user.modules || [], pathname) && !(isFinancePath(pathname) && user.financeAccess === false);
  }
  const match = Object.keys(pathRoles)
    .sort((a, b) => b.length - a.length)
    .find((path) => pathname === path || (path !== '/' && pathname.startsWith(`${path}/`)));
  return (pathRoles[match || '/'] || ALL).includes(role);
}

export function filterNav(sections, userOrRole) {
  return sections
    .map((section) => ({
      ...section,
      items: section.items.filter((item) => canAccessPath(userOrRole, item.path)),
    }))
    .filter((section) => {
      if (section.title === 'Finance' && asUser(userOrRole)?.financeAccess === false) return false;
      return section.items.length > 0;
    });
}

export function defaultModulesForRole(role) {
  if (role === ROLES.SUPER_ADMIN) return [...MODULE_KEYS];
  if (role === ROLES.FINANCE) return ['dashboard', 'payments', 'revenue', 'finance', 'invoices', 'reports'];
  if (role === ROLES.OPERATIONS) return ['dashboard', 'orders', 'riders', 'vehicles', 'deliveries', 'customers'];
  if (role === ROLES.SUPPORT) return ['dashboard', 'orders', 'customers'];
  if (role === ROLES.MANAGER) return MODULE_KEYS.filter((key) => key !== 'settings' && key !== 'finance');
  return ['dashboard', 'orders', 'customers', 'riders'];
}
