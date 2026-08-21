import { Search } from 'lucide-react';

export default function SearchBar({
  value,
  onChange,
  placeholder = 'Search anything...',
}) {
  return (
    <label className="relative block min-w-0 w-full">
      <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-muted" />
      <input
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        className="h-12 w-full rounded-full border border-line bg-white pl-11 pr-4 text-sm text-ink shadow-card outline-none placeholder:text-ink-muted focus:border-brand-300 focus:ring-2 focus:ring-brand-200"
      />
    </label>
  );
}
