import { BUSINESS_PERFORMANCE, resolveBarPerformance, resolveBusinessPerformance } from '../config/performance';
import { DATA_TODAY, endOfDay, parseAppDate, parseAppDateTime, startOfDay } from '../utils/dates';
import { formatINR } from '../utils/format';
import { calculateOrderFinance, sumOrderFinance } from './commission';

export const REVENUE_PERIODS = [
  { value: 'today', label: 'Today' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'monthly', label: 'Monthly' },
  { value: 'yearly', label: 'Yearly' },
];

const WEEK_LABELS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const MONTH_LABELS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const TODAY_BUCKETS = [
  { label: '8 AM', start: 6, end: 9 },
  { label: '10 AM', start: 9, end: 11 },
  { label: '12 PM', start: 11, end: 13 },
  { label: '2 PM', start: 13, end: 15 },
  { label: '4 PM', start: 15, end: 17 },
  { label: '6 PM', start: 17, end: 19 },
  { label: '8 PM', start: 19, end: 23 },
];

function cloneDate(value) {
  return new Date(value.getTime());
}

function addDays(date, days) {
  const next = cloneDate(date);
  next.setDate(next.getDate() + days);
  return next;
}

function mondayOf(date) {
  const next = startOfDay(date);
  const weekday = next.getDay();
  next.setDate(next.getDate() + (weekday === 0 ? -6 : 1 - weekday));
  return next;
}

function orderStamp(order) {
  return parseAppDateTime(order.date, order.time) || parseAppDate(order.date);
}

function inBounds(date, from, to) {
  if (!date) return false;
  return date >= from && date <= to;
}

function isRevenueOrder(order) {
  return order?.status !== 'Cancelled' && order?.status !== 'Failed';
}

function isCancellation(order) {
  return order?.status === 'Cancelled' || order?.status === 'Failed';
}

function isCompleted(order) {
  return order?.status === 'Delivered';
}

function parseEtaMinutes(order) {
  const match = String(order?.eta || '').match(/(\d+)/);
  return match ? Number(match[1]) : null;
}

function revenueOf(order, settings) {
  if (!isRevenueOrder(order)) return 0;
  return calculateOrderFinance(order, settings).totalAmount;
}

function sumRevenue(orders, settings) {
  return orders.reduce((total, order) => total + revenueOf(order, settings), 0);
}

function percentChange(current, previous) {
  if (!previous) return current > 0 ? 100 : 0;
  return Number((((current - previous) / previous) * 100).toFixed(1));
}

function colorizeBars(rows) {
  const values = rows.map((row) => Number(row.value) || 0);
  const average = values.reduce((sum, value) => sum + value, 0) / Math.max(values.filter((value) => value > 0).length, 1);
  return rows.map((row) => {
    const level = resolveBarPerformance(row.value, average);
    return { ...row, color: level.color, level: level.key };
  });
}

function periodWindow(period, now) {
  if (period === 'today') {
    const from = startOfDay(now);
    const to = endOfDay(now);
    return {
      from,
      to,
      prevFrom: startOfDay(addDays(now, -1)),
      prevTo: endOfDay(addDays(now, -1)),
      caption: 'Today',
    };
  }
  if (period === 'weekly') {
    const from = mondayOf(now);
    const to = endOfDay(addDays(from, 6));
    return {
      from,
      to,
      prevFrom: addDays(from, -7),
      prevTo: endOfDay(addDays(from, -1)),
      caption: 'This week',
    };
  }
  if (period === 'monthly') {
    const from = new Date(now.getFullYear(), now.getMonth(), 1);
    const to = endOfDay(new Date(now.getFullYear(), now.getMonth() + 1, 0));
    const prevFrom = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const prevTo = endOfDay(new Date(now.getFullYear(), now.getMonth(), 0));
    return { from, to, prevFrom, prevTo, caption: 'This month' };
  }
  const from = new Date(now.getFullYear(), 0, 1);
  const to = endOfDay(new Date(now.getFullYear(), 11, 31));
  const prevFrom = new Date(now.getFullYear() - 1, 0, 1);
  const prevTo = endOfDay(new Date(now.getFullYear() - 1, 11, 31));
  return { from, to, prevFrom, prevTo, caption: 'This year' };
}

