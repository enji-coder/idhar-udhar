import { X } from 'lucide-react';

const widths = {
  md: 'sm:max-w-md',
  lg: 'sm:max-w-lg',
  xl: 'sm:max-w-xl',
  '2xl': 'sm:max-w-2xl',
};

export default function Drawer({ open, title, subtitle, eyebrow, onClose, children, footer, size = 'md' }) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button type="button" className="absolute inset-0 bg-slate-900/30" aria-label="Close drawer" onClick={onClose} />
      <aside className={`relative z-10 flex h-full w-full flex-col rounded-none glass-panel p-5 sm:rounded-l-[22px] sm:p-6 ${widths[size] || widths.md}`}>
        <div className="mb-4 flex items-start justify-between gap-3">
          <div className="min-w-0">
            {eyebrow ? <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-soft">{eyebrow}</p> : null}
            <h3 className="truncate text-lg font-semibold text-ink">{title}</h3>
            {subtitle ? <p className="mt-0.5 text-sm text-ink-muted">{subtitle}</p> : null}
          </div>
          <button type="button" onClick={onClose} className="rounded-full p-1 text-ink-soft hover:bg-brand-50" aria-label="Close">
            <X size={18} />
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto overflow-x-hidden pr-1">{children}</div>
        {footer ? <div className="mt-4 flex flex-wrap justify-end gap-2">{footer}</div> : null}
      </aside>
    </div>
  );
}
