import { useEffect, useState } from 'react';
import { fetchPaymentSettings } from '../api/adminApi';
import {
  getPaymentSettings,
  PAYMENT_SETTINGS_KEY,
  paymentSettingsFromApi,
  rememberPaymentSettings,
  subscribePaymentSettings,
} from '../services/commission';

export default function usePaymentSettings() {
  const [settings, setSettings] = useState(getPaymentSettings);

  useEffect(() => {
    const refresh = () => setSettings(getPaymentSettings());
    const unsubscribe = subscribePaymentSettings(refresh);
    fetchPaymentSettings()
      .then((body) => {
        const payment = paymentSettingsFromApi(body?.active);
        if (payment) rememberPaymentSettings(payment);
      })
      .catch(() => {
        /* The settings page reports a failed load. Other screens keep the last saved values. */
      });
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
