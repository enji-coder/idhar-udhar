import { Injectable } from '@nestjs/common';
import {
  LocationStore,
  LocationStoreBackend,
  RiderLocationFix,
} from './location-store';

/**
 * Process-local last-known fix. Lost on restart.
 * Does not write PostgreSQL. Does not pretend Redis durability.
 */
@Injectable()
export class MemoryLocationStore implements LocationStore {
  readonly backend: LocationStoreBackend = 'memory';
  readonly durable = false;
  private readonly byRider = new Map<string, RiderLocationFix>();

  async upsert(fix: RiderLocationFix): Promise<void> {
    this.byRider.set(fix.riderProfileId, fix);
  }

  async get(riderProfileId: string): Promise<RiderLocationFix | null> {
    return this.byRider.get(riderProfileId) ?? null;
  }
}
