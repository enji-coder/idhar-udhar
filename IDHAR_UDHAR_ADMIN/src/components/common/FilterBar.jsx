import { Search, SlidersHorizontal } from 'lucide-react';
import Button from './Button';

export default function FilterBar({
  search,
  onSearch,
  placeholder = 'Search…',
  onOpenFilters,
  children,
  trailing,
}) {
  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <label className="relative min-w-0 flex-1">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-muted" />
          <input
            value={search}
            onChange={(event) => onSearch(event.target.value)}
            placeholder={placeholder}
            className="h-11 w-full rounded-2xl border border-line bg-white pl-10 pr-3 text-sm outline-none focus:border-brand-300 focus:ring-2 focus:ring-brand-200"
          />
        </label>
        {onOpenFilters ? (
          <Button variant="secondary" icon={SlidersHorizontal} className="shrink-0 md:hidden" onClick={onOpenFilters}>
            Filters
          </Button>
        ) : null}
        {trailing}
      </div>
      {children ? (
        <div className="hidden min-w-0 flex-wrap items-center gap-2 md:flex">
          {children}
        </div>
      ) : null}
    </div>
  );
}
