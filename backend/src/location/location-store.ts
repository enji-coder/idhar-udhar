export const LOCATION_STORE = 'LOCATION_STORE';

export type LocationStoreBackend = 'memory';

export type RiderLocationFix = {
  riderProfileId: string;
  identityId: string;
  latitude: number;
  longitude: number;
  accuracyMeters: number | null;
  heading: number | null;
  speedMps: number | null;
  recordedAt: Date;
  receivedAt: Date;
};

export interface LocationStore {
  readonly backend: LocationStoreBackend;
  readonly durable: boolean;
  upsert(fix: RiderLocationFix): Promise<void>;
  get(riderProfileId: string): Promise<RiderLocationFix | null>;
}
