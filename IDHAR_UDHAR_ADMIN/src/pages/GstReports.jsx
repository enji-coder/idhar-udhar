import { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Download, RefreshCw, Settings2, X } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import Button from '../components/common/Button';
import Select from '../components/common/Select';
import Tabs from '../components/common/Tabs';
import Modal from '../components/common/Modal';
import Toast from '../components/common/Toast';
import EmptyState from '../components/common/EmptyState';
import ErrorState from '../components/common/ErrorState';
import Field, { inputClass } from '../components/common/Field';
import { TableSkeleton } from '../components/common/Skeleton';
import {
  downloadGstReportExcel,
  fetchAdminVehicleCategories,
  fetchAdminZones,
  fetchGstReport,
  fetchTaxConfig,
  publishTaxConfig,
} from '../api/adminApi';
import { formatINRExact } from '../utils/format';
import { useAuth } from '../context/AuthContext';

const presets = [
  { value: 'today', label: 'Today' },
  { value: 'yesterday', label: 'Yesterday' },
  { value: 'this_week', label: 'This Week' },
  { value: 'this_month', label: 'This Month' },
  { value: 'previous_month', label: 'Previous Month' },
  { value: 'custom', label: 'Custom' },
];

const groupings = [
  { value: 'day', label: 'Date-wise' },
  { value: 'month', label: 'Month-wise' },
];

const paymentStatuses = [
  { value: '', label: 'All payment statuses' },
  { value: 'UNPAID', label: 'Unpaid' },
  { value: 'PARTIALLY_PAID', label: 'Partially paid' },
  { value: 'PAID', label: 'Paid' },
];

const paymentMethods = [
  { value: '', label: 'All payment methods' },
  { value: 'CASH', label: 'Cash collected' },
  { value: 'ONLINE', label: 'Online collected' },
];

const orderStatuses = [
  { value: '', label: 'All order statuses' },
  { value: 'DELIVERED', label: 'Delivered' },
  { value: 'IN_TRANSIT', label: 'In transit' },
  { value: 'ASSIGNED', label: 'Assigned' },
  { value: 'CONFIRMED', label: 'Confirmed' },
  { value: 'CANCELLED', label: 'Cancelled' },
  { value: 'FAILED', label: 'Failed' },
];

const gstBases = [
  { value: 'EXCLUSIVE', label: 'Exclusive — GST computed on top of commission' },
  { value: 'INCLUSIVE', label: 'Inclusive — commission already contains GST' },
  { value: 'NONE', label: 'None — no GST on commission' },
];

const PAGE_SIZE = 25;

const emptyFilters = {
  preset: 'today',
  from: '',
  to: '',
  group_by: 'day',
  display_id: '',
  city_id: '',
  vehicle_category_id: '',
  order_status: '',
  payment_status: '',
  payment_method: '',
};

function money(value) {
  if (value == null) return '—';
  return formatINRExact(value);
}

