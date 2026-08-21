import { useEffect, useRef } from 'react';
import { useSearchParams } from 'react-router-dom';

export default function useQueryAction(action, onTrigger) {
  const [params, setParams] = useSearchParams();
  const callback = useRef(onTrigger);
  callback.current = onTrigger;
  const current = params.get('action');

  useEffect(() => {
    if (current !== action) return;
    callback.current();
    const next = new URLSearchParams(window.location.search);
    next.delete('action');
    setParams(next, { replace: true });
  }, [action, current, setParams]);
}