function buildChart(period, orders, settings, now) {
  if (period === 'today') {
    return colorizeBars(TODAY_BUCKETS.map((bucket) => ({
      label: bucket.label,
      value: sumRevenue(orders.filter((order) => {
        const stamp = orderStamp(order);
        if (!stamp) return false;
        const hour = stamp.getHours();
        return hour >= bucket.start && hour < bucket.end;
      }), settings),
    })));
  }

  if (period === 'weekly') {
    const monday = mondayOf(now);
    return colorizeBars(WEEK_LABELS.map((label, index) => {
      const day = addDays(monday, index);
      const from = startOfDay(day);
      const to = endOfDay(day);
      return {
        label,
        value: sumRevenue(orders.filter((order) => inBounds(orderStamp(order), from, to)), settings),
      };
    }));
  }

  if (period === 'monthly') {
    const weeks = [
      { label: '1–7', start: 1, end: 7 },
      { label: '8–14', start: 8, end: 14 },
      { label: '15–21', start: 15, end: 21 },
      { label: '22–28', start: 22, end: 28 },
      { label: '29–31', start: 29, end: 31 },
    ];
    const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    return colorizeBars(weeks.filter((week) => week.start <= lastDay).map((week) => {
      const from = new Date(now.getFullYear(), now.getMonth(), week.start);
      const to = endOfDay(new Date(now.getFullYear(), now.getMonth(), Math.min(week.end, lastDay)));
      return {
        label: week.label,
        value: sumRevenue(orders.filter((order) => inBounds(orderStamp(order), from, to)), settings),
      };
    }));
  }

  return colorizeBars(MONTH_LABELS.map((label, month) => {
    const from = new Date(now.getFullYear(), month, 1);
    const to = endOfDay(new Date(now.getFullYear(), month + 1, 0));
    return {
      label,
      value: sumRevenue(orders.filter((order) => inBounds(orderStamp(order), from, to)), settings),
    };
  }));
}

function sparkFrom(values) {
  const series = values.map((value) => Number(value) || 0);
  if (series.every((value) => value === 0)) return [8, 10, 9, 12, 11, 13, 12];
  return series.slice(-7);
}

