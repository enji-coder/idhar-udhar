import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ApiError, mapApiError } from './errors.js';

describe('admin API errors', () => {
  it('maps known codes to friendly copy', () => {
    const error = mapApiError({ error: { code: 'INVALID_CREDENTIALS', message: 'nope', request_id: 'req-1' } }, 401);
    assert.equal(error instanceof ApiError, true);
    assert.equal(error.message, 'Invalid email or password.');
    assert.equal(error.requestId, 'req-1');
  });

  it('hides SQL-looking messages', () => {
    const error = mapApiError({ error: { code: 'INTERNAL_ERROR', message: 'relation orders does not exist' } }, 500);
    assert.equal(error.message, 'Something went wrong. Try again.');
  });

  it('maps a network failure without dummy fallback copy', () => {
    const error = mapApiError({ error: { code: 'NETWORK_ERROR', message: 'Cannot reach the API at http://localhost:3000.' } }, 0);
    assert.equal(error.message, 'Cannot reach the local API. Confirm NestJS is running on http://localhost:3000.');
  });
});
