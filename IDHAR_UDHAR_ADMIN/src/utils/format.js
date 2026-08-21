export function formatINR(value) {
  return `₹${Number(value || 0).toLocaleString('en-IN')}`;
}

export function formatINRExact(value, digits = 2) {
  return `₹${Number(value || 0).toLocaleString('en-IN', {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  })}`;
}

export function formatCompactINR(value) {
  const amount = Number(value || 0);
  if (amount >= 10000000) return `₹${(amount / 10000000).toFixed(1)}Cr`;
  if (amount >= 100000) return `₹${(amount / 100000).toFixed(1)}L`;
  return formatINR(amount);
}

export function initials(name = '') {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join('')
    .toUpperCase();
}

export function downloadCsv(filename, rows, columns) {
  const header = columns.map((column) => column.label).join(',');
  const body = rows
    .map((row) =>
      columns
        .map((column) => `"${String(row[column.key] ?? '').replaceAll('"', '""')}"`)
        .join(','),
    )
    .join('\n');
  const blob = new Blob([`${header}\n${body}`], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export function printReport(title, rows, columns) {
  const win = window.open('', '_blank');
  if (!win) return;
  const keys = columns?.length ? columns : Object.keys(rows[0] || {}).map((key) => ({ key, label: key }));
  const head = keys.map((column) => `<th>${column.label}</th>`).join('');
  const htmlRows = rows
    .map((row) => `<tr>${keys.map((column) => `<td>${row[column.key] ?? ''}</td>`).join('')}</tr>`)
    .join('');
  win.document.write(`
    <html><head><title>${title}</title>
    <style>body{font-family:Inter,sans-serif;padding:24px;color:#0F1F3D} table{width:100%;border-collapse:collapse} td,th{border:1px solid #d7e4f5;padding:8px;text-align:left}</style>
    </head><body><h1>${title}</h1><table><thead><tr>${head}</tr></thead><tbody>${htmlRows}</tbody></table></body></html>
  `);
  win.document.close();
  win.focus();
  win.print();
}