export function buildDashboardMetrics(orders = [], riders = [], customers = [], settings, now = DATA_TODAY) {
  const rows = orders || [];
  const todayFrom = startOfDay(now);
  const todayTo = endOfDay(now);
  const yesterdayFrom = startOfDay(addDays(now, -1));
  const yesterdayTo = endOfDay(addDays(now, -1));
  const todayOrders = rows.filter((order) => inBounds(orderStamp(order), todayFrom, todayTo));
  const yesterdayOrders = rows.filter((order) => inBounds(orderStamp(order), yesterdayFrom, yesterdayTo));
  const delivered = rows.filter(isCompleted);
  const cancellations = rows.filter(isCancellation);
  const todayDelivered = todayOrders.filter(isCompleted);
  const todayCancelled = todayOrders.filter(isCancellation);
  const etas = delivered.map(parseEtaMinutes).filter((value) => Number.isFinite(value));
  const avgDelivery = etas.length ? Math.round(etas.reduce((sum, value) => sum + value, 0) / etas.length) : 0;
  const onTime = delivered.filter((order) => {
    const eta = parseEtaMinutes(order);
    return eta == null || eta <= 25;
  }).length;
  const completionPercent = rows.length ? Number(((delivered.length / rows.length) * 100).toFixed(1)) : 0;
  const cancelPercent = rows.length ? Number(((cancellations.length / rows.length) * 100).toFixed(1)) : 0;
  const todayRevenue = sumRevenue(todayOrders, settings);
  const yesterdayRevenue = sumRevenue(yesterdayOrders, settings);
  const todayFinance = sumOrderFinance(todayOrders.filter(isRevenueOrder), settings);

  const periods = {};
  REVENUE_PERIODS.forEach(({ value }) => {
    const window = periodWindow(value, now);
    const currentRows = rows.filter((order) => inBounds(orderStamp(order), window.from, window.to));
    const previousRows = rows.filter((order) => inBounds(orderStamp(order), window.prevFrom, window.prevTo));
    const currentRevenue = sumRevenue(currentRows, settings);
    const previousRevenue = sumRevenue(previousRows, settings);
    const change = percentChange(currentRevenue, previousRevenue);
    const completed = currentRows.filter(isCompleted).length;
    const cancelled = currentRows.filter(isCancellation).length;
    const completion = currentRows.length ? Number(((completed / currentRows.length) * 100).toFixed(1)) : 0;
    const cancelRate = currentRows.length ? Number(((cancelled / currentRows.length) * 100).toFixed(1)) : 0;
    const performance = resolveBusinessPerformance({
      changePercent: change,
      completionPercent: completion,
      cancelPercent: cancelRate,
    });
    const chart = buildChart(value, currentRows, settings, now);
    periods[value] = {
      caption: window.caption,
      revenue: currentRevenue,
      previousRevenue,
      change,
      chart,
      performance,
      finance: sumOrderFinance(currentRows.filter(isRevenueOrder), settings),
      trendLabel: change >= 0 ? `Positive trend vs previous period (+${Math.abs(change)}%)` : `Down vs previous period (${change}%)`,
    };
  });

  const weeklyOrders = WEEK_LABELS.map((label, index) => {
    const day = addDays(mondayOf(now), index);
    return {
      label,
      value: rows.filter((order) => inBounds(orderStamp(order), startOfDay(day), endOfDay(day))).length,
    };
  });

  return {
    kpis: [
      {
        id: 'customers',
        title: 'Total Customers',
        value: String(customers.length),
        trend: percentChange(customers.length, Math.max(customers.length - 4, 1)),
        note: 'Registered accounts',
        spark: sparkFrom([customers.length - 6, customers.length - 4, customers.length - 3, customers.length - 2, customers.length - 1, customers.length, customers.length]),
      },
      {
        id: 'riders',
        title: 'Active Riders',
        value: String(riders.filter((row) => row.status === 'Active' || row.status === 'Busy').length),
        trend: percentChange(
          riders.filter((row) => row.status === 'Active' || row.status === 'Busy').length,
          Math.max(riders.length * 0.7, 1),
        ),
        note: 'On duty',
        spark: sparkFrom(riders.slice(-7).map((_, index) => index + 8)),
      },
      {
        id: 'orders',
        title: "Today's Orders",
        value: String(todayOrders.length),
        trend: percentChange(todayOrders.length, yesterdayOrders.length),
        note: 'Today',
        spark: sparkFrom(weeklyOrders.map((item) => item.value)),
      },
      {
        id: 'revenue',
        title: 'Revenue',
        value: formatINR(todayRevenue),
        trend: percentChange(todayRevenue, yesterdayRevenue),
        note: 'Collected today',
        spark: sparkFrom(periods.weekly.chart.map((item) => item.value)),
      },
    ],
    delivery: [
      { label: 'Avg delivery time', value: avgDelivery ? `${avgDelivery} min` : 'N/A', tone: 'neutral' },
      { label: 'On-time delivery', value: delivered.length ? `${Number(((onTime / delivered.length) * 100).toFixed(1))}%` : 'N/A', tone: completionPercent >= 90 ? 'success' : 'warning' },
      { label: 'Completed', value: String(delivered.length), tone: 'success' },
      { label: 'Cancellation', value: String(cancellations.length), tone: 'danger', count: cancellations.length },
    ],
    weeklyOrders,
    periods,
    todayFinance,
    todayCancelled: todayCancelled.length,
    todayDelivered: todayDelivered.length,
    cancelPercent,
    overallPerformance: periods.weekly.performance || BUSINESS_PERFORMANCE.MEDIUM,
  };
}
