import { json, readCookie, readSessionToken } from './lib/session.js';

const DEFAULT_CATEGORIES = [
  { id: 'VC-1001', name: 'Bike', status: 'Active', createdAt: '2026-01-12T09:00:00.000Z', updatedAt: '2026-01-12T09:00:00.000Z', available: true },
  { id: 'VC-1002', name: 'Auto', status: 'Active', createdAt: '2026-01-12T09:00:00.000Z', updatedAt: '2026-01-12T09:00:00.000Z', available: true },
  { id: 'VC-1003', name: 'Mini Truck', status: 'Active', createdAt: '2026-01-12T09:00:00.000Z', updatedAt: '2026-01-12T09:00:00.000Z', available: true },
  { id: 'VC-1004', name: 'Tempo', status: 'Active', createdAt: '2026-01-12T09:00:00.000Z', updatedAt: '2026-01-12T09:00:00.000Z', available: true },
  { id: 'VC-1005', name: 'Large Tempo', status: 'Active', createdAt: '2026-01-12T09:00:00.000Z', updatedAt: '2026-01-12T09:00:00.000Z', available: true },
  { id: 'VC-1006', name: 'Truck', status: 'Active', createdAt: '2026-01-12T09:00:00.000Z', updatedAt: '2026-01-12T09:00:00.000Z', available: true },
];

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function reply(statusCode, body) {
  return json(statusCode, body, CORS);
}

let memory = structuredClone(DEFAULT_CATEGORIES);

async function store() {
  try {
    const { getStore } = await import('@netlify/blobs');
    return getStore('vehicle-categories');
  } catch {
    return null;
  }
}

async function readCategories() {
  const blob = await store();
  if (!blob) return memory;
  try {
    const stored = await blob.get('catalog', { type: 'json' });
    if (Array.isArray(stored) && stored.length) return stored;
  } catch {
    /* keep seed */
  }
  return memory;
}

async function writeCategories(rows) {
  memory = rows;
  const blob = await store();
  if (!blob) return;
  await blob.setJSON('catalog', rows);
}

function isAdmin(event) {
  return Boolean(readSessionToken(readCookie(event)));
}

export async function handler(event) {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: { ...CORS, 'Cache-Control': 'no-store' } };
  }

  if (event.httpMethod === 'GET') {
    const rows = await readCategories();
    const publicOnly = event.queryStringParameters?.all !== '1';
    const categories = publicOnly ? rows.filter((row) => row.status !== 'Inactive') : rows;
    return reply(200, { success: true, categories });
  }

  if (event.httpMethod === 'PUT') {
    if (!isAdmin(event)) return reply(401, { success: false, message: 'Unauthorized.' });
    let payload = {};
    try {
      payload = JSON.parse(event.body || '{}');
    } catch {
      payload = {};
    }
    const categories = Array.isArray(payload.categories) ? payload.categories : [];
    const cleaned = categories
      .map((row) => ({
        id: String(row.id || '').trim(),
        name: String(row.name || '').replace(/\s+/g, ' ').trim(),
        status: row.status === 'Inactive' ? 'Inactive' : 'Active',
        createdAt: row.createdAt || new Date().toISOString(),
        updatedAt: row.updatedAt || new Date().toISOString(),
        available: Boolean(row.available),
      }))
      .filter((row) => row.id && row.name);
    await writeCategories(cleaned.length ? cleaned : DEFAULT_CATEGORIES);
    return reply(200, { success: true, categories: await readCategories() });
  }

  return reply(405, { success: false, message: 'Method not allowed.' });
}
