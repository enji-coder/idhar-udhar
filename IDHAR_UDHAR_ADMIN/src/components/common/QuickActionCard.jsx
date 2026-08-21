export default function QuickActionCard({ icon: Icon, label, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex min-w-[132px] flex-1 flex-col items-center gap-2 rounded-[20px] border border-line bg-white px-4 py-4 shadow-card transition hover:shadow-card-hover"
    >
      <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-brand-50 text-brand-500">
        {Icon ? <Icon size={20} /> : null}
      </span>
      <span className="text-sm font-semibold text-ink">{label}</span>
    </button>
  );
}
