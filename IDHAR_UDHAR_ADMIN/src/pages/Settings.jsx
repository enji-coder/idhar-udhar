import { useEffect, useState } from 'react';
import { Pencil, Pause, Play, ArrowDown, Wallet, Building2, Wrench, BadgePercent } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import Tabs from '../components/common/Tabs';
import Button from '../components/common/Button';
import StatusBadge from '../components/common/StatusBadge';
import Toast from '../components/common/Toast';
import Field, { inputClass } from '../components/common/Field';
import Modal from '../components/common/Modal';
import DataTable from '../components/common/DataTable';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import { PageSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import { useAuth } from '../context/AuthContext';
import { adminUserStore } from '../services/adminUsers';
import { MODULES, ROLES, defaultModulesForRole } from '../config/permissions';
import { recordAudit } from '../services/auditService';
import { nextId } from '../utils/ids';
import { compactErrors, isEmail, required } from '../utils/validation';
import {
  PAYMENT_DEFAULTS,
  calculateDistribution,
  normalizePaymentSettings,
  notifyPaymentSettings,
  round2,
} from '../services/commission';
import { formatINRExact } from '../utils/format';
import {
  CANCELLATION_STAGES,
  defaultCancellationConfig,
  loadCancellationConfig,
  saveCancellationConfig,
  validateCancellationConfig,
} from '../services/cancellationRules';
import { loadCompanyOffice, saveCompanyOffice } from '../services/companyOfficeStore';
import { COD_SUSPEND_THRESHOLD } from '../services/codWallet';

const tabs = [
  { value: 'general', label: 'General Settings' },
  { value: 'office', label: 'Company Office' },
  { value: 'cancellation', label: 'Cancellation' },
  { value: 'notifications', label: 'Notification Settings' },
  { value: 'payments', label: 'Payment Settings' },
  { value: 'security', label: 'Security' },
  { value: 'admins', label: 'Admins & Access' },
];

const SETTINGS_KEY = 'iu_admin_settings';

const defaults = {
  company: 'IDHAR UDHAR Logistics Pvt. Ltd.',
  city: 'Ahmedabad, Gujarat',
  email: 'support@idharudhar.in',
  emailAlerts: true,
  smsAlerts: true,
  pushAlerts: true,
  upi: true,
  cash: true,
  wallet: true,
  card: true,
  riderSharePercent: PAYMENT_DEFAULTS.riderSharePercent,
  companyCommissionPercent: PAYMENT_DEFAULTS.companyCommissionPercent,
  operationalCostPercent: PAYMENT_DEFAULTS.operationalCostPercent,
  twoFactor: true,
  expiryWindow: '30',
};

function loadSettings() {
  try {
    const stored = JSON.parse(localStorage.getItem(SETTINGS_KEY) || '{}');
    return { ...defaults, ...stored, ...normalizePaymentSettings({
      riderSharePercent: stored.riderSharePercent ?? (stored.riderRate != null ? Number(stored.riderRate) * 100 : undefined),
      companyCommissionPercent: stored.companyCommissionPercent,
      operationalCostPercent: stored.operationalCostPercent,
    }) };
  } catch {
    return defaults;
  }
}

const emptyAdmin = {
  id: '',
  name: '',
  email: '',
  password: '',
  role: ROLES.SUB_ADMIN,
  status: 'Active',
  financeAccess: false,
  payoutApprove: false,
  modules: defaultModulesForRole(ROLES.SUB_ADMIN),
};

function PaymentExplanation({ settings }) {
  const example = calculateDistribution(100, settings);
  const steps = [
        { icon: Wallet, title: 'Trip Fare', percent: null, amount: example.totalAmount, note: '85/15 uses trip fare, not discounted payable' },
    { icon: BadgePercent, title: 'Rider receives', percent: example.riderPercentage, amount: example.riderAmount, note: 'Always paid from the ride amount' },
    { icon: Building2, title: 'Company Commission', percent: example.companyCommissionPercentage, amount: example.companyCommission, note: 'Remaining share after rider payout' },
  ];
  const split = [
    { icon: Wrench, title: 'Operational Cost', percent: example.operationalCostPercentage, amount: example.operationalCost, note: 'Taken from company commission only' },
    { icon: Building2, title: 'Actual Company Profit', percent: example.actualProfitPercentage, amount: example.actualProfit, note: 'Remaining company commission' },
  ];

  return (
    <GlassCard className="space-y-4">
      <div>
        <h2 className="text-lg font-semibold">How Your Payment Distribution Works</h2>
        <p className="mt-1 text-sm text-ink-muted">This example uses ₹100 and updates instantly when you change the percentages above.</p>
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        {steps.map((step, index) => (
          <div key={step.title} className="relative rounded-2xl bg-white/70 p-4">
            {index > 0 ? <ArrowDown size={16} className="absolute -top-3 left-4 text-brand-400 sm:hidden" /> : null}
            <div className="flex h-9 w-9 items-center justify-center rounded-2xl bg-brand-50 text-brand-600">
              <step.icon size={18} />
            </div>
            <p className="mt-3 text-sm font-semibold">{step.title}</p>
            {step.percent != null ? <p className="text-xs text-ink-muted">{step.percent}%</p> : null}
            <p className="mt-1 text-xl font-bold">{formatINRExact(step.amount)}</p>
            <p className="mt-1 text-xs text-ink-soft">{step.note}</p>
          </div>
        ))}
      </div>
      <div>
        <p className="mb-2 text-sm font-semibold">Company Commission Distribution</p>
        <div className="h-3 overflow-hidden rounded-full bg-slate-100">
          <div className="flex h-full">
            <div className="bg-amber-400" style={{ width: `${example.operationalCostPercentage}%` }} />
            <div className="bg-brand-500" style={{ width: `${example.actualProfitPercentage}%` }} />
          </div>
        </div>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          {split.map((step) => (
            <div key={step.title} className="rounded-2xl bg-white/70 p-4">
              <div className="flex h-9 w-9 items-center justify-center rounded-2xl bg-brand-50 text-brand-600">
                <step.icon size={18} />
              </div>
              <p className="mt-3 text-sm font-semibold">{step.title}</p>
              <p className="text-xs text-ink-muted">{step.percent}% of company commission</p>
              <p className="mt-1 text-xl font-bold">{formatINRExact(step.amount)}</p>
              <p className="mt-1 text-xs text-ink-soft">{step.note}</p>
            </div>
          ))}
        </div>
      </div>
    </GlassCard>
  );
}

export default function Settings() {
  const loading = useMockLoader();
  const { user } = useAuth();
  const admins = useStore(adminUserStore);
  const [tab, setTab] = useState('general');
  const [form, setForm] = useState(defaults);
  const [office, setOffice] = useState(loadCompanyOffice);
  const [cancellation, setCancellation] = useState(defaultCancellationConfig);
  const [cancelErrors, setCancelErrors] = useState([]);
  const [toast, setToast] = useState('');
  const [editor, setEditor] = useState(null);
  const [errors, setErrors] = useState({});
  const [payErrors, setPayErrors] = useState({});

  useEffect(() => {
    setForm(loadSettings());
    setOffice(loadCompanyOffice());
    setCancellation(loadCancellationConfig());
  }, []);

  function save() {
    const finance = normalizePaymentSettings(form);
    const issues = {};
    if (round2(finance.riderSharePercent + finance.companyCommissionPercent) !== 100) {
      issues.share = 'Rider Share and Company Commission must add up to 100%.';
    }
    if (finance.operationalCostPercent > 100) {
      issues.opex = 'Operational Cost cannot exceed 100%.';
    }
    const cancelIssues = validateCancellationConfig(cancellation);
    setPayErrors(issues);
    setCancelErrors(cancelIssues);
    if (Object.keys(issues).length) return;
    if (cancelIssues.length) {
      setTab('cancellation');
      return;
    }
    const next = { ...form, ...finance };
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(next));
    setForm(next);
    saveCompanyOffice(office);
    saveCancellationConfig(cancellation);
    notifyPaymentSettings();
    setToast('Settings saved.');
    recordAudit({ user, action: 'Update', module: 'Settings', newValue: 'General settings saved' });
  }

  function setRiderShare(value) {
    const riderSharePercent = round2(Math.min(100, Math.max(0, Number(value) || 0)));
    setForm({
      ...form,
      riderSharePercent,
      companyCommissionPercent: round2(100 - riderSharePercent),
    });
    setPayErrors({});
  }

  function setCompanyCommission(value) {
    const companyCommissionPercent = round2(Math.min(100, Math.max(0, Number(value) || 0)));
    setForm({
      ...form,
      companyCommissionPercent,
      riderSharePercent: round2(100 - companyCommissionPercent),
    });
    setPayErrors({});
  }

  function setOperationalCost(value) {
    const operationalCostPercent = round2(Math.min(100, Math.max(0, Number(value) || 0)));
    setForm({ ...form, operationalCostPercent });
    setPayErrors({});
  }

  function saveAdmin() {
    const issues = compactErrors({
      name: required(editor.name, 'Name is required.'),
      email: required(editor.email, 'Email is required.') || (isEmail(editor.email) ? '' : 'Enter a valid email.'),
    });
    const duplicate = admins.some((item) => item.email.toLowerCase() === editor.email.trim().toLowerCase() && item.id !== editor.id);
    if (duplicate) issues.email = 'An admin with this email already exists.';
    setErrors(issues);
    if (Object.keys(issues).length) return;
    const id = editor.id || nextId('ADM', admins);
    const previous = admins.find((item) => item.id === id);
    const next = {
      ...editor,
      id,
      initials: editor.name.split(' ').filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase(),
      city: 'Ahmedabad',
      modules: editor.role === ROLES.SUPER_ADMIN ? MODULES.map((item) => item.key) : editor.modules,
      financeAccess: editor.role === ROLES.SUPER_ADMIN ? true : Boolean(editor.financeAccess),
    };
    adminUserStore.upsert(next);
    recordAudit({
      user,
      action: previous ? 'Update' : 'Create',
      module: 'Settings',
      recordId: id,
      previousValue: previous ? JSON.stringify({ modules: previous.modules, financeAccess: previous.financeAccess, status: previous.status }) : '',
      newValue: JSON.stringify({ modules: next.modules, financeAccess: next.financeAccess, status: next.status }),
    });
    if (previous && previous.financeAccess !== next.financeAccess) {
      recordAudit({ user, action: 'Finance Access Change', module: 'Finance', recordId: id, previousValue: String(previous.financeAccess), newValue: String(next.financeAccess) });
    }
    if (previous && JSON.stringify(previous.modules) !== JSON.stringify(next.modules)) {
      recordAudit({ user, action: 'Permission Change', module: 'Settings', recordId: id });
    }
    setToast(previous ? 'Admin updated.' : 'Sub-admin created.');
    setEditor(null);
  }

  if (loading) return <PageSkeleton />;

  const visibleTabs = user?.role === ROLES.SUPER_ADMIN ? tabs : tabs.filter((item) => item.value !== 'admins');

  return (
    <PageContainer className="space-y-4">
      <Tabs tabs={visibleTabs} value={tab} onChange={setTab} />

      {tab === 'general' ? (
        <GlassCard className="space-y-3">
          <h2 className="text-lg font-semibold">Company information</h2>
          <Field label="Company name"><input className={inputClass} value={form.company} onChange={(event) => setForm({ ...form, company: event.target.value })} /></Field>
          <Field label="City"><input className={inputClass} value={form.city} onChange={(event) => setForm({ ...form, city: event.target.value })} /></Field>
          <Field label="Support email"><input className={inputClass} value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} /></Field>
          <Field label="Document expiry alert (days)"><input className={inputClass} value={form.expiryWindow} onChange={(event) => setForm({ ...form, expiryWindow: event.target.value })} /></Field>
        </GlassCard>
      ) : null}

      {tab === 'office' ? (
        <GlassCard className="space-y-3">
          <h2 className="text-lg font-semibold">Company office location</h2>
          <p className="text-sm text-ink-muted">Used for failed-delivery handover and resend pickup. Not a hardcoded placeholder after you save.</p>
          <Field label="Office name"><input className={inputClass} value={office.name || ''} onChange={(event) => setOffice({ ...office, name: event.target.value })} /></Field>
          <Field label="Address"><input className={inputClass} value={office.address || ''} onChange={(event) => setOffice({ ...office, address: event.target.value })} /></Field>
          <Field label="City"><input className={inputClass} value={office.city || ''} onChange={(event) => setOffice({ ...office, city: event.target.value })} /></Field>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Latitude"><input type="number" step="0.0001" className={inputClass} value={office.latitude ?? ''} onChange={(event) => setOffice({ ...office, latitude: event.target.value })} /></Field>
            <Field label="Longitude"><input type="number" step="0.0001" className={inputClass} value={office.longitude ?? ''} onChange={(event) => setOffice({ ...office, longitude: event.target.value })} /></Field>
          </div>
        </GlassCard>
      ) : null}

      {tab === 'cancellation' ? (
        <div className="space-y-4">
          <p className="text-sm text-ink-muted">Customer and rider rules are separate. Default fee is ₹0 until you enable a charge. Rider % + Company % must equal 100% on every row.</p>
          {cancelErrors.map((item) => (
            <p key={item} className="text-sm text-red-600">{item}</p>
          ))}
          {['customer', 'rider'].map((actor) => (
            <GlassCard key={actor} className="space-y-3">
              <h2 className="text-lg font-semibold">{actor === 'customer' ? 'Customer cancellation' : 'Rider cancellation'}</h2>
              {CANCELLATION_STAGES.map((stage) => {
                const rule = cancellation[actor][stage.id];
                return (
                  <div key={stage.id} className="rounded-2xl bg-white/70 p-3 space-y-2">
                    <label className="flex items-center justify-between text-sm font-medium">
                      {stage.label}
                      <input
                        type="checkbox"
                        checked={Boolean(rule.enabled)}
                        onChange={(event) => setCancellation({
                          ...cancellation,
                          [actor]: {
                            ...cancellation[actor],
                            [stage.id]: { ...rule, enabled: event.target.checked },
                          },
                        })}
                      />
                    </label>
                    <div className="grid gap-2 sm:grid-cols-3">
                      <Field label="Charge (₹)">
                        <input type="number" min="0" className={inputClass} value={rule.fee} onChange={(event) => setCancellation({
                          ...cancellation,
                          [actor]: { ...cancellation[actor], [stage.id]: { ...rule, fee: event.target.value } },
                        })} />
                      </Field>
                      <Field label="Rider %">
                        <input type="number" min="0" max="100" className={inputClass} value={rule.riderSharePercent} onChange={(event) => {
                          const riderSharePercent = round2(Math.min(100, Math.max(0, Number(event.target.value) || 0)));
                          setCancellation({
                            ...cancellation,
                            [actor]: {
                              ...cancellation[actor],
                              [stage.id]: { ...rule, riderSharePercent, companySharePercent: round2(100 - riderSharePercent) },
                            },
                          });
                        }} />
                      </Field>
                      <Field label="Company %">
                        <input type="number" min="0" max="100" className={inputClass} value={rule.companySharePercent} onChange={(event) => {
                          const companySharePercent = round2(Math.min(100, Math.max(0, Number(event.target.value) || 0)));
                          setCancellation({
                            ...cancellation,
                            [actor]: {
                              ...cancellation[actor],
                              [stage.id]: { ...rule, companySharePercent, riderSharePercent: round2(100 - companySharePercent) },
                            },
                          });
                        }} />
                      </Field>
                    </div>
                  </div>
                );
              })}
            </GlassCard>
          ))}
        </div>
      ) : null}

      {tab === 'notifications' ? (
        <GlassCard className="space-y-3 text-sm">
          <h2 className="text-lg font-semibold">Notification preferences</h2>
          {[['emailAlerts', 'Email alerts'], ['smsAlerts', 'SMS alerts'], ['pushAlerts', 'Push notifications']].map(([key, label]) => (
            <label key={key} className="flex items-center justify-between rounded-2xl bg-white/70 px-3 py-3">
              {label}
              <input type="checkbox" checked={form[key]} onChange={(event) => setForm({ ...form, [key]: event.target.checked })} className="h-4 w-4" />
            </label>
          ))}
        </GlassCard>
      ) : null}

      {tab === 'payments' ? (
        <>
          <GlassCard className="space-y-3 text-sm">
            <h2 className="text-lg font-semibold">Accepted methods</h2>
            {[['upi', 'UPI'], ['cash', 'Cash'], ['wallet', 'Wallet'], ['card', 'Card']].map(([key, label]) => (
              <label key={key} className="flex items-center justify-between rounded-2xl bg-white/70 px-3 py-3">
                {label}
                <input type="checkbox" checked={form[key]} onChange={(event) => setForm({ ...form, [key]: event.target.checked })} className="h-4 w-4" />
              </label>
            ))}
          </GlassCard>

          <GlassCard className="space-y-4">
            <h2 className="text-lg font-semibold">Payment distribution</h2>
            <p className="text-sm text-ink-muted">85/15 is calculated on confirmed Trip Fare, not on the discounted amount the customer pays. COD Due is tracked separately from the rider earning wallet (never as a negative balance). A rider is suspended when COD Due is ₹{COD_SUSPEND_THRESHOLD} or more.</p>
            <div className="grid gap-3 sm:grid-cols-3">
              <Field label="Rider Share (%)" error={payErrors.share}>
                <input type="number" min="0" max="100" step="0.01" className={inputClass} value={form.riderSharePercent ?? 85} onChange={(event) => setRiderShare(event.target.value)} />
              </Field>
              <Field label="Company Commission (%)" error={payErrors.share}>
                <input type="number" min="0" max="100" step="0.01" className={inputClass} value={form.companyCommissionPercent ?? 15} onChange={(event) => setCompanyCommission(event.target.value)} />
              </Field>
              <Field label="Operational Cost (% of Company Commission)" error={payErrors.opex}>
                <input type="number" min="0" max="100" step="0.01" className={inputClass} value={form.operationalCostPercent ?? 50} onChange={(event) => setOperationalCost(event.target.value)} />
              </Field>
            </div>
            <div className="rounded-2xl bg-white/70 px-3 py-3 text-sm">
              <p className="text-ink-muted">Actual Profit of Company Commission</p>
              <p className="font-semibold">{round2(100 - Number(form.operationalCostPercent || 0))}%</p>
            </div>
          </GlassCard>

          <PaymentExplanation settings={normalizePaymentSettings(form)} />
        </>
      ) : null}

      {tab === 'security' ? (
        <GlassCard className="space-y-3">
          <h2 className="text-lg font-semibold">Security</h2>
          <label className="flex items-center justify-between rounded-2xl bg-white/70 px-3 py-3 text-sm">
            Two-factor authentication
            <input type="checkbox" checked={form.twoFactor} onChange={(event) => setForm({ ...form, twoFactor: event.target.checked })} />
          </label>
          <p className="text-sm text-ink-muted">2 active sessions · Ahmedabad HQ and remote ops.</p>
          <ul className="space-y-3">
            {admins.map((item) => (
              <li key={item.email} className="flex min-w-0 flex-wrap items-center justify-between gap-2 rounded-2xl bg-white/70 px-3 py-3">
                <div>
                  <p className="font-semibold">{item.name}</p>
                  <p className="text-xs text-ink-muted">{item.email}</p>
                </div>
                <StatusBadge status={item.role} />
              </li>
            ))}
          </ul>
        </GlassCard>
      ) : null}

      {tab === 'admins' && user?.role === ROLES.SUPER_ADMIN ? (
        <GlassCard className="overflow-hidden">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
            <h2 className="text-lg font-semibold">Admin users</h2>
            <Button onClick={() => { setErrors({}); setEditor({ ...emptyAdmin }); }}>Create sub-admin</Button>
          </div>
          <DataTable
            columns={[
              { key: 'name', label: 'Name', sortable: true, render: (row) => <div><p className="font-semibold">{row.name}</p><p className="text-xs text-ink-muted">{row.email}</p></div> },
              { key: 'role', label: 'Role', render: (row) => <StatusBadge status={row.role} /> },
              { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
              { key: 'financeAccess', label: 'Finance', render: (row) => row.financeAccess ? 'Show' : 'Hide' },
              { key: 'modules', label: 'Modules', hideBelow: 'lg', render: (row) => (row.modules || []).length },
              {
                key: 'actions',
                label: 'Actions',
                className: 'overflow-visible',
                render: (row) => (
                  <ActionGroup>
                    <ActionButton icon={Pencil} tone="edit" onClick={() => { setErrors({}); setEditor({ ...emptyAdmin, ...row, modules: row.modules || [] }); }}>Edit</ActionButton>
                    {row.role !== ROLES.SUPER_ADMIN ? (
                      <ActionButton icon={row.status === 'Active' ? Pause : Play} tone={row.status === 'Active' ? 'danger' : 'approve'} onClick={() => {
                        const next = row.status === 'Active' ? 'Inactive' : 'Active';
                        adminUserStore.patch(row.id, { status: next });
                        recordAudit({ user, action: 'Update', module: 'Settings', recordId: row.id, previousValue: row.status, newValue: next });
                        setToast(`Admin ${next === 'Active' ? 'activated' : 'deactivated'}.`);
                      }}>{row.status === 'Active' ? 'Deactivate' : 'Activate'}</ActionButton>
                    ) : null}
                  </ActionGroup>
                ),
              },
            ]}
            data={admins}
            pageSize={8}
            compact
            itemLabel="admins"
          />
        </GlassCard>
      ) : null}

      {tab !== 'admins' ? <Button onClick={save}>Save settings</Button> : null}
      <Toast open={Boolean(toast)} message={toast} onClose={() => setToast('')} />

      <Modal
        open={Boolean(editor)}
        title={editor?.id ? 'Edit admin' : 'Create sub-admin'}
        size="lg"
        onClose={() => setEditor(null)}
        footer={<><Button variant="ghost" onClick={() => setEditor(null)}>Cancel</Button><Button onClick={saveAdmin}>Save</Button></>}
      >
        {editor ? (
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Name" error={errors.name}><input className={inputClass} value={editor.name} onChange={(event) => setEditor({ ...editor, name: event.target.value })} /></Field>
            <Field label="Email" error={errors.email}><input className={inputClass} value={editor.email} onChange={(event) => setEditor({ ...editor, email: event.target.value })} /></Field>
            <Field label="Role">
              <select className={inputClass} value={editor.role} onChange={(event) => setEditor({ ...editor, role: event.target.value, modules: defaultModulesForRole(event.target.value), financeAccess: event.target.value === ROLES.FINANCE || event.target.value === ROLES.SUPER_ADMIN })}>
                {Object.values(ROLES).map((role) => <option key={role}>{role}</option>)}
              </select>
            </Field>
            <Field label="Status">
              <select className={inputClass} value={editor.status} onChange={(event) => setEditor({ ...editor, status: event.target.value })}>
                <option>Active</option>
                <option>Inactive</option>
              </select>
            </Field>
            {editor.role === ROLES.SUB_ADMIN ? (
              <Field label="Password"><input className={inputClass} type="text" value={editor.password || ''} onChange={(event) => setEditor({ ...editor, password: event.target.value })} placeholder="Local sign-in password" /></Field>
            ) : null}
            <label className="flex items-center justify-between rounded-2xl bg-white/70 px-3 py-3 text-sm sm:col-span-2">
              Show Finance
              <input type="checkbox" checked={Boolean(editor.financeAccess)} onChange={(event) => setEditor({ ...editor, financeAccess: event.target.checked, modules: event.target.checked ? [...new Set([...(editor.modules || []), 'finance', 'payments', 'invoices'])] : (editor.modules || []).filter((key) => key !== 'finance') })} />
            </label>
            <label className="flex items-center justify-between rounded-2xl bg-white/70 px-3 py-3 text-sm sm:col-span-2">
              Allow payout approval
              <input type="checkbox" checked={Boolean(editor.payoutApprove)} onChange={(event) => setEditor({ ...editor, payoutApprove: event.target.checked })} />
            </label>
            <div className="sm:col-span-2">
              <p className="mb-2 text-sm font-medium">Module permissions</p>
              <div className="grid gap-2 sm:grid-cols-2">
                {MODULES.map((item) => (
                  <label key={item.key} className="flex items-center justify-between rounded-2xl bg-white/70 px-3 py-2 text-sm">
                    {item.label}
                    <input
                      type="checkbox"
                      checked={(editor.modules || []).includes(item.key)}
                      onChange={(event) => {
                        const modules = event.target.checked
                          ? [...new Set([...(editor.modules || []), item.key])]
                          : (editor.modules || []).filter((key) => key !== item.key);
                        setEditor({ ...editor, modules, financeAccess: item.key === 'finance' ? event.target.checked : editor.financeAccess });
                      }}
                    />
                  </label>
                ))}
              </div>
            </div>
          </div>
        ) : null}
      </Modal>
    </PageContainer>
  );
}
