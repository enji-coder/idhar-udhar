import { customerResendCharge, riderOfficeCompensation } from '../src/services/failedDelivery.js';
import { quoteFare } from '../src/services/fareEngine.js';

function assert(cond, msg) {
  if (!cond) {
    console.error('FAIL', msg);
    process.exitCode = 1;
    return;
  }
  console.log('ok', msg);
}

assert(riderOfficeCompensation(5) === 40, 'Scenario D: 5km × ₹8 = ₹40');
assert(customerResendCharge(5) === 50, 'Scenario E: 5km × ₹10 = ₹50');

const oldQuote = quoteFare({ baseFare: 40, perKmCharge: 0, initialMinimum: 40, fareVersionId: 'bike_40' }, 0);
const newQuote = quoteFare({ baseFare: 50, perKmCharge: 0, initialMinimum: 50, fareVersionId: 'bike_50' }, 0);
assert(oldQuote.netTotal === 40 && oldQuote.tax === 0, 'Scenario H: old snapshot ₹40 / no GST');
assert(newQuote.netTotal === 50, 'Scenario H: new config ₹50');
assert(oldQuote.configVersionId === 'bike_40', 'Scenario H: version frozen on quote');

if (process.exitCode) {
  process.exit(1);
}
console.log('Admin business-rule checks passed');
