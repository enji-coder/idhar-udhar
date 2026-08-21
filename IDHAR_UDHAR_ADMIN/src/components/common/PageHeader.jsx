export default function PageHeader({ action, children }) {
  if (!action && !children) return null;
  return (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <div>{children}</div>
      {action}
    </div>
  );
}
