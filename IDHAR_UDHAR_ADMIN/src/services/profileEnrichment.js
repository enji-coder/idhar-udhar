import { NA } from '../config/status';
import { maskAadhaar, maskBankAccount, maskIfsc, maskPan } from '../utils/masking';

function extractPincodeLocal(text) {
  const match = String(text || '').match(/\b(\d{6})\b/);
  return match ? match[1] : '';
}

function seedFrom(id, salt = 0) {
  let n = salt;
  const source = String(id || '');
  for (let i = 0; i < source.length; i += 1) n = (n * 33 + source.charCodeAt(i)) >>> 0;
  return n;
}

function pad(value, length) {
  return String(value).padStart(length, '0').slice(-length);
}

export function enrichRiderProfile(rider = {}) {
  const n = seedFrom(rider.id || rider.name);
  const aadhaar = rider.aadhaarNumber || `9999${pad(n % 100000000, 8)}`;
  const pan = rider.panNumber || `BK${String.fromCharCode(65 + (n % 26))}${String.fromCharCode(65 + ((n >> 4) % 26))}P${pad(1000 + (n % 9000), 4)}F`;
  const account = rider.bankAccountNumber || `50100${pad(200000 + (n % 800000), 6)}`;
  const ifsc = rider.ifscCode || `HDFC0${pad(400 + (n % 500), 6).slice(-6)}`;
  const license = rider.drivingLicenseNumber || `GJ01 ${2018 + (n % 8)}${pad(10000 + (n % 80000), 7)}`;
  const joined = rider.joined || rider.onboardingDate || '12 Jan 2025';
  const address = rider.address || `${rider.zone || 'Ahmedabad'}, Ahmedabad`;
  const pincode = rider.pincode || extractPincodeLocal(address) || `3800${pad(n % 80, 2)}`;
  return {
    ...rider,
    email: rider.email || `${String(rider.name || 'rider').toLowerCase().replace(/[^a-z]+/g, '.')}@riders.idharudhar.in`,
    address,
    pincode,
    emergencyContact: rider.emergencyContact || rider.phone,
    onboardingDate: joined,
    joined,
    drivingLicenseNumber: license,
    licenseExpiry: rider.licenseExpiry || (rider.verification === 'Correction' ? '10 Jul 2026' : n % 7 === 0 ? '02 Sep 2026' : '18 Mar 2028'),
    aadhaarNumber: aadhaar,
    aadhaarMasked: maskAadhaar(aadhaar),
    panNumber: pan,
    panMasked: maskPan(pan),
    bankAccountNumber: account,
    bankMasked: maskBankAccount(account),
    ifscCode: ifsc,
    ifscMasked: maskIfsc(ifsc),
    rcNumber: rider.rcNumber || rider.vehicleNumber || NA,
    documents: rider.documents || {},
  };
}

const DOC_STATUS = ['Pending', 'Verified', 'Rejected'];

function normalizeDocStatus(value, fallback = 'Pending') {
  if (DOC_STATUS.includes(value)) return value;
  if (value === 'Approved' || value === 'Valid') return 'Verified';
  if (value === 'Expired' || value === 'Missing' || value === 'Blurry' || value === 'Mismatch') return 'Rejected';
  if (value === 'Correction' || value === 'Expiring' || value === 'Pending Verification' || value === 'Submitted') return 'Pending';
  return fallback;
}

function defaultDocumentStatus(rider, key) {
  const stored = rider.documents?.[key];
  if (stored) return normalizeDocStatus(stored);
  if (rider.verification === 'Approved') return 'Verified';
  if (rider.verification === 'Rejected') return key === 'photo' ? 'Pending' : 'Rejected';
  if (rider.verification === 'Correction') {
    if (key === 'drivingLicense') return 'Rejected';
    if (key === 'aadhaar' || key === 'rc' || key === 'photo') return 'Verified';
    return 'Pending';
  }
  if (key === 'pan' && rider.verification === 'Pending') return 'Pending';
  if (key === 'rc' || key === 'photo') return rider.verification === 'Pending' ? 'Pending' : 'Verified';
  return 'Pending';
}

