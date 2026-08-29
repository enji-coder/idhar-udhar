import test from 'node:test';
import assert from 'node:assert/strict';
import { ROLES, can, canAccessPath, filterNav } from './permissions.js';
import { navSections } from '../data/navigation.js';

const GST = '/gst-reports';

test('GST Reports is reachable only by finance-facing roles', () => {
  assert.equal(canAccessPath({ role: ROLES.SUPER_ADMIN }, GST), true);
  assert.equal(canAccessPath({ role: ROLES.FINANCE }, GST), true);
  assert.equal(canAccessPath({ role: ROLES.SUPPORT }, GST), false);
  assert.equal(canAccessPath({ role: ROLES.OPERATIONS }, GST), false);
  assert.equal(canAccessPath({ role: ROLES.MANAGER }, GST), false);
  assert.equal(canAccessPath(null, GST), false);
});

test('withdrawing finance access closes GST Reports', () => {
  assert.equal(canAccessPath({ role: ROLES.FINANCE, financeAccess: false }, GST), false);
  assert.equal(
    canAccessPath({ role: ROLES.SUB_ADMIN, modules: ['reports'], financeAccess: false }, GST),
    false,
  );
  assert.equal(canAccessPath({ role: ROLES.FINANCE, status: 'Inactive' }, GST), false);
});

test('a sub admin needs a granting module', () => {
  assert.equal(canAccessPath({ role: ROLES.SUB_ADMIN, modules: ['reports'] }, GST), true);
  assert.equal(canAccessPath({ role: ROLES.SUB_ADMIN, modules: ['finance'] }, GST), true);
  assert.equal(canAccessPath({ role: ROLES.SUB_ADMIN, modules: ['orders'] }, GST), false);
});

test('only roles the backend accepts may publish a GST version', () => {
  assert.equal(can({ role: ROLES.SUPER_ADMIN }, 'gstReports', 'configure'), true);
  assert.equal(can({ role: ROLES.FINANCE }, 'gstReports', 'configure'), true);
  assert.equal(can({ role: ROLES.MANAGER }, 'gstReports', 'configure'), false);
  assert.equal(can({ role: ROLES.SUB_ADMIN, modules: ['reports'] }, 'gstReports', 'configure'), false);
});

test('export follows view for the roles that can open the page', () => {
  assert.equal(can({ role: ROLES.FINANCE }, 'gstReports', 'export'), true);
  assert.equal(can({ role: ROLES.SUB_ADMIN, modules: ['reports'] }, 'gstReports', 'export'), true);
  assert.equal(can({ role: ROLES.SUPPORT }, 'gstReports', 'export'), false);
});

test('the nav item sits in Finance and disappears without finance access', () => {
  const finance = filterNav(navSections, { role: ROLES.FINANCE });
  const section = finance.find((item) => item.title === 'Finance');
  assert.ok(section, 'Finance section should be present');
  assert.ok(section.items.some((item) => item.path === GST && item.label === 'GST Reports'));

  const blocked = filterNav(navSections, { role: ROLES.FINANCE, financeAccess: false });
  assert.equal(blocked.some((item) => item.title === 'Finance'), false);
  assert.equal(
    blocked.flatMap((item) => item.items).some((item) => item.path === GST),
    false,
  );

  const support = filterNav(navSections, { role: ROLES.SUPPORT });
  assert.equal(
    support.flatMap((item) => item.items).some((item) => item.path === GST),
    false,
  );
});

test('existing page access is unchanged', () => {
  assert.equal(canAccessPath({ role: ROLES.FINANCE }, '/earnings'), true);
  assert.equal(canAccessPath({ role: ROLES.OPERATIONS }, '/orders'), true);
  assert.equal(canAccessPath({ role: ROLES.OPERATIONS }, '/earnings'), false);
  assert.equal(canAccessPath({ role: ROLES.MANAGER }, '/payments'), true);
  assert.equal(canAccessPath({ role: ROLES.FINANCE }, '/settings'), false);
  assert.equal(canAccessPath({ role: ROLES.SUB_ADMIN, modules: ['reports'] }, '/reports'), true);
});
