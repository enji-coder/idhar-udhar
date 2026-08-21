export function nextId(prefix, rows = [], key = 'id') {
  const numbers = rows
    .map((row) => Number(String(row[key] || '').replace(/\D/g, '').slice(-4)))
    .filter((value) => Number.isFinite(value));
  const next = (numbers.length ? Math.max(...numbers) : 1000) + 1;
  return `${prefix}-${String(next).padStart(4, '0')}`;
}

export function todayLabel() {
  return '17 Aug 2026';
}
