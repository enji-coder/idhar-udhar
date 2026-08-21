import Button from './Button';
import Modal from './Modal';

export default function ConfirmDialog({
  open,
  title = 'Are you sure you want to delete this item?',
  description,
  confirmLabel = 'Delete',
  onClose,
  onConfirm,
}) {
  return (
    <Modal
      open={open}
      title={title}
      onClose={onClose}
      footer={(
        <>
          <Button variant="ghost" onClick={onClose}>Cancel</Button>
          <Button variant="reject" onClick={onConfirm}>{confirmLabel}</Button>
        </>
      )}
    >
      <p className="text-sm leading-6 text-ink-muted">{description || 'This will remove the item from the Admin Panel.'}</p>
    </Modal>
  );
}
