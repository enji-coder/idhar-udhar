import { useState } from 'react';
import Modal from '../common/Modal';
import Button from '../common/Button';
import { CANCEL_REASONS } from '../../services/orderRules';
import { CANCELLED_BY } from '../../config/status';

export default function CancelOrderModal({ open, order, onClose, onConfirm }) {
  const [reason, setReason] = useState('Customer Request');
  const [cancelledBy, setCancelledBy] = useState('Admin');
  const [other, setOther] = useState('');

  if (!order) return null;

  function confirm() {
    const value = reason === 'Other' ? (other.trim() || 'Other') : reason;
    onConfirm(value, cancelledBy);
    setReason('Customer Request');
    setCancelledBy('Admin');
    setOther('');
  }

  return (
    <Modal
      open={open}
      title="Cancel Order?"
      onClose={onClose}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>Keep Order</Button>
          <Button variant="reject" onClick={confirm} disabled={reason === 'Other' && !other.trim()}>Cancel Order</Button>
        </>
      }
    >
      <p className="text-sm text-ink-muted">Order: <span className="font-semibold text-ink">{order.id}</span></p>
      <p className="mt-4 text-sm font-medium">Cancelled by</p>
      <div className="mt-2 flex flex-wrap gap-2">
        {CANCELLED_BY.map((item) => (
          <label key={item} className="flex items-center gap-2 rounded-2xl bg-white/80 px-3 py-2 text-sm">
            <input type="radio" name="cancelled-by" checked={cancelledBy === item} onChange={() => setCancelledBy(item)} />
            {item}
          </label>
        ))}
      </div>
      <p className="mt-4 text-sm font-medium">Please select cancellation reason:</p>
      <div className="mt-3 space-y-2">
        {CANCEL_REASONS.map((item) => (
          <label key={item} className="flex items-center gap-3 rounded-2xl bg-white/80 px-3 py-2.5 text-sm">
            <input type="radio" name="cancel-reason" checked={reason === item} onChange={() => setReason(item)} />
            {item}
          </label>
        ))}
      </div>
      {reason === 'Other' ? (
        <textarea
          value={other}
          onChange={(event) => setOther(event.target.value)}
          placeholder="Describe the reason"
          className="mt-3 h-24 w-full rounded-2xl border border-line px-3 py-2 text-sm outline-none focus:border-brand-300 focus:ring-2 focus:ring-brand-200"
        />
      ) : null}
    </Modal>
  );
}
