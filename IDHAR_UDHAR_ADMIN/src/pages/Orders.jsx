import { useEffect, useMemo, useState } from 'react';
import { useOutletContext, useSearchParams } from 'react-router-dom';
import { Download, Package, Plus, Printer, RotateCcw, Share2 } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import Drawer from '../components/common/Drawer';
import Modal from '../components/common/Modal';
import Button from '../components/common/Button';
import Select from '../components/common/Select';
import StatusBadge from '../components/common/StatusBadge';
import EmptyState from '../components/common/EmptyState';
import ErrorState from '../components/common/ErrorState';
import Toast from '../components/common/Toast';
import Field, { inputClass } from '../components/common/Field';
import FilterBar from '../components/common/FilterBar';
import OrderRowActions from '../components/orders/OrderRowActions';
import OrderDetailDrawer from '../components/orders/OrderDetailDrawer';
import ReassignRiderDrawer from '../components/orders/ReassignRiderDrawer';
import CancelOrderModal from '../components/orders/CancelOrderModal';
import InvoicePreview from '../components/orders/InvoicePreview';
import CreateOrderModal from '../components/orders/CreateOrderModal';
import ConfirmDialog from '../components/common/ConfirmDialog';
import PageHeader from '../components/common/PageHeader';
import useStore from '../hooks/useStore';
import useQueryAction from '../hooks/useQueryAction';
import { customerStore, orderStore, riderStore, vehicleStore } from '../services/stores';
import { ORDER_STATUSES, normalizeOrder } from '../services/orderRules';
import { useAuth } from '../context/AuthContext';
import { formatINR } from '../utils/format';
import { buildInvoice, downloadInvoicePdf, invoicePrintMarkup, invoiceShareText, printInvoiceHtml } from '../services/invoiceService';
import { assignAdminOrder, cancelAdminOrder, transitionAdminOrder } from '../api/adminApi';
import { hydrateAdminDirectory } from '../api/hydrate';
import { UI_TO_CANONICAL } from '../api/mappers';
import { ApiError } from '../api/errors';
import { vehicleCategoryNames, vehicleCategoryStore } from '../services/vehicleCategories';

const activeStatuses = ['Assigned', 'Accepted', 'Rider Arriving', 'Picked Up', 'In Transit', 'Pending', 'Searching'];

const emptyFilters = {
  status: 'All',
  payment: 'All',
  rider: 'All',
  vehicle: 'All',
  date: 'All',
  customer: '',
  pickup: '',
  destination: '',
};

