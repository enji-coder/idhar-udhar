import { useEffect, useState } from 'react';
import { getPaymentSettings, PAYMENT_SETTINGS_KEY, subscribePaymentSettings } from '../services/commission';

export default function usePaymentSettings() {
  const [settings, setSettings] = useState(getPaymentSettings);

  useEffect(() => {
    const refresh = () => setSettings(getPaymentSettings());
    const unsubscribe = subscribePaymentSettings(refresh);
    function onStorage(event) {
      if (!event.key || event.key === PAYMENT_SETTINGS_KEY) refresh();
    }
    window.addEventListener('storage', onStorage);
    return () => {
      unsubscribe();
      window.removeEventListener('storage', onStorage);
    };
  }, []);

  return settings;
}
