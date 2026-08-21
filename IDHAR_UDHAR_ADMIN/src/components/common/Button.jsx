export default function Button({
  children,
  variant = 'primary',
  icon: Icon,
  onClick,
  type = 'button',
  className = '',
  disabled = false,
  loading = false,
  size = 'md',
  title,
  form,
}) {
  const styles = {
    primary: 'bg-brand-500 text-white shadow-floating hover:bg-brand-600 active:bg-brand-700 disabled:bg-brand-300',
    secondary: 'bg-white text-brand-700 border border-brand-100 hover:bg-brand-50 active:bg-brand-100',
    view: 'bg-slate-100 text-slate-700 hover:bg-slate-200 active:bg-slate-300',
    edit: 'border border-amber-200 bg-amber-50 text-amber-800 hover:bg-amber-100 active:bg-amber-200',
    danger: 'border border-red-200 bg-red-50 text-red-700 hover:bg-red-100 active:bg-red-200',
    approve: 'border border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100',
    reject: 'bg-red-600 text-white hover:bg-red-700 active:bg-red-800',
    export: 'border border-indigo-200 bg-indigo-50 text-indigo-700 hover:bg-indigo-100',
    ghost: 'bg-transparent text-ink-muted hover:bg-slate-100',
  };
  const sizes = {
    sm: 'rounded-full px-3 py-1.5 text-xs',
    md: 'rounded-full px-4 py-2.5 text-sm',
    icon: 'rounded-xl p-2 text-xs',
  };

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled || loading}
      title={title}
      form={form}
      className={`inline-flex items-center justify-center gap-1.5 font-semibold transition disabled:cursor-not-allowed disabled:opacity-60 ${styles[variant] || styles.primary} ${sizes[size]} ${className}`}
    >
      {Icon ? <Icon size={size === 'sm' ? 13 : 16} /> : null}
      {loading ? 'Please wait…' : children}
    </button>
  );
}
