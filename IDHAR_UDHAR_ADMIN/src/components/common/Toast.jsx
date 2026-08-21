import { useEffect } from 'react';
import { CheckCircle2, X } from 'lucide-react';

export default function Toast({ open, message, onClose, duration = 2800 }) {
  useEffect(() => {
    if (!open) return undefined;
    const timer = window.setTimeout(() => onClose?.(), duration);
    return () => window.clearTimeout(timer);
  }, [open, duration, onClose]);

  if (!open || !message) return null;

  return (
    <div className="pointer-events-none fixed bottom-6 right-6 z-[70] flex justify-end">
      <div className="pointer-events-auto flex max-w-sm items-start gap-3 glass-panel px-4 py-3 shadow-floating">
        <CheckCircle2 size={18} className="mt-0.5 shrink-0 text-emerald-600" />
        <p className="text-sm font-medium leading-5 text-ink">{message}</p>
        <button type="button" className="rounded-full p-1 text-ink-soft hover:bg-brand-50" aria-label="Dismiss" onClick={onClose}>
          <X size={14} />
        </button>
      </div>
    </div>
  );
}
