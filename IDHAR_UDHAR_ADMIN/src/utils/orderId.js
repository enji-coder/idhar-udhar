export function numericOrderId(value) {
  if (value == null || value === '') return null;
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  const digits = String(value).replace(/\D/g, '');
  if (!digits) return null;
  const parsed = Number(digits.slice(-6));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

export function formatNumericOrderId(value) {
  const id = numericOrderId(value);
  return id == null ? 'N/A' : String(id);
}

export function composeOrderCode(numericId) {
  const n = Number(numericId) || 0;
  return `IU-AMD-${String(n).padStart(10, '0')}`;
}

export function invoiceNumberFor(orderOrId) {
  const numeric = numericOrderId(orderOrId?.invoiceNumber || orderOrId?.id || orderOrId);
  return numeric == null ? 'N/A' : `INV-AMD-${numeric}`;
}

export function nextNumericOrderId(orders = []) {
  const numbers = orders.map((row) => numericOrderId(row.orderId || row.id)).filter(Boolean);
  return (numbers.length ? Math.max(...numbers) : 10420) + 1;
}

export function withStableOrderId(order) {
  if (!order) return order;
  const orderId = numericOrderId(order.orderId || order.id);
  return {
    ...order,
    orderId,
    orderCode: order.id || (orderId == null ? '' : composeOrderCode(orderId)),
  };
}
