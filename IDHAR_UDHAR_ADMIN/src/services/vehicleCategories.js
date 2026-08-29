import { createEntityStore } from './entityStore';
import { orderStore, riderStore, vehicleStore } from './stores';
import {
  createAdminVehicleCategory,
  deleteAdminVehicleCategory,
  fetchAdminVehicleCategories,
  updateAdminVehicleCategory,
} from '../api/adminApi';
import { ApiError } from '../api/errors';

export const vehicleCategoryStore = createEntityStore('vehicle_categories_v2', [], { persist: false });

function normalizeName(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function toRates(form) {
  const number = (value) => {
    if (value === '' || value == null) return undefined;
    const amount = Number(value);
    return Number.isFinite(amount) ? amount : undefined;
  };
  return {
    base_fare: number(form.baseFare),
    per_km: number(form.perKmCharge),
    initial_minimum: number(form.initialMinimum ?? form.baseFare),
    waiting: number(form.waitingCharge),
    surge: number(form.surgeCharge),
    toll: number(form.tollCharge),
    parking: number(form.parkingCharge),
  };
}

function ratesHaveAmount(rates) {
  return Object.values(rates).some((value) => value != null && Number(value) > 0);
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
  return activeVehicleCategories()[0]?.name || '';
}

export function isTwoWheelerCategory(name) {
  const value = String(name || '').toLowerCase();
  return value === 'bike' || value === 'scooter' || value.includes('bike');
}

export function findVehicleCategoryByName(name, excludeId) {
  const target = normalizeName(name).toLowerCase();
  return listVehicleCategories().find((row) => row.id !== excludeId && normalizeName(row.name).toLowerCase() === target);
}

export function categoryUsage(nameOrRow) {
  if (nameOrRow && typeof nameOrRow === 'object' && nameOrRow.usage) {
    return nameOrRow.usage;
  }
  const target = normalizeName(nameOrRow).toLowerCase();
  const row = listVehicleCategories().find((item) => normalizeName(item.name).toLowerCase() === target);
  if (row?.usage) return row.usage;
  const vehicles = vehicleStore.getAll().filter((item) => normalizeName(item.category || item.type).toLowerCase() === target);
  const riders = riderStore.getAll().filter((item) => normalizeName(item.vehicle).toLowerCase() === target);
  const orders = orderStore.getAll().filter((item) => normalizeName(item.vehicle).toLowerCase() === target);
  return {
    vehicles: vehicles.length,
    riders: riders.length,
    orders: orders.length,
    total: vehicles.length + riders.length + orders.length,
  };
}

export function validateVehicleCategory(form, rows = listVehicleCategories()) {
  const name = normalizeName(form.name);
  const issues = {};
  if (!name) issues.name = 'Vehicle category name is required.';
  else if (rows.find((row) => row.id !== form.id && normalizeName(row.name).toLowerCase() === name.toLowerCase())) {
    issues.name = 'This vehicle category already exists.';
  }
  return { name, issues };
}

export async function syncVehicleCategories() {
  const rows = await fetchAdminVehicleCategories();
  vehicleCategoryStore.replace(rows);
  return rows;
}

export async function saveVehicleCategory(form) {
  const rows = listVehicleCategories();
  const { name, issues } = validateVehicleCategory(form, rows);
  if (Object.keys(issues).length) return { ok: false, issues };
  const rates = toRates(form);
  const payload = {
    name,
    active: form.status !== 'Inactive',
    weight_capacity: form.weightCapacityKg ? String(form.weightCapacityKg) : '',
    size: form.size ? String(form.size) : '',
    ...(ratesHaveAmount(rates) ? { rates } : {}),
  };
  try {
    const record = form.id
      ? await updateAdminVehicleCategory(form.id, payload)
      : await createAdminVehicleCategory(payload);
    await syncVehicleCategories();
    return { ok: true, record };
  } catch (error) {
    if (error instanceof ApiError && error.code === 'VEHICLE_CATEGORY_NAME_TAKEN') {
      return { ok: false, issues: { name: error.message } };
    }
    throw error;
  }
}

export async function deactivateVehicleCategory(id) {
  await updateAdminVehicleCategory(id, { active: false });
  await syncVehicleCategories();
}

export async function activateVehicleCategory(id) {
  await updateAdminVehicleCategory(id, { active: true });
  await syncVehicleCategories();
}

export async function deleteVehicleCategory(id) {
  const row = listVehicleCategories().find((item) => item.id === id);
  if (!row) return { ok: false, message: 'Vehicle category not found.' };
  const usage = categoryUsage(row);
  if (usage.total > 0) {
    return {
      ok: false,
      inUse: true,
      usage,
      message: 'Cannot delete this vehicle category because it is already used by published fare data or other protected records. Please deactivate it instead.',
    };
  }
  try {
    await deleteAdminVehicleCategory(id);
    await syncVehicleCategories();
    return { ok: true };
  } catch (error) {
    if (error instanceof ApiError && error.code === 'VEHICLE_CATEGORY_IN_USE') {
      return {
        ok: false,
        inUse: true,
        usage,
        message: error.message,
      };
    }
    throw error;
  }
}
