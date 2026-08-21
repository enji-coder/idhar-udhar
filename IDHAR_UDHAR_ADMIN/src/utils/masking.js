function digitsOnly(value) {
  return String(value || '').replace(/\D/g, '');
}

export function maskAadhaar(value) {
  const digits = digitsOnly(value);
  if (digits.length < 4) return 'XXXX XXXX XXXX';
  return `XXXX XXXX ${digits.slice(-4)}`;
}

export function maskPan(value) {
  const text = String(value || '').replace(/\s/g, '').toUpperCase();
  if (text.length < 4) return 'XXXXXXX***';
  return `${text.slice(0, 2)}XXXXX${text.slice(-3)}`;
}

export function maskBankAccount(value) {
  const digits = digitsOnly(value);
  if (digits.length < 4) return 'XXXXXXXXXXXX';
  return `${'X'.repeat(Math.max(digits.length - 4, 4))}${digits.slice(-4)}`;
}

export function maskIfsc(value) {
  const text = String(value || '').replace(/\s/g, '').toUpperCase();
  if (text.length < 4) return 'XXXX0000XXX';
  return `${text.slice(0, 4)}XXXX${text.slice(-3)}`;
}

export function maskPhone(value) {
  const digits = digitsOnly(value);
  if (digits.length < 4) return value || 'N/A';
  return `XXXXXX${digits.slice(-4)}`;
}

export function redactForExport(row, keys = []) {
  const next = { ...row };
  keys.forEach((key) => {
    if (key === 'aadhaar' || key === 'aadhaarNumber') next[key] = maskAadhaar(row[key]);
    if (key === 'pan' || key === 'panNumber') next[key] = maskPan(row[key]);
    if (key === 'bankAccount' || key === 'bankAccountNumber') next[key] = maskBankAccount(row[key]);
    if (key === 'ifsc' || key === 'ifscCode') next[key] = maskIfsc(row[key]);
  });
  return next;
}
