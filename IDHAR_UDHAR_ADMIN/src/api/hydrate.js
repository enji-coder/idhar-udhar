import { customerStore, orderStore, paymentStore, riderStore, vehicleStore, zoneStore } from '../services/stores';
import { vehicleCategoryStore } from '../services/vehicleCategories';
import {
  fetchAdminCustomers,
  fetchAdminOrders,
  fetchAdminPayments,
  fetchAdminRiders,
  fetchAdminVehicleCategories,
  fetchAdminVehicles,
  fetchAdminZones,
} from './adminApi';
import { setDirectoryError, setDirectoryLoading } from './directory';
import { ApiError } from './errors';

export function resetAdminDirectory() {
  orderStore.replace([]);
  riderStore.replace([]);
  customerStore.replace([]);
  paymentStore.replace([]);
  vehicleCategoryStore.replace([]);
  vehicleStore.replace([]);
  zoneStore.replace([]);
  setDirectoryError(null);
  setDirectoryLoading(true);
}

async function hydrateCatalog() {
  const [categories, vehicles, zones] = await Promise.allSettled([
    fetchAdminVehicleCategories(),
    fetchAdminVehicles(),
    fetchAdminZones(),
  ]);
  vehicleCategoryStore.replace(categories.status === 'fulfilled' ? categories.value : []);
  vehicleStore.replace(vehicles.status === 'fulfilled' ? vehicles.value : []);
  zoneStore.replace(zones.status === 'fulfilled' ? zones.value : []);
}

export async function hydrateAdminDirectory({ silent = false } = {}) {
  if (!silent) {
    setDirectoryLoading(true);
    setDirectoryError(null);
  }
  try {
    const [orders, riders, customers] = await Promise.all([
      fetchAdminOrders(),
      fetchAdminRiders(),
      fetchAdminCustomers(),
    ]);
    orderStore.replace(orders);
    riderStore.replace(riders);
    customerStore.replace(customers.map((row) => mapCustomerWithOrders(row, orders)));
    try {
      paymentStore.replace(await fetchAdminPayments());
    } catch (error) {
      paymentStore.replace([]);
      if (!(error instanceof ApiError && error.status === 403)) {
        setDirectoryError(error);
        throw error;
      }
    }
    try {
      await hydrateCatalog();
    } catch {
      vehicleCategoryStore.replace([]);
      vehicleStore.replace([]);
      zoneStore.replace([]);
    }
    setDirectoryError(null);
  } catch (error) {
    orderStore.replace([]);
    riderStore.replace([]);
    customerStore.replace([]);
    paymentStore.replace([]);
    vehicleCategoryStore.replace([]);
    vehicleStore.replace([]);
    zoneStore.replace([]);
    setDirectoryError(error);
    throw error;
  } finally {
    if (!silent) setDirectoryLoading(false);
  }
}

function mapCustomerWithOrders(customer, orders) {
  const related = Array.isArray(orders) ? orders.filter((order) => order.customerId === customer.id) : [];
  const spent = related.reduce((sum, order) => sum + Number(order.tripFare || order.amount || 0), 0);
  return { ...customer, orders: related.length, spent };
}