export function riderDocumentsFor(rider = {}) {
  const profile = enrichRiderProfile(rider);
  return [
    { key: 'drivingLicense', label: 'Driving License', number: profile.drivingLicenseNumber, status: defaultDocumentStatus(profile, 'drivingLicense') },
    { key: 'rc', label: 'RC', number: profile.rcNumber, status: defaultDocumentStatus(profile, 'rc') },
    { key: 'aadhaar', label: 'Aadhaar', number: profile.aadhaarMasked, status: defaultDocumentStatus(profile, 'aadhaar'), redacted: true },
    { key: 'pan', label: 'PAN', number: profile.panNumber, status: defaultDocumentStatus(profile, 'pan') },
    { key: 'bank', label: 'Bank document', number: `${profile.bankMasked} · ${profile.ifscCode}`, status: defaultDocumentStatus(profile, 'bank') },
    { key: 'photo', label: 'Profile photo', number: 'Submitted', status: defaultDocumentStatus(profile, 'photo') },
  ];
}

export function enrichCustomerProfile(customer = {}) {
  const pincode = customer.pincode || extractPincodeLocal(customer.area) || '380015';
  return {
    ...customer,
    onboardingDate: customer.onboardingDate || customer.joined || 'N/A',
    location: customer.location || customer.area || 'Ahmedabad',
    pincode,
    email: customer.email || 'N/A',
    phone: customer.phone || 'N/A',
  };
}

export function enrichVehicleRecord(vehicle = {}, rider) {
  const type = vehicle.category || vehicle.type || rider?.vehicle || 'Bike';
  const twoWheeler = type === 'Bike' || type === 'Scooter';
  const number = vehicle.rcNumber || vehicle.number || rider?.vehicleNumber || '';
  const brands = {
    Bike: ['Hero', 'Honda', 'TVS', 'Bajaj'],
    Scooter: ['Honda', 'TVS', 'Suzuki'],
    Auto: ['Bajaj', 'Piaggio'],
    'Mini Truck': ['Tata', 'Mahindra'],
    Tempo: ['Piaggio', 'Force'],
    'Large Tempo': ['Force', 'Tata'],
    Truck: ['Tata', 'Ashok Leyland'],
    Van: ['Maruti', 'Tata'],
  };
  const models = {
    Hero: 'Splendor Plus',
    Honda: twoWheeler && type === 'Scooter' ? 'Activa 6G' : 'Shine',
    TVS: type === 'Scooter' ? 'Jupiter' : 'Raider',
    Bajaj: type === 'Auto' ? 'RE Compact' : 'Pulsar 125',
    Piaggio: type === 'Auto' ? 'Ape Auto' : 'Ape Xtra',
    Tata: type === 'Truck' ? 'LPT 1613' : 'Ace Gold',
    Mahindra: 'Jeeto',
    Force: 'Traveller',
    'Ashok Leyland': 'Dost Plus',
    Maruti: 'Eeco Cargo',
    Suzuki: 'Access 125',
  };
  const palette = ['White', 'Black', 'Blue', 'Silver', 'Red', 'Grey'];
  const n = Number(String(number).replace(/\D/g, '').slice(-2) || 1);
  const brand = vehicle.brand || (brands[type] || brands.Bike)[n % (brands[type] || brands.Bike).length];
  return {
    ...vehicle,
    number,
    rcNumber: number,
    category: type === 'Scooter' ? 'Bike' : type,
    type: type === 'Scooter' ? 'Bike' : type,
    twoWheelerType: twoWheeler ? (vehicle.twoWheelerType || (type === 'Scooter' || rider?.vehicle === 'Scooter' ? 'Scooter' : 'Bike')) : '',
    brand,
    model: vehicle.model || models[brand] || 'N/A',
    variant: vehicle.variant || (twoWheeler ? 'Drum / Standard' : 'Standard'),
    color: vehicle.color || palette[n % palette.length],
    rcExpiry: vehicle.rcExpiry || (vehicle.insurance === 'Expired' ? '12 Jun 2026' : '22 Jan 2028'),
    insuranceExpiry: vehicle.insuranceExpiry || (vehicle.insurance === 'Expiring' ? '05 Sep 2026' : vehicle.insurance === 'Expired' ? '01 Jul 2026' : '14 Feb 2028'),
  };
}
