import { useEffect, useMemo, useState } from 'react';
import { Search } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { commandLinks } from '../../data/navigation';
import { useAuth } from '../../context/AuthContext';
import {
  customerStore,
  invoiceStore,
  orderStore,
  riderStore,
  vehicleStore,
} from '../../services/stores';

function match(query, ...values) {
  return values.join(' ').toLowerCase().includes(query);
}

export default function CommandPalette({ open, onClose }) {
  const navigate = useNavigate();
  const { canPath } = useAuth();
  const [query, setQuery] = useState('');

  const results = useMemo(() => {
    const value = query.toLowerCase().trim();
    const pages = commandLinks.filter((item) => canPath(item.path)).filter((item) => !value || item.label.toLowerCase().includes(value)).map((item) => ({
      id: item.path,
      label: item.label,
      hint: 'Page',
      path: item.path,
      icon: item.icon,
    }));
    if (!value) return pages.slice(0, 8);

    const records = [
      ...orderStore.getAll().filter((row) => match(value, row.id, row.customer, row.rider)).slice(0, 5).map((row) => ({ id: row.id, label: row.id, hint: `Order · ${row.customer}`, path: '/orders' })),
      ...riderStore.getAll().filter((row) => match(value, row.id, row.name, row.phone)).slice(0, 5).map((row) => ({ id: row.id, label: row.name, hint: `Rider · ${row.id}`, path: `/riders/${row.id}` })),
      ...customerStore.getAll().filter((row) => match(value, row.id, row.name, row.email, row.phone)).slice(0, 5).map((row) => ({ id: row.id, label: row.name, hint: `Customer · ${row.id}`, path: `/customers/${row.id}` })),
      ...vehicleStore.getAll().filter((row) => match(value, row.id, row.number, row.type)).slice(0, 5).map((row) => ({ id: row.id, label: row.number, hint: `Vehicle · ${row.type}`, path: '/vehicles' })),
      ...invoiceStore.getAll().filter((row) => match(value, row.invoiceNumber, row.customer, row.orderId)).slice(0, 5).map((row) => ({ id: row.id, label: row.invoiceNumber, hint: `Invoice · ${row.customer}`, path: '/invoices' })),
    ];
    return [...pages.slice(0, 6), ...records].slice(0, 16);
  }, [query, canPath]);

  useEffect(() => {
    if (open) setQuery('');
  }, [open]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center p-4 pt-[12vh]">
      <button type="button" className="absolute inset-0 bg-slate-900/30" aria-label="Close search" onClick={onClose} />
      <div className="relative z-10 w-full max-w-lg glass-panel p-3">
        <label className="relative block">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-muted" />
          <input
            autoFocus
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search orders, riders, customers, vehicles, invoices..."
            className="h-12 w-full rounded-2xl border border-line bg-white pl-10 pr-4 text-sm outline-none"
          />
        </label>
        <ul className="mt-2 max-h-72 overflow-y-auto">
          {results.length === 0 ? (
            <li className="px-3 py-4 text-sm text-ink-muted">No matching records found.</li>
          ) : (
            results.map((item) => (
              <li key={`${item.path}-${item.id}`}>
                <button
                  type="button"
                  onClick={() => {
                    navigate(item.path);
                    onClose();
                  }}
                  className="flex w-full items-center justify-between gap-3 rounded-2xl px-3 py-2.5 text-left text-sm hover:bg-brand-50"
                >
                  <span className="flex items-center gap-3">
                    {item.icon ? <item.icon size={16} className="text-brand-500" /> : null}
                    {item.label}
                  </span>
                  <span className="text-xs text-ink-muted">{item.hint}</span>
                </button>
              </li>
            ))
          )}
        </ul>
      </div>
    </div>
  );
}