function percent(value) {
  if (value == null) return '—';
  return `${Number(value).toFixed(2)}%`;
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

export default function GstReports() {
  const { can } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const [filters, setFilters] = useState({
    ...emptyFilters,
    from: todayIso(),
    to: todayIso(),
  });
  const [offset, setOffset] = useState(0);
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);
  const [exporting, setExporting] = useState(false);
  const [toast, setToast] = useState('');
  const [cities, setCities] = useState([]);
  const [categories, setCategories] = useState([]);
  const [taxConfig, setTaxConfig] = useState(null);
  const [configOpen, setConfigOpen] = useState(false);
  const [configForm, setConfigForm] = useState({
    gst_rate: '18.00',
    gst_calculation_basis: 'EXCLUSIVE',
    notes: '',
  });
  const [configError, setConfigError] = useState('');
  const [publishing, setPublishing] = useState(false);

  // Deep links from a customer or rider profile scope the report by id.
  const customerProfileId = searchParams.get('customer_profile_id') || '';
  const riderProfileId = searchParams.get('rider_profile_id') || '';

  const query = useMemo(() => {
    const base = {
      preset: filters.preset,
      group_by: filters.group_by,
      display_id: filters.display_id.trim(),
      city_id: filters.city_id,
      vehicle_category_id: filters.vehicle_category_id,
      order_status: filters.order_status,
      payment_status: filters.payment_status,
      payment_method: filters.payment_method,
      customer_profile_id: customerProfileId,
      rider_profile_id: riderProfileId,
    };
    if (filters.preset === 'custom') {
      base.from = filters.from;
      base.to = filters.to;
    }
    return base;
  }, [filters, customerProfileId, riderProfileId]);

  const load = useCallback(
    (nextOffset) => {
      setLoading(true);
      return fetchGstReport({ ...query, limit: PAGE_SIZE, offset: nextOffset })
        .then((body) => {
          setReport(body);
          setLoadError(null);
        })
        .catch((error) => {
          setReport(null);
          setLoadError(error);
        })
        .finally(() => setLoading(false));
    },
    [query],
  );

  useEffect(() => {
    setOffset(0);
    load(0);
  }, [load]);

  useEffect(() => {
    fetchAdminZones()
      .then((zones) => {
        const unique = new Map();
        zones.forEach((zone) => {
          if (zone.cityId && !unique.has(zone.cityId)) {
            unique.set(zone.cityId, zone.area || zone.cityId);
          }
        });
        setCities([...unique.entries()].map(([value, label]) => ({ value, label })));
      })
      .catch(() => setCities([]));
    fetchAdminVehicleCategories()
      .then((list) => setCategories(list.map((item) => ({ value: item.id, label: item.name }))))
      .catch(() => setCategories([]));
    fetchTaxConfig()
      .then(setTaxConfig)
      .catch(() => setTaxConfig(null));
  }, []);

  function updateFilter(key, value) {
    setFilters((current) => ({ ...current, [key]: value }));
  }

  function clearProfileFilter(key) {
    const next = new URLSearchParams(searchParams);
    next.delete(key);
    setSearchParams(next, { replace: true });
  }

  function resetFilters() {
    setFilters({ ...emptyFilters, from: todayIso(), to: todayIso() });
    const next = new URLSearchParams(searchParams);
    next.delete('customer_profile_id');
    next.delete('rider_profile_id');
    setSearchParams(next, { replace: true });
  }

  function goToPage(nextOffset) {
    setOffset(nextOffset);
    load(nextOffset);
  }

  async function handleExport() {
    setExporting(true);
    try {
      const { blob, filename } = await downloadGstReportExcel(query);
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      link.click();
      URL.revokeObjectURL(url);
      setToast('Excel downloaded for the selected filters.');
    } catch (error) {
      setToast(error.message || 'Could not generate the Excel file.');
    } finally {
      setExporting(false);
    }
  }

  async function handlePublish() {
    setConfigError('');
    setPublishing(true);
    try {
      const body = await publishTaxConfig({
        gst_rate: configForm.gst_rate,
        gst_calculation_basis: configForm.gst_calculation_basis,
        ...(configForm.notes.trim() ? { notes: configForm.notes.trim() } : {}),
      });
      setTaxConfig((current) => ({
        ...(current || {}),
        active: body.tax_config,
        versions: [body.tax_config, ...((current && current.versions) || [])],
      }));
      setConfigOpen(false);
      setToast(
        `GST set to ${body.tax_config.gst_rate}% ${body.tax_config.gst_calculation_basis}. Existing reports keep their original rate.`,
      );
      load(offset);
      fetchTaxConfig().then(setTaxConfig).catch(() => {});
    } catch (error) {
      setConfigError(error.message || 'Could not publish the GST configuration.');
    } finally {
      setPublishing(false);
    }
  }

  const summary = report?.summary;
  const activeConfig = taxConfig?.active || report?.active_tax_config || null;

  const summaryCards = [
    { label: 'Total Trip Fare', value: money(summary?.total_trip_fare) },
    {
      label: `Total Rider Share${report?.records?.[0] ? ` — ${percent(report.records[0].rider_percentage)}` : ''}`,
      value: money(summary?.total_rider_share),
    },
    {
      label: `Total Company Commission${report?.records?.[0] ? ` — ${percent(report.records[0].company_commission_percentage)}` : ''}`,
      value: money(summary?.total_company_commission),
    },
    { label: 'Total GST', value: money(summary?.total_gst) },
    { label: 'Total Operational Cost', value: money(summary?.total_operational_cost) },
    { label: 'Company Profit', value: money(summary?.total_company_profit) },
  ];

  const groupColumns = [
    { key: 'period', label: filters.group_by === 'month' ? 'Month' : 'Date', sortable: true },
    { key: 'order_count', label: 'Orders', sortable: true },
    { key: 'trip_fare', label: 'Trip Fare', render: (row) => money(row.trip_fare) },
    { key: 'rider_share', label: 'Rider Share', render: (row) => money(row.rider_share) },
    { key: 'company_commission', label: 'Company Commission', render: (row) => money(row.company_commission) },
    { key: 'gst_amount', label: 'GST', render: (row) => money(row.gst_amount) },
    { key: 'operational_cost', label: 'Operations', render: (row) => money(row.operational_cost) },
    { key: 'company_profit', label: 'Profit', render: (row) => money(row.company_profit) },
  ];

  const detailColumns = [
    { key: 'date', label: 'Date', sortable: true },
    { key: 'display_id', label: 'Order ID', sortable: true },
    { key: 'customer_name', label: 'Customer', render: (row) => row.customer_name || '—' },
    { key: 'rider_phone', label: 'Rider', render: (row) => row.rider_phone || 'Unassigned' },
    { key: 'city_name', label: 'City', hideBelow: 'lg', render: (row) => row.city_name || '—' },
    { key: 'vehicle_category_name', label: 'Vehicle', hideBelow: 'lg', render: (row) => row.vehicle_category_name || '—' },
    { key: 'trip_fare', label: 'Trip Fare', render: (row) => money(row.trip_fare) },
    { key: 'rider_share', label: 'Rider Share', render: (row) => money(row.rider_share) },
    { key: 'company_commission', label: 'Commission', render: (row) => money(row.company_commission) },
    { key: 'gst_rate', label: 'GST Rate', render: (row) => percent(row.gst_rate) },
    { key: 'gst_basis', label: 'GST Basis' },
    { key: 'gst_amount', label: 'GST', render: (row) => money(row.gst_amount) },
    { key: 'operational_cost', label: 'Operations', hideBelow: 'lg', render: (row) => money(row.operational_cost) },
    { key: 'company_profit', label: 'Profit', render: (row) => money(row.company_profit) },
    { key: 'payment_status', label: 'Payment' },
    { key: 'order_status', label: 'Order', hideBelow: 'lg' },
  ];

  if (loadError) {
    return (
      <PageContainer>
        <ErrorState
          title="Couldn't load the GST report"
          description={loadError.message || 'The reports API did not respond.'}
        />
      </PageContainer>
    );
  }

  const total = report?.page?.total || 0;
  const shownFrom = total === 0 ? 0 : offset + 1;
  const shownTo = Math.min(offset + PAGE_SIZE, total);

  return (
    <PageContainer className="space-y-4">
      <GlassCard className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <Tabs tabs={presets} value={filters.preset} onChange={(value) => updateFilter('preset', value)} />
          <div className="flex flex-wrap items-center gap-2">
            <Button variant="ghost" icon={RefreshCw} onClick={() => load(offset)}>Refresh</Button>
            {can('gstReports', 'export') ? (
              <Button variant="export" icon={Download} loading={exporting} onClick={handleExport}>
                Download Excel
              </Button>
            ) : null}
          </div>
        </div>

        {filters.preset === 'custom' ? (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 md:max-w-md">
            <Field label="From date">
              <input
                type="date"
                className={inputClass}
                value={filters.from}
                max={filters.to || undefined}
                onChange={(event) => updateFilter('from', event.target.value)}
              />
            </Field>
            <Field label="To date">
              <input
                type="date"
                className={inputClass}
                value={filters.to}
                min={filters.from || undefined}
                onChange={(event) => updateFilter('to', event.target.value)}
              />
            </Field>
          </div>
        ) : null}

        <div className="flex flex-wrap items-center gap-2">
          <input
            className={`${inputClass} md:w-56`}
            placeholder="Order / Trip ID"
            value={filters.display_id}
            onChange={(event) => updateFilter('display_id', event.target.value)}
          />
          <Select
            aria-label="City"
            value={filters.city_id}
            onChange={(value) => updateFilter('city_id', value)}
            options={[{ value: '', label: 'All cities' }, ...cities]}
          />
          <Select
            aria-label="Vehicle category"
            value={filters.vehicle_category_id}
            onChange={(value) => updateFilter('vehicle_category_id', value)}
            options={[{ value: '', label: 'All vehicle categories' }, ...categories]}
          />
          <Select
            aria-label="Order status"
            value={filters.order_status}
            onChange={(value) => updateFilter('order_status', value)}
            options={orderStatuses}
          />
          <Select
            aria-label="Payment status"
            value={filters.payment_status}
            onChange={(value) => updateFilter('payment_status', value)}
            options={paymentStatuses}
          />
          <Select
            aria-label="Payment method"
            value={filters.payment_method}
            onChange={(value) => updateFilter('payment_method', value)}
            options={paymentMethods}
          />
          <Select
            aria-label="Grouping"
            value={filters.group_by}
            onChange={(value) => updateFilter('group_by', value)}
            options={groupings}
          />
          <Button variant="secondary" onClick={resetFilters}>Clear filters</Button>
        </div>

        {customerProfileId || riderProfileId ? (
          <div className="flex flex-wrap items-center gap-2 text-xs">
            {customerProfileId ? (
              <span className="inline-flex items-center gap-1 rounded-full bg-brand-50 px-3 py-1 font-semibold text-brand-700">
                Customer {customerProfileId.slice(0, 8)}
                <button type="button" aria-label="Clear customer filter" onClick={() => clearProfileFilter('customer_profile_id')}>
                  <X size={12} />
                </button>
              </span>
            ) : null}
            {riderProfileId ? (
              <span className="inline-flex items-center gap-1 rounded-full bg-brand-50 px-3 py-1 font-semibold text-brand-700">
                Rider {riderProfileId.slice(0, 8)}
                <button type="button" aria-label="Clear rider filter" onClick={() => clearProfileFilter('rider_profile_id')}>
                  <X size={12} />
                </button>
              </span>
            ) : null}
          </div>
        ) : null}

        {report ? (
          <p className="text-xs text-ink-soft">
            {report.period.from_date} to {report.period.to_date} ({report.period.time_zone}), grouped by finance freeze date. {report.scope}
          </p>
        ) : null}
      </GlassCard>

      <GlassCard className="flex flex-wrap items-center justify-between gap-3">
        <div className="min-w-0">
          <p className="text-sm font-medium text-ink-muted">Applied GST configuration</p>
          <p className="text-lg font-semibold text-ink">
            {activeConfig
              ? `${Number(activeConfig.gst_rate).toFixed(2)}% · ${activeConfig.gst_calculation_basis} · on company commission`
              : 'No GST configuration published'}
          </p>
          {report?.gst_rates_applied?.length ? (
            <p className="mt-1 text-xs text-ink-soft">
              Rates in this period:{' '}
              {report.gst_rates_applied
                .map((row) => `${row.gst_basis || 'UNCONFIGURED'} ${Number(row.gst_rate || 0).toFixed(2)}% (${row.order_count})`)
                .join(', ')}
              . Historical orders keep the rate frozen at their finance freeze.
            </p>
          ) : null}
          {summary?.unconfigured_order_count ? (
            <p className="mt-1 text-xs font-semibold text-danger">
              {summary.unconfigured_order_count} order(s) have no applicable GST configuration and contribute no GST or profit.
            </p>
          ) : null}
        </div>
        {can('gstReports', 'configure') ? (
          <Button variant="secondary" icon={Settings2} onClick={() => setConfigOpen(true)}>
            Change GST configuration
          </Button>
        ) : null}
      </GlassCard>

      {loading && !report ? (
        <TableSkeleton />
      ) : (
        <>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-6">
            {summaryCards.map((card) => (
              <GlassCard key={card.label}>
                <p className="text-sm text-ink-muted">{card.label}</p>
                <p className="text-2xl font-bold">{card.value}</p>
              </GlassCard>
            ))}
          </div>

          <GlassCard className="overflow-hidden">
            <div className="mb-3 flex flex-wrap items-baseline justify-between gap-2">
              <h2 className="text-lg font-semibold text-ink">
                {filters.group_by === 'month' ? 'Month-wise' : 'Date-wise'} breakdown
              </h2>
              <p className="text-xs text-ink-soft">
                Totals: {money(summary?.total_trip_fare)} fare · {money(summary?.total_gst)} GST ·{' '}
                {money(summary?.total_company_profit)} profit · {summary?.order_count || 0} orders
              </p>
            </div>
            {report?.groups?.length ? (
              <DataTable columns={groupColumns} data={report.groups} rowKey="period" pageSize={12} itemLabel="periods" compact scroll />
            ) : (
              <EmptyState title="No frozen finance snapshots in this period" description="Change the date range or filters." />
            )}
          </GlassCard>

          <GlassCard className="overflow-hidden">
            <div className="mb-3 flex flex-wrap items-baseline justify-between gap-2">
              <h2 className="text-lg font-semibold text-ink">Transactions</h2>
              <p className="text-xs text-ink-soft">
                {total === 0 ? 'No records' : `Showing ${shownFrom}–${shownTo} of ${total}`}
              </p>
            </div>
            {report?.records?.length ? (
              <>
                <DataTable
                  columns={detailColumns}
                  data={report.records}
                  rowKey="order_id"
                  pageSize={PAGE_SIZE}
                  itemLabel="orders"
                  compact
                  scroll
                  pageNumbers={false}
                />
                <div className="mt-3 flex items-center justify-end gap-2">
                  <Button variant="secondary" disabled={offset === 0 || loading} onClick={() => goToPage(Math.max(0, offset - PAGE_SIZE))}>
                    Previous
                  </Button>
                  <Button variant="secondary" disabled={shownTo >= total || loading} onClick={() => goToPage(offset + PAGE_SIZE)}>
                    Next
                  </Button>
                </div>
              </>
            ) : (
              <EmptyState title="No transactions found" description="Only orders with a frozen finance snapshot appear here." />
            )}
          </GlassCard>
        </>
      )}

      <Modal
        open={configOpen}
        title="Publish a new GST configuration"
        onClose={() => setConfigOpen(false)}
        footer={(
          <>
            <Button variant="secondary" onClick={() => setConfigOpen(false)}>Cancel</Button>
            <Button loading={publishing} onClick={handlePublish}>Publish new version</Button>
          </>
        )}
      >
        <div className="space-y-3">
          <p className="text-sm text-ink-muted">
            This publishes a new version effective from now. Orders already frozen keep the rate and basis
            that applied to them, so past reports do not change.
          </p>
          <Field label="GST rate (%)">
            <input
              className={inputClass}
              value={configForm.gst_rate}
              inputMode="decimal"
              onChange={(event) => setConfigForm((current) => ({ ...current, gst_rate: event.target.value }))}
            />
          </Field>
          <Field label="GST calculation basis">
            <Select
              aria-label="GST calculation basis"
              className="w-full"
              value={configForm.gst_calculation_basis}
              onChange={(value) => setConfigForm((current) => ({ ...current, gst_calculation_basis: value }))}
              options={gstBases}
            />
          </Field>
          <Field label="Notes (optional)" error={configError}>
            <input
              className={inputClass}
              value={configForm.notes}
              placeholder="Reason or CA reference"
              onChange={(event) => setConfigForm((current) => ({ ...current, notes: event.target.value }))}
            />
          </Field>
          {taxConfig?.versions?.length ? (
            <div>
              <p className="mb-1 text-sm font-medium text-ink">Version history</p>
              <ul className="space-y-1 text-xs text-ink-soft">
                {taxConfig.versions.map((version) => (
                  <li key={version.tax_config_version_id}>
                    v{version.version} · {Number(version.gst_rate).toFixed(2)}% {version.gst_calculation_basis} ·{' '}
                    {version.status} · from {new Date(version.effective_from).toLocaleString('en-IN')}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </div>
      </Modal>

      <Toast open={Boolean(toast)} message={toast} onClose={() => setToast('')} />
    </PageContainer>
  );
}
