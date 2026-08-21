import { useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Check, Eye, X } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Modal from '../components/common/Modal';
import Drawer from '../components/common/Drawer';
import EmptyState from '../components/common/EmptyState';
import Tabs from '../components/common/Tabs';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import { useAuth } from '../context/AuthContext';
import { verifications as seed } from '../data/mockData';

const tabs = [
  { value: 'All', label: 'All' },
  { value: 'Pending', label: 'Pending' },
  { value: 'Approved', label: 'Approved' },
  { value: 'Rejected', label: 'Rejected' },
  { value: 'Correction', label: 'Expiring / Correction' },
];

export default function Verification() {
  const { searchQuery } = useOutletContext() || {};
  const { can } = useAuth();
  const loading = useMockLoader();
  const [rows, setRows] = useState(seed);
  const [tab, setTab] = useState('All');
  const [selected, setSelected] = useState(null);
  const [view, setView] = useState(null);
  const [action, setAction] = useState(null);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => {
      const matchesTab = tab === 'All' || row.status === tab;
      return matchesTab && `${row.name} ${row.id}`.toLowerCase().includes(query);
    });
  }, [rows, tab, searchQuery]);

  if (loading) return <TableSkeleton />;

  function apply(status) {
    setRows((current) => current.map((row) => (row.id === selected.id ? { ...row, status } : row)));
    setSelected(null);
    setAction(null);
  }

  const columns = [
    { key: 'name', label: 'Rider', sortable: true, render: (row) => <div><p className="font-semibold">{row.name}</p><p className="text-xs text-ink-muted">{row.id}</p></div> },
    { key: 'identity', label: 'Document Type', render: () => 'KYC pack' },
    { key: 'photo', label: 'Submitted', render: (row) => row.photo || 'Submitted' },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => setView(row)}>View</ActionButton>
          {can('riders', 'approve') ? <ActionButton icon={Check} tone="approve" onClick={() => { setSelected(row); setAction('Approved'); }}>Approve</ActionButton> : null}
          {can('riders', 'reject') ? <ActionButton icon={X} tone="danger" onClick={() => { setSelected(row); setAction('Rejected'); }}>Reject</ActionButton> : null}
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4 pb-8">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {['Pending', 'Approved', 'Rejected', 'Correction'].map((status) => (
          <GlassCard key={status} className="py-4">
            <p className="text-xs text-ink-muted">{status === 'Correction' ? 'Expiring docs' : status}</p>
            <p className="text-2xl font-bold">{rows.filter((row) => row.status === status).length}</p>
          </GlassCard>
        ))}
      </div>
      <Tabs tabs={tabs} value={tab} onChange={setTab} />
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState title="No applications" description="Nothing matches this verification queue." />
        ) : (
          <DataTable columns={columns} data={data} mobileTitleKey="name" pageSize={8} itemLabel="applications" compact />
        )}
      </GlassCard>
      <Drawer open={Boolean(view)} size="lg" eyebrow="Verification" title={view?.name} subtitle={view?.id} onClose={() => setView(null)} footer={<Button onClick={() => setView(null)}>Close</Button>}>
        {view ? (
          <DetailSection title="Documents">
            <DetailRow label="Identity" value={view.identity} />
            <DetailRow label="Licence" value={view.licence} />
            <DetailRow label="Vehicle RC" value={view.rc} />
            <DetailRow label="Insurance" value={view.insurance} />
            <DetailRow label="Photo" value={view.photo} />
            <DetailRow label="Status" value={view.status} />
          </DetailSection>
        ) : null}
      </Drawer>
      <Modal
        open={Boolean(selected)}
        title={`${action} ${selected?.name}?`}
        onClose={() => setSelected(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setSelected(null)}>Back</Button>
            <Button onClick={() => apply(action)}>Confirm</Button>
          </>
        }
      >
        <p className="text-sm text-ink-muted">This updates the mock verification queue only.</p>
      </Modal>
    </PageContainer>
  );
}
