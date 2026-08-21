import { useEffect, useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight, ChevronsUpDown } from 'lucide-react';

function pageItems(current, total) {
  if (total <= 5) return Array.from({ length: total }, (_, index) => index + 1);
  const items = [1];
  const start = Math.max(2, current - 1);
  const end = Math.min(total - 1, current + 1);
  if (start > 2) items.push('…');
  for (let page = start; page <= end; page += 1) items.push(page);
  if (end < total - 1) items.push('…');
  items.push(total);
  return items;
}

function visibleColumns(columns, mode) {
  return columns.filter((column) => {
    if (mode === 'desktop') return true;
    if (mode === 'tablet') return column.hideBelow !== 'md' && column.hideBelow !== 'lg';
    return column.mobile !== false;
  });
}

export default function DataTable({
  columns,
  data,
  pageSize = 8,
  rowKey = 'id',
  mobileTitleKey,
  compact = true,
  pageNumbers = true,
  itemLabel = '',
  mobileCard,
  scroll = false,
}) {
  const [page, setPage] = useState(1);
  const [sortKey, setSortKey] = useState(null);
  const [sortDir, setSortDir] = useState('asc');

  useEffect(() => {
    setPage(1);
  }, [data]);

  const sorted = useMemo(() => {
    if (!sortKey) return data;
    const next = [...data];
    next.sort((a, b) => {
      const left = a[sortKey];
      const right = b[sortKey];
      if (typeof left === 'number' && typeof right === 'number') {
        return sortDir === 'asc' ? left - right : right - left;
      }
      return sortDir === 'asc'
        ? String(left ?? '').localeCompare(String(right ?? ''))
        : String(right ?? '').localeCompare(String(left ?? ''));
    });
    return next;
  }, [data, sortKey, sortDir]);

  const totalPages = Math.max(1, Math.ceil(sorted.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * pageSize;
  const rows = sorted.slice(start, start + pageSize);
  const cellPad = compact ? 'px-2 py-2 sm:px-3' : 'px-3 py-3';
  const desktopCols = visibleColumns(columns, 'desktop');
  const tabletCols = visibleColumns(columns, 'tablet');

  function toggleSort(key, sortable) {
    if (!sortable) return;
    if (sortKey === key) setSortDir((dir) => (dir === 'asc' ? 'desc' : 'asc'));
    else {
      setSortKey(key);
      setSortDir('asc');
    }
    setPage(1);
  }

  function renderCell(column, row) {
    if (column.render) return column.render(row);
    return row[column.key];
  }

  function TableView({ cols, className }) {
    return (
      <div className={className}>
        <div className={scroll ? 'overflow-x-auto' : 'min-w-0'}>
        <table className={`w-full text-left text-sm ${scroll ? 'min-w-[1080px] table-auto' : 'table-fixed'}`}>
          <thead>
            <tr className="border-b border-slate-100 text-ink-soft">
              {cols.map((column) => (
                <th
                  key={column.key}
                  className={`px-2 py-2 text-[11px] font-semibold uppercase tracking-wide sm:px-3 ${column.headerClassName || ''} ${column.key === 'actions' || column.key === 'action' ? 'w-[10.5rem] xl:w-[34%]' : ''}`}
                >
                  {column.sortable ? (
                    <button type="button" onClick={() => toggleSort(column.key, true)} className="inline-flex items-center gap-1 hover:text-ink">
                      {column.label}
                      <ChevronsUpDown size={12} />
                    </button>
                  ) : (
                    column.label
                  )}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row[rowKey]} className="border-b border-slate-50 last:border-0 hover:bg-slate-50/70">
                {cols.map((column) => (
                  <td key={column.key} className={`${cellPad} align-middle text-ink ${column.key === 'actions' || column.key === 'action' ? 'overflow-visible' : ''} ${column.className || 'truncate'}`}>
                    {renderCell(column, row)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
        </div>
      </div>
    );
  }

  return (
    <div className="min-w-0">
      <TableView cols={desktopCols} className="hidden min-w-0 xl:block" />
      <TableView cols={tabletCols} className="hidden min-w-0 md:block xl:hidden" />

      <div className="space-y-3 md:hidden">
        {rows.map((row) => (
          mobileCard ? (
            <div key={row[rowKey]}>{mobileCard(row)}</div>
          ) : (
            <article key={row[rowKey]} className="rounded-2xl border border-slate-100 bg-white/80 p-4">
              {mobileTitleKey ? <p className="mb-2 font-semibold text-brand-600">{row[mobileTitleKey]}</p> : null}
              <dl className="space-y-2">
                {columns.filter((column) => column.mobile !== false && column.key !== 'actions' && column.key !== 'action' && column.key !== mobileTitleKey).slice(0, 5).map((column) => (
                  <div key={column.key} className="flex items-start justify-between gap-3 text-sm">
                    <dt className="text-ink-soft">{column.label}</dt>
                    <dd className="text-right font-medium text-ink">{renderCell(column, row)}</dd>
                  </div>
                ))}
              </dl>
              {columns.find((column) => column.key === 'actions' || column.key === 'action') ? (
                <div className="mt-3 border-t border-slate-100 pt-3">
                  {renderCell(columns.find((column) => column.key === 'actions' || column.key === 'action'), row)}
                </div>
              ) : null}
            </article>
          )
        ))}
      </div>

      <div className="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm text-ink-muted">
        <p>
          Showing {sorted.length === 0 ? 0 : start + 1}–{Math.min(start + pageSize, sorted.length)} of {sorted.length}{itemLabel ? ` ${itemLabel}` : ''}
        </p>
        <div className="flex flex-wrap items-center gap-1">
          <button type="button" disabled={currentPage === 1} onClick={() => setPage((value) => Math.max(1, value - 1))} className="rounded-xl px-2 py-1.5 hover:bg-slate-100 disabled:opacity-40" aria-label="Previous page">
            <span className="inline-flex items-center gap-1"><ChevronLeft size={16} /> <span className="hidden sm:inline">Previous</span></span>
          </button>
          {pageNumbers ? pageItems(currentPage, totalPages).map((item, index) => (
            item === '…' ? (
              <span key={`ellipsis-${index}`} className="px-1">…</span>
            ) : (
              <button key={item} type="button" onClick={() => setPage(item)} className={`min-w-8 rounded-xl px-2 py-1.5 text-sm font-semibold ${item === currentPage ? 'bg-brand-500 text-white' : 'hover:bg-slate-100'}`}>
                {item}
              </button>
            )
          )) : <span className="px-2">{currentPage} / {totalPages}</span>}
          <button type="button" disabled={currentPage === totalPages} onClick={() => setPage((value) => Math.min(totalPages, value + 1))} className="rounded-xl px-2 py-1.5 hover:bg-slate-100 disabled:opacity-40" aria-label="Next page">
            <span className="inline-flex items-center gap-1"><span className="hidden sm:inline">Next</span> <ChevronRight size={16} /></span>
          </button>
        </div>
      </div>
    </div>
  );
}
