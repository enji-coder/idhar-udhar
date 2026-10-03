import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const envText = readFileSync(new URL('../.env', import.meta.url), 'utf8');
const m = envText.match(/^DATABASE_PASSWORD=(.*)$/m);
const be = (m?.[1] ?? '').trim().replace(/^['"]|['"]$/g, '');
const cp = execSync('docker exec idhar_udhar_postgres printenv POSTGRES_PASSWORD', {
  encoding: 'utf8',
}).trim();
console.log(
  JSON.stringify({
    be_len: be.length,
    cp_len: cp.length,
    equal: be === cp,
    be_has_cr: be.includes('\r'),
    cp_has_cr: cp.includes('\r'),
    be_first: be ? be.charCodeAt(0) : null,
    cp_first: cp ? cp.charCodeAt(0) : null,
    be_last: be ? be.charCodeAt(be.length - 1) : null,
    cp_last: cp ? cp.charCodeAt(cp.length - 1) : null,
  }),
);
