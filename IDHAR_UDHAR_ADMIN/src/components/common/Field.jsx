export default function Field({ label, error, children }) {
  return (
    <label className="block text-sm">
      <span className="font-medium text-ink">{label}</span>
      <div className="mt-1">{children}</div>
      {error ? <span className="mt-1 block text-xs text-danger">{error}</span> : null}
    </label>
  );
}

export const inputClass = 'h-11 w-full rounded-2xl border border-line bg-white px-3 text-sm text-ink outline-none focus:border-brand-300 focus:ring-2 focus:ring-brand-200';
