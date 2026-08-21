import { FileText, MapPinned, Pencil, RefreshCw, ShieldCheck, XCircle } from 'lucide-react';
import Drawer from '../common/Drawer';
import Button from '../common/Button';
import StatusBadge from '../common/StatusBadge';
import Field, { inputClass } from '../common/Field';
import OrderTimeline from './OrderTimeline';
import MockRouteMap from './MockRouteMap';
import { formatINR } from '../../utils/format';
import { buildInvoice } from '../../services/invoiceService';
import { buildTimeline, getOrderActions, validateOrderEdits } from '../../services/orderRules';
import { useState } from 'react';

import DetailSection, { DetailRow } from '../common/DetailSection';

export default function OrderDetailDrawer({
  open,
  order,
  mode,
  can,
  onClose,
  onAction,
  onSaveEdit,
}) {
  const [errors, setErrors] = useState({});
  if (!order) return null;

  const actions = getOrderActions(order);
  const invoice = buildInvoice(order);
  const timeline = buildTimeline(order);
  const isEdit = mode === 'edit';
  const isTrack = mode === 'track';

  function submitEdit(event) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const values = {
      pickup: String(data.get('pickup') || ''),
      destination: String(data.get('destination') || ''),
      packageType: String(data.get('packageType') || ''),
      weight: String(data.get('weight') || ''),
      quantity: String(data.get('quantity') || '1'),
      instructions: String(data.get('instructions') || ''),
    };
    const nextErrors = validateOrderEdits(values);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length) return;
    onSaveEdit({
      ...values,
      quantity: Number(values.quantity),
      pickupAddress: values.pickup,
      destinationAddress: values.destination,
    });
  }

  const footerActions = isEdit ? (
    <>
      <Button variant="ghost" onClick={onClose}>Cancel</Button>
      <Button type="submit" form="order-edit-form">Save changes</Button>
    </>
  ) : (
    <>
      {can('orders', 'track') && actions.track && !isTrack ? <Button size="sm" variant="view" icon={MapPinned} onClick={() => onAction('track', order)}>Track</Button> : null}
      {isTrack ? <Button size="sm" variant="secondary" onClick={() => onAction('view', order)}>View Timeline</Button> : null}
      {can('orders', 'edit') && actions.edit ? <Button size="sm" variant="edit" icon={Pencil} onClick={() => onAction('edit', order)}>Edit</Button> : null}
      {can('orders', 'assign') && actions.reassign ? <Button size="sm" variant="approve" icon={RefreshCw} onClick={() => onAction('reassign', order)}>{actions.assign ? 'Assign' : 'Reassign'}</Button> : null}
      {can('orders', 'invoice') ? <Button size="sm" variant="export" icon={FileText} onClick={() => onAction('invoice', order)}>{order.status === 'Delivered' ? 'View Invoice' : 'Invoice'}</Button> : null}
      {actions.proof ? <Button size="sm" variant="secondary" icon={ShieldCheck} onClick={() => onAction('proof', order)}>Proof</Button> : null}
      {can('orders', 'cancel') && actions.cancel ? <Button size="sm" variant="danger" icon={XCircle} onClick={() => onAction('cancel', order)}>Cancel</Button> : null}
    </>
  );

  return (
    <Drawer
      open={open}
      size="xl"
      eyebrow="Order details"
      title={order.id}
      subtitle={`${order.date} • ${order.time || ''}`.trim()}
      onClose={onClose}
      footer={footerActions}
    >
      {isTrack ? (
        <div className="space-y-4">
          <div className="flex items-center justify-between gap-3">
            <StatusBadge status={order.status} />
            <p className="text-sm text-ink-muted">{order.eta} · {order.distance}</p>
          </div>
          <MockRouteMap order={order} />
          <DetailSection title="Current rider">
            <p className="font-semibold text-ink">{order.rider || 'Unassigned'}</p>
            <p className="text-sm text-ink-muted">{order.vehicle} {order.vehicleNumber ? `· ${order.vehicleNumber}` : ''}</p>
          </DetailSection>
          <DetailSection title="Route">
            <p className="text-sm"><span className="text-ink-muted">Pickup</span> · {order.pickup}</p>
            <p className="mt-2 text-sm"><span className="text-ink-muted">Destination</span> · {order.destination}</p>
          </DetailSection>
          <DetailSection title="Timeline">
            <OrderTimeline steps={timeline} />
          </DetailSection>
        </div>
      ) : null}

      {isEdit ? (
        <form id="order-edit-form" className="space-y-3" onSubmit={submitEdit}>
          <Field label="Pickup" error={errors.pickup}><input name="pickup" defaultValue={order.pickup} className={inputClass} /></Field>
          <Field label="Destination" error={errors.destination}><input name="destination" defaultValue={order.destination} className={inputClass} /></Field>
          <Field label="Package type" error={errors.packageType}>
            <select name="packageType" defaultValue={order.packageType || 'Package'} className={inputClass}>
              <option>Documents</option>
              <option>Parcel</option>
              <option>Package</option>
              <option>Gift</option>
              <option>Fragile</option>
            </select>
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Weight" error={errors.weight}><input name="weight" defaultValue={order.weight} className={inputClass} /></Field>
            <Field label="Quantity" error={errors.quantity}><input name="quantity" type="number" min="1" defaultValue={order.quantity || 1} className={inputClass} /></Field>
          </div>
          <Field label="Delivery instructions">
            <textarea name="instructions" defaultValue={order.instructions || ''} rows={3} className={`${inputClass} h-auto py-3`} />
          </Field>
        </form>
      ) : null}

      {!isEdit && !isTrack ? (
        <div className="space-y-4 text-sm">
          <StatusBadge status={order.status} />

          <DetailSection title="Order">
            <DetailRow label="Order ID" value={order.id} />
            <DetailRow label="Canonical status" value={order.canonicalStatus || order.status} />
            <DetailRow label="Created" value={`${order.date} ${order.time || ''}`.trim()} />
            <DetailRow label="Delivery date" value={order.deliveredAt || (order.status === 'Delivered' ? order.date : 'In progress')} />
          </DetailSection>

          <DetailSection title="Customer">
            <p className="font-semibold text-ink">{order.customer}</p>
            <DetailRow label="Phone" value={order.customerPhone} />
            <DetailRow label="Email" value={order.customerEmail} />
            <DetailRow label="Address" value={order.pickupAddress || order.pickup} />
          </DetailSection>

          <DetailSection title="Pickup">
            <p className="font-medium text-ink">{order.pickupAddress || order.pickup}</p>
            <DetailRow label="Contact" value={order.customerPhone} />
          </DetailSection>

          <DetailSection title="Destination">
            <p className="font-medium text-ink">{order.destinationAddress || order.destination}</p>
            <DetailRow label="Contact" value={order.customerPhone} />
          </DetailSection>

          <DetailSection title="Rider">
            <p className="font-semibold text-ink">{order.rider || 'Unassigned'}</p>
            <DetailRow label="Phone" value={order.riderPhone} />
            <DetailRow label="Vehicle" value={order.vehicle} />
            <DetailRow label="Vehicle number" value={order.vehicleNumber} />
            <DetailRow label="Rating" value={order.riderRating} />
            <DetailRow label="Status" value={order.riderStatus} />
          </DetailSection>

          <DetailSection title="Package">
            <DetailRow label="Type" value={order.packageType || 'Package'} />
            <DetailRow label="Weight" value={order.weight} />
            <DetailRow label="Quantity" value={order.quantity || 1} />
            <DetailRow label="Dimensions" value={order.dimensions} />
            {order.instructions ? <p className="pt-2 text-ink-muted">Special instructions: {order.instructions}</p> : null}
          </DetailSection>

          <DetailSection title="Payment">
            <DetailRow label="Trip Fare" value={formatINR(order.tripFare ?? order.amount)} />
            <DetailRow label="Discount" value={formatINR(order.discount || 0)} />
            <DetailRow label="Additional charge" value={formatINR(order.additionalCharge || order.resendCharge || 0)} />
            <DetailRow label="Amount payable" value={formatINR(invoice.total)} />
            <DetailRow label="Customer responsibility" value={formatINR(order.customerResponsibility)} />
            <DetailRow label="Receiver responsibility" value={formatINR(order.receiverResponsibility)} />
            <DetailRow label="Customer paid" value={formatINR(order.customerPaid)} />
            <DetailRow label="Receiver paid" value={formatINR(order.receiverPaid)} />
            <DetailRow label="Outstanding" value={formatINR(order.outstandingAmount)} />
            <DetailRow label="Payment status" value={order.paymentStatus || invoice.payment.status} />
            <DetailRow label="Payment methods" value={order.payment} />
            <DetailRow label="Rider amount" value={formatINR(order.riderEarning || order.riderCommission || order.financeSnapshot?.riderAmount)} />
            <DetailRow label="Company amount" value={formatINR(order.companyCommission || order.financeSnapshot?.companyCommission)} />
            <DetailRow label="Cancellation fee" value={formatINR(order.cancellationFee || 0)} />
            <DetailRow label="Resend charge" value={formatINR(order.resendCharge || 0)} />
            <DetailRow label="Tax" value="No GST" />
          </DetailSection>
          {(order.paymentPlan?.transactions || []).length ? (
            <DetailSection title="Payment transactions">
              {order.paymentPlan.transactions.map((txn) => (
                <DetailRow
                  key={txn.id}
                  label={`${txn.payer} · ${txn.method}`}
                  value={`${formatINR(txn.amount)} · ${txn.status}`}
                />
              ))}
            </DetailSection>
          ) : null}

          {actions.proof ? (
            <DetailSection title="Delivery proof">
              <div className="h-28 rounded-2xl bg-gradient-to-br from-brand-50 to-cyan-50" />
              <p className="mt-2 font-medium">{order.proofNote || 'Photo POD captured by rider'}</p>
              <p className="text-xs text-ink-soft">{order.deliveredAt || order.date}</p>
            </DetailSection>
          ) : null}

          {order.failureReason || order.status === 'Failed' ? (
            <DetailSection title="Failed delivery">
              <DetailRow label="Failure reason" value={order.failureReason || 'Receiver Unavailable'} />
              <DetailRow label="Original destination" value={order.originalDestination || order.destination} />
              <DetailRow label="Company office" value={order.companyOffice || order.companyOfficeAddress} />
              <DetailRow label="Original trip fare" value={formatINR(order.amount)} />
              <DetailRow label="Rider amount" value={formatINR(order.riderEarning || order.riderCommission)} />
              <DetailRow label="IDHAR UDHAR" value={formatINR(order.companyCommission)} />
              <DetailRow label="Additional rider compensation" value={formatINR(order.riderOfficeCompensation)} />
              <DetailRow label="Resend status" value={order.resendStatus || 'not_decided'} />
              <DetailRow label="Resend charge" value={formatINR(order.resendCharge)} />
            </DetailSection>
          ) : null}

          {order.stops?.length ? (
            <DetailSection title="Stops">
              {order.stops.map((stop, index) => (
                <DetailRow key={stop.id || index} label={`Stop ${stop.sequence ?? index}`} value={stop.label || stop.address} />
              ))}
            </DetailSection>
          ) : null}

          <DetailSection title="Delivery timeline">
            <OrderTimeline steps={timeline} />
          </DetailSection>
        </div>
      ) : null}
    </Drawer>
  );
}
