import { defaultVehicleCategories } from '../data/vehicleCategories';
import { nextId } from '../utils/ids';
import { DEFAULT_FARE_BY_CATEGORY, emptyFareFields, publishFareVersion } from './fareEngine';
import { createEntityStore } from './entityStore';
import { orderStore, riderStore, vehicleStore } from './stores';

export const vehicleCategoryStore = createEntityStore('vehicle_categories_v1', defaultVehicleCategories);

const CATEGORY_API = '/.netlify/functions/vehicle-categories';

function normalizeName(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function nowIso() {
  return new Date().toISOString();
}

export function listVehicleCategories() {
  return vehicleCategoryStore.getAll();
}

export function activeVehicleCategories() {
  return listVehicleCategories().filter((row) => row.status !== 'Inactive');
}

export function vehicleCategoryNames({ includeInactive = false, current } = {}) {
  const rows = includeInactive ? listVehicleCategories() : activeVehicleCategories();
  const names = rows.map((row) => row.name).filter(Boolean);
  if (current && !names.includes(current)) return [current, ...names];
  return names;
}

export function defaultVehicleCategoryName() {
  return activeVehicleCategories()[0]?.name || 'Bike';
}

export function isTwoWheelerCategory(name) {
  const value = String(name || '').toLowerCase();
  return value === 'bike' || value === 'scooter' || value.includes('bike');
}

export function findVehicleCategoryByName(name, excludeId) {
  const target = normalizeName(name).toLowerCase();
  return listVehicleCategories().find((row) => row.id !== excludeId && normalizeName(row.name).toLowerCase() === target);
}

export function categoryUsage(name) {
  const target = normalizeName(name).toLowerCase();
  const vehicles = vehicleStore.getAll().filter((row) => normalizeName(row.category || row.type).toLowerCase() === target);
  const riders = riderStore.getAll().filter((row) => normalizeName(row.vehicle).toLowerCase() === target);
  const orders = orderStore.getAll().filter((row) => normalizeName(row.vehicle).toLowerCase() === target);
  return {
    vehicles: vehicles.length,
    riders: riders.length,
    orders: orders.length,
    total: vehicles.length + riders.length + orders.length,
  };
}

export function renameCategoryUsage(fromName, toName) {
  const from = normalizeName(fromName);
  const to = normalizeName(toName);
  if (!from || !to || from.toLowerCase() === to.toLowerCase()) return;
  vehicleStore.getAll().forEach((row) => {
    if (normalizeName(row.category || row.type).toLowerCase() === from.toLowerCase()) {
      vehicleStore.patch(row.id, { category: to, type: to });
    }
  });
  riderStore.getAll().forEach((row) => {
    if (normalizeName(row.vehicle).toLowerCase() === from.toLowerCase()) {
      riderStore.patch(row.id, { vehicle: to });
    }
  });
  orderStore.getAll().forEach((row) => {
    if (normalizeName(row.vehicle).toLowerCase() === from.toLowerCase()) {
      orderStore.patch(row.id, { vehicle: to });
    }
  });
}

export function validateVehicleCategory(form, rows = listVehicleCategories()) {
  const name = normalizeName(form.name);
  const issues = {};
  if (!name) issues.name = 'Vehicle category name is required.';
  else if (findVehicleCategoryByName(name, form.id)) issues.name = 'This vehicle category already exists.';
  return { name, issues };
}

export function saveVehicleCategory(form) {
  const rows = listVehicleCategories();
  const { name, issues } = validateVehicleCategory(form, rows);
  if (Object.keys(issues).length) return { ok: false, issues };
  const existing = form.id ? rows.find((row) => row.id === form.id) : null;
  const previousName = existing?.name;
  const stamp = nowIso();
  const record = {
    id: existing?.id || nextId('VC', rows),
    name,
    status: form.status === 'Inactive' ? 'Inactive' : 'Active',
    createdAt: existing?.createdAt || stamp,
    updatedAt: stamp,
    ...emptyFareFields(),
    ...(DEFAULT_FARE_BY_CATEGORY[name] || {}),
    baseFare: Number(form.baseFare ?? existing?.baseFare ?? DEFAULT_FARE_BY_CATEGORY[name]?.baseFare ?? 0),
    perKmCharge: Number(form.perKmCharge ?? existing?.perKmCharge ?? 0),
    initialMinimum: Number(form.initialMinimum ?? existing?.initialMinimum ?? form.baseFare ?? 0),
    waitingCharge: Number(form.waitingCharge ?? existing?.waitingCharge ?? 0),
    surgeCharge: Number(form.surgeCharge ?? existing?.surgeCharge ?? 0),
    tollCharge: Number(form.tollCharge ?? existing?.tollCharge ?? 0),
    parkingCharge: Number(form.parkingCharge ?? existing?.parkingCharge ?? 0),
    weightCapacityKg: form.weightCapacityKg ?? existing?.weightCapacityKg ?? DEFAULT_FARE_BY_CATEGORY[name]?.weightCapacityKg ?? '',
    size: form.size ?? existing?.size ?? DEFAULT_FARE_BY_CATEGORY[name]?.size ?? '',
    fareVersionId: `fare_${existing?.id || 'new'}_${Date.now()}`,
  };
  if (existing) {
    publishFareVersion(record.id, record);
  }
  vehicleCategoryStore.upsert(record);
  if (existing && previousName && previousName !== name) renameCategoryUsage(previousName, name);
  syncVehicleCategories();
  return { ok: true, record };
}

export function deactivateVehicleCategory(id) {
  vehicleCategoryStore.patch(id, { status: 'Inactive', updatedAt: nowIso() });
  syncVehicleCategories();
}

export function activateVehicleCategory(id) {
  vehicleCategoryStore.patch(id, { status: 'Active', updatedAt: nowIso() });
  syncVehicleCategories();
}

export function deleteVehicleCategory(id) {
  const row = listVehicleCategories().find((item) => item.id === id);
  if (!row) return { ok: false, message: 'Vehicle category not found.' };
  const usage = categoryUsage(row.name);
  if (usage.total > 0) {
    return {
      ok: false,
      inUse: true,
      usage,
      message: 'Cannot delete this vehicle category because it is currently being used. Please deactivate it instead.',
    };
  }
  vehicleCategoryStore.remove(id);
  syncVehicleCategories();
  return { ok: true };
}

function withAvailability(rows) {
  const vehicles = vehicleStore.getAll();
  return rows.map((row) => {
    const usage = categoryUsage(row.name);
    const available = vehicles.some((item) => {
      const type = normalizeName(item.category || item.type).toLowerCase();
      const live = item.status === 'Active' || item.status === 'Available' || item.status === 'Busy';
      return type === normalizeName(row.name).toLowerCase() && live;
    });
    return { ...row, available, usageCount: usage.total };
  });
}

export async function syncVehicleCategories() {
  try {
    await fetch(CATEGORY_API, {
      method: 'PUT',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ categories: withAvailability(listVehicleCategories()) }),
    });
  } catch {
    /* local store remains source of truth */
  }
}
