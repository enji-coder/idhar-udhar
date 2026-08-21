import { companyOffice as seedOffice } from '../data/companyOffice.js';

export const COMPANY_OFFICE_KEY = 'iu_admin_company_office_v1';

export function defaultCompanyOffice() {
  return { ...seedOffice, configurationStatus: 'configured' };
}

export function loadCompanyOffice() {
  try {
    const stored = JSON.parse(localStorage.getItem(COMPANY_OFFICE_KEY) || 'null');
    if (stored?.address) return { ...defaultCompanyOffice(), ...stored };
  } catch {
    /* seed */
  }
  return defaultCompanyOffice();
}

export function saveCompanyOffice(office) {
  const next = {
    id: office.id || 'office_amd',
    name: String(office.name || 'Company Office').trim(),
    address: String(office.address || '').trim(),
    city: String(office.city || '').trim(),
    latitude: Number(office.latitude),
    longitude: Number(office.longitude),
    configurationStatus: 'configured',
  };
  localStorage.setItem(COMPANY_OFFICE_KEY, JSON.stringify(next));
  return next;
}
