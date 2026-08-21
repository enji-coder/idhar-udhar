import { useCallback, useState } from 'react';

export default function usePanelState(emptyForm) {
  const [mode, setMode] = useState(null);
  const [form, setForm] = useState(emptyForm);
  const [view, setView] = useState(null);
  const [confirm, setConfirm] = useState(null);
  const [toast, setToast] = useState('');
  const [errors, setErrors] = useState({});

  const openCreate = useCallback(() => {
    setForm(typeof emptyForm === 'function' ? emptyForm() : { ...emptyForm });
    setErrors({});
    setMode('create');
  }, [emptyForm]);

  const openEdit = useCallback((row) => {
    setForm({ ...row });
    setErrors({});
    setMode('edit');
  }, []);

  const closeForm = useCallback(() => {
    setMode(null);
    setErrors({});
  }, []);

  return {
    mode,
    form,
    setForm,
    view,
    setView,
    confirm,
    setConfirm,
    toast,
    setToast,
    errors,
    setErrors,
    openCreate,
    openEdit,
    closeForm,
  };
}
