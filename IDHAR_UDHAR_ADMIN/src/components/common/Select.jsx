export default function Select({ value, onChange, options, className = '', 'aria-label': ariaLabel }) {
  return (
    <select
      value={value}
      onChange={(event) => onChange(event.target.value)}
      aria-label={ariaLabel}
      className={`h-11 w-full min-w-0 max-w-full rounded-2xl border border-line bg-white px-3 text-sm text-ink md:w-auto ${className}`}
    >
      {options.map((option) => {
        const item = typeof option === 'string' ? { value: option, label: option } : option;
        return (
          <option key={item.value} value={item.value}>
            {item.label}
          </option>
        );
      })}
    </select>
  );
}
