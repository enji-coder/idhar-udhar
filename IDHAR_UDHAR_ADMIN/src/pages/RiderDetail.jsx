import { Link, useParams } from 'react-router-dom';
import { useEffect, useMemo, useState } from 'react';
import { Eye } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import StatusBadge from '../components/common/StatusBadge';
import DataTable from '../components/common/DataTable';
import ErrorState from '../components/common/ErrorState';
import Button from '../components/common/Button';
import Modal from '../components/common/Modal';
import Field, { inputClass } from '../components/common/Field';
import ActionButton from '../components/common/ActionButton';
import Toast from '../components/common/Toast';
import { PageSkeleton } from '../components/common/Skeleton';
import useStore from '../hooks/useStore';
import { orderStore, riderStore } from '../services/stores';
import { useAuth } from '../context/AuthContext';
import { formatINR, initials } from '../utils/format';
import { formatAppDate, formatAppTime, parseAppDate, sortByDateTime } from '../utils/dates';
import { maskAadhaar, maskBankAccount } from '../utils/masking';
import { enrichRiderProfile, enrichVehicleRecord, riderDocumentsFor } from '../services/profileEnrichment';
import { calculateOrderFinance } from '../services/commission';
import { fetchAdminRider, fetchRiderCod, fetchRiderEarnings, fetchRiderWallet, fetchRiderWalletLedger } from '../api/adminApi';

const DOC_STATUSES = ['Pending', 'Verified', 'Rejected'];

