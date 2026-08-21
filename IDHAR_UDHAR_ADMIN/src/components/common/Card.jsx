export default function Card({ children, className = '' }) {
  return (
    <article className={`card-surface p-5 ${className}`}>{children}</article>
  );
}
