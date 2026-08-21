export default function Tabs({ tabs, value, onChange }) {
  return (
    <div className="max-w-full overflow-x-auto">
      <div className="inline-flex min-w-max gap-1 rounded-full bg-white/70 p-1 shadow-card">
        {tabs.map((tab) => (
          <button
            key={tab.value}
            type="button"
            onClick={() => onChange(tab.value)}
            className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-semibold transition sm:px-4 sm:py-2 sm:text-sm ${
              value === tab.value ? 'bg-brand-500 text-white shadow-floating' : 'text-ink-muted hover:bg-brand-50'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>
    </div>
  );
}