export default function RiderDetail() {
  const { id } = useParams();
  const { can } = useAuth();
  const riders = useStore(riderStore);
  const orders = useStore(orderStore);
  const stored = riders.find((item) => item.id === id);
  const [rider, setRider] = useState(stored || null);
  const [edit, setEdit] = useState(false);
  const [draft, setDraft] = useState(null);
  const [docView, setDocView] = useState(null);
  const [toast, setToast] = useState('');
  const [wallet, setWalletBalance] = useState(null);
  const [cod, setCod] = useState(null);
  const [pay, setPay] = useState([]);
  const [ledger, setLedger] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(null);

  useEffect(() => {
    if (!id) return undefined;
    let cancelled = false;
    setLoading(true);
    (async () => {
      try {
        const profile = await fetchAdminRider(id);
        if (cancelled) return;
        setRider(profile);
        const [walletResult, codResult, earningsResult, ledgerResult] = await Promise.allSettled([
          fetchRiderWallet(id),
          fetchRiderCod(id),
          fetchRiderEarnings(id),
          fetchRiderWalletLedger(id),
        ]);
        if (cancelled) return;
        if (walletResult.status === 'fulfilled') setWalletBalance(walletResult.value);
        else setWalletBalance(null);
        if (codResult.status === 'fulfilled') setCod(codResult.value);
        else setCod(null);
        if (earningsResult.status === 'fulfilled') setPay(earningsResult.value);
        else setPay([]);
        if (ledgerResult.status === 'fulfilled') {
          setLedger((ledgerResult.value || []).map((entry) => ({
            id: entry.wallet_ledger_id,
            date: entry.created_at,
            time: '',
            type: entry.direction === 'CREDIT' ? 'Credit' : 'Debit',
            amount: Number(entry.amount || 0),
            status: 'Success',
            method: 'Wallet',
            reference: entry.related_order_id || entry.entry_type,
          })));
        } else {
          setLedger([]);
        }
        setLoadError(null);
      } catch (error) {
        if (!cancelled) setLoadError(error);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [id]);

  const profile = useMemo(() => (rider ? enrichRiderProfile(rider) : null), [rider]);
  const vehicleRecord = useMemo(() => {
    if (!rider) return null;
    return enrichVehicleRecord({ number: rider.vehicleNumber, category: rider.vehicle, type: rider.vehicle }, rider);
  }, [rider]);
  const documents = useMemo(() => (rider ? riderDocumentsFor(rider) : []), [rider]);
  const history = useMemo(
    () => sortByDateTime(orders.filter((order) => order.riderId === id || order.rider === rider?.name)),
    [orders, id, rider?.name],
  );
  const transactions = ledger;

  if (loading) return <PageSkeleton />;
  if (loadError && !rider) {
    return <PageContainer><ErrorState title="Couldn't load rider" description={loadError.message || 'The rider API did not respond. Dummy records are not shown.'} /></PageContainer>;
  }
  if (!rider) {
    return <PageContainer><ErrorState title="Rider not found" description="This rider is not in the current directory." /></PageContainer>;
  }

  function updateDocumentStatus() {
    setToast('Document verification is not available on the server yet.');
  }

  return (
    <PageContainer className="space-y-4">
      <p className="text-sm"><Link to="/riders" className="font-semibold text-brand-600">← Riders</Link></p>
      <section className="grid gap-4 lg:grid-cols-3">
        <GlassCard className="lg:col-span-1">
          <div className="flex items-center gap-3">
            <span className="flex h-14 w-14 items-center justify-center rounded-full bg-brand-500 text-lg font-bold text-white">{initials(rider.name)}</span>
            <div>
              <h2 className="text-xl font-bold">{rider.name}</h2>
              <p className="text-sm text-ink-muted">{rider.id} · {rider.zone}</p>
            </div>
          </div>
          <dl className="mt-4 space-y-2 text-sm">
            <div className="flex justify-between"><dt className="text-ink-muted">Phone</dt><dd>{rider.phone}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-muted">Vehicle</dt><dd>{rider.vehicle}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-muted">Rating</dt><dd>{rider.rating || 'N/A'}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-muted">On-time</dt><dd>{rider.onTime != null ? `${rider.onTime}%` : 'N/A'}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-muted">Score</dt><dd>{rider.score != null ? rider.score : 'N/A'}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-muted">Earnings</dt><dd>{wallet ? formatINR(wallet.available_balance) : 'N/A'}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-muted">Wallet</dt><dd>{wallet ? formatINR(wallet.available_balance) : 'N/A'}</dd></div>
            <div className="flex justify-between"><dt className="text-ink-muted">COD Due</dt><dd>{cod ? formatINR(cod.cod_due) : 'N/A'}</dd></div>
            <StatusBadge status={rider.status} />
          </dl>
          <div className="mt-4 flex flex-wrap gap-2">
            {can('riders', 'edit') ? <Button size="sm" variant="edit" onClick={() => { setDraft(rider); setEdit(true); }}>Edit</Button> : null}
            {can('riders', 'suspend') && rider.status !== 'Suspended' ? <Button size="sm" variant="danger" onClick={() => setToast('Suspending riders from Admin is not available on the server yet.')}>Suspend</Button> : null}
            {can('riders', 'activate') && rider.status === 'Suspended' ? <Button size="sm" variant="approve" onClick={() => setToast('Activating riders from Admin is not available on the server yet.')}>Activate</Button> : null}
          </div>
        </GlassCard>
        <GlassCard className="lg:col-span-2">
          <h3 className="mb-3 text-lg font-semibold">Documents</h3>
          <ul className="grid gap-3 sm:grid-cols-2">
            {documents.map((doc) => (
              <li key={doc.key} className="flex items-center justify-between gap-3 rounded-2xl bg-white/70 px-3 py-3">
                <div className="min-w-0">
                  <p className="font-medium">{doc.label}</p>
                  <p className="truncate text-xs text-ink-muted">{doc.number}</p>
                </div>
                <div className="flex shrink-0 items-center gap-2">
                  <StatusBadge status={doc.status} />
                  <ActionButton icon={Eye} tone="view" onClick={() => setDocView(doc)}>View</ActionButton>
                </div>
              </li>
            ))}
          </ul>
        </GlassCard>
      </section>
      <section className="grid gap-4 lg:grid-cols-2">
        <GlassCard>
          <h3 className="mb-3 text-lg font-semibold">Rider KYC & Banking</h3>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between gap-3"><dt className="text-ink-muted">Driving License (DL) No.</dt><dd className="text-right font-medium">{rider.source === 'api' ? (rider.kyc || 'N/A') : profile.drivingLicenseNumber}</dd></div>
            <div className="flex justify-between gap-3"><dt className="text-ink-muted">RC No.</dt><dd className="text-right font-medium">{rider.source === 'api' ? 'N/A' : profile.rcNumber}</dd></div>
            <div className="flex justify-between gap-3"><dt className="text-ink-muted">Aadhaar</dt><dd className="text-right font-medium">{rider.source === 'api' ? 'N/A' : maskAadhaar(profile.aadhaarNumber)}</dd></div>
            <div className="flex justify-between gap-3"><dt className="text-ink-muted">PAN No.</dt><dd className="text-right font-medium">{rider.source === 'api' ? 'N/A' : profile.panNumber}</dd></div>
            <div className="flex justify-between gap-3"><dt className="text-ink-muted">Bank Account No.</dt><dd className="text-right font-medium">{rider.source === 'api' ? 'N/A' : maskBankAccount(profile.bankAccountNumber)}</dd></div>
            <div className="flex justify-between gap-3"><dt className="text-ink-muted">IFSC Code</dt><dd className="text-right font-medium">{rider.source === 'api' ? 'N/A' : profile.ifscCode}</dd></div>
          </dl>
        </GlassCard>
        <GlassCard>
          <h3 className="mb-3 text-lg font-semibold">Vehicle Information</h3>
          <dl className="space-y-2 text-sm">
            <div className="flex justify-between gap-3"><dt className="text-ink-muted">Rider Vehicle Registration Number</dt><dd className="text-right font-medium">{vehicleRecord?.rcNumber || rider.vehicleNumber || 'N/A'}</dd></div>
            <div className="flex justify-between gap-3"><dt className="text-ink-muted">Vehicle Category</dt><dd className="text-right font-medium">{rider.vehicle || vehicleRecord?.category || 'N/A'}</dd></div>
            {vehicleRecord?.brand ? <div className="flex justify-between gap-3"><dt className="text-ink-muted">Brand / Model</dt><dd className="text-right font-medium">{vehicleRecord.brand} {vehicleRecord.model}</dd></div> : null}
          </dl>
        </GlassCard>
      </section>
      <GlassCard className="overflow-hidden">
        <h3 className="mb-3 text-lg font-semibold">Delivery history</h3>
        <DataTable
          columns={[
            { key: 'id', label: 'Delivery / Order ID' },
            { key: 'customer', label: 'Customer' },
            { key: 'date', label: 'Date', render: (row) => formatAppDate(parseAppDate(row.date)) },
            { key: 'time', label: 'Time', render: (row) => formatAppTime(row.time || row.deliveredAt || row.date) },
            { key: 'status', label: 'Delivery Status', render: (row) => <StatusBadge status={row.status} /> },
            { key: 'amount', label: 'Amount', render: (row) => formatINR(row.amount) },
            { key: 'earning', label: 'Earning', render: (row) => formatINR(calculateOrderFinance(row).riderEarning) },
            { key: 'vehicle', label: 'Vehicle', hideBelow: 'lg', render: (row) => `${row.vehicle || ''} ${row.vehicleNumber || ''}`.trim() },
          ]}
          data={history}
          pageSize={10}
          compact
          itemLabel="deliveries"
          scroll
        />
      </GlassCard>
      <GlassCard className="overflow-hidden">
        <h3 className="mb-3 text-lg font-semibold">Transaction history</h3>
        <DataTable
          columns={[
            { key: 'id', label: 'Transaction ID' },
            { key: 'date', label: 'Date', render: (row) => formatAppDate(parseAppDate(row.date)) },
            { key: 'time', label: 'Time', render: (row) => formatAppTime(row.time || row.date) },
            { key: 'type', label: 'Transaction Type', render: (row) => <StatusBadge status={row.type} /> },
            { key: 'amount', label: 'Amount', render: (row) => formatINR(row.amount) },
            { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
            { key: 'method', label: 'Payment / Wallet' },
            { key: 'reference', label: 'Reference', hideBelow: 'lg' },
          ]}
          data={transactions}
          pageSize={10}
          compact
          itemLabel="transactions"
          scroll
        />
      </GlassCard>
      <section className="grid gap-4 lg:grid-cols-2">
        <GlassCard>
          <h3 className="mb-3 text-lg font-semibold">Earnings</h3>
          {pay.length ? pay.map((item) => <p key={item.id} className="rounded-2xl bg-white/70 px-3 py-3 text-sm">{item.date}: {formatINR(item.riderEarning || item.tripFare)} · {item.orders} order</p>) : <p className="text-sm text-ink-muted">No frozen earnings for this rider yet.</p>}
        </GlassCard>
        <GlassCard>
          <h3 className="mb-3 text-lg font-semibold">Performance</h3>
          <ul className="space-y-3 text-sm">
            {history.length ? history.slice(0, 8).map((item) => (
              <li key={item.id} className="flex gap-3"><span className="font-semibold text-brand-600">{item.status}</span><span>{item.id}</span></li>
            )) : <li className="text-ink-muted">No recent order activity.</li>}
          </ul>
        </GlassCard>
      </section>
      <Modal open={Boolean(docView)} title={docView?.label || 'Document'} onClose={() => setDocView(null)} footer={<Button onClick={() => setDocView(null)}>Close</Button>}>
        {docView ? (
          <div className="space-y-4">
            <div className="rounded-2xl bg-white/70 p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-soft">{docView.label}</p>
              <p className="mt-2 text-lg font-semibold">{docView.number}</p>
              <p className="mt-1 text-sm text-ink-muted">Rider: {rider.name} · {rider.id}</p>
            </div>
            <Field label="Verification status">
              <select
                className={inputClass}
                value={docView.status}
                onChange={(event) => updateDocumentStatus(docView.key, event.target.value)}
              >
                {DOC_STATUSES.map((status) => <option key={status}>{status}</option>)}
              </select>
            </Field>
            <StatusBadge status={docView.status} />
          </div>
        ) : null}
      </Modal>
      <Modal open={edit} title="Edit rider" onClose={() => setEdit(false)} footer={<><Button variant="ghost" onClick={() => setEdit(false)}>Cancel</Button><Button onClick={() => { setEdit(false); setToast('Editing riders from Admin is not available on the server yet.'); }}>Save</Button></>}>
        {draft ? (
          <div className="space-y-3">
            <Field label="Name"><input className={inputClass} value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></Field>
            <Field label="Phone"><input className={inputClass} value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} /></Field>
            <Field label="Zone"><input className={inputClass} value={draft.zone} onChange={(event) => setDraft({ ...draft, zone: event.target.value })} /></Field>
          </div>
        ) : null}
      </Modal>
      <Toast open={Boolean(toast)} message={toast} onClose={() => setToast('')} />
    </PageContainer>
  );
}
