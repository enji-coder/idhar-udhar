import { useMemo, useState } from 'react';
import { useOutletContext } from 'react-router-dom';
import { Check, Eye, MessageSquare, Pencil, UserPlus } from 'lucide-react';
import PageContainer from '../components/layout/PageContainer';
import GlassCard from '../components/common/GlassCard';
import DataTable from '../components/common/DataTable';
import StatusBadge from '../components/common/StatusBadge';
import Button from '../components/common/Button';
import Select from '../components/common/Select';
import Drawer from '../components/common/Drawer';
import EmptyState from '../components/common/EmptyState';
import Field, { inputClass } from '../components/common/Field';
import ActionButton, { ActionGroup } from '../components/common/ActionButton';
import DetailSection, { DetailRow } from '../components/common/DetailSection';
import { TableSkeleton } from '../components/common/Skeleton';
import useMockLoader from '../hooks/useMockLoader';
import useStore from '../hooks/useStore';
import { ticketStore } from '../services/stores';
import { useAuth } from '../context/AuthContext';

export default function Support() {
  const { searchQuery } = useOutletContext() || {};
  const { can, user } = useAuth();
  const loading = useMockLoader();
  const rows = useStore(ticketStore);
  const [type, setType] = useState('All');
  const [status, setStatus] = useState('All');
  const [selected, setSelected] = useState(null);
  const [reply, setReply] = useState('');
  const [filtersOpen, setFiltersOpen] = useState(false);

  const data = useMemo(() => {
    const query = (searchQuery || '').toLowerCase();
    return rows.filter((row) => (type === 'All' || row.type === type) && (status === 'All' || row.status === status) && `${row.id} ${row.from} ${row.type}`.toLowerCase().includes(query));
  }, [rows, type, status, searchQuery]);

  if (loading) return <TableSkeleton />;

  const columns = [
    { key: 'id', label: 'Ticket ID', sortable: true, render: (row) => <span className="font-semibold text-brand-600">{row.id}</span> },
    { key: 'from', label: 'Customer', sortable: true },
    { key: 'type', label: 'Subject' },
    { key: 'priority', label: 'Priority', render: (row) => <StatusBadge status={row.priority} /> },
    { key: 'status', label: 'Status', render: (row) => <StatusBadge status={row.status} /> },
    { key: 'date', label: 'Created', hideBelow: 'lg' },
    {
      key: 'actions',
      label: 'Actions',
      className: 'overflow-visible',
      render: (row) => (
        <ActionGroup>
          <ActionButton icon={Eye} tone="view" onClick={() => setSelected(row)}>View</ActionButton>
          {can('support', 'reply') ? <ActionButton icon={Pencil} tone="edit" onClick={() => setSelected(row)}>Update</ActionButton> : null}
          {can('support', 'resolve') && row.status !== 'Resolved' && row.status !== 'Closed' ? <ActionButton icon={Check} tone="approve" onClick={() => ticketStore.patch(row.id, { status: 'Resolved' })}>Resolve</ActionButton> : null}
        </ActionGroup>
      ),
    },
  ];

  return (
    <PageContainer className="space-y-4">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
        {['Open', 'In Progress', 'Waiting', 'Resolved', 'Closed'].map((item) => (
          <GlassCard key={item} className="py-4">
            <p className="text-xs text-ink-muted">{item}</p>
            <p className="text-xl font-bold sm:text-2xl">{rows.filter((row) => row.status === item).length}</p>
          </GlassCard>
        ))}
      </div>
      <GlassCard className="flex flex-wrap items-end gap-3 overflow-hidden">
        <div className="hidden min-w-0 flex-wrap items-center gap-2 md:flex">
          <Select aria-label="Type" value={type} onChange={setType} options={['All', 'Customer Complaint', 'Rider Complaint', 'Delivery Dispute', 'Payment Dispute']} />
          <Select aria-label="Status" value={status} onChange={setStatus} options={['All', 'Open', 'In Progress', 'Waiting', 'Resolved', 'Closed']} />
        </div>
        <Button variant="secondary" className="md:hidden" onClick={() => setFiltersOpen(true)}>Filters</Button>
      </GlassCard>
      <GlassCard className="overflow-hidden">
        {data.length === 0 ? (
          <EmptyState title="No tickets found" description="Try changing your filters or search criteria." action={<Button variant="secondary" onClick={() => { setType('All'); setStatus('All'); }}>Clear Filters</Button>} />
        ) : (
          <DataTable columns={columns} data={data} mobileTitleKey="id" pageSize={8} compact itemLabel="tickets" />
        )}
      </GlassCard>
      <Drawer
        open={filtersOpen}
        title="Filters"
        onClose={() => setFiltersOpen(false)}
        footer={<Button onClick={() => setFiltersOpen(false)}>Done</Button>}
      >
        <div className="space-y-3">
          <Field label="Type">
            <Select aria-label="Type" value={type} onChange={setType} options={['All', 'Customer Complaint', 'Rider Complaint', 'Delivery Dispute', 'Payment Dispute']} />
          </Field>
          <Field label="Status">
            <Select aria-label="Status" value={status} onChange={setStatus} options={['All', 'Open', 'In Progress', 'Waiting', 'Resolved', 'Closed']} />
          </Field>
        </div>
      </Drawer>
      <Drawer
        open={Boolean(selected)}
        size="lg"
        eyebrow="Support ticket"
        title={selected?.id}
        subtitle={selected?.type}
        onClose={() => { setSelected(null); setReply(''); }}
        footer={
          selected && can('support', 'resolve') ? (
            <>
              {can('support', 'assign') ? <Button variant="secondary" icon={UserPlus} onClick={() => { ticketStore.patch(selected.id, { assignee: user.name, status: 'In Progress' }); setSelected({ ...selected, assignee: user.name, status: 'In Progress' }); }}>Assign me</Button> : null}
              <Button variant="approve" onClick={() => { ticketStore.patch(selected.id, { status: 'Resolved' }); setSelected(null); }}>Resolve</Button>
              <Button variant="view" onClick={() => { ticketStore.patch(selected.id, { status: 'Closed' }); setSelected(null); }}>Close</Button>
            </>
          ) : null
        }
      >
        {selected ? (
          <div className="space-y-4">
            <DetailSection title="Ticket">
              <DetailRow label="Customer" value={selected.from} />
              <DetailRow label="Subject" value={selected.type} />
              <DetailRow label="Priority" value={selected.priority} />
              <DetailRow label="Status" value={selected.status} />
              <DetailRow label="Created" value={selected.date} />
              <DetailRow label="Assignee" value={selected.assignee || 'Unassigned'} />
            </DetailSection>
            <DetailSection title="Conversation">
              {(selected.replies || []).length === 0 ? (
                <p className="text-sm text-ink-muted">No replies yet.</p>
              ) : (
                <div className="space-y-2">
                  {(selected.replies || []).map((item, index) => (
                    <p key={index} className="rounded-2xl bg-brand-50 px-3 py-2 text-sm">{item}</p>
                  ))}
                </div>
              )}
            </DetailSection>
            {can('support', 'reply') ? (
              <Field label="Reply">
                <textarea className={`${inputClass} h-24 py-2`} value={reply} onChange={(event) => setReply(event.target.value)} />
                <Button className="mt-2" icon={MessageSquare} onClick={() => {
                  if (!reply.trim()) return;
                  const next = [...(selected.replies || []), `${user.name}: ${reply}`];
                  ticketStore.patch(selected.id, { replies: next, status: 'Waiting' });
                  setSelected({ ...selected, replies: next, status: 'Waiting' });
                  setReply('');
                }}>Reply</Button>
              </Field>
            ) : null}
          </div>
        ) : null}
      </Drawer>
    </PageContainer>
  );
}
