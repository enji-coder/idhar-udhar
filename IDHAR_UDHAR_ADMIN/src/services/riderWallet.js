import { calculateOrderFinance } from './commission';
import { applyCodEarning, isCodSuspended } from './codWallet';
import { PAYOUT_STATUSES } from '../config/status';
import { sortByDateTime } from '../utils/dates';

export function buildRiderWallets({ riders = [], orders = [], payouts = [] }) {
  return riders.map((rider) => {
    const related = orders.filter((order) => order.riderId === rider.id || order.rider === rider.name);
    const delivered = related.filter((order) => order.status === 'Delivered');
    let availableWallet = 0;
    let codDue = 0;
    delivered.forEach((order) => {
      const finance = calculateOrderFinance(order);
      const cash = String(order.payment || '').toLowerCase() === 'cash';
      if (cash) {
        codDue = roundDue(codDue + finance.companyCommission);
      } else {
        const settled = applyCodEarning({
          availableWallet,
          codDue,
          grossEarning: finance.riderAmount,
        });
        availableWallet = settled.availableWallet;
        codDue = settled.codDue;
      }
    });
    const riderPayouts = payouts.filter((row) => row.riderId === rider.id || row.rider === rider.name);
    const paidAmount = riderPayouts.filter((row) => row.status === 'Paid').reduce((sum, row) => sum + Number(row.amount || 0), 0);
    const latest = riderPayouts[0];
    const pendingPayout = Math.max(0, Number((availableWallet - paidAmount).toFixed(2)));
    let payoutStatus = latest?.status || 'Pending';
    if (!PAYOUT_STATUSES.includes(payoutStatus)) payoutStatus = payoutStatus === 'Processing' ? 'Approved' : 'Pending';
    if (pendingPayout <= 0 && paidAmount > 0) payoutStatus = 'Paid';
    return {
      id: rider.id,
      rider: rider.name,
      riderId: rider.id,
      cashInHand: 0,
      availableWallet,
      codDue,
      suspended: isCodSuspended(codDue),
      onlinePayoutBalance: availableWallet,
      totalEarnings: availableWallet,
      paidAmount,
      pendingPayout,
      payoutStatus,
    };
  });
}

function roundDue(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}

export function buildRiderTransactions({ rider, orders = [], wallet = [], payouts = [] }) {
  if (!rider) return [];
  const rows = [];

  wallet
    .filter((item) => item.user === rider.name && item.userType === 'Rider')
    .forEach((item) => {
      rows.push({
        id: item.id,
        date: item.date,
        time: item.time || '10:00 AM',
        type: item.type,
        amount: item.amount,
        status: item.status,
        method: item.method || 'Wallet',
        reference: item.description,
      });
    });

  payouts
    .filter((item) => item.riderId === rider.id || item.rider === rider.name)
    .forEach((item) => {
      rows.push({
        id: item.id,
        date: item.date,
        time: item.time || '10:00 AM',
        type: 'Payout',
        amount: item.amount,
        status: item.status,
        method: item.method || 'UPI',
        reference: item.period || 'Weekly settlement',
      });
    });

  orders
    .filter((order) => (order.riderId === rider.id || order.rider === rider.name) && order.status === 'Delivered')
    .forEach((order) => {
      const finance = calculateOrderFinance(order);
      rows.push({
        id: `TXN-${String(order.id || '').replace('IU-AMD-', '')}`,
        date: order.date,
        time: order.time || order.deliveredAt,
        type: 'Delivery Earning',
        amount: finance.riderEarning,
        status: order.paymentStatus === 'Paid' ? 'Success' : order.paymentStatus || 'Pending',
        method: order.payment,
        reference: order.id,
      });
    });

  return sortByDateTime(rows);
}
