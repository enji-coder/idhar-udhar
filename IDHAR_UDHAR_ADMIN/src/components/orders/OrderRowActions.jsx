import { Eye, FileText, MapPinned, Pencil, RefreshCw, Trash2, XCircle } from 'lucide-react';
import ActionButton, { ActionGroup } from '../common/ActionButton';
import { getOrderActions } from '../../services/orderRules';

export default function OrderRowActions({ order, can, onAction }) {
  const actions = getOrderActions(order);

  return (
    <ActionGroup onClick={(event) => event.stopPropagation()}>
      {can('orders', 'view') && actions.view ? <ActionButton icon={Eye} tone="view" onClick={() => onAction('view', order)}>View</ActionButton> : null}
      {can('orders', 'track') && actions.track ? <ActionButton icon={MapPinned} tone="track" onClick={() => onAction('track', order)}>Track</ActionButton> : null}
      {can('orders', 'edit') && actions.edit ? <ActionButton icon={Pencil} tone="edit" onClick={() => onAction('edit', order)}>Edit</ActionButton> : null}
      {can('orders', 'assign') && actions.reassign ? (
        <ActionButton icon={RefreshCw} tone="reassign" onClick={() => onAction('reassign', order)}>{actions.assign ? 'Assign' : 'Reassign'}</ActionButton>
      ) : null}
      <ActionButton icon={RefreshCw} tone="ghost" onClick={() => onAction('status', order)}>Update Status</ActionButton>
      {can('orders', 'invoice') && actions.invoice ? <ActionButton icon={FileText} tone="invoice" onClick={() => onAction('invoice', order)}>Invoice</ActionButton> : null}
      {can('orders', 'cancel') && actions.cancel ? <ActionButton icon={XCircle} tone="danger" onClick={() => onAction('cancel', order)}>Cancel</ActionButton> : null}
      <ActionButton icon={Trash2} tone="danger" onClick={() => onAction('delete', order)}>Delete</ActionButton>
    </ActionGroup>
  );
}
