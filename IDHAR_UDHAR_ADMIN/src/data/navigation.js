import {
  LayoutDashboard,
  Radio,
  Package,
  Map,
  Bike,
  Users,
  ShieldCheck,
  CreditCard,
  Wallet,
  Banknote,
  TicketPercent,
  Megaphone,
  Bell,
  Headphones,
  BarChart3,
  Settings,
  Truck,
  Tags,
  MapPinned,
  FileText,
  Receipt,
  UserRound,
} from 'lucide-react';

export const navSections = [
  {
    title: 'Overview',
    items: [{ label: 'Dashboard', path: '/dashboard', icon: LayoutDashboard }],
  },
  {
    title: 'Operations',
    items: [
      { label: 'Live Operations', path: '/live', icon: Radio },
      { label: 'Orders', path: '/orders', icon: Package },
      { label: 'Riders', path: '/riders', icon: Bike },
      { label: 'Customers', path: '/customers', icon: Users },
      { label: 'Vehicles', path: '/vehicles', icon: Truck },
      { label: 'Vehicle Categories', path: '/vehicle-categories', icon: Tags },
      { label: 'Zones', path: '/zones', icon: MapPinned },
      { label: 'Tracking', path: '/tracking', icon: Map },
      { label: 'Verification', path: '/verification', icon: ShieldCheck },
    ],
  },
  {
    title: 'Finance',
    items: [
      { label: 'Payments', path: '/payments', icon: CreditCard },
      { label: 'Wallet', path: '/wallet', icon: Wallet },
      { label: 'Invoices', path: '/invoices', icon: FileText },
      { label: 'Purchase Invoices', path: '/purchase-invoices', icon: Receipt },
      { label: 'Earnings', path: '/earnings', icon: Banknote },
      { label: 'Payouts', path: '/payouts', icon: Banknote },
    ],
  },
  {
    title: 'Management',
    items: [
      { label: 'Reports', path: '/reports', icon: BarChart3 },
      { label: 'Notifications', path: '/notifications', icon: Bell },
      { label: 'Company Announcements', path: '/announcements', icon: Megaphone },
      { label: 'Coupons', path: '/coupons', icon: TicketPercent },
      { label: 'Promotions', path: '/promotions', icon: Megaphone },
      { label: 'Support', path: '/support', icon: Headphones },
    ],
  },
  {
    title: 'System',
    items: [
      { label: 'Settings', path: '/settings', icon: Settings },
      { label: 'Profile', path: '/profile', icon: UserRound },
    ],
  },
];

export const pageMeta = {
  '/': { title: 'Dashboard', subtitle: 'Ahmedabad operations at a glance.', crumbs: ['Dashboard'] },
  '/dashboard': { title: 'Dashboard', subtitle: 'Ahmedabad operations at a glance.', crumbs: ['Dashboard'] },
  '/live': { title: 'Live Operations', subtitle: 'Active deliveries moving now.', crumbs: ['Operations', 'Live Operations'] },
  '/orders': { title: 'Orders', subtitle: 'Search, filter and manage every delivery.', crumbs: ['Operations', 'Orders'] },
  '/tracking': { title: 'Tracking', subtitle: 'Riders, pickups and live routes.', crumbs: ['Operations', 'Tracking'] },
  '/riders': { title: 'Riders', subtitle: 'Fleet, status and performance.', crumbs: ['Operations', 'Riders'] },
  '/customers': { title: 'Customers', subtitle: 'Accounts, history and activity.', crumbs: ['Operations', 'Customers'] },
  '/verification': { title: 'Verification', subtitle: 'Review rider documents and KYC.', crumbs: ['Operations', 'Verification'] },
  '/payments': { title: 'Payments', subtitle: 'Collections, refunds and settlements.', crumbs: ['Finance', 'Payments'] },
  '/earnings': { title: 'Rider Earnings', subtitle: 'Commission, incentives and tips.', crumbs: ['Finance', 'Earnings'] },
  '/payouts': { title: 'Payouts', subtitle: 'Weekly rider settlement batches.', crumbs: ['Finance', 'Payouts'] },
  '/coupons': { title: 'Coupons', subtitle: 'Discount codes and usage limits.', crumbs: ['Growth', 'Coupons'] },
  '/promotions': { title: 'Promotions', subtitle: 'Campaigns and referral offers.', crumbs: ['Growth', 'Promotions'] },
  '/notifications': { title: 'Notifications', subtitle: 'Operational alerts and system messages.', crumbs: ['Communication', 'Notifications'] },
  '/support': { title: 'Support', subtitle: 'Tickets, disputes and complaints.', crumbs: ['Communication', 'Support'] },
  '/reports': { title: 'Reports', subtitle: 'Export operations and finance insights.', crumbs: ['Analytics', 'Reports'] },
  '/settings': { title: 'Settings', subtitle: 'Company, pricing, security and roles.', crumbs: ['System', 'Settings'] },
  '/profile': { title: 'Admin Profile', subtitle: 'Your account and session.', crumbs: ['System', 'Profile'] },
  '/vehicles': { title: 'Vehicles', subtitle: 'Fleet vehicles and assignments.', crumbs: ['Operations', 'Vehicles'] },
  '/vehicle-categories': { title: 'Vehicle Categories', subtitle: 'Manage selectable vehicle types.', crumbs: ['Operations', 'Vehicle Categories'] },
  '/wallet': { title: 'Wallet', subtitle: 'Customer and rider wallet balances.', crumbs: ['Finance', 'Wallet'] },
  '/zones': { title: 'Zones', subtitle: 'Service areas and rider coverage.', crumbs: ['Operations', 'Zones'] },
  '/invoices': { title: 'Invoices', subtitle: 'Customer invoices and billing.', crumbs: ['Finance', 'Invoices'] },
  '/purchase-invoices': { title: 'Purchase Invoices', subtitle: 'Vendor, vehicle and expense invoices.', crumbs: ['Finance', 'Purchase Invoices'] },
  '/announcements': { title: 'Company Announcements', subtitle: 'Internal and customer-facing notices.', crumbs: ['Management', 'Company Announcements'] },
};

export function resolvePageMeta(pathname) {
  if (pageMeta[pathname]) return pageMeta[pathname];
  if (pathname.startsWith('/riders/')) {
    return { title: 'Rider Profile', subtitle: 'Documents, earnings and performance.', crumbs: ['People', 'Riders', 'Profile'] };
  }
  if (pathname.startsWith('/customers/')) {
    return { title: 'Customer Profile', subtitle: 'Orders, addresses and activity.', crumbs: ['People', 'Customers', 'Profile'] };
  }
  return pageMeta['/'];
}

export const commandLinks = navSections.flatMap((section) => section.items);