export default function Orders() {
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const [params, setParams] = useSearchParams();
  const rows = useStore(orderStore);
  const riders = useStore(riderStore);
  const customers = useStore(customerStore);
  const vehicles = useStore(vehicleStore);
  useStore(vehicleCategoryStore);
  const [createOpen, setCreateOpen] = useState(false);
  const [deleteRow, setDeleteRow] = useState(null);
  const [statusRow, setStatusRow] = useState(null);
  const [localSearch, setLocalSearch] = useState('');
  const [filters, setFilters] = useState({ ...emptyFilters, status: params.get('status') || 'All' });
  const [advancedOpen, setAdvancedOpen] = useState(false);
  const [draftFilters, setDraftFilters] = useState(emptyFilters);
  const [selectedId, setSelectedId] = useState(null);
  const [panel, setPanel] = useState(null);
  const [toast, setToast] = useState('');
  const [error, setError] = useState(false);
  const [refund, setRefund] = useState(null);
  useQueryAction('add', () => setCreateOpen(true));

  useEffect(() => {
    const next = params.get('status');
    if (next) setFilters((current) => ({ ...current, status: next }));
    const customer = params.get('customer');
    if (customer) setFilters((current) => ({ ...current, customer }));
  }, [params]);

  const orders = useMemo(
    () => rows.map((row) => normalizeOrder(row, customers, riders)),
    [rows, customers, riders],
  );

  const selected = useMemo(
    () => orders.find((row) => row.id === selectedId) || null,
    [orders, selectedId],
  );

  const invoice = selected && panel === 'invoice' ? buildInvoice(selected) : null;

  const data = useMemo(() => {
    const query = `${searchQuery || ''} ${localSearch}`.trim().toLowerCase();
    return orders.filter((row) => {
      const blob = `${row.id} ${row.customer} ${row.rider} ${row.pickup} ${row.destination} ${row.customerPhone || ''}`.toLowerCase();
      const matchesQuery = !query || blob.includes(query);
      const matchesStatus = filters.status === 'All'
        || row.status === filters.status
        || (filters.status === 'Active' && activeStatuses.includes(row.status));
      const matchesPayment = filters.payment === 'All' || row.payment === filters.payment;
      const matchesRider = filters.rider === 'All' || row.rider === filters.rider;
      const matchesVehicle = filters.vehicle === 'All' || row.vehicle === filters.vehicle;
      const matchesDate = filters.date === 'All'
        || (filters.date === 'Today' && row.date === '14 Aug 2026')
        || (filters.date === 'Yesterday' && row.date === '13 Aug 2026');
      const matchesCustomer = !filters.customer || row.customer.toLowerCase().includes(filters.customer.toLowerCase());
      const matchesPickup = !filters.pickup || row.pickup.toLowerCase().includes(filters.pickup.toLowerCase());
      const matchesDestination = !filters.destination || row.destination.toLowerCase().includes(filters.destination.toLowerCase());
      return matchesQuery && matchesStatus && matchesPayment && matchesRider && matchesVehicle && matchesDate && matchesCustomer && matchesPickup && matchesDestination;
    });
  }, [orders, searchQuery, localSearch, filters]);

  function setStatusFilter(value) {
    setFilters((current) => ({ ...current, status: value }));
    const next = new URLSearchParams(params);
    if (value === 'All') next.delete('status');
    else next.set('status', value);
    setParams(next, { replace: true });
  }

  function resetFilters() {
    setFilters(emptyFilters);
    setLocalSearch('');
    setParams(new URLSearchParams(), { replace: true });
  }

  function openPanel(nextPanel, order) {
    setSelectedId(order.id);
    setPanel(nextPanel);
  }

  function closePanels() {
    setPanel(null);
    setSelectedId(null);
  }

  async function runOrderApi(work, successMessage) {
    try {
      await work();
      await hydrateAdminDirectory({ silent: true });
      if (successMessage) setToast(successMessage);
    } catch (error) {
      setToast(error instanceof ApiError ? error.message : 'Could not update the order.');
    }
  }

  function handleAction(type, order) {
    if (type === 'proof') {
      openPanel('view', order);
      return;
    }
    if (type === 'refund') {
      setRefund(order);
      return;
    }
    if (type === 'delete') {
      setDeleteRow(order);
      return;
    }
    if (type === 'status') {
      setStatusRow(order);
      return;
    }
    openPanel(type, order);
  }

  const columns = [
    { key: 'id', label: 'Order ID', sortable: true, className: 'font-semibold', render: (row) => <button type="button" className="font-semibold text-brand-600 hover:underline" onClick={() => openPanel('view', row)}>{row.id}</button> },
    { key: 'customer', label: 'Customer', sortable: true },
    { key: 'rider', label: 'Rider', sortable: true, render: (row) => row.rider || 'Unassigned' },
    { key: 'pickup', label: 'Pickup', render: (row) => <span title={row.pickup}>{row.pickup}</span> },
    { key: 'destination', label: 'Destination', render: (row) => <span title={row.destination}>{row.destination}</span> },
    { key: 'vehicle', label: 'Vehicle', hideBelow: 'lg' },
    { key: 'amount', label: 'Amount', sortable: true, render: (row) => formatINR(row.amount) },
    { key: 'payment', label: 'Payment', hideBelow: 'lg' },
    { key: 'status', label: 'Status', hideBelow: 'md', render: (row) => <StatusBadge status={row.status} /> },
    { key: 'date', label: 'Date', hideBelow: 'lg' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      headerClassName: 'text-right',
      mobile: false,
      render: (row) => <OrderRowActions order={row} can={can} onAction={handleAction} />,
    },
  ];

  if (error) {
    return (
      <PageContainer>
        <ErrorState title="Couldn't load orders" description="Check your connection and try again." onRetry={() => setError(false)} />
      </PageContainer>
    );
  }

  return (
    <PageContainer className="space-y-4 pb-8">
      <PageHeader action={<Button icon={Plus} onClick={() => setCreateOpen(true)}>Create Order</Button>} />
      <GlassCard className="overflow-hidden">
        <FilterBar
          search={localSearch}
          onSearch={setLocalSearch}
          placeholder="Search order, customer, rider or area"
          onOpenFilters={() => { setDraftFilters(filters); setAdvancedOpen(true); }}
        >
          <Select aria-label="Status" value={filters.status} onChange={setStatusFilter} options={['All', 'Active', ...ORDER_STATUSES]} />
          <Select aria-label="Payment" value={filters.payment} onChange={(value) => setFilters((current) => ({ ...current, payment: value }))} options={['All', 'UPI', 'Cash', 'Card', 'Wallet', 'Net Banking']} />
          <Select aria-label="Vehicle" value={filters.vehicle} onChange={(value) => setFilters((current) => ({ ...current, vehicle: value }))} options={['All', ...vehicleCategoryNames({ includeInactive: true, current: filters.vehicle === 'All' ? '' : filters.vehicle })]} />
          <Select aria-label="Rider" value={filters.rider} onChange={(value) => setFilters((current) => ({ ...current, rider: value }))} options={['All', 'Unassigned', ...riders.map((item) => item.name)]} />
          <Select aria-label="Date" value={filters.date} onChange={(value) => setFilters((current) => ({ ...current, date: value }))} options={['All', 'Today', 'Yesterday']} />
          <Button variant="secondary" onClick={() => { setDraftFilters(filters); setAdvancedOpen(true); }}>More filters</Button>
        </FilterBar>
      </GlassCard>

      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState
            icon={Package}
            title="No orders found"
            description="Nothing matches the current search and filters. Reset to see the full Ahmedabad queue."
            action={<Button variant="secondary" onClick={resetFilters}>Reset Filters</Button>}
          />
        ) : (
          <DataTable
            columns={columns}
            data={data}
            mobileTitleKey="id"
            pageSize={20}
            compact
            pageNumbers
            itemLabel="orders"
            mobileCard={(row) => (
              <article className="rounded-2xl border border-slate-100 bg-white/80 p-4">
                <button type="button" className="font-semibold text-brand-600" onClick={() => openPanel('view', row)}>{row.id}</button>
                <p className="mt-1 text-sm text-ink">{row.customer}</p>
                <p className="text-sm text-ink-muted">{row.rider || 'Unassigned'}</p>
                <p className="mt-2 truncate text-sm text-ink-muted">{row.pickup} → {row.destination}</p>
                <p className="mt-1 text-sm font-semibold">{formatINR(row.amount)}</p>
                <div className="mt-3">
                  <OrderRowActions order={row} can={can} onAction={handleAction} />
                </div>
              </article>
            )}
          />
        )}
      </GlassCard>

      <OrderDetailDrawer
        open={Boolean(selected) && ['view', 'track', 'edit'].includes(panel)}
        order={selected}
        mode={panel}
        can={can}
        onClose={closePanels}
        onAction={handleAction}
        onSaveEdit={() => {
          setToast('Editing orders from Admin is not available on the server yet.');
          setPanel('view');
        }}
      />

      <ReassignRiderDrawer
        open={Boolean(selected) && panel === 'reassign'}
        order={selected}
        riders={riders}
        orders={orders}
        onClose={() => setPanel('view')}
        onAssign={(rider) => {
          if (!selected?.backendOrderId) {
            setToast('This mock order is not on the server.');
            return;
          }
          runOrderApi(
            () => assignAdminOrder(selected.backendOrderId, rider.id),
            'Rider successfully reassigned.',
          );
          setPanel('view');
        }}
      />

      <Modal
        open={Boolean(selected) && panel === 'invoice'}
        title={`Invoice ${selected?.id || ''}`}
        size="xl"
        onClose={() => setPanel('view')}
        footer={
          <>
            <Button variant="ghost" onClick={() => setPanel('view')}>Close</Button>
            <Button variant="secondary" icon={Share2} onClick={async () => {
              if (!invoice) return;
              const text = invoiceShareText(invoice);
              if (navigator.share) {
                try { await navigator.share({ title: invoice.invoiceNumber, text }); } catch { /* dismissed */ }
              } else {
                await navigator.clipboard.writeText(text);
                setToast('Invoice summary copied.');
              }
            }}>Share</Button>
            <Button variant="secondary" icon={Printer} onClick={() => invoice && printInvoiceHtml(invoicePrintMarkup(invoice), invoice.invoiceNumber)}>Print</Button>
            <Button icon={Download} onClick={() => invoice && downloadInvoicePdf(invoice)}>Download PDF</Button>
          </>
        }
      >
        <InvoicePreview invoice={invoice} />
      </Modal>

      <CancelOrderModal
        open={Boolean(selected) && panel === 'cancel'}
        order={selected}
        onClose={() => setPanel('view')}
        onConfirm={() => {
          if (!selected?.backendOrderId) {
            setToast('This mock order is not on the server.');
            return;
          }
          runOrderApi(
            () => cancelAdminOrder(selected.backendOrderId),
            'Order cancelled.',
          );
          setPanel(null);
        }}
      />

      <Modal
        open={Boolean(refund)}
        title="Refund this payment?"
        onClose={() => setRefund(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setRefund(null)}>Keep</Button>
            <Button variant="reject" icon={RotateCcw} onClick={() => {
              setRefund(null);
              setToast('Refunds are not available on the server yet.');
            }}>Refund</Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">Refunds are not available on the server yet. {refund ? `${formatINR(refund.amount)} for ${refund.customer}` : ''} remains unchanged.</p>
      </Modal>

      <Drawer
        open={advancedOpen}
        title="Advanced filters"
        size="md"
        onClose={() => setAdvancedOpen(false)}
        footer={
          <>
            <Button variant="ghost" onClick={() => { setDraftFilters(emptyFilters); }}>Clear</Button>
            <Button onClick={() => { setFilters(draftFilters); setAdvancedOpen(false); if (draftFilters.status !== filters.status) setStatusFilter(draftFilters.status); }}>Apply</Button>
          </>
        }
      >
        <div className="space-y-3">
          <Field label="Status">
            <select className={inputClass} value={draftFilters.status} onChange={(event) => setDraftFilters((current) => ({ ...current, status: event.target.value }))}>
              {['All', 'Active', ...ORDER_STATUSES].map((item) => <option key={item}>{item}</option>)}
            </select>
          </Field>
          <Field label="Payment">
            <select className={inputClass} value={draftFilters.payment} onChange={(event) => setDraftFilters((current) => ({ ...current, payment: event.target.value }))}>
              {['All', 'UPI', 'Cash', 'Card', 'Wallet', 'Net Banking'].map((item) => <option key={item}>{item}</option>)}
            </select>
          </Field>
          <Field label="Customer"><input className={inputClass} value={draftFilters.customer} onChange={(event) => setDraftFilters((current) => ({ ...current, customer: event.target.value }))} placeholder="Rahul Mehta" /></Field>
          <Field label="Pickup area"><input className={inputClass} value={draftFilters.pickup} onChange={(event) => setDraftFilters((current) => ({ ...current, pickup: event.target.value }))} placeholder="Navrangpura" /></Field>
          <Field label="Destination area"><input className={inputClass} value={draftFilters.destination} onChange={(event) => setDraftFilters((current) => ({ ...current, destination: event.target.value }))} placeholder="SG Highway" /></Field>
          <Field label="Date">
            <select className={inputClass} value={draftFilters.date} onChange={(event) => setDraftFilters((current) => ({ ...current, date: event.target.value }))}>
              <option>All</option>
              <option>Today</option>
              <option>Yesterday</option>
            </select>
          </Field>
        </div>
      </Drawer>

      <Toast open={Boolean(toast)} message={toast} onClose={() => setToast('')} />
      <CreateOrderModal
        open={createOpen}
        customers={customers}
        riders={riders}
        vehicles={vehicles}
        onClose={() => setCreateOpen(false)}
        onSave={() => {
          setToast('Creating orders from Admin is not available on the server yet.');
          setCreateOpen(false);
        }}
      />
      <ConfirmDialog
        open={Boolean(deleteRow)}
        description={`${deleteRow?.id} will be removed from the orders list.`}
        onClose={() => setDeleteRow(null)}
        onConfirm={() => { setDeleteRow(null); setToast('Deleting orders from Admin is not available on the server yet.'); }}
      />
      <Modal
        open={Boolean(statusRow)}
        title={`Update status · ${statusRow?.id || ''}`}
        onClose={() => setStatusRow(null)}
        footer={<Button variant="ghost" onClick={() => setStatusRow(null)}>Close</Button>}
      >
        <div className="grid gap-2 sm:grid-cols-2">
          {ORDER_STATUSES.map((status) => (
            <Button key={status} variant="secondary" onClick={() => {
              if (!statusRow?.backendOrderId) {
                setToast('This mock order is not on the server.');
                return;
              }
              if (status === 'Cancelled') {
                runOrderApi(() => cancelAdminOrder(statusRow.backendOrderId), 'Order cancelled.');
                setStatusRow(null);
                return;
              }
              const canonical = UI_TO_CANONICAL[status];
              if (!canonical) {
                setToast('That status is display-only.');
                return;
              }
              runOrderApi(
                () => transitionAdminOrder(statusRow.backendOrderId, canonical),
                `Status updated to ${status}.`,
              );
              setStatusRow(null);
            }}>{status}</Button>
          ))}
        </div>
      </Modal>
    </PageContainer>
  );
}
