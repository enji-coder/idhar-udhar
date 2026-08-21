import { X } from 'lucide-react';

export default function Modal({ open, title, onClose, children, footer, size = 'md' }) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-stretch justify-center sm:items-center sm:p-4">
      <button type="button" aria-label="Close dialog" className="absolute inset-0 bg-slate-900/30" onClick={onClose} />
      <div className={`relative z-10 flex h-full w-full max-h-none flex-col overflow-hidden rounded-none glass-panel p-5 sm:h-auto sm:max-h-[90vh] sm:rounded-[22px] sm:p-6 ${size === 'xl' ? 'sm:max-w-3xl' : size === 'lg' ? 'sm:max-w-2xl' : 'sm:max-w-lg'}`}>
        <div className="mb-4 flex items-start justify-between gap-3">
          <h3 className="text-lg font-semibold text-ink">{title}</h3>
          <button type="button" onClick={onClose} className="rounded-full p-1 text-ink-soft hover:bg-brand-50" aria-label="Close">
            <X size={18} />
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto overflow-x-hidden">{children}</div>
        {footer ? <div className="mt-5 flex flex-wrap justify-end gap-2">{footer}</div> : null}
      </div>
    </div>
  );
}
