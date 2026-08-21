export default function EmptyState({ icon: Icon, title, description, action }) {
  return (
    <div className="flex flex-col items-center justify-center px-6 py-16 text-center">
      {Icon ? (
        <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-brand-50 text-brand-500">
          <Icon size={26} />
        </div>
      ) : null}
      <h2 className="text-lg font-semibold text-ink">{title}</h2>
      <p className="mt-2 max-w-md text-sm leading-6 text-ink-muted">{description}</p>
      {action ? <div className="mt-5">{action}</div> : null}
    </div>
  );
}
