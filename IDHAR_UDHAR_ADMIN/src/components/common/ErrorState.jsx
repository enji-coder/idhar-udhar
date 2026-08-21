import Button from './Button';

export default function ErrorState({ title = 'Something went wrong', description, onRetry }) {
  return (
    <div className="flex flex-col items-center justify-center rounded-3xl border border-red-100 bg-white/80 px-6 py-16 text-center">
      <h2 className="text-lg font-semibold text-ink">{title}</h2>
      <p className="mt-2 max-w-md text-sm leading-6 text-ink-muted">{description}</p>
      {onRetry ? (
        <div className="mt-5">
          <Button onClick={onRetry}>Try again</Button>
        </div>
      ) : null}
    </div>
  );
}
