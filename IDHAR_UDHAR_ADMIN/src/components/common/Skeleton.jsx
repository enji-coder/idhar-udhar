export default function Skeleton({ className = '' }) {
  return <div className={`animate-pulse rounded-2xl bg-brand-100 ${className}`} />;
}

export function PageSkeleton() {
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, index) => (
          <Skeleton key={index} className="h-32" />
        ))}
      </div>
      <Skeleton className="h-72" />
    </div>
  );
}

export function TableSkeleton({ rows = 8 }) {
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <Skeleton className="h-11 w-52 rounded-2xl" />
        <Skeleton className="h-11 w-36 rounded-2xl" />
        <Skeleton className="h-11 w-36 rounded-2xl" />
        <Skeleton className="h-11 w-36 rounded-2xl" />
      </div>
      <div className="space-y-2 rounded-[24px] border border-line bg-white/70 p-4">
        {Array.from({ length: rows }).map((_, index) => (
          <Skeleton key={index} className="h-11 rounded-xl" />
        ))}
      </div>
    </div>
  );
}
