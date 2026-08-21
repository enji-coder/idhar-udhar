const tones = {
  view: 'bg-brand-50 text-brand-700 hover:bg-brand-100',
  track: 'bg-indigo-50 text-indigo-700 hover:bg-indigo-100',
  edit: 'bg-amber-50 text-amber-800 hover:bg-amber-100',
  reassign: 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100',
  invoice: 'bg-violet-50 text-violet-700 hover:bg-violet-100',
  approve: 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100',
  danger: 'bg-red-50 text-red-700 hover:bg-red-100',
  export: 'bg-indigo-50 text-indigo-700 hover:bg-indigo-100',
  ghost: 'bg-slate-50 text-ink-muted hover:bg-slate-100',
};

export default function ActionButton({
  icon: Icon,
  children,
  tone = 'view',
  onClick,
  disabled = false,
  loading = false,
  title,
  type = 'button',
  className = '',
}) {
  return (
    <button
      type={type}
      title={title || (typeof children === 'string' ? children : undefined)}
      aria-label={title || (typeof children === 'string' ? children : undefined)}
      disabled={disabled || loading}
      onClick={onClick}
      className={`inline-flex h-7 items-center gap-1 whitespace-nowrap rounded-lg px-2 text-[11px] font-semibold leading-none transition disabled:cursor-not-allowed disabled:opacity-40 sm:h-8 sm:px-2.5 sm:text-xs ${tones[tone] || tones.view} ${className}`}
    >
      {Icon ? <Icon size={13} strokeWidth={2.2} /> : null}
      <span>{loading ? '…' : children}</span>
    </button>
  );
}

export function ActionGroup({ children, className = '', ...props }) {
  return (
    <div className={`flex max-w-full flex-wrap justify-start gap-1 xl:justify-end ${className}`} {...props}>
      {children}
    </div>
  );
}
