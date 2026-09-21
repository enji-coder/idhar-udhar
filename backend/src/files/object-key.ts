import { UUID_RE } from '../common/uuid-param.pipe';

function assertUuidSegment(value: string, label: string): string {
  if (!UUID_RE.test(value)) {
    throw new Error(`Unsafe ${label} in object key`);
  }
  return value.toLowerCase();
}

export function safeFileName(
  originalName: string | undefined,
  contentType: string,
): string {
  const raw = (originalName ?? 'file').replace(/\\/g, '/');
  const base = raw.split('/').pop() ?? 'file';
  const lower = base.toLowerCase();
  let ext = extensionForContentType(contentType);
  if (lower.endsWith('.jpeg') || lower.endsWith('.jpg')) {
    ext = '.jpg';
  } else if (lower.endsWith('.png')) {
    ext = '.png';
  } else if (lower.endsWith('.pdf')) {
    ext = '.pdf';
  }
  const stem = base
    .replace(/\.[^.]+$/, '')
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .replace(/^\.+/, '')
    .slice(0, 64);
  const name = `${stem || 'file'}${ext}`;
  if (name.includes('..') || name.includes('/') || name.includes('\\')) {
    return `file${ext}`;
  }
  return name;
}

export function extensionForContentType(contentType: string): string {
  if (contentType === 'image/jpeg') {
    return '.jpg';
  }
  if (contentType === 'image/png') {
    return '.png';
  }
  if (contentType === 'application/pdf') {
    return '.pdf';
  }
  return '.bin';
}

export function riderDocumentObjectKey(input: {
  riderProfileId: string;
  documentId: string;
  fileName: string;
}): string {
  const riderProfileId = assertUuidSegment(input.riderProfileId, 'riderProfileId');
  const documentId = assertUuidSegment(input.documentId, 'documentId');
  const fileName = safeFileName(input.fileName, '');
  return `riders/${riderProfileId}/documents/${documentId}/${fileName}`;
}

export function orderPodObjectKey(input: {
  orderId: string;
  stopId: string;
  fileName: string;
}): string {
  const orderId = assertUuidSegment(input.orderId, 'orderId');
  const stopId = assertUuidSegment(input.stopId, 'stopId');
  const fileName = safeFileName(input.fileName, '');
  return `orders/${orderId}/pod/${stopId}/${fileName}`;
}

export function fileNameFromStorageKey(storageKey: string): string {
  const segment = storageKey.replace(/\\/g, '/').split('/').pop();
  return safeFileName(segment, '');
}
