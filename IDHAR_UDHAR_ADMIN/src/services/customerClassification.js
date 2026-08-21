import { CUSTOMER_CATEGORIES } from '../config/status';

export { CUSTOMER_CATEGORIES };

export function classifyCustomer(customer, orders = []) {
  if (customer?.account === 'Inactive' || customer?.status === 'Inactive') return 'Inactive';
  if (customer?.status === 'New' || customer?.status === 'Repeat' || customer?.status === 'Active') {
    return customer.status;
  }
  const related = orders.filter((order) => order.customerId === customer?.id || order.customer === customer?.name);
  const count = related.length || Number(customer?.orders || 0);
  if (count <= 1) return 'New';
  if (count >= 20) return 'Repeat';
  return 'Active';
}

export function categoryLabel(category) {
  if (category === 'New') return 'New Customer';
  if (category === 'Repeat') return 'Returning Customer';
  if (category === 'Inactive') return 'Inactive Customer';
  return 'Active Customer';
}
