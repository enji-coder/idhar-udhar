import { calculateDistribution, round2 } from './commission.js';
import { loadCompanyOffice } from './companyOfficeStore.js';

export const RIDER_OFFICE_PER_KM = 8;
export const CUSTOMER_RESEND_PER_KM = 10;
export const CASE_B_RIDER_PER_KM = 8;
export const CASE_B_COMPANY_PER_KM = 2;

export const RESEND_STATUSES = [
  'not_decided',
  'resend_requested',
  'resend_in_progress',
  'resend_completed',
  'none',
];

export function riderOfficeCompensation(distanceKm) {
  return round2(Number(distanceKm || 0) * RIDER_OFFICE_PER_KM);
}

export function customerResendCharge(distanceKm) {
  return round2(Number(distanceKm || 0) * CUSTOMER_RESEND_PER_KM);
}

/** Case A: trip ended. Case B: trip still active. */
export function quoteResend({ originalTripEnded, distanceKm = 0, baseFare = 0, settings } = {}) {
  const km = Math.max(0, Number(distanceKm) || 0);
  const surcharge = customerResendCharge(km);
  if (originalTripEnded) {
    const trip = calculateDistribution(baseFare, settings);
    const extra = calculateDistribution(surcharge, settings);
    return {
      resendCase: 'ended',
      distanceKm: km,
      baseFare: round2(baseFare),
      resendSurcharge: surcharge,
      customerPays: round2(Number(baseFare || 0) + surcharge),
      riderAmount: round2(trip.riderAmount + extra.riderAmount),
      companyAmount: round2(trip.companyCommission + extra.companyCommission),
    };
  }
  return {
    resendCase: 'active',
    distanceKm: km,
    baseFare: 0,
    resendSurcharge: surcharge,
    customerPays: surcharge,
    riderAmount: round2(km * CASE_B_RIDER_PER_KM),
    companyAmount: round2(km * CASE_B_COMPANY_PER_KM),
  };
}

export function openFailedDelivery(order, { officeDistanceKm = 5 } = {}) {
  const office = loadCompanyOffice();
  const compensation = riderOfficeCompensation(officeDistanceKm);
  return {
    ...order,
    status: 'Failed',
    canonicalStatus: 'failedDelivery',
    failureReason: 'Receiver Unavailable',
    companyOffice: office.name,
    companyOfficeAddress: office.address,
    companyOfficeLat: office.latitude,
    companyOfficeLng: office.longitude,
    officeDistanceKm,
    riderOfficeCompensation: compensation,
    resendStatus: 'not_decided',
    resendCharge: 0,
    originalDestination: order.destination || order.destinationAddress,
    customerNotified: true,
  };
}

export function applyResend(order, { resendDistanceKm = 5, resendOrderId, originalTripEnded = true } = {}) {
  const quote = quoteResend({
    originalTripEnded,
    distanceKm: resendDistanceKm,
    baseFare: originalTripEnded ? (order.tripFare ?? order.amount ?? 0) : 0,
  });
  return {
    ...order,
    resendStatus: 'resend_requested',
    resendCharge: quote.customerPays,
    resendSurcharge: quote.resendSurcharge,
    resendDistanceKm,
    resendOrderId,
    resendCase: quote.resendCase,
    resendRiderAmount: quote.riderAmount,
    resendCompanyAmount: quote.companyAmount,
  };
}

export function resendStatusLabel(value) {
  switch (value) {
    case 'resend_requested':
      return 'Requested resend';
    case 'resend_in_progress':
      return 'Resend in progress';
    case 'resend_completed':
      return 'Resend completed';
    case 'not_decided':
      return 'Has not decided yet';
    default:
      return 'Has not requested resend';
  }
}
