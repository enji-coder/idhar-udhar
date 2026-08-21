export default function OrderTimeline({ steps }) {
  return (
    <ol className="space-y-0">
      {steps.map((step, index) => (
        <li key={step.label} className="flex gap-3">
          <div className="flex flex-col items-center">
            <span className={`mt-0.5 h-3 w-3 rounded-full ${step.current ? 'bg-brand-500 shadow-floating' : step.done ? 'bg-emerald-500' : 'bg-slate-200'}`} />
            {index < steps.length - 1 ? (
              <span className={`w-px flex-1 ${step.done ? 'bg-brand-200' : 'bg-slate-200'}`} />
            ) : null}
          </div>
          <div className={`pb-4 ${step.current ? 'text-ink' : step.done ? 'text-ink' : 'text-ink-muted'}`}>
            <p className={`text-sm ${step.current ? 'font-semibold' : 'font-medium'}`}>{step.label}</p>
            {step.time ? <p className="text-xs text-ink-soft">{step.time}</p> : null}
          </div>
        </li>
      ))}
    </ol>
  );
}
