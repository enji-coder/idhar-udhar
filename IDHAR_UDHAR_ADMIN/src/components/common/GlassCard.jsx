export default function GlassCard({ children, className = '' }) {
  return <article className={`glass-card min-w-0 p-4 transition hover:shadow-card-hover sm:p-5 ${className}`}>{children}</article>;
}
