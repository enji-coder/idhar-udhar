import { RIDER_DOCUMENT_TYPES, RiderDocumentType } from './file-validation';

const LABELS: Record<RiderDocumentType, string> = {
  AADHAAR_FRONT: 'Aadhaar (front)',
  AADHAAR_BACK: 'Aadhaar (back)',
  PAN_FRONT: 'PAN',
  DRIVING_LICENSE_FRONT: 'Driving Licence (front)',
  DRIVING_LICENSE_BACK: 'Driving Licence (back)',
  VEHICLE_RC_FRONT: 'Vehicle RC (front)',
  VEHICLE_RC_BACK: 'Vehicle RC (back)',
  BANK_PROOF: 'Bank verification',
};

/** Human-readable document name for rider notifications. */
export function riderDocumentLabel(documentType: string): string {
  if ((RIDER_DOCUMENT_TYPES as readonly string[]).includes(documentType)) {
    return LABELS[documentType as RiderDocumentType];
  }
  return documentType
    .split('_')
    .filter((part) => part.length > 0)
    .map((part) => part.charAt(0) + part.slice(1).toLowerCase())
    .join(' ');
}
