import { useState } from 'react';
import Button from '../common/Button';
import Field, { inputClass } from '../common/Field';
import Modal from '../common/Modal';
import useStore from '../../hooks/useStore';
import { compactErrors, nonNegative, required } from '../../utils/validation';
import { defaultVehicleCategoryName, vehicleCategoryNames, vehicleCategoryStore } from '../../services/vehicleCategories';

export default function CreateOrderModal({ open, customers, riders, vehicles, onClose, onSave }) {
  useStore(vehicleCategoryStore);
  const [form, setForm] = useState({
    customer: customers[0]?.name || '',
    rider: 'Unassigned',
    pickup: '',
    destination: '',
    vehicle: vehicles[0]?.type || defaultVehicleCategoryName(),
    amount: '',
    whoPays: 'customer',
    customerAmount: '',
    customerMode: 'online',
    receiverMode: 'cash',
    status: 'Pending',
  });
  const [errors, setErrors] = useState({});

  function save() {
    const issues = compactErrors({
      customer: required(form.customer, 'Customer is required.'),
      pickup: required(form.pickup, 'Pickup is required.'),
      destination: required(form.destination, 'Destination is required.'),
      amount: required(form.amount, 'Amount is required.') || nonNegative(form.amount, 'Amount cannot be negative.'),
    });
    setErrors(issues);
    if (Object.keys(issues).length) return;
    const customer = customers.find((item) => item.name === form.customer);
    const rider = riders.find((item) => item.name === form.rider);
    onSave({
      ...form,
      customerId: customer?.id || '',
      riderId: rider?.id || '',
      amount: Number(form.amount),
      vehicleNumber: rider?.vehicleNumber || '',
      date: '17 Aug 2026',
      time: '1:40 PM',
      eta: '32 min',
      distance: '6.0 km',
      paymentStatus: 'UNPAID',
      lastUpdated: '17 Aug 2026 1:40 PM',
    });
  }

  return (
    <Modal open={open} title="Create Order" size="lg" onClose={onClose} footer={<><Button variant="ghost" onClick={onClose}>Cancel</Button><Button onClick={save}>Save</Button></>}>
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label="Customer" error={errors.customer}>
          <select className={inputClass} value={form.customer} onChange={(event) => setForm({ ...form, customer: event.target.value })}>
            {customers.map((item) => <option key={item.id}>{item.name}</option>)}
            {customers.length === 0 ? <option>Walk-in customer</option> : null}
          </select>
        </Field>
        <Field label="Rider">
          <select className={inputClass} value={form.rider} onChange={(event) => setForm({ ...form, rider: event.target.value })}>
            <option>Unassigned</option>
            {riders.map((item) => <option key={item.id}>{item.name}</option>)}
          </select>
        </Field>
        <Field label="Pickup" error={errors.pickup}><input className={inputClass} value={form.pickup} onChange={(event) => setForm({ ...form, pickup: event.target.value })} /></Field>
        <Field label="Destination" error={errors.destination}><input className={inputClass} value={form.destination} onChange={(event) => setForm({ ...form, destination: event.target.value })} /></Field>
        <Field label="Vehicle">
          <select className={inputClass} value={form.vehicle} onChange={(event) => setForm({ ...form, vehicle: event.target.value })}>
            {vehicleCategoryNames({ current: form.vehicle }).map((item) => <option key={item}>{item}</option>)}
          </select>
        </Field>
        <Field label="Amount" error={errors.amount}><input type="number" className={inputClass} value={form.amount} onChange={(event) => setForm({ ...form, amount: event.target.value })} /></Field>
        <Field label="Who pays">
          <select className={inputClass} value={form.whoPays} onChange={(event) => setForm({ ...form, whoPays: event.target.value })}>
            <option value="customer">Customer</option>
            <option value="receiver">Receiver</option>
            <option value="split">Customer + Receiver</option>
          </select>
        </Field>
        {form.whoPays === 'split' ? (
          <Field label="Customer amount">
            <input type="number" className={inputClass} value={form.customerAmount} onChange={(event) => setForm({ ...form, customerAmount: event.target.value })} />
          </Field>
        ) : null}
        <Field label="Customer method">
          <select className={inputClass} value={form.customerMode} onChange={(event) => setForm({ ...form, customerMode: event.target.value })}>
            <option value="online">Online</option>
            <option value="cash">Cash</option>
            <option value="split">Online + Cash</option>
          </select>
        </Field>
        <Field label="Receiver method">
          <select className={inputClass} value={form.receiverMode} onChange={(event) => setForm({ ...form, receiverMode: event.target.value })}>
            <option value="cash">Cash</option>
            <option value="online">Online</option>
            <option value="split">Online + Cash</option>
          </select>
        </Field>
        <Field label="Status">
          <select className={inputClass} value={form.status} onChange={(event) => setForm({ ...form, status: event.target.value })}>
            <option>Pending</option><option>Assigned</option>
          </select>
        </Field>
      </div>
      <p className="mt-3 text-xs text-ink-muted">Online stays UNPAID until a payment provider confirms. This screen does not fake a successful charge. Receiver online is architecture ready / integration pending.</p>
    </Modal>
  );
}
