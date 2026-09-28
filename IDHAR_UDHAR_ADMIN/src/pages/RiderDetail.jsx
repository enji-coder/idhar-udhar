import { Link, useParams } from 'react-router-dom';
import { useEffect, useMemo, useRef, useState } from 'react';
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
import { approveRiderDocument, fetchAdminRider, fetchRiderCod, fetchRiderDocumentUrl, fetchRiderDocuments, fetchRiderEarnings, fetchRiderProfilePicture, fetchRiderWallet, fetchRiderWalletLedger, rejectRiderDocument, reopenRiderVerification } from '../api/adminApi';
import { canSubmitReview, documentLabel, documentStatusLabel, documentsLockedLabel, languageLabel, rejectionIssue, verificationSourceLabel } from '../services/documentReview';

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
  const [serverDocuments, setServerDocuments] = useState([]);
  const [documentsError, setDocumentsError] = useState(null);
  const [reviewing, setReviewing] = useState(false);
  const [openingDoc, setOpeningDoc] = useState(false);
  const reviewingRef = useRef(false);
  const openingRef = useRef(false);
  const [profilePictureUrl, setProfilePictureUrl] = useState('');
  const [documentMeta, setDocumentMeta] = useState(null);
  const [reopening, setReopening] = useState(false);
  const [rejectReason, setRejectReason] = useState('');

  useEffect(() => {
    if (!id) return undefined;
    let cancelled = false;
    setLoading(true);
    (async () => {
      try {
        const profile = await fetchAdminRider(id);
        if (cancelled) return;
        setRider(profile);
        const [walletResult, codResult, earningsResult, ledgerResult, documentsResult] = await Promise.allSettled([
          fetchRiderWallet(id),
          fetchRiderCod(id),
          fetchRiderEarnings(id),
          fetchRiderWalletLedger(id),
          fetchRiderDocuments(id),
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
        if (documentsResult.status === 'fulfilled') {
          setServerDocuments(documentsResult.value?.documents || []);
          setDocumentMeta(documentsResult.value || null);
          setDocumentsError(null);
          if (documentsResult.value?.has_profile_picture) {
            try {
              const signed = await fetchRiderProfilePicture(id);
              if (!cancelled) setProfilePictureUrl(signed?.download_url || '');
            } catch {
              if (!cancelled) setProfilePictureUrl('');
            }
          } else if (!cancelled) {
            setProfilePictureUrl('');
          }
        } else {
          setServerDocuments([]);
          setDocumentsError(documentsResult.reason);
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
  const documents = useMemo(() => {
    if (rider?.source === 'api') return serverDocuments;
    return rider ? riderDocumentsFor(rider) : [];
  }, [rider, serverDocuments]);
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

  async function viewServerDocument(doc) {
    if (!canSubmitReview(openingRef.current || reviewingRef.current)) return;
    openingRef.current = true;
    setOpeningDoc(true);
    try {
      const signed = await fetchRiderDocumentUrl(doc.rider_document_id);
      if (!signed?.download_url) {
        setToast('The document link was not returned.');
        return;
      }
      window.open(signed.download_url, '_blank', 'noopener,noreferrer');
    } catch (error) {
      setToast(error.message || 'Could not open the document.');
    } finally {
      openingRef.current = false;
      setOpeningDoc(false);
    }
  }

  async function submitDocumentDecision(decision) {
    if (!docView?.rider_document_id || !canSubmitReview(reviewingRef.current)) return;
    if (decision === 'REJECTED') {
      const issue = rejectionIssue(rejectReason);
      if (issue) {
        setToast(issue);
        return;
      }
    }
    reviewingRef.current = true;
    setReviewing(true);
    try {
      const result = decision === 'APPROVED'
        ? await approveRiderDocument(docView.rider_document_id)
        : await rejectRiderDocument(docView.rider_document_id, rejectReason.trim());
      setServerDocuments((current) => current.map((row) => (
        row.rider_document_id === result.document.rider_document_id ? result.document : row
      )));
      setDocumentMeta((current) => ({
        ...(current || {}),
        approval_status: result.approval_status,
        onboarding_kyc_status: result.onboarding_kyc_status,
        documents_locked: result.approval_status === 'APPROVED',
      }));
      const profile = await fetchAdminRider(id);
      setRider(profile);
      setDocView(null);
      setRejectReason('');
      setToast(decision === 'APPROVED' ? 'Document approved.' : 'Document rejected.');
    } catch (error) {
      setToast(error.message || 'Could not save the document decision.');
    } finally {
      reviewingRef.current = false;
      setReviewing(false);
    }
  }

  async function reopenVerification() {
    if (!id || !canSubmitReview(reopening)) return;
    setReopening(true);
    try {
      const result = await reopenRiderVerification(id);
      setDocumentMeta((current) => ({
        ...(current || {}),
        approval_status: result.approval_status,
        onboarding_kyc_status: result.onboarding_kyc_status,
        documents_locked: result.documents_locked,
      }));
      const profile = await fetchAdminRider(id);
      setRider(profile);
      setToast('Rider reopened for verification.');
    } catch (error) {
      setToast(error.message || 'Could not reopen verification.');
    } finally {
      setReopening(false);
    }
  }

  return (
    <PageContainer className="space-y-4">
      <p className="text-sm"><Link to="/riders" className="font-semibold text-brand-600">← Riders</Link></p>
      <section className="grid gap-4 lg:grid-cols-3">
        <GlassCard className="lg:col-span-1">
          <div className="flex items-center gap-3">
            {profilePictureUrl ? (
              <img src={profilePictureUrl} alt="" className="h-14 w-14 rounded-full object-cover" />
            ) : (
              <span className="flex h-14 w-14 items-center justify-center rounded-full bg-brand-500 text-lg font-bold text-white">{initials(rider.name)}</span>
            )}
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
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <h3 className="text-lg font-semibold">Documents</h3>
            {rider.source === 'api' ? (
              <div className="flex flex-wrap items-center gap-2 text-sm text-ink-muted">
                <span>Approval {documentMeta?.approval_status || rider.approval || 'PENDING'} · KYC {documentMeta?.onboarding_kyc_status || rider.kyc || 'PENDING'}</span>
                <span>Language {languageLabel(documentMeta?.preferred_language)}</span>
                <span>Documents {documentsLockedLabel(Boolean(documentMeta?.documents_locked))}</span>
                {documentMeta?.documents_locked ? (
                  <Button size="sm" variant="edit" loading={reopening} disabled={reopening} onClick={reopenVerification}>Reopen for re-verification</Button>
                ) : null}
              </div>
            ) : null}
          </div>
          {rider.source === 'api' && documentsError ? (
            <p className="text-sm text-danger">{documentsError.message || 'Documents could not be loaded.'}</p>
          ) : null}
          {rider.source === 'api' && !documentsError && documents.length === 0 ? (
            <p className="text-sm text-ink-muted">No documents have been uploaded.</p>
          ) : null}
          <ul className="grid gap-3 sm:grid-cols-2">
            {rider.source === 'api'
              ? documents.map((doc) => (
                <li key={doc.rider_document_id} className="flex items-center justify-between gap-3 rounded-2xl bg-white/70 px-3 py-3">
                  <div className="min-w-0">
                    <p className="font-medium">{documentLabel(doc.document_type)}</p>
                    <p className="truncate text-xs text-ink-muted">
                      {verificationSourceLabel(doc.verification_source)} · {formatAppDate(parseAppDate(doc.created_at))} {formatAppTime(doc.created_at)}
                    </p>
                    {doc.rejection_reason ? <p className="truncate text-xs text-danger">{doc.rejection_reason}</p> : null}
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <StatusBadge status={documentStatusLabel(doc.status)} />
                    <ActionButton icon={Eye} tone="view" disabled={openingDoc || reviewing} onClick={() => { setRejectReason(''); setDocView(doc); }}>View</ActionButton>
                  </div>
                </li>
              ))
              : documents.map((doc) => (
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
      <Modal
        open={Boolean(docView)}
        title={docView?.rider_document_id ? documentLabel(docView.document_type) : (docView?.label || 'Document')}
        onClose={() => { if (!reviewing) setDocView(null); }}
        footer={docView?.rider_document_id ? (
          <>
            <Button variant="ghost" disabled={reviewing} onClick={() => setDocView(null)}>Close</Button>
            <Button variant="approve" loading={reviewing} disabled={reviewing || openingDoc} onClick={() => submitDocumentDecision('APPROVED')}>Approve</Button>
            <Button variant="reject" loading={reviewing} disabled={reviewing || openingDoc} onClick={() => submitDocumentDecision('REJECTED')}>Reject</Button>
          </>
        ) : <Button onClick={() => setDocView(null)}>Close</Button>}
      >
        {docView?.rider_document_id ? (
          <div className="space-y-4">
            <div className="rounded-2xl bg-white/70 p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-soft">{documentLabel(docView.document_type)}</p>
              <p className="mt-2 text-sm text-ink-muted">Status {documentStatusLabel(docView.status)} · {verificationSourceLabel(docView.verification_source)}</p>
              <p className="mt-1 text-sm text-ink-muted">Uploaded {formatAppDate(parseAppDate(docView.created_at))} {formatAppTime(docView.created_at)}</p>
              {docView.rejection_reason ? <p className="mt-2 text-sm text-danger">{docView.rejection_reason}</p> : null}
            </div>
            <Button variant="view" loading={openingDoc} disabled={reviewing} onClick={() => viewServerDocument(docView)}>Open document</Button>
            <Field label="Rejection reason">
              <textarea
                className={inputClass}
                rows={3}
                value={rejectReason}
                disabled={reviewing}
                onChange={(event) => setRejectReason(event.target.value)}
                placeholder="Required only when rejecting"
              />
            </Field>
          </div>
        ) : docView ? (
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
