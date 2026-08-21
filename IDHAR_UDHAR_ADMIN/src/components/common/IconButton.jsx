const tones = {
  view: 'text-brand-600 hover:bg-brand-50',
  track: 'text-indigo-600 hover:bg-indigo-50',
  edit: 'text-amber-700 hover:bg-amber-50',
  reassign: 'text-emerald-700 hover:bg-emerald-50',
  invoice: 'text-violet-700 hover:bg-violet-50',
  more: 'text-ink-muted hover:bg-slate-100',
  danger: 'text-red-600 hover:bg-red-50',
  ghost: 'text-ink-muted hover:bg-brand-50',
};

export default function IconButton({
  icon: Icon,
  label,
  onClick,
  tone = 'ghost',
  disabled = false,
  className = '',
}) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={`inline-flex h-8 w-8 items-center justify-center rounded-xl transition disabled:cursor-not-allowed disabled:opacity-40 ${tones[tone] || tones.ghost} ${className}`}
    >
      <Icon size={15} strokeWidth={2.1} />
    </button>
  );
}
