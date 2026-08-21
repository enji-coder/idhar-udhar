import { useMemo, useState } from 'react';
import { Download, Eye, Printer } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import Button from '../components/common/Button';
import Select from '../components/common/Select';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Tabs from '../components/common/Tabs';
import Drawer from '../components/common/Drawer';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import BarChart from '../components/charts/BarChart';
import EmptyState from '../components/common/EmptyState';
import FilterBar from '../components/common/FilterBar';
import { PageSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import {
  auditStore,
  customerStore,
  invoiceStore,
  orderStore,
  paymentStore,
  payoutStore,
  riderStore,
  vehicleStore,
} from '../services/stores';
import { monthlyRevenue, yearlyComparison } from '../data/mockData';
import { formatCompactINR, formatINR, formatINRExact, printReport } from '../utils/format';
import { useAuth } from '../context/AuthContext';
import { filterByDate, joinOrders, searchRows } from '../services/reportJoin';
import { formatAppDate, formatAppTime, parseAppDate, rangeForPreset, sortByDateTime } from '../utils/dates';
import usePaymentSettings from '../hooks/usePaymentSettings';
import { exportCsv, exportXlsx } from '../services/exportEngine';
import { classifyCustomer, categoryLabel, CUSTOMER_CATEGORIES } from '../services/customerClassification';
import { buildDocumentAlerts } from '../services/documentExpiry';
import { enrichRiderProfile, enrichVehicleRecord } from '../services/profileEnrichment';
import { recordAudit } from '../services/auditService';
import { calculateOrderFinance, sumOrderFinance } from '../services/commission';
import {
  DELIVERY_REPORT_STATUSES,
  PAYMENT_MODES,
  displayValue,
} from '../config/status';

const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

const reportTypes = [
  { value: 'orders', label: 'Order Report' },
  { value: 'revenue', label: 'Revenue Report' },
  { value: 'riders', label: 'Rider Performance' },
  { value: 'customers', label: 'Customer Report' },
  { value: 'delivery', label: 'Delivery Performance' },
  { value: 'cancellation', label: 'Cancellation Report' },
  { value: 'vehicles', label: 'Vehicle Report' },
  { value: 'payment', label: 'Payment Report' },
  { value: 'master', label: 'Master Report' },
  { value: 'expiry', label: 'Document Expiry' },
  { value: 'audit', label: 'Admin Audit' },
];

const presets = [
  { value: 'today', label: 'Today' },
  { value: 'yesterday', label: 'Yesterday' },
  { value: 'week', label: 'This Week' },
  { value: 'month', label: 'This Month' },
  { value: 'lastMonth', label: 'Last Month' },
  { value: '3m', label: 'Last 3 Months' },
  { value: '6m', label: 'Last 6 Months' },
  { value: 'year', label: 'This Year' },
  { value: 'lastYear', label: 'Last Year' },
  { value: 'custom', label: 'Custom Range' },
];

function money(row, key) {
  return formatINRExact(row[key] || 0);
}

export default function Reports() {
  const loading = useMockLoader();
  const { can, user } = useAuth();
  const orders = useStore(orderStore);
  const riders = useStore(riderStore);
  const customers = useStore(customerStore);
  const payments = useStore(paymentStore);
  const vehicles = useStore(vehicleStore);
  const invoices = useStore(invoiceStore);
  const payouts = useStore(payoutStore);
  const audits = useStore(auditStore);
  const [type, setType] = useState('revenue');
  const [preset, setPreset] = useState('year');
  const [year, setYear] = useState('2026');
  const [month, setMonth] = useState('August');
  const [from, setFrom] = useState('2026-01-01');
  const [to, setTo] = useState('2026-08-14');
  const [applied, setApplied] = useState({ from: '2026-01-01', to: '2026-08-17' });
  const [view, setView] = useState(null);
  const [chartMode, setChartMode] = useState('monthly');
  const [search, setSearch] = useState('');
  const [revenueTab, setRevenueTab] = useState('status');
  const [paymentMode, setPaymentMode] = useState('All');
  const [customerCategory, setCustomerCategory] = useState('All');
  const [deliveryStatus, setDeliveryStatus] = useState('All');
  const pay = usePaymentSettings();
  const [dailyFrom, setDailyFrom] = useState('2026-08-01');
  const [dailyTo, setDailyTo] = useState('2026-08-17');
  const [dailyApplied, setDailyApplied] = useState(null);

  const range = useMemo(() => {
    if (preset === 'custom') return applied;
    return rangeForPreset(preset, year, month, from, to);
  }, [preset, year, month, from, to, applied]);

  const joined = useMemo(
    () => joinOrders({ orders, riders, customers, payments, vehicles, invoices, payouts }),
    [orders, riders, customers, payments, vehicles, invoices, payouts, pay],
  );

  const dated = useMemo(() => filterByDate(joined, range.from, range.to, 'orderDate'), [joined, range]);

  const chart = useMemo(() => {
    if (chartMode === 'yearly') {
      return Object.entries(monthlyRevenue).map(([label, values]) => ({
        label,
        value: values.reduce((sum, item) => sum + item, 0),
      }));
    }
    const values = monthlyRevenue[year] || monthlyRevenue[2026];
    return months.map((label, index) => ({ label: label.slice(0, 3), value: values[index] || 0 })).filter((item) => item.value > 0 || year !== '2026');
  }, [year, chartMode]);

  const table = useMemo(() => {
    if (type === 'riders') {
      const rows = riders.map((row) => {
        const related = orders.filter((order) => order.riderId === row.id || order.rider === row.name);
        return {
          ...row,
          earnings: related.reduce((sum, order) => sum + calculateOrderFinance(order).riderAmount, 0),
        };
      });
      return {
        columns: [
          { key: 'id', label: 'Rider', sortable: true },
          { key: 'name', label: 'Name', sortable: true },
          { key: 'monthDeliveries', label: 'Deliveries', sortable: true },
          { key: 'onTime', label: 'On-time %', sortable: true },
          { key: 'rating', label: 'Rating', sortable: true },
          { key: 'earnings', label: `Rider Payout — ${pay.riderSharePercent}%`, sortable: true, render: (row) => formatINRExact(row.earnings) },
        ],
        rows,
        searchKeys: ['id', 'name'],
        dateField: null,
      };
    }
    if (type === 'customers') {
      const rows = customers.map((row) => {
        const category = classifyCustomer(row, orders);
        return { ...row, category, categoryLabel: categoryLabel(category) };
      }).filter((row) => customerCategory === 'All' || row.category === customerCategory);
      return {
        columns: [
          { key: 'id', label: 'Customer' },
          { key: 'name', label: 'Name', sortable: true },
          { key: 'phone', label: 'Mobile' },
          { key: 'orders', label: 'Orders', sortable: true },
          { key: 'categoryLabel', label: 'Category', render: (row) => <StatusBadge status={row.category} /> },
          { key: 'spent', label: 'Spent', sortable: true, render: (row) => formatINR(row.spent) },
        ],
        rows,
        searchKeys: ['id', 'name', 'phone', 'categoryLabel'],
        dateField: 'joined',
      };
    }
    if (type === 'vehicles') {
      const rows = vehicles.map((row) => {
        const rider = riders.find((item) => item.id === row.riderId || item.name === row.rider);
        return enrichVehicleRecord(row, rider);
      });
      return {
        columns: [
          { key: 'id', label: 'Vehicle' },
          { key: 'rcNumber', label: 'Vehicle RC Number', sortable: true },
          { key: 'category', label: 'Vehicle Category' },
          { key: 'brand', label: 'Brand / Company' },
          { key: 'model', label: 'Model' },
          { key: 'variant', label: 'Variant', hideBelow: 'lg' },
          { key: 'color', label: 'Color', hideBelow: 'lg' },
          { key: 'twoWheelerType', label: 'Bike/Scooter', render: (row) => row.twoWheelerType || 'N/A', hideBelow: 'lg' },
          { key: 'rider', label: 'Rider', render: (row) => displayValue(row.rider, 'Not Assigned') },
          { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
        ],
        rows,
        searchKeys: ['id', 'rcNumber', 'number', 'brand', 'model', 'rider'],
        dateField: null,
        scroll: true,
      };
    }
    if (type === 'payment') {
      return {
        columns: [
          { key: 'orderId', label: 'Order ID', sortable: true },
          { key: 'transactionId', label: 'Transaction ID' },
          { key: 'invoiceNumber', label: 'Invoice Number' },
          { key: 'customerName', label: 'Customer', sortable: true },
          { key: 'paymentAmount', label: 'Payment Amount', sortable: true, render: (row) => money(row, 'paymentAmount') },
          { key: 'riderCommission', label: `Rider Payout — ${pay.riderSharePercent}%`, render: (row) => money(row, 'riderCommission') },
          { key: 'companyCommission', label: `Company Commission — ${pay.companyCommissionPercent}%`, hideBelow: 'lg', render: (row) => money(row, 'companyCommission') },
          { key: 'operationalExpense', label: `Operational Cost — ${pay.operationalCostPercent}% of Commission`, hideBelow: 'lg', render: (row) => money(row, 'operationalExpense') },
          { key: 'netCompanyEarnings', label: 'Actual Profit', hideBelow: 'lg', render: (row) => money(row, 'netCompanyEarnings') },
          { key: 'paymentMode', label: 'Payment Mode' },
          { key: 'paymentStatus', label: 'Payment Status', render: (row) => <StatusBadge status={row.paymentStatus} /> },
          { key: 'paymentGatewayStatus', label: 'Payment Gateway Status', hideBelow: 'lg' },
          { key: 'cashCollection', label: 'Cash Collection', render: (row) => formatINR(row.cashCollection || 0), hideBelow: 'lg' },
          { key: 'paymentDate', label: 'Payment Date' },
        ],
        rows: dated,
        searchKeys: ['orderId', 'transactionId', 'invoiceNumber', 'customerName', 'paymentMode'],
        dateField: 'paymentDate',
        scroll: true,
      };
    }
    if (type === 'revenue') {
      if (revenueTab === 'mode') {
        const rows = dated.filter((row) => paymentMode === 'All' || row.paymentMode === paymentMode);
        return {
          columns: [
            { key: 'customerName', label: 'Customer', sortable: true },
            { key: 'orderId', label: 'Order ID', sortable: true },
            { key: 'invoiceNumber', label: 'Invoice Number' },
            { key: 'paymentMode', label: 'Payment Mode' },
            { key: 'paymentAmount', label: 'Amount', sortable: true, render: (row) => money(row, 'paymentAmount') },
            { key: 'paymentStatus', label: 'Status', render: (row) => <StatusBadge status={row.paymentStatus} /> },
            { key: 'orderDate', label: 'Order Date' },
          ],
          rows,
          searchKeys: ['customerName', 'orderId', 'invoiceNumber', 'paymentMode'],
          dateField: 'orderDate',
          scroll: true,
        };
      }
      return {
        columns: [
          { key: 'orderId', label: 'Order ID', sortable: true },
          { key: 'invoiceNumber', label: 'Invoice Number' },
          { key: 'customerName', label: 'Customer Name' },
          { key: 'riderName', label: 'Rider Name' },
          { key: 'customerPayment', label: 'Total Ride Amount', sortable: true, render: (row) => money(row, 'customerPayment') },
          { key: 'riderCommission', label: `Rider Payout — ${pay.riderSharePercent}%`, render: (row) => money(row, 'riderCommission') },
          { key: 'companyCommission', label: `Company Commission — ${pay.companyCommissionPercent}%`, render: (row) => money(row, 'companyCommission') },
          { key: 'operationalExpense', label: `Operational Cost — ${pay.operationalCostPercent}% of Commission`, hideBelow: 'lg', render: (row) => money(row, 'operationalExpense') },
          { key: 'netCompanyEarnings', label: 'Actual Profit', render: (row) => money(row, 'netCompanyEarnings') },
          { key: 'paymentMode', label: 'Payment Mode' },
          { key: 'paymentStatus', label: 'Payment Status', render: (row) => <StatusBadge status={row.paymentStatus} /> },
          { key: 'revenueDate', label: 'Order Date' },
        ],
        rows: dated,
        searchKeys: ['orderId', 'invoiceNumber', 'customerName', 'riderName', 'paymentMode'],
        dateField: 'revenueDate',
        scroll: true,
      };
    }
    if (type === 'cancellation') {
      return {
        columns: [
          { key: 'orderId', label: 'Order ID', sortable: true },
          { key: 'customerName', label: 'Customer Name' },
          { key: 'riderName', label: 'Rider Name' },
          { key: 'invoiceNumber', label: 'Invoice Number' },
          { key: 'cancellationDate', label: 'Cancellation Date' },
          { key: 'cancellationTime', label: 'Cancellation Time', hideBelow: 'lg' },
          { key: 'cancellationTimestamp', label: 'Cancellation Timestamp', hideBelow: 'lg' },
          { key: 'cancellationReason', label: 'Cancellation Reason' },
          { key: 'cancelledBy', label: 'Cancelled By', render: (row) => <StatusBadge status={row.cancelledBy} /> },
        ],
        rows: dated.filter((row) => row.orderStatus === 'Cancelled'),
        searchKeys: ['orderId', 'customerName', 'riderName', 'invoiceNumber', 'cancellationReason', 'cancelledBy'],
        dateField: 'cancellationDate',
        scroll: true,
      };
    }
    if (type === 'delivery') {
      const rows = dated.filter((row) => row.orderStatus !== 'Cancelled').filter((row) => deliveryStatus === 'All' || row.deliveryStatus === deliveryStatus);
      return {
        columns: [
          { key: 'orderId', label: 'Order ID', sortable: true },
          { key: 'customerName', label: 'Customer' },
          { key: 'riderName', label: 'Rider' },
          { key: 'pickupLocation', label: 'Pickup' },
          { key: 'dropLocation', label: 'Drop' },
          { key: 'deliveryStatus', label: 'Delivery Status', render: (row) => <StatusBadge status={row.deliveryStatus} /> },
          { key: 'paymentAmount', label: 'Amount', render: (row) => money(row, 'paymentAmount') },
          { key: 'orderDate', label: 'Date' },
        ],
        rows,
        searchKeys: ['orderId', 'customerName', 'riderName', 'deliveryStatus'],
        dateField: 'orderDate',
        scroll: true,
      };
    }
    if (type === 'master') {
      return {
        columns: [
          { key: 'orderId', label: 'Order ID', sortable: true },
          { key: 'customerOnboardingDate', label: 'Customer Onboarding Date', hideBelow: 'lg' },
          { key: 'customerName', label: 'Customer Name' },
          { key: 'customerPhone', label: 'Mobile Number' },
          { key: 'customerEmail', label: 'Email ID', hideBelow: 'lg' },
          { key: 'customerLocation', label: 'Location', hideBelow: 'lg' },
          { key: 'customerPincode', label: 'Location Pincode', hideBelow: 'lg' },
          { key: 'riderOnboardingDate', label: 'Rider Onboarding Date', hideBelow: 'lg' },
          { key: 'riderName', label: 'Rider Name' },
          { key: 'riderPhone', label: 'Rider Contact' },
          { key: 'riderEmail', label: 'Rider Email', hideBelow: 'lg' },
          { key: 'riderAddress', label: 'Rider Address', hideBelow: 'lg' },
          { key: 'riderPincode', label: 'Address Pincode', hideBelow: 'lg' },
          { key: 'riderEmergency', label: 'Emergency Contact', hideBelow: 'lg' },
          { key: 'drivingLicenseNumber', label: 'Driving License Number', hideBelow: 'lg' },
          { key: 'rcNumber', label: 'RC Number' },
          { key: 'aadhaarMasked', label: 'Aadhaar Number' },
          { key: 'panNumber', label: 'PAN Number', hideBelow: 'lg' },
          { key: 'bankAccountNumber', label: 'Bank Account Number', hideBelow: 'lg' },
          { key: 'ifscCode', label: 'IFSC Code', hideBelow: 'lg' },
          { key: 'vehicleCategory', label: 'Vehicle Category' },
          { key: 'orderDate', label: 'Order Date' },
          { key: 'invoiceNumber', label: 'Invoice Number' },
          { key: 'goodsDetails', label: 'Goods Details', hideBelow: 'lg' },
          { key: 'goodsWeight', label: 'Goods Weight', hideBelow: 'lg' },
          { key: 'pickupLocation', label: 'Pickup Location' },
          { key: 'dropLocation', label: 'Drop Location' },
          { key: 'pickupPincode', label: 'Pickup Pincode', hideBelow: 'lg' },
          { key: 'dropPincode', label: 'Drop Pincode', hideBelow: 'lg' },
          { key: 'paymentAmount', label: 'Total Ride Amount', render: (row) => money(row, 'paymentAmount') },
          { key: 'paymentMode', label: 'Payment Mode' },
          { key: 'paymentStatus', label: 'Payment Status', render: (row) => <StatusBadge status={row.paymentStatus} /> },
          { key: 'paymentDate', label: 'Payment Date', hideBelow: 'lg' },
          { key: 'riderEarning', label: `Rider Payout — ${pay.riderSharePercent}%`, render: (row) => money(row, 'riderEarning') },
          { key: 'companyCommission', label: `Company Commission — ${pay.companyCommissionPercent}%`, hideBelow: 'lg', render: (row) => money(row, 'companyCommission') },
          { key: 'operationalExpense', label: `Operational Cost — ${pay.operationalCostPercent}% of Commission`, hideBelow: 'lg', render: (row) => money(row, 'operationalExpense') },
          { key: 'netCompanyEarnings', label: 'Actual Profit', hideBelow: 'lg', render: (row) => money(row, 'netCompanyEarnings') },
          { key: 'customerRatingByRider', label: 'Customer Rating by Rider', hideBelow: 'lg' },
          { key: 'riderRatingByCustomer', label: 'Rider Rating by Customer', hideBelow: 'lg' },
          { key: 'cancellationDate', label: 'Order Cancellation Date', hideBelow: 'lg' },
          { key: 'cancellationReason', label: 'Cancellation Reason', hideBelow: 'lg' },
          { key: 'cancelledBy', label: 'Order Cancelled By', hideBelow: 'lg' },
        ],
        rows: dated,
        searchKeys: ['orderId', 'customerName', 'riderName', 'invoiceNumber', 'rcNumber'],
        dateField: 'orderDate',
        scroll: true,
        exportMask: true,
      };
    }
    if (type === 'expiry') {
      const rows = buildDocumentAlerts({
        riders: riders.map((row) => enrichRiderProfile(row)),
        vehicles: vehicles.map((row) => enrichVehicleRecord(row, riders.find((item) => item.id === row.riderId))),
      });
      return {
        columns: [
          { key: 'document', label: 'Document' },
          { key: 'rider', label: 'Rider' },
          { key: 'vehicle', label: 'Vehicle' },
          { key: 'expiryDate', label: 'Expiry Date', sortable: true },
          { key: 'daysRemaining', label: 'Days Remaining', sortable: true },
          { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
        ],
        rows,
        searchKeys: ['document', 'rider', 'vehicle', 'status'],
        dateField: 'expiryDate',
      };
    }
    if (type === 'audit') {
      return {
        columns: [
          { key: 'timestamp', label: 'Timestamp', sortable: true },
          { key: 'adminId', label: 'Admin ID' },
          { key: 'adminName', label: 'Admin Name' },
          { key: 'role', label: 'Role', render: (row) => <StatusBadge status={row.role} /> },
          { key: 'action', label: 'Action' },
          { key: 'module', label: 'Module' },
          { key: 'recordId', label: 'Record/Order ID', hideBelow: 'lg' },
          { key: 'previousValue', label: 'Previous Value', hideBelow: 'lg' },
          { key: 'newValue', label: 'New Value', hideBelow: 'lg' },
        ],
        rows: audits,
        searchKeys: ['adminName', 'action', 'module', 'recordId', 'adminId'],
        dateField: 'timestamp',
        scroll: true,
      };
    }
    return {
      columns: [
        { key: 'orderId', label: 'Order ID', sortable: true },
        { key: 'orderDate', label: 'Order Date' },
        { key: 'invoiceNumber', label: 'Invoice Number' },
        { key: 'customerName', label: 'Customer Name' },
        { key: 'customerPhone', label: 'Customer Contact Number', hideBelow: 'lg' },
        { key: 'riderName', label: 'Rider Name' },
        { key: 'riderPhone', label: 'Rider Contact Number', hideBelow: 'lg' },
        { key: 'pickupLocation', label: 'Pickup Location' },
        { key: 'dropLocation', label: 'Drop Location' },
        { key: 'orderStatus', label: 'Order Status', render: (row) => <StatusBadge status={row.orderStatus} /> },
        { key: 'paymentAmount', label: 'Total Ride Amount', render: (row) => money(row, 'paymentAmount') },
        { key: 'riderCommission', label: `Rider Payout — ${pay.riderSharePercent}%`, hideBelow: 'lg', render: (row) => money(row, 'riderCommission') },
        { key: 'companyCommission', label: `Company Commission — ${pay.companyCommissionPercent}%`, hideBelow: 'lg', render: (row) => money(row, 'companyCommission') },
        { key: 'operationalExpense', label: `Operational Cost — ${pay.operationalCostPercent}% of Commission`, hideBelow: 'lg', render: (row) => money(row, 'operationalExpense') },
        { key: 'netCompanyEarnings', label: 'Actual Profit', hideBelow: 'lg', render: (row) => money(row, 'netCompanyEarnings') },
        { key: 'paymentMode', label: 'Payment Mode' },
        { key: 'paymentStatus', label: 'Payment Status', render: (row) => <StatusBadge status={row.paymentStatus} /> },
      ],
      rows: dated,
      searchKeys: ['orderId', 'invoiceNumber', 'customerName', 'riderName', 'pickupLocation', 'dropLocation'],
      dateField: 'orderDate',
      scroll: true,
    };
  }, [type, orders, riders, customers, vehicles, dated, revenueTab, paymentMode, customerCategory, deliveryStatus, audits, pay]);

  const visibleRows = useMemo(
    () => searchRows(table.rows, search, table.searchKeys || ['id', 'name']),
    [table, search],
  );

  const dailySource = useMemo(() => {
    if (type !== 'customers') return dated;
    if (dailyApplied?.from && dailyApplied?.to) return filterByDate(joined, dailyApplied.from, dailyApplied.to, 'orderDate');
    return dated;
  }, [type, dated, joined, dailyApplied]);

  const dailyBreakdown = useMemo(() => {
    if (type !== 'customers') return [];
    const groups = {};
    dailySource.forEach((row) => {
      const parsed = parseAppDate(row.orderDate || row.date);
      const key = parsed ? formatAppDate(parsed) : (row.orderDate || 'N/A');
      if (!groups[key]) groups[key] = { date: key, sortDate: parsed?.getTime() || 0, totalOrders: 0, completed: 0, pending: 0, cancelled: 0, totalValue: 0 };
      groups[key].totalOrders += 1;
      groups[key].totalValue += Number(row.paymentAmount || 0);
      if (row.orderStatus === 'Delivered') groups[key].completed += 1;
      else if (row.orderStatus === 'Cancelled') groups[key].cancelled += 1;
      else groups[key].pending += 1;
    });
    return Object.values(groups).sort((a, b) => b.sortDate - a.sortDate);
  }, [type, dailySource]);

  const dailyChart = useMemo(
    () => [...dailyBreakdown].sort((a, b) => a.sortDate - b.sortDate).map((row) => ({ label: String(row.date).replace(/ 2026/, ''), value: row.totalOrders })),
    [dailyBreakdown],
  );

  const viewedCustomerOrders = useMemo(() => {
    if (!view || type !== 'customers') return [];
    return sortByDateTime(orders.filter((order) => order.customerId === view.id || order.customer === view.name));
  }, [view, type, orders]);

  const financeTotals = useMemo(
    () => sumOrderFinance(visibleRows, pay),
    [visibleRows, pay],
  );

  if (loading) return <PageSkeleton />;

  const title = reportTypes.find((item) => item.value === type)?.label;
  const revenueGrowth = (((yearlyComparison.revenue.current - yearlyComparison.revenue.previous) / yearlyComparison.revenue.previous) * 100).toFixed(1);
  const exportCols = table.columns.map((column) => ({ key: column.key, label: column.label }));
  const totals = {
    amount: visibleRows.reduce((sum, row) => sum + Number(row.paymentAmount || row.customerPayment || row.amount || 0), 0),
    count: visibleRows.length,
  };

  function runExport(kind) {
    recordAudit({ user, action: 'Export', module: 'Reports', recordId: type, newValue: `${kind} ${range.from} to ${range.to}` });
    const filename = `${type}-report-${range.from}-to-${range.to}`;
    if (kind === 'csv') exportCsv(filename, visibleRows, exportCols);
    else exportXlsx(filename, visibleRows, exportCols);
  }

  return (
    <PageContainer className="space-y-4">
      <GlassCard className="flex flex-col gap-3 overflow-hidden lg:flex-row lg:flex-wrap lg:items-end">
        <label className="min-w-0 flex-1 text-sm lg:max-w-[220px]">Report<Select className="mt-1 block w-full" value={type} onChange={setType} options={reportTypes} /></label>
        <label className="min-w-0 flex-1 text-sm lg:max-w-[220px]">Period<Select className="mt-1 block w-full" value={preset} onChange={setPreset} options={presets} /></label>
        <label className="min-w-0 flex-1 text-sm lg:max-w-[160px]">Year<Select className="mt-1 block w-full" value={year} onChange={setYear} options={['2024', '2025', '2026']} /></label>
        <label className="min-w-0 flex-1 text-sm lg:max-w-[180px]">Month<Select className="mt-1 block w-full" value={month} onChange={setMonth} options={months} /></label>
        {preset === 'custom' ? (
          <>
            <label className="min-w-0 text-sm">From<input type="date" value={from} onChange={(event) => setFrom(event.target.value)} className="mt-1 block h-11 w-full rounded-2xl border border-line px-3" /></label>
            <label className="min-w-0 text-sm">To<input type="date" value={to} onChange={(event) => setTo(event.target.value)} className="mt-1 block h-11 w-full rounded-2xl border border-line px-3" /></label>
            <Button variant="secondary" onClick={() => setApplied({ from, to })}>Apply Filter</Button>
          </>
        ) : null}
        {can('reports', 'export') ? (
          <div className="flex min-w-0 flex-wrap gap-2">
            <Button variant="export" icon={Download} onClick={() => runExport('xlsx')}>Export XLSX</Button>
            <Button variant="export" icon={Download} onClick={() => runExport('csv')}>Export CSV</Button>
            <Button variant="export" icon={Printer} onClick={() => printReport(`${title} ${year}`, visibleRows, exportCols)}>Export PDF</Button>
            <Button variant="secondary" onClick={() => printReport(`${title} ${year}`, visibleRows, exportCols)}>Print</Button>
          </div>
        ) : null}
      </GlassCard>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <GlassCard><p className="text-sm text-ink-muted">2026 Revenue</p><p className="text-2xl font-bold">{formatCompactINR(yearlyComparison.revenue.current)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">2025 Revenue</p><p className="text-2xl font-bold">{formatCompactINR(yearlyComparison.revenue.previous)}</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">YoY growth</p><p className="text-2xl font-bold text-success">+{revenueGrowth}%</p></GlassCard>
        <GlassCard><p className="text-sm text-ink-muted">Orders YoY</p><p className="text-2xl font-bold">{yearlyComparison.orders.previous.toLocaleString('en-IN')} → {yearlyComparison.orders.current.toLocaleString('en-IN')}</p></GlassCard>
      </div>

      <GlassCard className="overflow-hidden">
        <div className="mb-3 flex min-w-0 flex-wrap items-center justify-between gap-3">
          <h2 className="text-lg font-semibold">{chartMode === 'yearly' ? 'Yearly revenue' : `${year} revenue`}</h2>
          <Tabs tabs={[{ value: 'monthly', label: 'Monthly' }, { value: 'yearly', label: 'Yearly' }]} value={chartMode} onChange={setChartMode} />
        </div>
        <BarChart data={chart} />
      </GlassCard>

      <div className="grid gap-3 md:grid-cols-4">
        {[
          ['Customer growth', `${yearlyComparison.customers.previous} → ${yearlyComparison.customers.current}`],
          ['Rider growth', `${yearlyComparison.riders.previous} → ${yearlyComparison.riders.current}`],
          ['On-time', `${yearlyComparison.onTime.previous}% → ${yearlyComparison.onTime.current}%`],
          ['Selected month', `${month} ${year}`],
        ].map(([label, value]) => (
          <GlassCard key={label}><p className="text-sm text-ink-muted">{label}</p><p className="font-semibold">{value}</p></GlassCard>
        ))}
      </div>

      {type === 'revenue' ? (
        <GlassCard className="flex flex-wrap items-center gap-3">
          <Tabs
            tabs={[{ value: 'status', label: 'Status' }, { value: 'mode', label: 'Payment Mode by Customer' }]}
            value={revenueTab}
            onChange={setRevenueTab}
          />
          {revenueTab === 'mode' ? (
            <Select aria-label="Payment mode" value={paymentMode} onChange={setPaymentMode} options={['All', ...PAYMENT_MODES]} />
          ) : null}
        </GlassCard>
      ) : null}

      {type === 'customers' ? (
        <GlassCard className="flex flex-wrap items-center gap-3">
          <Select aria-label="Category" value={customerCategory} onChange={setCustomerCategory} options={['All', ...CUSTOMER_CATEGORIES]} />
        </GlassCard>
      ) : null}

      {type === 'delivery' ? (
        <GlassCard className="flex flex-wrap items-center gap-3">
          <Select aria-label="Delivery status" value={deliveryStatus} onChange={setDeliveryStatus} options={['All', ...DELIVERY_REPORT_STATUSES]} />
        </GlassCard>
      ) : null}

      {type === 'customers' ? (
        <GlassCard className="overflow-hidden">
          <h2 className="mb-3 text-lg font-semibold">Daily-wise Order Breakdown</h2>
          <div className="mb-4 flex flex-col gap-3 overflow-hidden lg:flex-row lg:flex-wrap lg:items-end">
            <label className="min-w-0 text-sm">From Date<input type="date" value={dailyFrom} onChange={(event) => setDailyFrom(event.target.value)} className="mt-1 block h-11 w-full rounded-2xl border border-line px-3" /></label>
            <label className="min-w-0 text-sm">To Date<input type="date" value={dailyTo} onChange={(event) => setDailyTo(event.target.value)} className="mt-1 block h-11 w-full rounded-2xl border border-line px-3" /></label>
            <Button variant="secondary" onClick={() => setDailyApplied({ from: dailyFrom, to: dailyTo })}>Apply Filter</Button>
            <Button variant="ghost" onClick={() => { setDailyFrom('2026-08-01'); setDailyTo('2026-08-17'); setDailyApplied(null); }}>Reset</Button>
          </div>
          <BarChart data={dailyChart} />
          <div className="mt-4">
            <DataTable
              columns={[
                { key: 'date', label: 'Date', sortable: true },
                { key: 'totalOrders', label: 'Total Orders', sortable: true },
                { key: 'completed', label: 'Completed Orders' },
                { key: 'pending', label: 'Pending Orders' },
                { key: 'cancelled', label: 'Cancelled Orders' },
                { key: 'totalValue', label: 'Total Order Value', render: (row) => formatINR(row.totalValue) },
              ]}
              data={dailyBreakdown}
              rowKey="date"
              pageSize={10}
              compact
              itemLabel="days"
            />
          </div>
        </GlassCard>
      ) : null}

      <GlassCard className="overflow-hidden">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-lg font-semibold">{title}</h2>
          <div className="flex min-w-0 flex-wrap justify-end gap-x-4 gap-y-1 text-sm text-ink-muted">
            <span>{totals.count} transactions</span>
            {['orders', 'revenue', 'payment', 'master', 'delivery'].includes(type) ? (
              <>
                <span>Total Ride Amount {formatINRExact(financeTotals.totalAmount)}</span>
                <span>Rider Payout {formatINRExact(financeTotals.riderAmount)}</span>
                <span>Company Commission {formatINRExact(financeTotals.companyCommission)}</span>
                <span>Operational Cost {formatINRExact(financeTotals.operationalCost)}</span>
                <span>Actual Profit {formatINRExact(financeTotals.actualProfit)}</span>
              </>
            ) : (
              <span>{formatINR(totals.amount)}</span>
            )}
          </div>
        </div>
        <div className="mt-3">
        <FilterBar search={search} onSearch={setSearch} placeholder="Search this report" />
        </div>
        {visibleRows.length === 0 ? (
          <EmptyState title="No rows in this range" description="Adjust the date range, search or filters and try again." />
        ) : (
          <DataTable
            columns={[
              ...table.columns,
              {
                key: 'actions',
                label: 'Actions',
                className: 'overflow-visible',
                render: (row) => (
                  <ActionGroup>
                    <ActionButton icon={Eye} tone="view" onClick={() => setView(row)}>View</ActionButton>
                  </ActionGroup>
                ),
              },
            ]}
            data={visibleRows}
            rowKey={visibleRows[0]?.id ? 'id' : visibleRows[0]?.orderId ? 'orderId' : table.columns[0].key}
            pageSize={8}
            compact
            itemLabel="rows"
            scroll={Boolean(table.scroll)}
          />
        )}
      </GlassCard>
      <Drawer open={Boolean(view)} size="2xl" eyebrow={title} title={String(view?.orderId || view?.id || view?.name || view?.reason || 'Report row')} onClose={() => setView(null)} footer={<Button onClick={() => setView(null)}>Close</Button>}>
        {view ? (
          <div className="space-y-4">
            <DetailSection title="Details">
              {table.columns.map((column) => (
                <DetailRow key={column.key} label={column.label} value={column.render ? column.render(view) : view[column.key]} />
              ))}
            </DetailSection>
            {type === 'customers' ? (
              <div>
                <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-soft">Order History</p>
                <DataTable
                  columns={[
                    { key: 'id', label: 'Order ID' },
                    { key: 'date', label: 'Date', render: (row) => formatAppDate(parseAppDate(row.date)) },
                    { key: 'time', label: 'Time', render: (row) => formatAppTime(row.time || row.deliveredAt || row.date) },
                    { key: 'status', label: 'Order Status', render: (row) => <StatusBadge status={row.status} /> },
                    { key: 'amount', label: 'Order Amount', render: (row) => formatINR(row.amount) },
                    { key: 'paymentStatus', label: 'Payment Status', render: (row) => <StatusBadge status={row.paymentStatus || 'Paid'} /> },
                    { key: 'payment', label: 'Payment Method' },
                    { key: 'destination', label: 'Destination', hideBelow: 'lg' },
                  ]}
                  data={viewedCustomerOrders}
                  pageSize={10}
                  compact
                  itemLabel="orders"
                  scroll
                />
              </div>
            ) : null}
          </div>
        ) : null}
      </Drawer>
    </PageContainer>
  );
}
