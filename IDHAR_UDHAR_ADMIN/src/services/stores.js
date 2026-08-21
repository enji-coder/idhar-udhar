import {
  coupons,
  promotions,
  orders,
  riders,
  customers,
  tickets,
  transactions,
  payouts,
} from '../data/mockData';
import { vehicles } from '../data/vehicles';
import { zones } from '../data/zones';
import { invoices, purchaseInvoices } from '../data/invoices';
import { walletTransactions } from '../data/wallet';
import { announcements } from '../data/announcements';
import { notificationCampaigns } from '../data/notifications';
import { createEntityStore } from './entityStore';
import { adminUserStore } from './adminUsers';
import { auditStore } from './auditService';

export const couponStore = createEntityStore('coupons', coupons);
export const promotionStore = createEntityStore('promotions', promotions);
export const orderStore = createEntityStore('orders_v3', orders);
export const riderStore = createEntityStore('riders_v3', riders);
export const customerStore = createEntityStore(
  'customers_v2',
  customers.map((item) => ({ account: 'Active', ...item })),
);
export const ticketStore = createEntityStore(
  'tickets',
  tickets.map((item) => ({ assignee: 'Unassigned', replies: [], ...item })),
);
export const paymentStore = createEntityStore('payments', transactions);
export const vehicleStore = createEntityStore('vehicles_v1', vehicles);
export const zoneStore = createEntityStore('zones_v1', zones);
export const invoiceStore = createEntityStore('invoices_v1', invoices);
export const purchaseInvoiceStore = createEntityStore('purchase_invoices_v1', purchaseInvoices);
export const walletStore = createEntityStore('wallet_v2', walletTransactions);
export const announcementStore = createEntityStore('announcements_v1', announcements);
export const campaignStore = createEntityStore('campaigns_v1', notificationCampaigns);
export const payoutStore = createEntityStore(
  'payouts_v2',
  payouts.map((row) => ({
    ...row,
    status: row.status === 'Processing' ? 'Approved' : row.status,
    period: row.date,
  })),
);
export { adminUserStore, auditStore };
